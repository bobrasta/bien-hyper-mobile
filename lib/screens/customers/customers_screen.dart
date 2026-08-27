import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/contact.dart';
import '../../services/contact_service.dart';
import '../../services/hospital_service.dart';
import '../../utils/api_error.dart';
import '../../utils/csv_export.dart';
import '../../widgets/common/error_view.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/email/compose_modal.dart';
import '../../theme/app_palette.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  int _selectedIdx = 0;
  String _tagFilter = 'all';
  final _search = TextEditingController();
  bool _showAddContact = false;
  bool _showLogInteraction = false;
  bool _showEditContact = false;
  bool _showScheduleFollowup = false;
  bool _showCompose = false;
  bool _showDetail = false;

  List<Contact> _allContacts   = [];
  List<String>  _hospitalNames = [];
  bool          _loading       = true;
  String?       _error;
  int           _showCount     = 25;
  static const  _pageSize      = 25;

  Contact? _detailContact;
  bool     _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ContactService.instance.list(),
        HospitalService.instance.list(),
      ]);
      if (mounted) {
        final contacts = results[0] as List<Contact>;
        setState(() {
          _allContacts   = contacts;
          _hospitalNames = (results[1] as List).map((h) => (h as dynamic).name as String).toList();
          _loading       = false;
          _detailContact = null;
        });
        if (contacts.isNotEmpty) _loadDetail(contacts[0]);
      }
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _loadDetail(Contact c) async {
    if (_detailContact?.id == c.id) return;
    setState(() { _loadingDetail = true; _detailContact = null; });
    try {
      final full = await ContactService.instance.get(c.id);
      if (mounted) setState(() { _detailContact = full; _loadingDetail = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final data = _filtered;
      final path = await CsvExport.contacts(data);
      if (path != null && mounted) showSuccessToast(context, 'Exported ${data.length} contact(s) to CSV');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  List<Contact> get _filtered {
    var list = _allContacts;
    if (_tagFilter != 'all') {
      list = list.where((c) => c.tags.contains(_tagFilter)).toList();
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) =>
        c.fullName.toLowerCase().contains(q) ||
        (c.email ?? '').toLowerCase().contains(q) ||
        c.hospitalName.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Contact? get _selected {
    final filtered = _filtered;
    if (filtered.isEmpty) return null;
    if (_selectedIdx >= filtered.length) return filtered.first;
    return filtered[_selectedIdx];
  }

  @override
  Widget build(BuildContext context) {
    final allFiltered = _filtered;
    final contacts    = allFiltered.take(_showCount).toList();
    final remaining   = allFiltered.length - contacts.length;
    final contact     = _selected;

    return Stack(children: [
      LayoutBuilder(builder: (ctx, cst) {
        final narrow = cst.maxWidth < 640;

        // ── Left pane (contact list) ────────────────────────────────────────
        Widget listPane = Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(
              color: narrow ? Colors.transparent : context.pal.border)),
          ),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.pal.border)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Contacts', style: AppTheme.pageTitle.copyWith(fontSize: 18))),
                  AppButton(label: 'Export', icon: Symbols.download, variant: BtnVariant.ghost, small: true,
                      onPressed: _exportCsv),
                  const SizedBox(width: 6),
                  AppButton(label: 'Add Contact', icon: Symbols.person_add, variant: BtnVariant.primary, small: true,
                      onPressed: () => setState(() => _showAddContact = true)),
                ]),
                const SizedBox(height: 12),
                // Search
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.pal.surface1,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.pal.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(children: [
                    const SizedBox(width: 6),
                    Expanded(child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() { _selectedIdx = 0; _showCount = _pageSize; }),
                      style: AppTheme.bodySm.copyWith(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Search contacts…',
                        hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim, fontSize: 12.5),
                        border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                      ),
                    )),
                  ]),
                ),
                const SizedBox(height: 10),
                // Tag filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _TagChip(label: 'All', value: 'all', active: _tagFilter == 'all',
                      onTap: () => setState(() { _tagFilter = 'all'; _selectedIdx = 0; _showCount = _pageSize; })),
                    const SizedBox(width: 6),
                    _TagChip(label: 'Key Account', value: 'key-account', active: _tagFilter == 'key-account',
                      onTap: () => setState(() { _tagFilter = 'key-account'; _selectedIdx = 0; _showCount = _pageSize; })),
                    const SizedBox(width: 6),
                    _TagChip(label: 'Decision Maker', value: 'decision-maker', active: _tagFilter == 'decision-maker',
                      onTap: () => setState(() { _tagFilter = 'decision-maker'; _selectedIdx = 0; _showCount = _pageSize; })),
                    const SizedBox(width: 6),
                    _TagChip(label: 'Lead', value: 'lead', active: _tagFilter == 'lead',
                      onTap: () => setState(() { _tagFilter = 'lead'; _selectedIdx = 0; _showCount = _pageSize; })),
                    const SizedBox(width: 6),
                    _TagChip(label: 'Technical', value: 'technical', active: _tagFilter == 'technical',
                      onTap: () => setState(() { _tagFilter = 'technical'; _selectedIdx = 0; _showCount = _pageSize; })),
                  ]),
                ),
              ]),
            ),
            // Contact list
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: contacts.isEmpty
                          ? ListView(children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 48),
                                child: Center(child: Text('No contacts found', style: AppTheme.bodySub)),
                              ),
                            ])
                          : ListView.builder(
                              itemCount: contacts.length + (remaining > 0 ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i == contacts.length) {
                                  return GestureDetector(
                                    onTap: () => setState(() => _showCount += _pageSize),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Load $remaining more',
                                        style: AppTheme.bodySm.copyWith(color: AppColors.teal, fontSize: 12.5),
                                      ),
                                    ),
                                  );
                                }
                                return _ContactListItem(
                                  contact: contacts[i],
                                  selected: _selectedIdx == i,
                                  onTap: () {
                                    setState(() { _selectedIdx = i; _showDetail = true; });
                                    _loadDetail(contacts[i]);
                                  },
                                );
                              },
                            ),
                      ),
            ),
          ]),
        );

        // ── Narrow: list or detail ──────────────────────────────────────────
        if (narrow) {
          if (_showDetail && contact != null) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              GestureDetector(
                onTap: () => setState(() => _showDetail = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: context.pal.border)),
                  ),
                  child: Row(children: [
                    Icon(Symbols.arrow_back, size: 16, color: AppColors.teal),
                    const SizedBox(width: 8),
                    Text('Back to contacts', style: AppTheme.bodySm.copyWith(color: AppColors.teal)),
                  ]),
                ),
              ),
              Expanded(child: _ContactDetail(
                contact: _detailContact ?? contact,
                loadingDetail: _loadingDetail,
                onLogInteraction: () => setState(() => _showLogInteraction = true),
                onEditContact: () => setState(() => _showEditContact = true),
                onScheduleFollowup: () => setState(() => _showScheduleFollowup = true),
                onSendEmail: () => setState(() => _showCompose = true),
              )),
            ]);
          }
          return listPane;
        }

        // ── Wide: side-by-side ──────────────────────────────────────────────
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 340, child: listPane),
          Expanded(
            child: contact == null
              ? Center(child: Text('Select a contact', style: TextStyle(color: context.pal.textMute)))
              : _ContactDetail(
                  contact: _detailContact ?? contact,
                  loadingDetail: _loadingDetail,
                  onLogInteraction: () => setState(() => _showLogInteraction = true),
                  onEditContact: () => setState(() => _showEditContact = true),
                  onScheduleFollowup: () => setState(() => _showScheduleFollowup = true),
                  onSendEmail: () => setState(() => _showCompose = true),
                ),
          ),
        ]);
      }),  // LayoutBuilder

      // Dialogs
      if (_showAddContact)
        _AddContactDialog(
          hospitalNames: _hospitalNames,
          onClose: () => setState(() => _showAddContact = false),
          onSaved: () { setState(() => _showAddContact = false); _load(); },
        ),
      if (_showLogInteraction)
        _LogInteractionDialog(
          contact: contact,
          onClose: () => setState(() => _showLogInteraction = false),
          onSaved: () { setState(() => _showLogInteraction = false); _load(); },
        ),
      if (_showEditContact && contact != null)
        _EditContactDialog(
          contact: contact,
          hospitalNames: _hospitalNames,
          onClose: () => setState(() => _showEditContact = false),
          onSaved: () { setState(() => _showEditContact = false); _load(); },
        ),
      if (_showScheduleFollowup && contact != null)
        _ScheduleFollowupDialog(
          contact: _detailContact ?? contact,
          onClose: () => setState(() => _showScheduleFollowup = false),
          onSaved: () {
            setState(() { _showScheduleFollowup = false; _detailContact = null; });
            _loadDetail(contact);
          },
        ),
      if (_showCompose && contact != null)
        ComposeModal(
          initialTo: (_detailContact ?? contact).email ?? '',
          onClose: () => setState(() => _showCompose = false),
          onSent:  () => setState(() => _showCompose = false),
        ),
    ]);  // Stack
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.value, required this.active, required this.onTap});
  final String label, value; final bool active; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.tealSoft : context.pal.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppColors.teal : context.pal.border),
      ),
      child: Text(label, style: AppTheme.bodySub.copyWith(
        color: active ? AppColors.teal : context.pal.textMute,
        fontSize: 11.5, fontWeight: FontWeight.w500,
      )),
    ),
  );
}

class _ContactListItem extends StatelessWidget {
  const _ContactListItem({required this.contact, required this.selected, required this.onTap});
  final Contact contact; final bool selected; final VoidCallback onTap;

  AvatarVariant _variant(String name) {
    final h = name.hashCode;
    const variants = AvatarVariant.values;
    return variants[h.abs() % variants.length];
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? context.pal.surface2 : Colors.transparent,
        border: Border(bottom: BorderSide(color: context.pal.divider)),
      ),
      child: Row(children: [
        AvatarWidget(initials: contact.initials, size: 36, variant: _variant(contact.fullName)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(contact.fullName, style: AppTheme.bodyStrong.copyWith(fontSize: 13)),
          Text(contact.jobTitle ?? contact.hospitalName,
            style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
          const SizedBox(height: 4),
          Row(children: contact.tags.take(2).map((tag) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: context.pal.surface3, borderRadius: BorderRadius.circular(4)),
              child: Text(tag, style: AppTheme.monoXs.copyWith(fontSize: 9.5, color: context.pal.textMute)),
            ),
          )).toList()),
        ])),
        if (contact.nextFollowupAt != null) ...[
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Icon(Symbols.calendar_today, size: 12, color: AppColors.amber),
            const SizedBox(height: 2),
            Text(contact.nextFollowupAt!, style: AppTheme.monoXs.copyWith(color: AppColors.amber, fontSize: 10)),
          ]),
        ],
      ]),
    ),
  );
}

class _ContactDetail extends StatelessWidget {
  const _ContactDetail({
    required this.contact,
    this.loadingDetail = false,
    this.onLogInteraction,
    this.onEditContact,
    this.onScheduleFollowup,
    this.onSendEmail,
  });
  final Contact contact;
  final bool loadingDetail;
  final VoidCallback? onLogInteraction;
  final VoidCallback? onEditContact;
  final VoidCallback? onScheduleFollowup;
  final VoidCallback? onSendEmail;

  AvatarVariant _variant(String name) {
    final h = name.hashCode;
    const variants = AvatarVariant.values;
    return variants[h.abs() % variants.length];
  }

  String _interactionIcon(String type) => switch (type) {
    'call'     => '📞',
    'email'    => '✉️',
    'meeting'  => '🤝',
    'whatsapp' => '💬',
    'visit'    => '🏥',
    _          => '📋',
  };

  Color _dotColor(String type) => switch (type) {
    'call'     => AppColors.teal,
    'email'    => AppColors.blue,
    'meeting'  => AppColors.violet,
    'whatsapp' => const Color(0xFF25D366),
    'visit'    => AppColors.amber,
    _          => AppColors.textDim,
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Profile header
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AvatarWidget(initials: contact.initials, size: 56, variant: _variant(contact.fullName)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact.fullName, style: AppTheme.pageTitle.copyWith(fontSize: 20)),
            const SizedBox(height: 2),
            if (contact.jobTitle != null)
              Text(contact.jobTitle!, style: AppTheme.bodySub),
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 6),
              Text(contact.hospitalName, style: AppTheme.bodySm),
            ]),
            if (contact.department != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const SizedBox(width: 6),
                Text(contact.department!, style: AppTheme.bodySm),
              ]),
            ],
          ])),
          Column(children: [
            AppButton(label: 'Log Interaction', icon: Symbols.add_comment, variant: BtnVariant.primary, small: true,
                onPressed: onLogInteraction),
            const SizedBox(height: 8),
            AppButton(label: 'Edit Contact', icon: Symbols.edit, variant: BtnVariant.normal, small: true,
                onPressed: onEditContact),
            const SizedBox(height: 8),
            AppButton(label: 'Send Email', icon: Symbols.mail, variant: BtnVariant.normal, small: true,
                onPressed: contact.email != null ? onSendEmail : null),
          ]),
        ]),
      ),
      const SizedBox(height: 16),

      // Contact info + follow-up row
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Contact details
        Expanded(child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const SizedBox(width: 8),
              Text('Contact Details', style: AppTheme.cardTitle),
            ]),
            const SizedBox(height: 14),
            if (contact.email != null)
              _DetailRow(icon: Symbols.mail_outline, value: contact.email!),
            if (contact.phone != null) ...[
              const SizedBox(height: 8),
              _DetailRow(icon: Symbols.phone, value: contact.phone!),
            ],
            if (contact.whatsapp != null) ...[
              const SizedBox(height: 8),
              _DetailRow(icon: Symbols.chat, value: contact.whatsapp!),
            ],
            if (contact.lastContactedAt != null) ...[
              const SizedBox(height: 14),
              const SizedBox(height: 10),
              _DetailRow(icon: Symbols.history, value: 'Last contacted: ${contact.lastContactedAt!}'),
            ],
          ]),
        )),
        const SizedBox(width: 16),
        // Follow-up
        Expanded(child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const SizedBox(width: 8),
              Text('Follow-up & Tags', style: AppTheme.cardTitle),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: contact.nextFollowupAt != null ? AppColors.amberSoft : context.pal.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: contact.nextFollowupAt != null
                    ? AppColors.amber.withValues(alpha: 0.3) : context.pal.border),
              ),
              child: Row(children: [
                Icon(Symbols.calendar_today, size: 14,
                    color: contact.nextFollowupAt != null ? AppColors.amber : context.pal.textDim),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Next Follow-up', style: AppTheme.labelCaps),
                  Text(contact.nextFollowupAt ?? 'Not scheduled',
                      style: AppTheme.bodyStrong.copyWith(
                          color: contact.nextFollowupAt != null ? AppColors.amber : context.pal.textMute)),
                ])),
                GestureDetector(
                  onTap: onScheduleFollowup,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Symbols.edit_calendar, size: 14, color: AppColors.teal),
                    const SizedBox(width: 4),
                    Text('Set', style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 11.5)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (contact.tags.isNotEmpty) ...[
              Text('TAGS', style: AppTheme.labelCaps),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: contact.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tealSoft, borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                ),
                child: Text(tag, style: AppTheme.bodySub.copyWith(
                  color: AppColors.teal, fontSize: 11.5, fontWeight: FontWeight.w500)),
              )).toList()),
            ],
          ]),
        )),
      ]),
      const SizedBox(height: 16),

      // Interaction history
      Container(
        decoration: BoxDecoration(
          color: context.pal.surface1,
          borderRadius: BorderRadius.circular(AppColors.rLg),
          border: Border.all(color: context.pal.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(children: [
              const SizedBox(width: 8),
              Text('Interaction History', style: AppTheme.cardTitle),
              const Spacer(),
              if (loadingDetail)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Text('${contact.interactions.length} interactions',
                  style: AppTheme.monoXs.copyWith(color: context.pal.textDim)),
            ]),
          ),
          if (!loadingDetail && contact.interactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('No interactions logged yet', style: AppTheme.bodySub)),
            )
          else if (!loadingDetail)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: contact.interactions.asMap().entries.map((e) {
                  final isLast = e.key == contact.interactions.length - 1;
                  final ix = e.value;
                  return IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Timeline spine
                      SizedBox(width: 32, child: Column(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _dotColor(ix.type).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: _dotColor(ix.type).withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(_interactionIcon(ix.type), style: const TextStyle(fontSize: 13)),
                        ),
                        if (!isLast)
                          Expanded(child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: context.pal.divider,
                          )),
                      ])),
                      const SizedBox(width: 12),
                      // Content
                      Expanded(child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 4),
                          Row(children: [
                            Text(ix.type.toUpperCase(), style: AppTheme.labelCaps),
                            const SizedBox(width: 8),
                            Text(ix.createdAt, style: AppTheme.bodySub.copyWith(fontSize: 11)),
                          ]),
                          const SizedBox(height: 4),
                          Text(ix.summary, style: AppTheme.bodySm.copyWith(height: 1.5)),
                          if (ix.outcome != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              Text('Outcome: ', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                              Flexible(child: Text(ix.outcome!,
                                  style: AppTheme.bodySm.copyWith(fontSize: 11.5, color: AppColors.teal))),
                            ]),
                          ],
                          if (ix.nextAction != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Symbols.arrow_forward, size: 12, color: AppColors.amber),
                              const SizedBox(width: 4),
                              Flexible(child: Text(
                                '${ix.nextAction!}${ix.nextActionDate != null ? "  ·  ${ix.nextActionDate}" : ""}',
                                style: AppTheme.bodySub.copyWith(fontSize: 11.5, color: AppColors.amber))),
                            ]),
                          ],
                        ]),
                      )),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ]),
      ),
    ]),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value});
  final IconData icon; final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: context.pal.textDim),
    const SizedBox(width: 8),
    Expanded(child: Text(value, style: AppTheme.bodySm.copyWith(fontSize: 12.5))),
  ]);
}

// ── Add Contact Dialog ──────────────────────────────────────────────────────
class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog({required this.onClose, required this.hospitalNames, this.onSaved});
  final VoidCallback  onClose;
  final VoidCallback? onSaved;
  final List<String>  hospitalNames;
  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl  = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _hospital = '';
  bool   _saving   = false;

  @override
  void initState() {
    super.initState();
    if (widget.hospitalNames.isNotEmpty) _hospital = widget.hospitalNames.first;
  }

  @override
  void dispose() {
    _firstCtrl.dispose(); _lastCtrl.dispose(); _titleCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _firstCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ContactService.instance.create({
        'first_name':    _firstCtrl.text.trim(),
        'last_name':     _lastCtrl.text.trim(),
        'job_title':     _titleCtrl.text.trim(),
        'hospital_name': _hospital,
        'email':         _emailCtrl.text.trim(),
        'phone':         _phoneCtrl.text.trim(),
      });
      if (mounted) showSuccessToast(context, 'Contact created');
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) { setState(() => _saving = false); showErrorToast(context, e); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospitals = widget.hospitalNames;
    final effectiveHospital = hospitals.contains(_hospital) && hospitals.isNotEmpty
        ? _hospital : (hospitals.isNotEmpty ? hospitals.first : '');
    return _ModalShell(
    onClose: widget.onClose,
    onSave: _save,
    saving: _saving,
    icon: Symbols.person_add,
    title: 'Add Contact',
    saveLabel: 'Save Contact',
    child: Column(children: [
      Row(children: [
        Expanded(child: _CField('First Name', _firstCtrl, 'Amina')),
        const SizedBox(width: 14),
        Expanded(child: _CField('Last Name', _lastCtrl, 'Hassan')),
      ]),
      const SizedBox(height: 14),
      _CField('Job Title', _titleCtrl, 'e.g. Head of Procurement'),
      const SizedBox(height: 14),
      if (hospitals.isNotEmpty) _CDropdown(
        label: 'Hospital',
        value: effectiveHospital,
        items: hospitals,
        onChanged: (v) => setState(() => _hospital = v),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _CField('Email', _emailCtrl, 'name@hospital.go.tz')),
        const SizedBox(width: 14),
        Expanded(child: _CField('Phone', _phoneCtrl, '+255 7XX XXX XXX')),
      ]),
    ]),
  );
  }
}

// ── Log Interaction Dialog ──────────────────────────────────────────────────
class _LogInteractionDialog extends StatefulWidget {
  const _LogInteractionDialog({required this.onClose, this.contact, this.onSaved});
  final VoidCallback  onClose;
  final VoidCallback? onSaved;
  final Contact?      contact;
  @override
  State<_LogInteractionDialog> createState() => _LogInteractionDialogState();
}

class _LogInteractionDialogState extends State<_LogInteractionDialog> {
  String    _type    = 'call';
  String    _outcome = 'Positive —follow-up needed';
  DateTime? _nextActionDate;
  bool      _saving  = false;
  String?   _error;
  final _summaryCtrl    = TextEditingController();
  final _nextActionCtrl = TextEditingController();

  @override
  void dispose() { _summaryCtrl.dispose(); _nextActionCtrl.dispose(); super.dispose(); }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextActionDate ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _nextActionDate = picked);
  }

  Future<void> _save() async {
    final contact = widget.contact;
    if (contact == null || _saving || _summaryCtrl.text.trim().isEmpty) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ContactService.instance.addInteraction(contact.id, {
        'type':             _type,
        'summary':          _summaryCtrl.text.trim(),
        'outcome':          _outcome,
        if (_nextActionCtrl.text.trim().isNotEmpty)
          'next_action': _nextActionCtrl.text.trim(),
        if (_nextActionDate != null)
          'next_action_date': _fmtDate(_nextActionDate!),
      });
      if (mounted) showSuccessToast(context, 'Interaction logged');
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) { setState(() => _saving = false); showErrorToast(context, e); }
    }
  }

  @override
  Widget build(BuildContext context) => _ModalShell(
    onClose: widget.onClose,
    onSave:  _save,
    saving:  _saving,
    icon: Symbols.add_comment,
    title: 'Log Interaction${widget.contact != null ? " · ${widget.contact!.fullName}" : ""}',
    saveLabel: 'Save Interaction',
    child: Column(children: [
      _CDropdown(
        label: 'Type',
        value: _type,
        items: const ['call', 'email', 'meeting', 'whatsapp', 'visit'],
        display: const ['Phone Call', 'Email', 'Meeting', 'WhatsApp', 'Site Visit'],
        onChanged: (v) => setState(() => _type = v),
      ),
      const SizedBox(height: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SUMMARY'.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
        const SizedBox(height: 6),
        Container(
          height: 80,
          decoration: BoxDecoration(color: context.pal.surface2,
              borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(controller: _summaryCtrl, maxLines: null, expands: true,
            style: AppTheme.bodySm,
            decoration: InputDecoration(hintText: 'What was discussed?',
                hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)),
        ),
      ]),
      const SizedBox(height: 14),
      _CDropdown(
        label: 'Outcome',
        value: _outcome,
        items: const [
          'Positive —follow-up needed',
          'Proposal requested',
          'Contract signed',
          'Not interested',
          'No answer',
        ],
        onChanged: (v) => setState(() => _outcome = v),
      ),
      const SizedBox(height: 14),
      _CField('Next Action', _nextActionCtrl, 'e.g. Send formal proposal'),
      const SizedBox(height: 14),
      // Next action date picker
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NEXT ACTION DATE', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.pal.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _nextActionDate != null ? AppColors.teal : context.pal.border),
            ),
            child: Row(children: [
              Icon(Symbols.calendar_today, size: 14,
                  color: _nextActionDate != null ? AppColors.teal : context.pal.textDim),
              const SizedBox(width: 8),
              Text(
                _nextActionDate != null ? _fmtDate(_nextActionDate!) : 'Optional —pick a date',
                style: AppTheme.bodySm.copyWith(
                  color: _nextActionDate != null ? context.pal.text : context.pal.textDim),
              ),
            ]),
          ),
        ),
      ]),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
      ],
    ]),
  );
}

// ── Schedule Follow-up Dialog ───────────────────────────────────────────────
class _ScheduleFollowupDialog extends StatefulWidget {
  const _ScheduleFollowupDialog({required this.contact, required this.onClose, this.onSaved});
  final Contact      contact;
  final VoidCallback onClose;
  final VoidCallback? onSaved;
  @override
  State<_ScheduleFollowupDialog> createState() => _ScheduleFollowupDialogState();
}

class _ScheduleFollowupDialogState extends State<_ScheduleFollowupDialog> {
  DateTime? _date;
  bool      _saving = false;
  String?   _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing follow-up date if set
    if (widget.contact.nextFollowupAt != null) {
      _date = DateTime.tryParse(widget.contact.nextFollowupAt!);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_date == null || _saving) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ContactService.instance.update(widget.contact.id, {'next_followup_at': _fmtDate(_date!)});
      if (mounted) showSuccessToast(context, 'Follow-up scheduled for ${_fmtDate(_date!)}');
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = friendlyError(e); });
    }
  }

  @override
  Widget build(BuildContext context) => _ModalShell(
    onClose: widget.onClose,
    onSave:  _save,
    saving:  _saving,
    icon: Symbols.edit_calendar,
    title: 'Schedule Follow-up · ${widget.contact.fullName}',
    saveLabel: 'Schedule',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('FOLLOW-UP DATE', style: AppTheme.labelCaps.copyWith(fontSize: 10)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.pal.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _date != null ? AppColors.teal : context.pal.border),
          ),
          child: Row(children: [
            Icon(Symbols.calendar_today, size: 16,
                color: _date != null ? AppColors.teal : context.pal.textDim),
            const SizedBox(width: 10),
            Text(
              _date != null ? _fmtDate(_date!) : 'Click to choose a date',
              style: AppTheme.bodySm.copyWith(
                  color: _date != null ? context.pal.text : context.pal.textDim),
            ),
          ]),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
      ],
    ]),
  );
}

// ── Shared modal shell ──────────────────────────────────────────────────────
class _ModalShell extends StatelessWidget {
  const _ModalShell({
    required this.onClose,
    required this.icon,
    required this.title,
    required this.child,
    required this.saveLabel,
    this.onSave,
    this.saving = false,
  });
  final VoidCallback  onClose;
  final VoidCallback? onSave;
  final IconData icon;
  final String title, saveLabel;
  final Widget child;
  final bool saving;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onClose,
    child: Container(
      color: const Color(0xAA06070A),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 500,
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
                Icon(icon, size: 18, color: AppColors.teal),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: AppTheme.bodyStrong)),
                GestureDetector(onTap: onClose,
                    child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(padding: const EdgeInsets.all(20), child: child),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: onClose,
                  child: Container(height: 38,
                    decoration: BoxDecoration(border: Border.all(color: context.pal.border),
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('Cancel', style: AppTheme.bodySm))),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: onSave ?? onClose,
                  child: Container(height: 38,
                    decoration: BoxDecoration(color: AppColors.teal,
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(child: saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(saveLabel, style: AppTheme.bodyStrong.copyWith(
                          color: const Color(0xFF06120F), fontSize: 13)))),
                )),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _CField extends StatelessWidget {
  const _CField(this.label, this.ctrl, this.hint);
  final String label, hint;
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10)),
    const SizedBox(height: 6),
    Container(
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(controller: ctrl, style: AppTheme.bodySm,
        decoration: InputDecoration(hintText: hint,
            hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
            border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero)),
    ),
  ]);
}

class _CDropdown extends StatelessWidget {
  const _CDropdown({required this.label, required this.value, required this.items,
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
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, isExpanded: true,
        dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
        icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
        items: items.asMap().entries.map((e) =>
            DropdownMenuItem(value: e.value,
                child: Text(display != null ? display![e.key] : e.value))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      )),
    ),
  ]);
}

// ── Edit Contact Dialog ─────────────────────────────────────────────────────
class _EditContactDialog extends StatefulWidget {
  const _EditContactDialog({required this.contact, required this.onClose, required this.hospitalNames, this.onSaved});
  final Contact      contact;
  final VoidCallback onClose;
  final VoidCallback? onSaved;
  final List<String>  hospitalNames;
  @override
  State<_EditContactDialog> createState() => _EditContactDialogState();
}

class _EditContactDialogState extends State<_EditContactDialog> {
  late final _firstCtrl = TextEditingController(text: widget.contact.firstName);
  late final _lastCtrl  = TextEditingController(text: widget.contact.lastName);
  late final _titleCtrl = TextEditingController(text: widget.contact.jobTitle ?? '');
  late final _emailCtrl = TextEditingController(text: widget.contact.email ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.contact.phone ?? '');
  late String _hospital = widget.contact.hospitalName;
  bool        _saving   = false;

  @override
  void dispose() {
    _firstCtrl.dispose(); _lastCtrl.dispose(); _titleCtrl.dispose();
    _emailCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ContactService.instance.update(widget.contact.id, {
        'first_name':    _firstCtrl.text.trim(),
        'last_name':     _lastCtrl.text.trim(),
        'job_title':     _titleCtrl.text.trim(),
        'hospital_name': _hospital,
        'email':         _emailCtrl.text.trim(),
        'phone':         _phoneCtrl.text.trim(),
      });
      if (mounted) showSuccessToast(context, 'Contact updated');
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) { setState(() => _saving = false); showErrorToast(context, e); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospitals = widget.hospitalNames;
    final effectiveHospital = hospitals.contains(_hospital) ? _hospital
        : (hospitals.isNotEmpty ? hospitals.first : _hospital);

    return _ModalShell(
      onClose: widget.onClose,
      onSave: _save,
      saving: _saving,
      icon: Symbols.edit,
      title: 'Edit: ${widget.contact.fullName}',
      saveLabel: 'Save Changes',
      child: Column(children: [
        Row(children: [
          Expanded(child: _CField('First Name', _firstCtrl, '')),
          const SizedBox(width: 14),
          Expanded(child: _CField('Last Name', _lastCtrl, '')),
        ]),
        const SizedBox(height: 14),
        _CField('Job Title', _titleCtrl, ''),
        const SizedBox(height: 14),
        if (hospitals.isNotEmpty) _CDropdown(
          label: 'Hospital',
          value: effectiveHospital,
          items: hospitals,
          onChanged: (v) => setState(() => _hospital = v),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _CField('Email', _emailCtrl, '')),
          const SizedBox(width: 14),
          Expanded(child: _CField('Phone', _phoneCtrl, '')),
        ]),
      ]),
    );
  }
}
