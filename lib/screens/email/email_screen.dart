import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/email.dart';
import '../../models/email_account.dart';
import '../../services/email_account_service.dart';
import '../../services/email_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/labeled_field.dart' show FieldFocusBox;
import '../../widgets/email/compose_modal.dart';
import '../../theme/app_palette.dart';

class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  // Folder state
  String _folder      = 'inbox';
  List<String> _serverFolders = [];

  // Email list
  List<Email> _emails    = [];
  bool        _loading   = true;
  bool        _syncing   = false;
  String?     _loadError;
  int         _selectedIdx = -1;
  int         _unread    = 0;

  // UI state
  int  _narrowPane   = 1; // 0=folders 1=list 2=reading

  // Account
  List<EmailAccount> _accounts = [];
  bool _checkingAccounts = true;

  Email? get _selected =>
      _selectedIdx >= 0 && _selectedIdx < _emails.length ? _emails[_selectedIdx] : null;

  // ── Init ───────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Stale-while-revalidate: skip both the account-check spinner and the
    // email-list spinner on a return visit when we already know accounts
    // exist and have the current folder's emails cached — same reasoning
    // as MachineListScreen.
    final cachedAccounts = EmailAccountService.cachedAccounts;
    if (cachedAccounts != null) {
      _accounts = cachedAccounts;
      _checkingAccounts = false;
    }
    final cachedEmails = EmailService.cachedByFolder[_folder];
    if (cachedEmails != null) {
      _emails = cachedEmails;
      _loading = false;
    }
    // 1. Check if any account is configured
    try {
      final accounts = await EmailAccountService.instance.list();
      if (!mounted) return;
      setState(() { _accounts = accounts; _checkingAccounts = false; });
      if (accounts.isEmpty) return; // Screen shows "set up account" prompt
    } catch (_) {
      if (mounted) setState(() => _checkingAccounts = false);
      return;
    }
    // 2. Load emails immediately — sync runs in background and doesn't block
    _sync(silent: true);   // fire-and-forget: IMAP failures won't delay inbox load
    await Future.wait([_loadFolders(), _loadUnread(), _loadEmails()]);
  }

  Future<void> _sync({bool silent = false}) async {
    if (!silent) setState(() => _syncing = true);
    try {
      await EmailService.instance.sync(
        folder: _folder == 'inbox' ? 'INBOX' : _folder.toUpperCase(),
      );
    } catch (_) {} // Sync failure is non-fatal — cached data still shows
    if (mounted && !silent) setState(() => _syncing = false);
  }

  Future<void> _loadFolders() async {
    try {
      final f = await EmailService.instance.folders();
      if (mounted && f.isNotEmpty) setState(() => _serverFolders = f);
    } catch (_) {
      // Non-fatal — keeps the default folder list.
    }
  }

  Future<void> _loadUnread() async {
    try {
      final n = await EmailService.instance.unreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {
      // Non-fatal — keeps the last known unread count.
    }
  }

  Future<void> _loadEmails() async {
    setState(() {
      if (_emails.isEmpty) _loading = true;
      _loadError = null;
      _selectedIdx = -1;
    });
    try {
      final list = await _fetchForFolder(_folder);
      if (!mounted) return;
      setState(() { _emails = list; _loading = false; });
      if (list.isNotEmpty) _selectAt(0, autoMark: false);
    } catch (e) {
      if (mounted) setState(() { _loadError = friendlyError(e); _loading = false; });
    }
  }

  Future<List<Email>> _fetchForFolder(String folder) {
    return switch (folder) {
      'inbox'  => EmailService.instance.inbox(),
      'sent'   => EmailService.instance.sent(),
      'drafts' => EmailService.instance.drafts(),
      _        => EmailService.instance.folder(folder),
    };
  }

  Future<void> _refresh() async {
    setState(() => _syncing = true);
    _sync(silent: true);  // fire-and-forget
    await Future.wait([_loadEmails(), _loadUnread()]);
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _switchFolder(String folder) async {
    // Switching folders is an identity change, same as
    // MachineDetailScreen's didUpdateWidget on a changed id — leaving the
    // OLD folder's emails showing under the NEW folder would be actively
    // wrong, so seed from that folder's own cache entry (or empty) rather
    // than carrying the previous folder's list over.
    final cached = EmailService.cachedByFolder[folder];
    setState(() {
      _folder = folder;
      _narrowPane = 1;
      _emails = cached ?? [];
      _selectedIdx = -1;
    });
    await _loadEmails();
  }

  Future<void> _selectAt(int i, {bool autoMark = true}) async {
    setState(() { _selectedIdx = i; _narrowPane = 2; });
    final email = _emails[i];
    if (autoMark && !email.isRead) {
      try {
        await EmailService.instance.toggleRead(email.id);
        if (mounted) {
          setState(() {
            _emails[i] = email.copyWith(isRead: true);
            if (_unread > 0) _unread--;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _toggleFlag(int i) async {
    final email = _emails[i];
    try {
      await EmailService.instance.toggleFlag(email.id);
      if (mounted) {
        setState(() => _emails[i] = email.copyWith(isFlagged: !email.isFlagged));
      }
    } catch (_) {}
  }

  Future<void> _deleteEmail(int i) async {
    final email = _emails[i];
    try {
      await EmailService.instance.delete(email.id);
      if (mounted) {
        setState(() {
          _emails.removeAt(i);
          _selectedIdx = _emails.isNotEmpty ? 0 : -1;
        });
        _loadUnread();
      }
    } catch (_) {}
  }

  // showDialog gives the modal the whole window as its route, not just this
  // screen's own content pane — stacking it as a bare Stack child (the old
  // approach) only got it the email screen's own bounds, which is why it
  // rendered cramped and undimmed instead of as a real full-screen overlay.
  void _openCompose() {
    showDialog(
      context: context,
      builder: (_) => ComposeModal(
        onClose: () => Navigator.of(context).pop(),
        onSent: () { _loadUnread(); Navigator.of(context).pop(); },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_checkingAccounts) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_accounts.isEmpty) {
      return _AccountSetupPrompt(
        onAccountAdded: (acc) {
          setState(() { _accounts = [acc]; });
          _init();
        },
      );
    }

    return LayoutBuilder(builder: (ctx, cst) {
      final narrow = cst.maxWidth < 720;
      return Stack(children: [
        narrow ? _narrowLayout(context) : _wideLayout(context),
        if (_syncing)
          Positioned(
            top: 8, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.pal.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.pal.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 10, height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5)),
                const SizedBox(width: 6),
                Text('Syncing', style: AppTheme.bodySub.copyWith(fontSize: 11)),
              ]),
            ),
          ),
      ]);
    });
  }

  // ── 3-pane wide layout ─────────────────────────────────────────────────────

  Widget _wideLayout(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        width: 220,
        decoration: BoxDecoration(border: Border(right: BorderSide(color: context.pal.border))),
        padding: const EdgeInsets.all(10),
        child: _sidebar(context),
      ),
      Container(
        width: 360,
        decoration: BoxDecoration(border: Border(right: BorderSide(color: context.pal.border))),
        child: Column(children: [
          _ListHeader(
            label: _folderLabel(_folder),
            unread: _folder == 'inbox' ? _unread : null,
            onRefresh: _refresh,
          ),
          Expanded(child: _emailList(context)),
        ]),
      ),
      Expanded(child: _readingPane(context)),
    ],
  );

  // ── Narrow layout ──────────────────────────────────────────────────────────

  Widget _narrowLayout(BuildContext context) {
    if (_narrowPane == 0) {
      return Column(children: [
        _NarrowBar(label: 'Folders',
          leading: GestureDetector(
            onTap: () => setState(() => _narrowPane = 1),
            child: Icon(Symbols.arrow_back, size: 18, color: context.pal.textMute),
          ),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(10), child: _sidebar(context))),
      ]);
    }
    if (_narrowPane == 2 && _selected != null) {
      return Column(children: [
        _NarrowBar(label: _folderLabel(_folder),
          leading: GestureDetector(
            onTap: () => setState(() => _narrowPane = 1),
            child: Icon(Symbols.arrow_back, size: 18, color: context.pal.textMute),
          ),
        ),
        Expanded(child: _readingPane(context)),
      ]);
    }
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() => _narrowPane = 0),
            child: Icon(Icons.menu, size: 20, color: context.pal.textMute),
          ),
          const SizedBox(width: 10),
          Text(_folderLabel(_folder), style: AppTheme.bodyStrong),
          if (_folder == 'inbox' && _unread > 0) ...[
            const SizedBox(width: 8),
            _CountBadge('$_unread'),
          ],
          const Spacer(),
          GestureDetector(
            onTap: _openCompose,
            child: Container(
              height: 28, padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(7)),
              child: Row(children: [
                const Icon(Symbols.edit_square, size: 13, color: Color(0xFF06120F)),
                const SizedBox(width: 4),
                Text('Compose', style: AppTheme.bodySub.copyWith(
                    color: const Color(0xFF06120F), fontSize: 11)),
              ]),
            ),
          ),
        ]),
      ),
      Expanded(child: _emailList(context)),
    ]);
  }

  // ── Sidebar ────────────────────────────────────────────────────────────────

  Widget _sidebar(BuildContext context) {
    final staticFolders = [
      (Symbols.inbox,   'inbox',  'Inbox',   _unread),
      (Symbols.send,    'sent',   'Sent',    0),
      (Symbols.drafts,  'drafts', 'Drafts',  0),
      (Symbols.flag,    'FLAGGED','Flagged', 0),
      (Symbols.archive, 'ARCHIVE','Archive', 0),
      (Symbols.delete,  'Trash',  'Trash',   0),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Compose button
      GestureDetector(
        onTap: _openCompose,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: AppColors.teal.withValues(alpha: 0.3), blurRadius: 12)],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Symbols.edit_square, size: 16, color: Color(0xFF06120F)),
            const SizedBox(width: 8),
            Text('Compose', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F))),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      _SectionLabel('Mailboxes'),
      ...staticFolders.map((f) => _FolderItem(
        icon: f.$1, label: f.$3,
        count: f.$4 > 0 ? '${f.$4}' : null,
        active: _folder == f.$2,
        onTap: () => _switchFolder(f.$2),
      )),
      // Additional server folders
      if (_serverFolders.isNotEmpty) ...[
        _SectionLabel('Server Folders'),
        ..._serverFolders
          .where((f) => !['INBOX','SENT','DRAFTS','TRASH','SPAM','FLAGGED','ARCHIVE']
              .contains(f.toUpperCase()))
          .map((f) => _FolderItem(
            icon: Symbols.folder,
            label: f,
            active: _folder == f,
            onTap: () => _switchFolder(f),
          )),
      ],
      const SizedBox(height: 12),
      // Account settings link
      GestureDetector(
        onTap: () => _showAccountSettings(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            Icon(Symbols.settings, size: 15, color: context.pal.textDim),
            const SizedBox(width: 8),
            Text('Account Settings',
              style: AppTheme.bodySub.copyWith(fontSize: 12, color: context.pal.textDim)),
          ]),
        ),
      ),
    ]);
  }

  // ── Email list ─────────────────────────────────────────────────────────────

  Widget _emailList(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    // A background refresh failing while stale-but-valid cached emails
    // are already showing shouldn't blow that away.
    if (_loadError != null && _emails.isEmpty) return ErrorView(message: _loadError!, onRetry: _loadEmails);
    if (_emails.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Symbols.inbox, size: 36, color: context.pal.textDim),
        const SizedBox(height: 10),
        Text('No messages in ${_folderLabel(_folder)}',
            style: AppTheme.bodySub.copyWith(fontSize: 13)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        itemCount: _emails.length,
        itemBuilder: (_, i) => _EmailListRow(
          email:    _emails[i],
          selected: _selectedIdx == i,
          onTap:    () => _selectAt(i),
        ),
      ),
    );
  }

  // ── Reading pane ───────────────────────────────────────────────────────────

  Widget _readingPane(BuildContext context) {
    final email = _selected;
    if (email == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Symbols.mark_email_unread, size: 40, color: context.pal.textDim),
        const SizedBox(height: 12),
        Text('Select an email to read', style: AppTheme.bodySub),
      ]));
    }
    return _ReadingPane(
      email:    email,
      onDelete: () => _deleteEmail(_selectedIdx),
      onFlag:   () => _toggleFlag(_selectedIdx),
    );
  }

  // ── Account settings ───────────────────────────────────────────────────────

  void _showAccountSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _AccountDialog(
        existing: _accounts.isNotEmpty ? _accounts.first : null,
        onSaved: (acc) {
          setState(() {
            if (_accounts.isEmpty) {
              _accounts = [acc];
            } else {
              _accounts[0] = acc;
            }
          });
        },
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _folderLabel(String f) => switch (f.toLowerCase()) {
    'inbox'   => 'Inbox',
    'sent'    => 'Sent',
    'drafts'  => 'Drafts',
    'trash'   => 'Trash',
    'flagged' => 'Flagged',
    'archive' => 'Archive',
    'spam'    => 'Spam',
    _         => f,
  };
}

// ── Account setup prompt ─────────────────────────────────────────────────────

class _AccountSetupPrompt extends StatelessWidget {
  const _AccountSetupPrompt({required this.onAccountAdded});
  final void Function(EmailAccount) onAccountAdded;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Symbols.mail_outline, size: 48, color: context.pal.textDim),
      const SizedBox(height: 16),
      Text('No email account configured',
          style: AppTheme.bodyStrong.copyWith(fontSize: 16)),
      const SizedBox(height: 8),
      Text('Connect your IMAP/SMTP account to use this screen.',
          style: AppTheme.bodySub),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _AccountDialog(
            onSaved: onAccountAdded,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.teal, borderRadius: BorderRadius.circular(10),
          ),
          child: Text('Connect Email Account', style: AppTheme.bodyStrong.copyWith(
              color: const Color(0xFF06120F))),
        ),
      ),
    ]),
  );
}

// ── Account dialog ───────────────────────────────────────────────────────────

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({this.existing, required this.onSaved});
  final EmailAccount?                       existing;
  final void Function(EmailAccount account) onSaved;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final _labelCtrl    = TextEditingController(text: widget.existing?.label    ?? '');
  late final _nameCtrl     = TextEditingController(text: widget.existing?.fromName ?? '');
  late final _emailCtrl    = TextEditingController(text: widget.existing?.fromEmail ?? '');
  late final _userCtrl     = TextEditingController(text: widget.existing?.username  ?? '');
  late final _passCtrl     = TextEditingController();
  late final _imapHostCtrl = TextEditingController(text: widget.existing?.imapHost ?? 'imap.gmail.com');
  late final _smtpHostCtrl = TextEditingController(text: widget.existing?.smtpHost ?? 'smtp.gmail.com');
  late int    _imapPort    = widget.existing?.imapPort ?? 993;
  late int    _smtpPort    = widget.existing?.smtpPort ?? 465;

  bool    _saving   = false;
  bool    _testing  = false;
  String? _error;
  String? _testMsg;

  static const _presets = [
    ('Gmail',    'imap.gmail.com',          993, 'smtp.gmail.com',          465),
    ('Outlook',  'outlook.office365.com',   993, 'smtp.office365.com',      587),
    ('Yahoo',    'imap.mail.yahoo.com',     993, 'smtp.mail.yahoo.com',     465),
    ('Custom',   'mail.yourdomain.com',     993, 'mail.yourdomain.com',     465),
  ];

  void _applyPreset(int i) {
    final p = _presets[i];
    setState(() {
      _imapHostCtrl.text = p.$2; _imapPort = p.$3;
      _smtpHostCtrl.text = p.$4; _smtpPort = p.$5;
    });
  }

  @override
  void dispose() {
    for (final c in [_labelCtrl,_nameCtrl,_emailCtrl,_userCtrl,_passCtrl,
                     _imapHostCtrl,_smtpHostCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final data = {
        'label':           _labelCtrl.text.trim(),
        'from_name':       _nameCtrl.text.trim(),
        'from_email':      _emailCtrl.text.trim(),
        'username':        _userCtrl.text.trim(),
        if (_passCtrl.text.isNotEmpty) 'password': _passCtrl.text,
        'imap_host':       _imapHostCtrl.text.trim(),
        'imap_port':       _imapPort,
        'imap_encryption': 'ssl',
        'smtp_host':       _smtpHostCtrl.text.trim(),
        'smtp_port':       _smtpPort,
        'smtp_encryption': _smtpPort == 587 ? 'tls' : 'ssl',
        'is_default':      true,
      };
      final acc = widget.existing != null
          ? await EmailAccountService.instance.update(widget.existing!.id, data)
          : await EmailAccountService.instance.create(data);
      if (mounted) { widget.onSaved(acc); Navigator.of(context).pop(); }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = friendlyError(e); });
    }
  }

  Future<void> _test() async {
    if (widget.existing == null) {
      setState(() => _testMsg = 'Save the account first, then test.');
      return;
    }
    setState(() { _testing = true; _testMsg = null; });
    try {
      final folders = await EmailAccountService.instance.test(widget.existing!.id);
      if (mounted) {
        setState(() {
          _testing = false;
          _testMsg = folders.isNotEmpty
              ? '✓ Connected. Folders: ${folders.take(5).join(', ')}'
              : '✓ Connected successfully.';
        });
      }
    } catch (e) {
      if (mounted) {
        // e is an Exception whose message is the server's specific error
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() { _testing = false; _testMsg = '✗ $msg'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.88;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: const Color(0xAA06070A),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520, maxHeight: maxH),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: context.pal.surface1,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.pal.borderStrong),
                  boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(children: [
                      Icon(Symbols.mail, size: 18, color: AppColors.teal),
                      const SizedBox(width: 10),
                      Text(widget.existing != null ? 'Email Account' : 'Connect Email Account',
                          style: AppTheme.bodyStrong),
                      const Spacer(),
                      GestureDetector(onTap: () => Navigator.of(context).pop(),
                          child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
                    ]),
                  ),
                  // Form
                  Flexible(child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: [
                      // Provider presets
                      Row(children: _presets.asMap().entries.map((e) =>
                        Expanded(child: Padding(
                          padding: EdgeInsets.only(right: e.key < _presets.length - 1 ? 6 : 0),
                          child: GestureDetector(
                            onTap: () => _applyPreset(e.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: _imapHostCtrl.text == e.value.$2
                                    ? AppColors.tealSoft : context.pal.surface2,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: _imapHostCtrl.text == e.value.$2
                                    ? AppColors.teal : context.pal.border),
                              ),
                              child: Center(child: Text(e.value.$1,
                                style: AppTheme.bodySub.copyWith(fontSize: 11.5,
                                  color: _imapHostCtrl.text == e.value.$2
                                      ? AppColors.teal : context.pal.textMute))),
                            ),
                          ),
                        ))
                      ).toList()),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _aField('Label',      _labelCtrl,    'My Work Email')),
                        const SizedBox(width: 12),
                        Expanded(child: _aField('From Name',  _nameCtrl,     'Edmund Salaho')),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _aField('From Email', _emailCtrl, 'info@medequip.tz')),
                        const SizedBox(width: 12),
                        Expanded(child: _aField('Username',   _userCtrl,  'info@medequip.tz')),
                      ]),
                      const SizedBox(height: 10),
                      _aField('Password / App Password', _passCtrl, '••••••••••••••••',
                          obscure: true),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _aField('IMAP Host', _imapHostCtrl, 'imap.gmail.com')),
                        const SizedBox(width: 12),
                        SizedBox(width: 80, child: _aField('Port', TextEditingController(text: '$_imapPort'), '993',
                            onChanged: (v) => setState(() => _imapPort = int.tryParse(v) ?? _imapPort))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _aField('SMTP Host', _smtpHostCtrl, 'smtp.gmail.com')),
                        const SizedBox(width: 12),
                        SizedBox(width: 80, child: _aField('Port', TextEditingController(text: '$_smtpPort'), '465',
                            onChanged: (v) => setState(() => _smtpPort = int.tryParse(v) ?? _smtpPort))),
                      ]),
                      if (_testMsg != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _testMsg!.startsWith('✓')
                                ? AppColors.tealSoft : AppColors.coral.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(_testMsg!, style: AppTheme.bodySub.copyWith(
                            fontSize: 12,
                            color: _testMsg!.startsWith('✓') ? AppColors.teal : AppColors.coral)),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
                      ],
                      const SizedBox(height: 20),
                    ]),
                  )),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(children: [
                      GestureDetector(
                        onTap: _testing ? null : _test,
                        child: Container(
                          height: 36, padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: context.pal.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: _testing
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text('Test', style: AppTheme.bodySm)),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 36, padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: context.pal.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(child: Text('Cancel', style: AppTheme.bodySm)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _saving ? null : _save,
                        child: Container(
                          height: 36, padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                          child: Center(child: _saving
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(color: Color(0xFF06120F), strokeWidth: 2))
                            : Text('Save', style: AppTheme.bodyStrong.copyWith(
                                color: const Color(0xFF06120F)))),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _aField(String label, TextEditingController ctrl, String hint,
      {bool obscure = false, void Function(String)? onChanged}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 5),
      FieldFocusBox(
        builder: (context, focusNode) => TextField(
          controller: ctrl,
          focusNode: focusNode,
          obscureText: obscure,
          style: AppTheme.bodySm,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        ),
      ),
    ]);
}

// ── Shared widgets ───────────────────────────────────────────────────────────

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.label, this.unread, this.onRefresh});
  final String label; final int? unread; final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
    child: Row(children: [
      Text(label, style: AppTheme.bodyStrong),
      if ((unread ?? 0) > 0) ...[const SizedBox(width: 8), _CountBadge('$unread')],
      const Spacer(),
      if (onRefresh != null)
        GestureDetector(onTap: onRefresh,
            child: Icon(Symbols.refresh, size: 16, color: context.pal.textDim)),
    ]),
  );
}

class _NarrowBar extends StatelessWidget {
  const _NarrowBar({required this.label, this.leading});
  final String label; final Widget? leading;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
    child: Row(children: [
      if (leading != null) ...[leading!, const SizedBox(width: 10)],
      Text(label, style: AppTheme.bodyStrong),
    ]),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 11)),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
    child: Text(text.toUpperCase(), style: AppTheme.monoXs.copyWith(letterSpacing: 0.10)),
  );
}

class _FolderItem extends StatelessWidget {
  const _FolderItem({required this.icon, required this.label, this.count,
      required this.active, required this.onTap});
  final IconData icon; final String label; final String? count;
  final bool active; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active ? context.pal.surface2 : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(children: [
        Icon(icon, size: 17, color: active ? context.pal.text : context.pal.textMute),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTheme.bodySm.copyWith(
          color: active ? context.pal.text : context.pal.textMute, fontSize: 13))),
        if (count != null)
          Text(count!, style: AppTheme.bodySub.copyWith(
            color: active ? AppColors.teal : context.pal.textDim, fontSize: 11)),
      ]),
    ),
  );
}

// ── Email list row ───────────────────────────────────────────────────────────

class _EmailListRow extends StatelessWidget {
  const _EmailListRow({required this.email, required this.selected, required this.onTap});
  final Email email; final bool selected; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? context.pal.surface2 : Colors.transparent,
        border: Border(bottom: BorderSide(color: context.pal.divider)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AvatarWidget(initials: email.initials, size: 22, variant: AvatarVariant.teal),
          const SizedBox(width: 6),
          Expanded(child: Text(email.from,
              style: AppTheme.bodyStrong.copyWith(fontSize: 13))),
          if (!email.isRead)
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
          if (email.isFlagged) ...[
            const SizedBox(width: 4),
            Icon(Symbols.flag, size: 13, color: AppColors.amber),
          ],
          const SizedBox(width: 6),
          Text(email.timeLabel, style: AppTheme.bodySub.copyWith(fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        Text(email.subject, style: AppTheme.bodySm.copyWith(
          color: !email.isRead ? context.pal.text : context.pal.textMute,
          fontWeight: !email.isRead ? FontWeight.w600 : FontWeight.w400,
        ), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(email.preview, style: AppTheme.bodySub.copyWith(fontSize: 12),
            overflow: TextOverflow.ellipsis),
        if (email.label != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: context.pal.surface3,
                borderRadius: BorderRadius.circular(999)),
            child: Text(email.label!, style: AppTheme.bodySub.copyWith(fontSize: 10)),
          ),
        ],
      ]),
    ),
  );
}

// ── Reading pane ─────────────────────────────────────────────────────────────

class _ReadingPane extends StatefulWidget {
  const _ReadingPane({required this.email, this.onDelete, this.onFlag});
  final Email email;
  final VoidCallback? onDelete;
  final VoidCallback? onFlag;

  @override
  State<_ReadingPane> createState() => _ReadingPaneState();
}

class _ReadingPaneState extends State<_ReadingPane> {
  final _replyCtrl = TextEditingController();
  bool _sending    = false;
  bool _replyAll   = false;

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

  Future<void> _sendReply() async {
    final body = _replyCtrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await EmailService.instance.reply(widget.email.id,
          body: body, replyAll: _replyAll);
      if (mounted) { _replyCtrl.clear(); setState(() => _sending = false); }
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showForward(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _ForwardDialog(emailId: widget.email.id,
          originalSubject: widget.email.subject),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Subject + actions
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(email.subject,
              style: AppTheme.pageTitle.copyWith(fontSize: 18))),
          GestureDetector(
            onTap: widget.onFlag,
            child: Icon(email.isFlagged ? Symbols.flag : Symbols.outlined_flag,
              size: 20, color: email.isFlagged ? AppColors.amber : context.pal.textDim),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _showForward(context),
            child: Icon(Symbols.forward_to_inbox, size: 20, color: context.pal.textDim),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onDelete,
            child: Icon(Symbols.delete_outline, size: 20, color: context.pal.textDim),
          ),
        ]),
        const SizedBox(height: 14),
        // Sender
        Container(
          padding: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.pal.divider))),
          child: Row(children: [
            AvatarWidget(initials: email.initials, size: 36, variant: AvatarVariant.teal),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(email.from, style: AppTheme.bodyStrong),
              Text(email.fromEmail.isNotEmpty ? '${email.fromEmail} · ${email.timeLabel}'
                      : email.timeLabel,
                  style: AppTheme.bodySub.copyWith(fontSize: 12)),
              if (email.to.isNotEmpty)
                Text('to: ${email.to}',
                    style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
              if (email.cc != null)
                Text('cc: ${email.cc}',
                    style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
            ])),
          ]),
        ),
        const SizedBox(height: 18),
        // Body
        Text(
          email.body.isNotEmpty ? email.body : email.preview,
          style: AppTheme.bodySm.copyWith(height: 1.7),
        ),
        const SizedBox(height: 28),
        // Reply box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _replyCtrl,
              maxLines: 4, minLines: 3,
              style: AppTheme.bodySm.copyWith(height: 1.6),
              decoration: InputDecoration(
                hintText: 'Reply to ${email.from}…',
                hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.pal.divider))),
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                // Reply / Reply All toggle
                GestureDetector(
                  onTap: () => setState(() => _replyAll = !_replyAll),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _replyAll ? AppColors.tealSoft : context.pal.surface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _replyAll ? AppColors.teal : context.pal.border),
                    ),
                    child: Text(_replyAll ? 'Reply All' : 'Reply',
                      style: AppTheme.bodySub.copyWith(
                        fontSize: 12,
                        color: _replyAll ? AppColors.teal : context.pal.textMute)),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _sendReply,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: _sending
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(color: Color(0xFF06120F), strokeWidth: 2))
                      : Text('Send', style: AppTheme.bodyStrong.copyWith(
                          color: const Color(0xFF06120F), fontSize: 13)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Forward dialog ───────────────────────────────────────────────────────────

class _ForwardDialog extends StatefulWidget {
  const _ForwardDialog({required this.emailId, required this.originalSubject});
  final int emailId; final String originalSubject;

  @override
  State<_ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends State<_ForwardDialog> {
  final _toCtrl   = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool    _sending = false;
  String? _error;

  @override
  void dispose() { _toCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (_toCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Recipient is required.');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await EmailService.instance.forward(widget.emailId,
          to: _toCtrl.text.trim(), body: _bodyCtrl.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() { _sending = false; _error = friendlyError(e); });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.pal.surface1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
    title: Row(children: [
      Icon(Symbols.forward_to_inbox, size: 18, color: AppColors.teal),
      const SizedBox(width: 10),
      Expanded(child: Text('Forward: ${widget.originalSubject}',
          style: AppTheme.bodyStrong, overflow: TextOverflow.ellipsis)),
    ]),
    content: SizedBox(
      width: 440,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _fField('To', _toCtrl, 'recipient@example.com', context),
        const SizedBox(height: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NOTE', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
          const SizedBox(height: 6),
          Container(
            height: 80,
            decoration: BoxDecoration(color: context.pal.surface2,
                borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(controller: _bodyCtrl, maxLines: null, expands: true,
              style: AppTheme.bodySm,
              decoration: InputDecoration(hintText: 'Add a note (optional)…',
                  hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                  border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)),
          ),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
        ],
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: AppTheme.bodySm.copyWith(color: context.pal.textMute))),
      GestureDetector(
        onTap: _sending ? null : _send,
        child: Container(
          height: 36, padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
          child: Center(child: _sending
            ? const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(color: Color(0xFF06120F), strokeWidth: 2))
            : Text('Forward', style: AppTheme.bodyStrong.copyWith(
                color: const Color(0xFF06120F), fontSize: 13))),
        ),
      ),
    ],
  );

  Widget _fField(String label, TextEditingController ctrl, String hint, BuildContext ctx) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 6),
      FieldFocusBox(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        builder: (context, focusNode) => TextField(controller: ctrl, focusNode: focusNode, style: AppTheme.bodySm,
          decoration: InputDecoration(hintText: hint,
              hintStyle: AppTheme.bodySm.copyWith(color: ctx.pal.textDim),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)),
      ),
    ]);
}

// ── Compose modal ────────────────────────────────────────────────────────────

