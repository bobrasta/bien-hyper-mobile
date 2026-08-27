import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../services/staff_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_palette.dart';
import '../../utils/format.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/error_view.dart';
import 'staff_hr_dialogs.dart';

class HrDirectoryTab extends StatefulWidget {
  const HrDirectoryTab({super.key});

  @override
  State<HrDirectoryTab> createState() => _HrDirectoryTabState();
}

class _HrDirectoryTabState extends State<HrDirectoryTab> {
  List<StaffMember> _staff = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  int? _selectedId;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({bool force = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await StaffService.instance.list(force: force);
      if (mounted) setState(() {
        _staff = list;
        _loading = false;
        _selectedId ??= list.isNotEmpty ? list.first.id : null;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<StaffMember> get _filtered => _search.isEmpty
      ? _staff
      : _staff.where((s) => s.name.toLowerCase().contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final selectedMatches = _staff.where((s) => s.id == _selectedId);
    final selected = selectedMatches.isEmpty ? null : selectedMatches.first;

    return LayoutBuilder(builder: (ctx, cst) {
      final narrow = cst.maxWidth < 760;
      final list = Container(
        width: narrow ? double.infinity : 320,
        decoration: BoxDecoration(
          border: narrow ? null : Border(right: BorderSide(color: context.pal.border)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search staff…',
                prefixIcon: const Icon(Symbols.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final s = _filtered[i];
                final isSelected = s.id == _selectedId;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: AppColors.tealSoft,
                  leading: AvatarWidget(initials: s.initials, size: 32, variant: s.variant),
                  title: Text(s.name, style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(s.positionTitle ?? s.role, style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
                  onTap: () => setState(() => _selectedId = s.id),
                );
              },
            ),
          ),
        ]),
      );

      final detail = selected == null
          ? Center(child: Text('Select a staff member', style: AppTheme.bodySub))
          : _StaffDetailPane(member: selected, staffList: _staff, onChanged: () => _load(force: true));

      if (narrow) {
        return selected != null && _selectedId != null
            ? Column(children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                    onPressed: () => setState(() => _selectedId = null),
                    icon: const Icon(Symbols.arrow_back, size: 16),
                    label: const Text('Back to list'),
                  )),
                ),
                Expanded(child: detail),
              ])
            : list;
      }

      return Row(children: [list, Expanded(child: detail)]);
    });
  }
}

class _StaffDetailPane extends StatelessWidget {
  const _StaffDetailPane({required this.member, required this.staffList, required this.onChanged});
  final StaffMember member;
  final List<StaffMember> staffList;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        AvatarWidget(initials: member.initials, size: 48, variant: member.variant),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(member.name, style: AppTheme.pageTitle.copyWith(fontSize: 18)),
          Text('${member.positionTitle ?? member.role} · ${member.role}', style: AppTheme.bodySub),
        ])),
        TextButton.icon(
          onPressed: () => showEditHrDetailsDialog(context, member, staffList, onChanged),
          icon: const Icon(Symbols.edit, size: 16),
          label: const Text('Edit'),
        ),
      ]),
      const SizedBox(height: 24),
      _InfoSection(title: 'Personal Info', children: [
        _InfoRow('Gender', member.gender ?? '—'),
        _InfoRow('Hire Date', member.hireDate != null ? formatDate(member.hireDate!) : '—'),
        _InfoRow('Email', member.email ?? '—'),
        _InfoRow('Phone', member.phone ?? '—'),
        _InfoRow('Zone', member.zone ?? '—'),
      ]),
      const SizedBox(height: 16),
      _InfoSection(title: 'Next of Kin', children: [
        _InfoRow('Name', member.nextOfKinName ?? '—'),
        _InfoRow('Phone', member.nextOfKinPhone ?? '—'),
        _InfoRow('Relationship', member.nextOfKinRelationship ?? '—'),
      ]),
      const SizedBox(height: 16),
      _InfoSection(title: 'Statutory IDs', children: [
        _InfoRow('NSSF No.', member.nssfNumber ?? '—'),
        _InfoRow('TIN No.', member.tinNumber ?? '—'),
        _InfoRow('NIDA No.', member.nidaNumber ?? '—'),
        _InfoRow('Biometric ID', member.biometricId ?? '—'),
      ]),
      const SizedBox(height: 20),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _ActionCard(
          icon: Symbols.description, label: 'Contracts',
          onTap: () => showContractsDialog(context, member),
        ),
        _ActionCard(
          icon: Symbols.gavel, label: 'Disciplinary Cases',
          onTap: () => showDisciplinaryCasesDialog(context, member),
        ),
        _ActionCard(
          icon: Symbols.trending_up, label: 'Career Progression',
          onTap: () => showCareerProgressionDialog(context, member),
        ),
      ]),
    ]),
  );
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.pal.surface1,
      borderRadius: BorderRadius.circular(AppColors.rLg),
      border: Border.all(color: context.pal.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 10.5, color: context.pal.textDim)),
      const SizedBox(height: 10),
      ...children,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 140, child: Text(label, style: AppTheme.bodySub.copyWith(fontSize: 12.5))),
      Expanded(child: Text(value, style: AppTheme.bodySm.copyWith(fontSize: 12.5))),
    ]),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.pal.surface1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.pal.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.teal),
        const SizedBox(width: 8),
        Text(label, style: AppTheme.bodySm.copyWith(fontSize: 12.5)),
      ]),
    ),
  );
}
