import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show can, userIdNotifier;
import '../../services/staff_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../widgets/common/error_view.dart';

// sales.create_subordinate_user has existed in the permission catalog since
// the original access-control pass, granted to sales_manager, but nothing
// ever surfaced it — a sales_manager had no way to build their own team at
// all. This screen is gated by that permission specifically (via can()),
// not by role, matching how the backend gate works (StaffController).
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<StaffMember> _team = [];
  bool _loading = true;
  String? _error;
  bool _showAdd = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // StaffService.list() returns whatever /staff hands back — for a
      // sales_manager that may already be the full roster (some hold
      // screens.staff too) or just their own reports (the scoped fallback)
      // depending on how their role is configured. Filter to "my reports"
      // here either way, so this screen is always exactly "my team"
      // regardless of that server-side nuance.
      final all = await StaffService.instance.list(force: true);
      final mine = all.where((m) => m.managerId == userIdNotifier.value).toList();
      if (mounted) setState(() { _team = mine; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!can('sales.create_subordinate_user')) {
      return Center(child: Text('You do not have access to team management.', style: AppTheme.bodySub));
    }
    return Stack(children: [
      LayoutBuilder(builder: (ctx, cst) {
        final pad = cst.maxWidth < 560 ? 16.0 : 26.0;
        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(width: 2, height: 36, decoration: BoxDecoration(color: AppColors.violet, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Team', style: AppTheme.pageTitle.copyWith(fontSize: 23)),
                const SizedBox(height: 3),
                Text('${_team.length} rep${_team.length == 1 ? '' : 's'} reporting to you', style: AppTheme.bodySub.copyWith(fontSize: 12)),
              ])),
              FilledButton.icon(onPressed: () => setState(() => _showAdd = true), icon: const Icon(Symbols.person_add, size: 16), label: const Text('Add subordinate')),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                      ? ErrorView(message: _error!, onRetry: _load)
                      : _team.isEmpty
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Symbols.group, size: 40, color: context.pal.textMute),
                              const SizedBox(height: 10),
                              Text('No reports yet.', style: AppTheme.bodySub),
                              const SizedBox(height: 4),
                              Text('Add a sales rep to start building your team.', style: AppTheme.bodySub.copyWith(fontSize: 12)),
                            ]))
                          : ListView.separated(
                              itemCount: _team.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _teamRow(context, _team[i]),
                            ),
            ),
          ]),
        );
      }),
      if (_showAdd)
        _AddSubordinateDialog(
          onClose: () => setState(() => _showAdd = false),
          onSaved: () { setState(() => _showAdd = false); _load(); },
        ),
    ]);
  }

  Widget _teamRow(BuildContext context, StaffMember m) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.pal.border)),
    child: Row(children: [
      AvatarWidget(initials: m.initials, size: 36, variant: m.variant),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.name, style: AppTheme.bodyStrong.copyWith(fontSize: 13.5)),
        const SizedBox(height: 2),
        Text(m.email ?? '—', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(m.availStatus.label.toUpperCase(), style: AppTheme.monoXs.copyWith(fontSize: 9.5, color: AppColors.teal)),
      ),
    ]),
  );
}

class _AddSubordinateDialog extends StatefulWidget {
  const _AddSubordinateDialog({required this.onClose, required this.onSaved});
  final VoidCallback onClose;
  final VoidCallback onSaved;

  @override
  State<_AddSubordinateDialog> createState() => _AddSubordinateDialogState();
}

class _AddSubordinateDialogState extends State<_AddSubordinateDialog> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name and email are required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      // role/manager_id are forced server-side to 'sales'/self regardless
      // of what's sent — see StaffController::store()'s
      // hasSalesCreateSubordinateAuthority() branch.
      await StaffService.instance.create({
        'name':  _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'role':  'sales',
      });
      widget.onSaved();
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _saving = false; });
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
          width: 440,
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
                Icon(Symbols.person_add, size: 18, color: AppColors.violet),
                const SizedBox(width: 10),
                Text('Add Subordinate', style: AppTheme.bodyStrong),
                const Spacer(),
                GestureDetector(onTap: widget.onClose, child: Icon(Symbols.close, size: 18, color: context.pal.textDim)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.coralSoft, borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12)),
                  ),
                ],
                Text('New reps join with the role Sales Rep, reporting to you.', style: AppTheme.bodySub.copyWith(fontSize: 12)),
                const SizedBox(height: 14),
                AppTextField(controller: _nameCtrl, hintText: 'Full name', autofocus: true),
                const SizedBox(height: 12),
                AppTextField(controller: _emailCtrl, hintText: 'Email address'),
                const SizedBox(height: 12),
                AppTextField(controller: _phoneCtrl, hintText: 'Phone (optional)'),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(children: [
                Expanded(child: GestureDetector(onTap: widget.onClose,
                  child: Container(height: 38,
                    decoration: BoxDecoration(border: Border.all(color: context.pal.border), borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text('Cancel', style: AppTheme.bodySm))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(onTap: _save,
                  child: Container(height: 38,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Add', style: AppTheme.bodyStrong.copyWith(color: const Color(0xFF06120F), fontSize: 13)))))),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}
