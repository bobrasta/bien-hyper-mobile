import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show authTokenNotifier, userNameNotifier, themeNotifier;
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/staff_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../theme/app_palette.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _section = 0;
  int _tab     = 0;

  // Security toggles
  bool _twoFa   = true;
  bool _sso     = false;
  bool _audit   = true;
  bool _session = true;

  // Communication toggles
  bool _emailTicket   = true;
  bool _emailPayment  = true;
  bool _emailWarranty = true;
  bool _emailDigest   = true;
  bool _pushTicket    = true;
  bool _pushPayment   = false;
  String _digestFreq  = 'Daily';

  // SSO tab
  bool _ssoEnabled     = false;
  bool _ssoSaving      = false;
  String? _ssoTestMsg;
  final _entityIdCtrl  = TextEditingController();
  final _ssoUrlCtrl    = TextEditingController();
  final _sloUrlCtrl    = TextEditingController();
  final _certCtrl      = TextEditingController();

  // Workspace
  final _companyCtrl   = TextEditingController();
  String _timezone     = 'Africa/Dar_es_Salaam';
  String _language     = 'English';
  String _dateFormat   = 'DD/MM/YYYY';
  bool   _savingWs     = false;

  // Profile
  bool _loadingProfile = true;
  bool _showInvite     = false;
  final _nameCtrl      = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _oldPwCtrl     = TextEditingController();
  final _newPwCtrl     = TextEditingController();
  bool   _savingProfile = false;
  bool   _savingPw      = false;
  String? _profileMsg;

  // Team members
  bool              _loadingMembers = true;
  List<StaffMember> _staffList      = [];
  String?           _memberError;

  // API key
  bool _apiKeyVisible = false;
  static const _apiKey = 'hmd_live_sk_••••••••••••••••••••••••••••••••';
  static const _apiKeyReal = 'hmd_live_sk_a8f3c2d1e9b74f56a2c8d7e3f1b9a405';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() { _loadingMembers = true; _memberError = null; });
    try {
      final list = await StaffService.instance.list();
      if (mounted) setState(() { _staffList = list; _loadingMembers = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingMembers = false; _memberError = 'Failed to load members.'; });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _oldPwCtrl.dispose(); _newPwCtrl.dispose();
    _entityIdCtrl.dispose(); _ssoUrlCtrl.dispose();
    _sloUrlCtrl.dispose(); _certCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.instance.getProfile();
    if (mounted) {
      setState(() {
        _loadingProfile = false;
        if (profile != null) {
          _nameCtrl.text  = profile['name']  as String? ?? '';
          _emailCtrl.text = profile['email'] as String? ?? '';
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    setState(() { _savingProfile = true; _profileMsg = null; });
    try {
      await ApiClient.instance.dio.put('/auth/profile', data: {
        'name':  _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      });
      await AuthService.instance.updateStoredName(_nameCtrl.text.trim());
      userNameNotifier.value = _nameCtrl.text.trim();
      if (mounted) setState(() { _savingProfile = false; _profileMsg = 'Profile updated.'; });
    } catch (e) {
      if (mounted) setState(() { _savingProfile = false; _profileMsg = 'Update failed.'; });
    }
  }

  Future<void> _changePassword() async {
    if (_savingPw) return;
    setState(() { _savingPw = true; _profileMsg = null; });
    try {
      await ApiClient.instance.dio.post('/auth/change-password', data: {
        'current_password': _oldPwCtrl.text,
        'new_password':     _newPwCtrl.text,
      });
      _oldPwCtrl.clear(); _newPwCtrl.clear();
      if (mounted) setState(() { _savingPw = false; _profileMsg = 'Password changed.'; });
    } catch (e) {
      if (mounted) setState(() { _savingPw = false; _profileMsg = 'Password change failed.'; });
    }
  }

  Future<void> _logout() async {
    final token = authTokenNotifier.value;
    if (token != null) await AuthService.instance.logout(token);
    authTokenNotifier.value = null;
  }

  static const _sections = [
    {'icon': Symbols.domain,        'label': 'Workspace'},
    {'icon': Symbols.credit_card,   'label': 'Billing & Plan'},
    {'icon': Symbols.notifications, 'label': 'Communication'},
    {'icon': Symbols.cable,         'label': 'Connections'},
    {'icon': Symbols.security,      'label': 'Security'},
    {'icon': Symbols.tune,          'label': 'Preferences'},
  ];

  static const _memberTabs = ['Members', 'Pending', 'Roles', 'Activity', 'SSO'];

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cst) {
      final narrow = cst.maxWidth < 720;
      final pad    = narrow ? 16.0 : 24.0;

      final mainContent = SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Narrow: section chip strip
          if (narrow) ...[
            Text('Settings', style: AppTheme.pageTitle.copyWith(fontSize: 18)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _sections.asMap().entries.map((e) {
                final active = _section == e.key;
                return GestureDetector(
                  onTap: () => setState(() { _section = e.key; }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? context.pal.surface2 : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.pal.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(e.value['icon'] as IconData, size: 14,
                          color: active ? context.pal.text : context.pal.textMute),
                      const SizedBox(width: 6),
                      Text(e.value['label'] as String, style: AppTheme.bodySm.copyWith(
                          color: active ? context.pal.text : context.pal.textMute, fontSize: 12)),
                    ]),
                  ),
                );
              }).toList()),
            ),
            const SizedBox(height: 16),
          ],

          // Profile + Password always visible
          _profileCard(context),
          const SizedBox(height: 16),
          _passwordCard(context),
          const SizedBox(height: 24),

          // Section-specific content
          _buildSectionContent(context),
        ]),
      );

      Widget layout;
      if (narrow) {
        layout = mainContent;
      } else {
        layout = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 220,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: context.pal.border)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Settings', style: AppTheme.pageTitle.copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              ..._sections.asMap().entries.map((e) => _SettingsSideItem(
                icon: e.value['icon'] as IconData,
                label: e.value['label'] as String,
                active: _section == e.key,
                onTap: () => setState(() { _section = e.key; }),
              )),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.tealSoft, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x4000D4AA)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Enterprise Plan', style: AppTheme.bodyStrong.copyWith(
                      color: AppColors.teal, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${_staffList.length} / 25 seats used',
                      style: AppTheme.bodySub.copyWith(fontSize: 11)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (_staffList.isEmpty ? 18 : _staffList.length) / 25,
                      backgroundColor: context.pal.surface3,
                      valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                      minHeight: 4,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          Expanded(child: mainContent),
        ]);
      }

      return Stack(children: [
        layout,
        if (_showInvite)
          _InviteDialog(
            onClose: () => setState(() => _showInvite = false),
            onSaved: () { setState(() => _showInvite = false); _loadMembers(); },
          ),
      ]);
    });
  }

  // ── Profile card ─────────────────────────────────────────────────────────────

  Widget _profileCard(BuildContext context) => _SCard(
    title: 'My Profile',
    trailing: GestureDetector(
      onTap: _logout,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Symbols.logout, size: 14, color: AppColors.coral),
        const SizedBox(width: 6),
        Text('Sign out', style: AppTheme.bodySm.copyWith(color: AppColors.coral, fontSize: 12.5)),
      ]),
    ),
    child: _loadingProfile
        ? const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(strokeWidth: 2)))
        : Column(children: [
            Row(children: [
              Expanded(child: _SettingsField(label: 'Full Name', ctrl: _nameCtrl, hint: 'Your name')),
              const SizedBox(width: 14),
              Expanded(child: _SettingsField(label: 'Email', ctrl: _emailCtrl, hint: 'your@email.com')),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              if (_profileMsg != null) ...[
                Icon(_profileMsg!.contains('failed') ? Symbols.error : Symbols.check_circle,
                    size: 14, color: _profileMsg!.contains('failed') ? AppColors.coral : AppColors.teal),
                const SizedBox(width: 6),
                Text(_profileMsg!, style: AppTheme.bodySub.copyWith(
                    color: _profileMsg!.contains('failed') ? AppColors.coral : AppColors.teal, fontSize: 12.5)),
              ],
              const Spacer(),
              _TealBtn(label: 'Save changes', saving: _savingProfile, onTap: _saveProfile),
            ]),
          ]),
  );

  // ── Password card ────────────────────────────────────────────────────────────

  Widget _passwordCard(BuildContext context) => _SCard(
    title: 'Change Password',
    child: Column(children: [
      Row(children: [
        Expanded(child: _SettingsField(label: 'Current Password', ctrl: _oldPwCtrl,
            hint: '••••••••', obscure: true)),
        const SizedBox(width: 14),
        Expanded(child: _SettingsField(label: 'New Password', ctrl: _newPwCtrl,
            hint: '••••••••', obscure: true)),
      ]),
      const SizedBox(height: 16),
      Align(alignment: Alignment.centerRight,
        child: _OutlineBtn(label: 'Update password', saving: _savingPw, onTap: _changePassword)),
    ]),
  );

  // ── Section content ──────────────────────────────────────────────────────────

  Widget _buildSectionContent(BuildContext context) => switch (_section) {
    0 => _workspaceSection(context),
    1 => _billingSection(context),
    2 => _communicationSection(context),
    3 => _connectionsSection(context),
    4 => _securitySection(context),
    5 => _preferencesSection(context),
    _ => const SizedBox.shrink(),
  };

  // ── Section 0: Workspace ─────────────────────────────────────────────────────

  Widget _workspaceSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    _SCard(
      title: 'Organisation',
      icon: Symbols.domain,
      child: Column(children: [
        Row(children: [
          Expanded(child: _SettingsField(label: 'Company Name', ctrl: _companyCtrl,
              hint: 'Your organisation name')),
          const SizedBox(width: 14),
          Expanded(child: _SDropdown(
            label: 'Industry',
            value: 'Healthcare / Medical',
            items: const ['Healthcare / Medical', 'Pharmaceuticals', 'Diagnostics', 'Other'],
            onChanged: (_) {},
          )),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SDropdown(
            label: 'Timezone',
            value: _timezone,
            items: const ['Africa/Dar_es_Salaam', 'Africa/Nairobi', 'UTC', 'Europe/London'],
            onChanged: (v) => setState(() => _timezone = v),
          )),
          const SizedBox(width: 14),
          Expanded(child: _SDropdown(
            label: 'Language',
            value: _language,
            items: const ['English', 'Swahili', 'French'],
            onChanged: (v) => setState(() => _language = v),
          )),
          const SizedBox(width: 14),
          Expanded(child: _SDropdown(
            label: 'Date Format',
            value: _dateFormat,
            items: const ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'],
            onChanged: (v) => setState(() => _dateFormat = v),
          )),
        ]),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerRight,
          child: _TealBtn(label: 'Save workspace', saving: _savingWs,
              onTap: () async {
                setState(() => _savingWs = true);
                await Future.delayed(const Duration(milliseconds: 600));
                if (mounted) setState(() => _savingWs = false);
              })),
      ]),
    ),
    const SizedBox(height: 24),

    // Team & Roles
    Text('Team & Roles', style: AppTheme.pageTitle),
    const SizedBox(height: 4),
    Text('Manage team members, permissions and security settings.',
        style: AppTheme.bodySub),
    const SizedBox(height: 20),

    // Tab bar
    Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _memberTabs.asMap().entries.map((e) => GestureDetector(
          onTap: () => setState(() => _tab = e.key),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(
              color: _tab == e.key ? AppColors.teal : Colors.transparent, width: 2))),
            child: Text(e.value, style: AppTheme.bodySm.copyWith(
              color: _tab == e.key ? context.pal.text : context.pal.textMute,
              fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        )).toList()),
      ),
    ),
    const SizedBox(height: 16),

    // Tab content
    switch (_tab) {
      0 => _membersTab(context),
      1 => _pendingTab(context),
      2 => _rolesTab(context),
      3 => _activityTab(context),
      4 => _ssoTab(context),
      _ => const SizedBox.shrink(),
    },
  ]);

  // ── Tab 0: Members ───────────────────────────────────────────────────────────

  Widget _membersTab(BuildContext context) => Column(children: [
    LayoutBuilder(builder: (ctx2, cst2) {
      final n2 = cst2.maxWidth < 520;
      final searchBox = _searchBox(context, 'Search members…');
      final roleFilter = _filterPill(context, 'Role: All');
      final inviteBtn = GestureDetector(
        onTap: () => setState(() => _showInvite = true),
        child: Container(
          height: 32, padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Symbols.person_add, size: 14, color: Color(0xFF06120F)),
            const SizedBox(width: 6),
            Text('Invite Member', style: AppTheme.bodyStrong.copyWith(
                color: const Color(0xFF06120F), fontSize: 12)),
          ]),
        ),
      );
      if (n2) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          searchBox, const SizedBox(height: 8),
          Row(children: [roleFilter, const Spacer(), inviteBtn]),
        ]);
      }
      return Row(children: [
        SizedBox(width: 260, child: searchBox), const SizedBox(width: 10),
        roleFilter, const Spacer(), inviteBtn,
      ]);
    }),
    const SizedBox(height: 12),
    Container(
      decoration: BoxDecoration(color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg), border: Border.all(color: context.pal.border)),
      child: _loadingMembers
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : _memberError != null
              ? Padding(padding: const EdgeInsets.all(24),
                  child: Center(child: Text(_memberError!,
                      style: AppTheme.bodySub.copyWith(color: AppColors.coral))))
              : HScrollTable(minWidth: 640, child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
                    child: Row(children: [
                      const SizedBox(width: 20),
                      _MemberTh('Member', flex: 3), _MemberTh('Role', flex: 1),
                      _MemberTh('2FA', flex: 1),    _MemberTh('Last Active', flex: 1),
                      const SizedBox(width: 60),
                    ]),
                  ),
                  if (_staffList.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No members found.')))
                  else
                    ..._staffList.map((m) => _MemberRow(member: m)),
                ])),
    ),
  ]);

  // ── Tab 1: Pending ───────────────────────────────────────────────────────────

  Widget _pendingTab(BuildContext context) {
    const pending = <_PendingInvite>[];

    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${pending.length} pending invitation${pending.length == 1 ? '' : 's'}',
            style: AppTheme.bodySub),
        _OutlineBtn(label: 'Resend all', saving: false, onTap: () {}),
      ]),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border)),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
            child: Row(children: [
              _PendTh('Email',    flex: 3), _PendTh('Role', flex: 1),
              _PendTh('Zone',     flex: 1), _PendTh('Sent',  flex: 1),
              const SizedBox(width: 120),
            ]),
          ),
          ...pending.asMap().entries.map((e) {
            final inv = e.value;
            final isLast = e.key == pending.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: isLast ? null : BoxDecoration(
                  border: Border(bottom: BorderSide(color: context.pal.divider))),
              child: Row(children: [
                Expanded(flex: 3, child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.amberSoft, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Symbols.mail_outline, size: 15, color: AppColors.amber),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(inv.email, style: AppTheme.bodySm, overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.amberSoft, borderRadius: BorderRadius.circular(999)),
                        child: Text('Pending', style: AppTheme.monoXs.copyWith(
                            color: AppColors.amber, fontSize: 9.5)),
                      ),
                    ]),
                  ])),
                ])),
                Expanded(flex: 1, child: Text(inv.role, style: AppTheme.bodySub.copyWith(fontSize: 12))),
                Expanded(flex: 1, child: Text(inv.zone, style: AppTheme.bodySub.copyWith(fontSize: 12))),
                Expanded(flex: 1, child: Text(inv.sent, style: AppTheme.monoXs.copyWith(
                    color: context.pal.textDim))),
                SizedBox(width: 120, child: Row(children: [
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.pal.border),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text('Resend', style: AppTheme.bodySm.copyWith(fontSize: 11.5)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.coralSoft, borderRadius: BorderRadius.circular(6)),
                      child: Text('Cancel', style: AppTheme.bodySm.copyWith(
                          color: AppColors.coral, fontSize: 11.5)),
                    ),
                  ),
                ])),
              ]),
            );
          }),
          if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Symbols.mark_email_read, size: 32, color: context.pal.textDim),
                const SizedBox(height: 8),
                Text('No pending invitations', style: AppTheme.bodySub),
              ])),
            ),
        ]),
      ),
    ]);
  }

  // ── Tab 2: Roles ─────────────────────────────────────────────────────────────

  Widget _rolesTab(BuildContext context) {
    const roles = [
      _RoleDef('Admin',       AppColors.teal,   'Full access to all settings, data and team management.',
          {'All screens': true,  'Edit data': true,  'Delete data': true,  'Manage team': true,  'Billing': true}),
      _RoleDef('Technician',  AppColors.blue,   'Field service access — can view machines, log tickets and update service records.',
          {'All screens': false, 'Edit data': true,  'Delete data': false, 'Manage team': false, 'Billing': false}),
      _RoleDef('Sales',       AppColors.violet, 'CRM and pipeline access — can manage contacts, deals and invoices.',
          {'All screens': false, 'Edit data': true,  'Delete data': false, 'Manage team': false, 'Billing': true}),
      _RoleDef('Finance',     AppColors.amber,  'Revenue and billing access — invoices, payments and reports.',
          {'All screens': false, 'Edit data': false, 'Delete data': false, 'Manage team': false, 'Billing': true}),
      _RoleDef('Read Only',   AppColors.textDim,'View-only access to all non-sensitive screens.',
          {'All screens': true,  'Edit data': false, 'Delete data': false, 'Manage team': false, 'Billing': false}),
    ];
    const permKeys = ['All screens', 'Edit data', 'Delete data', 'Manage team', 'Billing'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Row(children: [
        Expanded(child: Text('${roles.length} roles defined',
            style: AppTheme.bodySub)),
        _OutlineBtn(label: 'New Role', saving: false, onTap: () {}),
      ]),
      const SizedBox(height: 12),
      ...roles.map((role) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: role.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(role.name, style: AppTheme.bodyStrong.copyWith(
                  color: role.color, fontSize: 12.5)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(role.desc, style: AppTheme.bodySub.copyWith(fontSize: 12))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {},
              child: Icon(Symbols.edit, size: 15, color: context.pal.textDim)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: permKeys.map((perm) {
            final allowed = role.perms[perm] ?? false;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: allowed ? AppColors.tealSoft : context.pal.surface2,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: allowed
                    ? AppColors.teal.withValues(alpha: 0.3) : context.pal.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(allowed ? Symbols.check : Symbols.close,
                    size: 12, color: allowed ? AppColors.teal : context.pal.textDim),
                const SizedBox(width: 4),
                Text(perm, style: AppTheme.monoXs.copyWith(
                    fontSize: 10.5,
                    color: allowed ? AppColors.teal : context.pal.textDim)),
              ]),
            );
          }).toList()),
        ]),
      )),
    ]);
  }

  // ── Tab 3: Activity ──────────────────────────────────────────────────────────

  Widget _activityTab(BuildContext context) {
    const log = <_AuditEntry>[];

    return Column(children: [
      Row(children: [
        _filterPill(context, 'All types'),
        const SizedBox(width: 8),
        _filterPill(context, 'This week'),
        const Spacer(),
        _OutlineBtn(label: 'Export log', saving: false, onTap: () {}),
      ]),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border)),
        child: Column(children: log.asMap().entries.map((e) {
          final entry = e.value;
          final isLast = e.key == log.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: isLast ? null : BoxDecoration(
                border: Border(bottom: BorderSide(color: context.pal.divider))),
            child: Row(children: [
              AvatarWidget(initials: entry.initials, size: 30, variant: entry.variant),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(entry.user, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(entry.action, style: AppTheme.bodySub.copyWith(fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 3),
                Text(entry.detail, style: AppTheme.bodySub.copyWith(
                    fontSize: 11.5, color: context.pal.textDim),
                    overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width: 12),
              Text(entry.time, style: AppTheme.monoXs.copyWith(
                  color: context.pal.textDim, fontSize: 10.5)),
            ]),
          );
        }).toList()),
      ),
    ]);
  }

  // ── Tab 4: SSO ───────────────────────────────────────────────────────────────

  Widget _ssoTab(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Enable toggle
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rLg),
        border: Border.all(color: _ssoEnabled
            ? AppColors.teal.withValues(alpha: 0.4) : context.pal.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _ssoEnabled ? AppColors.tealSoft : context.pal.surface2,
            borderRadius: BorderRadius.circular(8)),
          child: Icon(Symbols.security, size: 18,
              color: _ssoEnabled ? AppColors.teal : context.pal.textDim),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SAML Single Sign-On', style: AppTheme.bodyStrong),
          Text('Allow team members to log in via your organisation\'s identity provider.',
              style: AppTheme.bodySub.copyWith(fontSize: 12)),
        ])),
        Switch(
          value: _ssoEnabled,
          onChanged: (v) => setState(() => _ssoEnabled = v),
          activeThumbColor: AppColors.teal,
          inactiveThumbColor: context.pal.textDim,
          inactiveTrackColor: context.pal.surface3,
        ),
      ]),
    ),

    if (_ssoEnabled) ...[
      const SizedBox(height: 16),
      _SCard(
        title: 'SAML Configuration',
        icon: Symbols.settings,
        child: Column(children: [
          Row(children: [
            Expanded(child: _SettingsField(label: 'Entity ID (SP)',
                ctrl: _entityIdCtrl, hint: 'https://hypermed.app/auth/saml/metadata')),
            const SizedBox(width: 14),
            Expanded(child: _SettingsField(label: 'SSO URL (IdP)',
                ctrl: _ssoUrlCtrl, hint: 'https://idp.yourcompany.com/sso')),
          ]),
          const SizedBox(height: 14),
          _SettingsField(label: 'SLO URL (optional)',
              ctrl: _sloUrlCtrl, hint: 'https://idp.yourcompany.com/slo'),
          const SizedBox(height: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('X.509 CERTIFICATE'.toUpperCase(),
                style: AppTheme.labelCaps.copyWith(fontSize: 10)),
            const SizedBox(height: 6),
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: context.pal.surface2, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.pal.border)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _certCtrl, maxLines: null, expands: true,
                style: AppTheme.monoXs.copyWith(fontSize: 11),
                decoration: InputDecoration(
                  hintText: '-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----',
                  hintStyle: AppTheme.monoXs.copyWith(color: context.pal.textDim, fontSize: 11),
                  border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_ssoTestMsg != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _ssoTestMsg!.startsWith('✓')
                    ? AppColors.tealSoft : AppColors.coralSoft,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(_ssoTestMsg!, style: AppTheme.bodySub.copyWith(
                color: _ssoTestMsg!.startsWith('✓') ? AppColors.teal : AppColors.coral,
                fontSize: 12)),
            ),
            const SizedBox(height: 12),
          ],
          Row(children: [
            _OutlineBtn(
              label: 'Test SSO connection', saving: _ssoSaving,
              onTap: () async {
                setState(() { _ssoSaving = true; _ssoTestMsg = null; });
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) {
                  setState(() {
                    _ssoSaving = false;
                    _ssoTestMsg = _ssoUrlCtrl.text.isNotEmpty
                        ? '✓ Connection verified — 12 users synced'
                        : '✗ SSO URL is required to test the connection.';
                  });
                }
              }),
            const Spacer(),
            _TealBtn(label: 'Save configuration', saving: false, onTap: () {}),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      _SCard(
        title: 'Attribute Mapping',
        icon: Symbols.tune,
        child: Column(children: [
          _attrRow('Email',        'user.email',       context),
          _attrRow('Display Name', 'user.displayName', context),
          _attrRow('Role',         'user.role',        context),
          _attrRow('Department',   'user.department',  context),
        ]),
      ),
    ],
  ]);

  Widget _attrRow(String label, String attr, BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label,
          style: AppTheme.bodySm.copyWith(fontSize: 12.5))),
      const SizedBox(width: 12),
      Expanded(child: Container(
        height: 34,
        decoration: BoxDecoration(color: context.pal.surface2,
            borderRadius: BorderRadius.circular(7), border: Border.all(color: context.pal.border)),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Center(child: Text(attr, style: AppTheme.monoXs.copyWith(
            color: AppColors.teal, fontSize: 11))),
      )),
    ]),
  );

  // ── Section 1: Billing ───────────────────────────────────────────────────────

  Widget _billingSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Plan card
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B2E), Color(0xFF0A2A1F)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppColors.rLg),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Symbols.workspace_premium, size: 18, color: AppColors.teal),
            const SizedBox(width: 8),
            Text('Enterprise Plan', style: AppTheme.pageTitle.copyWith(
                color: Colors.white, fontSize: 18)),
          ]),
          const SizedBox(height: 6),
          Text('Unlimited machines · 25 seats · Priority support · API access',
              style: AppTheme.bodySub.copyWith(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 16),
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SEATS USED', style: AppTheme.monoXs.copyWith(color: Colors.white38)),
              const SizedBox(height: 4),
              Text('${_staffList.isEmpty ? 18 : _staffList.length} / 25',
                  style: AppTheme.bodyStrong.copyWith(color: Colors.white, fontSize: 22)),
            ]),
            const SizedBox(width: 32),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('NEXT BILLING', style: AppTheme.monoXs.copyWith(color: Colors.white38)),
              const SizedBox(height: 4),
              Text('Jul 1, 2025', style: AppTheme.bodyStrong.copyWith(
                  color: Colors.white, fontSize: 14)),
            ]),
          ]),
        ])),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
            child: Text('Manage plan', style: AppTheme.bodyStrong.copyWith(
                color: const Color(0xFF06120F), fontSize: 12.5)),
          ),
          const SizedBox(height: 8),
          Text('+ Add seats', style: AppTheme.bodySub.copyWith(
              color: AppColors.teal, fontSize: 12)),
        ]),
      ]),
    ),
    const SizedBox(height: 20),

    // Invoices
    _SCard(
      title: 'Invoice History',
      icon: Symbols.receipt_long,
      child: HScrollTable(minWidth: 560, child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
          child: Row(children: [
            _MemberTh('Date',     flex: 2), _MemberTh('Description', flex: 3),
            _MemberTh('Amount',   flex: 1), _MemberTh('Status',      flex: 1),
            const SizedBox(width: 60),
          ]),
        ),
        ...[
          ('Jun 1, 2025',  'Enterprise Plan · June 2025',   'TSh 485,000', 'Paid'),
          ('May 1, 2025',  'Enterprise Plan · May 2025',    'TSh 485,000', 'Paid'),
          ('Apr 1, 2025',  'Enterprise Plan · April 2025',  'TSh 485,000', 'Paid'),
          ('Mar 1, 2025',  'Enterprise Plan · March 2025',  'TSh 485,000', 'Paid'),
        ].map((inv) => Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider))),
          child: Row(children: [
            Expanded(flex: 2, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Text(inv.$1, style: AppTheme.monoXs.copyWith(fontSize: 12)))),
            Expanded(flex: 3, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(inv.$2, style: AppTheme.bodySub.copyWith(fontSize: 12)))),
            Expanded(flex: 1, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(inv.$3, style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)))),
            Expanded(flex: 1, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.tealSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(inv.$4, style: AppTheme.bodySub.copyWith(
                    color: AppColors.teal, fontSize: 11))))),
            SizedBox(width: 60, child: Icon(Symbols.download, size: 16,
                color: context.pal.textDim)),
          ]),
        )),
      ])),
    ),
  ]);

  // ── Section 2: Communication ─────────────────────────────────────────────────

  Widget _communicationSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    _SCard(
      title: 'Email Notifications',
      icon: Symbols.mail_outline,
      child: Column(children: [
        _ToggleRow(label: 'Service ticket assigned to me',
            sub: 'Get notified when a ticket is assigned to you',
            value: _emailTicket, onChanged: (v) => setState(() => _emailTicket = v)),
        _ToggleRow(label: 'Payment overdue alerts',
            sub: 'Alerts for invoices more than 7 days overdue',
            value: _emailPayment, onChanged: (v) => setState(() => _emailPayment = v)),
        _ToggleRow(label: 'Warranty expiry reminders',
            sub: '30-day and 7-day reminders for expiring warranties',
            value: _emailWarranty, onChanged: (v) => setState(() => _emailWarranty = v)),
        _ToggleRow(label: 'Daily digest',
            sub: 'Summary of open tickets, overdue items and upcoming tasks',
            value: _emailDigest, onChanged: (v) => setState(() => _emailDigest = v)),
        if (_emailDigest) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(children: [
              Text('Digest time:', style: AppTheme.bodySub.copyWith(fontSize: 12)),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: _SDropdown(
                  label: '', value: _digestFreq,
                  items: const ['Daily', 'Weekly (Monday)', 'Weekly (Friday)'],
                  onChanged: (v) => setState(() => _digestFreq = v),
                ),
              ),
            ]),
          ),
        ],
      ]),
    ),
    const SizedBox(height: 16),
    _SCard(
      title: 'Push Notifications',
      icon: Symbols.notifications_active,
      child: Column(children: [
        _ToggleRow(label: 'Ticket assigned',
            sub: 'In-app + mobile push when a ticket is assigned',
            value: _pushTicket, onChanged: (v) => setState(() => _pushTicket = v)),
        _ToggleRow(label: 'Payment alerts',
            sub: 'Push notifications for overdue payments',
            value: _pushPayment, onChanged: (v) => setState(() => _pushPayment = v)),
      ]),
    ),
    const SizedBox(height: 16),
    _SCard(
      title: 'Email Signature',
      icon: Symbols.draw,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Appended to all outgoing emails from the system.',
            style: AppTheme.bodySub.copyWith(fontSize: 12)),
        const SizedBox(height: 10),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: context.pal.surface2, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.pal.border)),
          padding: const EdgeInsets.all(12),
          child: Text(
            'MedEquip Tanzania Ltd\ninfo@medequip.tz · +255 22 XXX XXXX\nDar es Salaam, Tanzania',
            style: AppTheme.bodySm.copyWith(color: context.pal.textMute, height: 1.6)),
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight,
          child: _OutlineBtn(label: 'Edit signature', saving: false, onTap: () {})),
      ]),
    ),
  ]);

  // ── Section 3: Connections ───────────────────────────────────────────────────

  Widget _connectionsSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    _SCard(
      title: 'API Access',
      icon: Symbols.code,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Use the API key below to authenticate requests from external systems.',
            style: AppTheme.bodySub.copyWith(fontSize: 12)),
        const SizedBox(height: 14),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: context.pal.surface2, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.pal.border)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(child: Text(
              _apiKeyVisible ? _apiKeyReal : _apiKey,
              style: AppTheme.monoXs.copyWith(
                  color: _apiKeyVisible ? AppColors.teal : context.pal.textMute,
                  fontSize: 12),
              overflow: TextOverflow.ellipsis)),
            GestureDetector(
              onTap: () => setState(() => _apiKeyVisible = !_apiKeyVisible),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(_apiKeyVisible ? Symbols.visibility_off : Symbols.visibility,
                    size: 16, color: context.pal.textDim))),
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: _apiKeyReal));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('API key copied'),
                  backgroundColor: AppColors.teal,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Symbols.content_copy, size: 16, color: context.pal.textDim))),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Symbols.warning, size: 13, color: AppColors.amber),
          const SizedBox(width: 6),
          Expanded(child: Text('Keep your API key secret. Regenerate it if you suspect it has been compromised.',
              style: AppTheme.bodySub.copyWith(color: AppColors.amber, fontSize: 11.5))),
          const SizedBox(width: 12),
          _OutlineBtn(label: 'Regenerate key', saving: false, onTap: () {}),
        ]),
      ]),
    ),
    const SizedBox(height: 16),
    _SCard(
      title: 'Webhooks',
      icon: Symbols.webhook,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Receive real-time POST requests when events occur in Hypermed.',
            style: AppTheme.bodySub.copyWith(fontSize: 12)),
        const SizedBox(height: 14),
        _SettingsField(label: 'Webhook URL', ctrl: TextEditingController(),
            hint: 'https://yourapp.com/webhook/hypermed'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          'ticket.created', 'ticket.resolved', 'machine.status_changed',
          'invoice.overdue', 'warranty.expiring',
        ].map((ev) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.pal.surface2, borderRadius: BorderRadius.circular(5),
            border: Border.all(color: context.pal.border)),
          child: Text(ev, style: AppTheme.monoXs.copyWith(
              color: context.pal.textMute, fontSize: 10.5)),
        )).toList()),
        const SizedBox(height: 14),
        Row(children: [
          _OutlineBtn(label: 'Send test', saving: false, onTap: () {}),
          const SizedBox(width: 10),
          _TealBtn(label: 'Save webhook', saving: false, onTap: () {}),
        ]),
      ]),
    ),
    const SizedBox(height: 16),
    _SCard(
      title: 'Integrations',
      icon: Symbols.extension,
      child: Column(children: [
        ...const [
          ('Slack',    'Send ticket alerts and daily digest to a Slack channel.',    Symbols.forum,     false),
          ('Zapier',   'Connect Hypermed to 5,000+ apps via Zapier automations.',    Symbols.bolt,      false),
          ('WhatsApp', 'Send WhatsApp notifications via the Business API.',          Symbols.chat,      false),
          ('Power BI', 'Stream revenue and service data to Power BI dashboards.',    Symbols.bar_chart, false),
        ].map((integ) => Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: context.pal.surface2, borderRadius: BorderRadius.circular(8)),
              child: Icon(integ.$3, size: 18, color: context.pal.textDim),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(integ.$1, style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
              Text(integ.$2, style: AppTheme.bodySub.copyWith(fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.pal.surface2, borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.pal.border)),
              child: Text('Coming soon', style: AppTheme.monoXs.copyWith(
                  fontSize: 10.5, color: context.pal.textDim)),
            ),
          ]),
        )),
      ]),
    ),
  ]);

  // ── Section 4: Security ──────────────────────────────────────────────────────

  Widget _securitySection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    _SCard(
      title: 'Authentication',
      icon: Symbols.lock,
      child: Column(children: [
        _ToggleRow(
          label: 'Require 2FA for all members',
          sub: 'Members without 2FA will be prompted on next login',
          value: _twoFa, onChanged: (v) => setState(() => _twoFa = v)),
        _ToggleRow(
          label: 'SAML Single Sign-On (SSO)',
          sub: 'Connect to your identity provider — configure in Team → SSO',
          value: _sso, onChanged: (v) => setState(() {
            _sso = v;
            if (v) { _section = 0; _tab = 4; }
          })),
      ]),
    ),
    const SizedBox(height: 16),
    _SCard(
      title: 'Sessions & Access',
      icon: Symbols.manage_accounts,
      child: Column(children: [
        _ToggleRow(
          label: 'Session timeout (8 hours)',
          sub: 'Auto-logout inactive sessions after 8 hours',
          value: _session, onChanged: (v) => setState(() => _session = v)),
        _ToggleRow(
          label: 'Audit log',
          sub: 'Track all member actions and data exports — view in Team → Activity',
          value: _audit, onChanged: (v) => setState(() => _audit = v)),
      ]),
    ),
    const SizedBox(height: 16),
    _SCard(
      title: 'Active Sessions',
      icon: Symbols.devices,
      child: Column(children: [
        ...const [
          ('Windows · Chrome 125',        'Dar es Salaam, TZ',  'Now',          true),
          ('Android · Hypermed Mobile',   'Dar es Salaam, TZ',  '2 hrs ago',    false),
          ('Windows · Chrome 124',        'Arusha, TZ',         '3 days ago',   false),
        ].map((s) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Icon(s.$4 ? Symbols.computer : Symbols.smartphone,
                size: 20, color: s.$4 ? AppColors.teal : context.pal.textDim),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.$1, style: AppTheme.bodySm.copyWith(
                  fontWeight: s.$4 ? FontWeight.w600 : FontWeight.w400)),
              Text('${s.$2} · ${s.$3}', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
            ])),
            if (s.$4)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.tealSoft, borderRadius: BorderRadius.circular(999)),
                child: Text('Current', style: AppTheme.monoXs.copyWith(
                    color: AppColors.teal, fontSize: 10)))
            else
              GestureDetector(
                onTap: () {},
                child: Text('Revoke', style: AppTheme.bodySub.copyWith(
                    color: AppColors.coral, fontSize: 12))),
          ]),
        )),
      ]),
    ),
  ]);

  // ── Section 5: Preferences ───────────────────────────────────────────────────

  Widget _preferencesSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    _SCard(
      title: 'Appearance',
      icon: Symbols.palette,
      child: Column(children: [
        ValueListenableBuilder<AppThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, mode, _) => Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme', style: AppTheme.bodyStrong),
                  const SizedBox(height: 2),
                  Text('Choose your interface appearance', style: AppTheme.bodySub),
                ],
              )),
              const SizedBox(width: 16),
              SegmentedButton<AppThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: AppThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Symbols.light_mode, size: 14),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.neutral,
                    label: Text('Neutral'),
                    icon: Icon(Symbols.tonality, size: 14),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Symbols.dark_mode, size: 14),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => themeNotifier.value = s.first,
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
      ]),
    ),
    const SizedBox(height: 16),
    _SCard(
      title: 'Localisation',
      icon: Symbols.language,
      child: Column(children: [
        Row(children: [
          Expanded(child: _SDropdown(
            label: 'Display Language', value: 'English',
            items: const ['English', 'Swahili', 'French'],
            onChanged: (_) {})),
          const SizedBox(width: 14),
          Expanded(child: _SDropdown(
            label: 'Currency Display', value: 'TSh (TZS)',
            items: const ['TSh (TZS)', 'USD (\$)', 'EUR (€)', 'KES (KSh)'],
            onChanged: (_) {})),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SDropdown(
            label: 'Date Format', value: _dateFormat,
            items: const ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'],
            onChanged: (v) => setState(() => _dateFormat = v))),
          const SizedBox(width: 14),
          Expanded(child: _SDropdown(
            label: 'Time Format', value: '24-hour',
            items: const ['24-hour', '12-hour (AM/PM)'],
            onChanged: (_) {})),
        ]),
      ]),
    ),
    const SizedBox(height: 16),
    _SCard(
      title: 'Table Density',
      icon: Symbols.density_medium,
      child: Row(children: [
        for (final opt in ['Comfortable', 'Compact', 'Dense'])
          Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: opt == 'Comfortable'
                      ? AppColors.tealSoft : context.pal.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: opt == 'Comfortable'
                      ? AppColors.teal : context.pal.border)),
                child: Center(child: Text(opt, style: AppTheme.bodySm.copyWith(
                  color: opt == 'Comfortable' ? AppColors.teal : context.pal.textMute,
                  fontWeight: opt == 'Comfortable' ? FontWeight.w600 : FontWeight.w400))),
              ),
            ),
          )),
      ]),
    ),
  ]);

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _searchBox(BuildContext context, String hint) => Container(
    height: 32,
    decoration: BoxDecoration(color: context.pal.surface1,
        borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(children: [
      Icon(Symbols.search, size: 14, color: context.pal.textDim),
      const SizedBox(width: 6),
      Text(hint, style: AppTheme.bodySub.copyWith(fontSize: 12)),
    ]),
  );

  Widget _filterPill(BuildContext context, String label) => Container(
    height: 32, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: context.pal.surface1,
        borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
    child: Center(child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 12))),
  );
}

// ─── Data classes ──────────────────────────────────────────────────────────────

class _PendingInvite {
  const _PendingInvite(this.email, this.role, this.zone, this.sent);
  final String email, role, zone, sent;
}

class _RoleDef {
  const _RoleDef(this.name, this.color, this.desc, this.perms);
  final String name, desc;
  final Color color;
  final Map<String, bool> perms;
}

class _AuditEntry {
  const _AuditEntry(this.user, this.initials, this.variant,
      this.action, this.detail, this.time);
  final String user, initials, action, detail, time;
  final AvatarVariant variant;
}

// ─── Shared card wrapper ───────────────────────────────────────────────────────

class _SCard extends StatelessWidget {
  const _SCard({required this.title, required this.child,
      this.icon, this.trailing});
  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (icon != null) ...[
          Icon(icon!, size: 16, color: context.pal.textMute),
          const SizedBox(width: 8),
        ] else
          const SizedBox(width: 8),
        Text(title, style: AppTheme.cardTitle),
        if (trailing != null) ...[const Spacer(), trailing!],
      ]),
      const SizedBox(height: 16),
      child,
    ]),
  );
}

// ─── Button helpers ────────────────────────────────────────────────────────────

class _TealBtn extends StatelessWidget {
  const _TealBtn({required this.label, required this.saving, required this.onTap});
  final String label; final bool saving; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: saving ? null : onTap,
    child: Container(
      height: 36, padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
      child: Center(child: saving
        ? const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(label, style: AppTheme.bodyStrong.copyWith(
            color: const Color(0xFF06120F), fontSize: 13))),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({required this.label, required this.saving, required this.onTap});
  final String label; final bool saving; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: saving ? null : onTap,
    child: Container(
      height: 36, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(border: Border.all(color: context.pal.border),
          borderRadius: BorderRadius.circular(8)),
      child: Center(child: saving
        ? const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label, style: AppTheme.bodySm)),
    ),
  );
}

// ─── Dropdown helper ───────────────────────────────────────────────────────────

class _SDropdown extends StatelessWidget {
  const _SDropdown({required this.label, required this.value,
      required this.items, required this.onChanged});
  final String label, value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (label.isNotEmpty) ...[
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 6),
    ],
    Container(
      height: 38,
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        isExpanded: true, dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);
}

// ─── Existing shared widgets (unchanged) ──────────────────────────────────────

class _SettingsSideItem extends StatelessWidget {
  const _SettingsSideItem({required this.icon, required this.label,
      required this.active, required this.onTap});
  final IconData icon; final String label; final bool active; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? context.pal.surface2 : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(children: [
        Icon(icon, size: 17, color: active ? context.pal.text : context.pal.textMute),
        const SizedBox(width: 10),
        Text(label, style: AppTheme.bodySm.copyWith(
          color: active ? context.pal.text : context.pal.textMute, fontSize: 13)),
      ]),
    ),
  );
}

class _MemberTh extends StatelessWidget {
  const _MemberTh(this.label, {required this.flex});
  final String label; final int flex;

  @override
  Widget build(BuildContext context) => Expanded(flex: flex, child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text(label.toUpperCase(),
        style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500)),
  ));
}

class _PendTh extends StatelessWidget {
  const _PendTh(this.label, {required this.flex});
  final String label; final int flex;

  @override
  Widget build(BuildContext context) => Expanded(flex: flex, child: Text(label.toUpperCase(),
      style: AppTheme.monoXs.copyWith(fontWeight: FontWeight.w500)));
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});
  final StaffMember member;

  String _lastActiveLabel() {
    final dt = member.lastActiveAt;
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 5)  return 'Just now';
    if (diff.inHours < 1)    return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = member.role.replaceAll('_', ' ');
    final roleColor = switch (member.role.toLowerCase()) {
      'admin'   => AppColors.teal,
      'finance' => AppColors.amber,
      'sales'   => AppColors.violet,
      _         => context.pal.textMute,
    };
    final isActive = member.availStatus == AvailStatus.available ||
        member.availStatus == AvailStatus.atDesk;

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider))),
      child: Row(children: [
        const SizedBox(width: 20),
        Expanded(flex: 3, child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(children: [
            AvatarWidget(initials: member.initials, size: 28, variant: member.variant),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(member.name,
                    style: AppTheme.bodyStrong.copyWith(fontSize: 12.5),
                    overflow: TextOverflow.ellipsis)),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  Container(width: 6, height: 6,
                      decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('Active', style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 10)),
                ],
              ]),
              Text(member.email ?? '—',
                  style: AppTheme.bodySub.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis),
            ])),
          ]),
        )),
        Expanded(flex: 1, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
            child: Text(roleLabel, style: AppTheme.bodySub.copyWith(
                color: roleColor, fontSize: 11.5, fontWeight: FontWeight.w500)),
          ),
        )),
        Expanded(flex: 1, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: member.twoFa == true
              ? Row(children: [
                  const Icon(Symbols.verified_user, size: 14, color: AppColors.teal),
                  const SizedBox(width: 4),
                  Text('Enabled', style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 11.5)),
                ])
              : Row(children: [
                  const Icon(Symbols.warning, size: 14, color: AppColors.amber),
                  const SizedBox(width: 4),
                  Text('Off', style: AppTheme.bodySub.copyWith(color: AppColors.amber, fontSize: 11.5)),
                ]),
        )),
        Expanded(flex: 1, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(_lastActiveLabel(), style: AppTheme.monoXs.copyWith(fontSize: 11)),
        )),
        SizedBox(width: 60, child: Icon(Symbols.more_horiz, size: 16, color: context.pal.textDim)),
      ]),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.sub,
      required this.value, required this.onChanged});
  final String label, sub; final bool value; final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
        const SizedBox(height: 2),
        Text(sub, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
      ])),
      Switch(
        value: value, onChanged: onChanged,
        activeThumbColor: AppColors.teal,
        inactiveThumbColor: context.pal.textDim,
        inactiveTrackColor: context.pal.surface3,
      ),
    ]),
  );
}

class _SettingsField extends StatelessWidget {
  const _SettingsField({required this.label, required this.ctrl,
      required this.hint, this.obscure = false});
  final String label, hint;
  final TextEditingController ctrl;
  final bool obscure;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (label.isNotEmpty) ...[
      Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 6),
    ],
    Container(
      height: 38,
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Center(child: TextField(
        controller: ctrl, obscureText: obscure, style: AppTheme.bodySm,
        decoration: InputDecoration(hintText: hint,
            hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
      )),
    ),
  ]);
}

// ─── Invite dialog ─────────────────────────────────────────────────────────────

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.onClose, this.onSaved});
  final VoidCallback  onClose;
  final VoidCallback? onSaved;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _role  = 'Technician';
  String _group = 'field';
  String _zone  = 'Dar es Salaam';
  bool   _saving = false;
  String? _error;

  static const _roles  = ['Technician', 'Sales', 'Finance', 'Admin', 'Read Only'];
  static const _groups = ['field', 'office', 'admin'];
  static const _groupLabels = ['Field Technician', 'Office / Sales', 'Admin'];
  static const _zones  = [
    'Dar es Salaam', 'Arusha', 'Kilimanjaro', 'Mwanza', 'Mbeya',
    'Dodoma', 'Tanga', 'Morogoro', 'HQ · Dar es Salaam',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) return;
    setState(() { _saving = true; _error = null; });
    try {
      await StaffService.instance.create({
        'name':    _nameCtrl.text.trim(),
        'email':   _emailCtrl.text.trim(),
        'phone':   _phoneCtrl.text.trim(),
        'role':    _role.toLowerCase().replaceAll(' ', '_'),
        'group':   _group,
        'zone':    _zone,
        'workload': 0.0,
        'is_active': true,
      });
      StaffService.instance.invalidateCache();
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'Failed to add member.'; });
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.pal.borderStrong),
            boxShadow: const [BoxShadow(color: Color(0x70000000), blurRadius: 60, offset: Offset(0, 20))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                const Icon(Symbols.person_add, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Text('Add Team Member', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _SettingsField(label: 'Full Name', ctrl: _nameCtrl, hint: 'e.g. Asha Komba')),
                  const SizedBox(width: 14),
                  Expanded(child: _SettingsField(label: 'Email', ctrl: _emailCtrl, hint: 'email@company.tz')),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _SettingsField(label: 'Phone', ctrl: _phoneCtrl, hint: '+255 7XX XXX XXX')),
                  const SizedBox(width: 14),
                  Expanded(child: _HDropdown(label: 'Role', value: _role, items: _roles,
                      onChanged: (v) => setState(() => _role = v))),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _HDropdown(label: 'Group', value: _group,
                      items: _groups, display: _groupLabels,
                      onChanged: (v) => setState(() => _group = v))),
                  const SizedBox(width: 14),
                  Expanded(child: _HDropdown(label: 'Zone / Region', value: _zone,
                      items: _zones, onChanged: (v) => setState(() => _zone = v))),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 12.5)),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Expanded(child: _OutlineBtn(label: 'Cancel', saving: false, onTap: widget.onClose)),
                const SizedBox(width: 12),
                Expanded(child: _TealBtn(label: 'Add Member', saving: _saving, onTap: _save)),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _HDropdown extends StatelessWidget {
  const _HDropdown({required this.label, required this.value, required this.items,
      this.display, required this.onChanged});
  final String label, value;
  final List<String> items;
  final List<String>? display;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      height: 38,
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, isExpanded: true,
        dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items.asMap().entries.map((e) => DropdownMenuItem(
            value: e.value,
            child: Text(display != null ? display![e.key] : e.value))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);
}
