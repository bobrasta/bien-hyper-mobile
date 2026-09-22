import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show authTokenNotifier, userNameNotifier, can;
import '../../models/expense.dart';
import '../../models/permission.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/permission_service.dart';
import '../../services/role_service.dart';
import '../../services/setting_service.dart';
import '../../services/staff_service.dart';
import 'org_chart_editor.dart';
import 'roles_graph_view.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_error.dart';
import '../../utils/csv_export.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../../widgets/common/app_dropdown.dart';
import '../../widgets/common/avatar_widget.dart';
import '../../theme/app_palette.dart';

// e.g. 'sales_manager' -> 'Sales Manager' —shared by the Roles tab and the
// Invite dialog's role dropdown.
String _roleLabel(String name) => name
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _section = 0;
  int _tab     = 0;

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

  // Section 15.7: payment details — required before any travel plan can
  // be submitted (PerDiemController::store() 422s without one).
  final _paymentProviderCtrl      = TextEditingController();
  final _paymentAccountNumberCtrl = TextEditingController();
  final _paymentAccountNameCtrl   = TextEditingController();
  bool    _savingPaymentProfile = false;
  String? _paymentProfileMsg;

  // Team members
  bool              _loadingMembers = true;
  List<StaffMember> _staffList      = [];
  String?           _memberError;
  final _memberSearchCtrl = TextEditingController();
  String            _memberSearch      = '';
  String            _memberRoleFilter  = 'All';

  List<StaffMember> get _filteredStaffList {
    var list = _staffList;
    if (_memberRoleFilter != 'All') {
      list = list.where((m) => m.role == _memberRoleFilter).toList();
    }
    final q = _memberSearch.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((m) =>
          m.name.toLowerCase().contains(q) ||
          (m.email?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  // Approvals
  bool _loadingApprovals = true;
  final _thresholdCtrl = TextEditingController();
  bool _savingThreshold = false;
  List<ExpenseCategory> _expenseCategories = [];

  // Section 15.6/15.2: travel plan signature-block role labels + default
  // per-diem rate — Settings-adjustable per the spec, not hardcoded.
  final _perDiemDefaultRateCtrl = TextEditingController();
  final _sigTeamLeadCtrl = TextEditingController();
  final _sigCtoCtrl = TextEditingController();
  final _sigAccountantCtrl = TextEditingController();
  final _sigFinalReleaseCtrl = TextEditingController();
  bool _savingTravelPlanSettings = false;
  String? _travelPlanSettingsMsg;

  // Roles & Permissions
  bool _loadingRoles = true;
  List<RoleSummary> _roles = [];
  Map<String, List<PermissionCatalogItem>> _permissionCatalog = {};
  String? _rolesError;
  bool _rolesGraphView = false;

  // Activity / audit log (permission overrides)
  bool _loadingAudit = true;
  List<UserPermissionOverride> _auditLog = [];
  bool _auditThisWeekOnly = false;

  List<UserPermissionOverride> get _filteredAuditLog {
    if (!_auditThisWeekOnly) return _auditLog;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _auditLog.where((o) {
      final dt = o.createdAt != null ? DateTime.tryParse(o.createdAt!) : null;
      return dt != null && dt.isAfter(cutoff);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadMembers();
    _loadApprovals();
    _loadRoles();
    _loadAudit();
  }

  Future<void> _loadAudit() async {
    setState(() => _loadingAudit = true);
    try {
      final log = await PermissionService.instance.allOverrides();
      if (mounted) setState(() { _auditLog = log; _loadingAudit = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingAudit = false);
    }
  }

  Future<void> _loadRoles() async {
    setState(() { _loadingRoles = true; _rolesError = null; });
    try {
      final rolesF   = RoleService.instance.list();
      final catalogF = RoleService.instance.catalog();
      final roles    = await rolesF;
      final catalog  = await catalogF;
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _permissionCatalog = catalog;
        _loadingRoles = false;
      });
    } catch (e) {
      if (mounted) setState(() { _rolesError = friendlyError(e); _loadingRoles = false; });
    }
  }

  Future<void> _createRole(String name) async {
    try {
      await RoleService.instance.create(name);
      if (mounted) showSuccessToast(context, 'Role "$name" created.');
      await _loadRoles();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _saveRolePermissions(RoleSummary role, List<String> keys) async {
    try {
      await RoleService.instance.syncPermissions(role.id, keys);
      if (mounted) showSuccessToast(context, 'Permissions updated for "${role.name}".');
      await _loadRoles();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _deleteRole(RoleSummary role) async {
    try {
      await RoleService.instance.delete(role.id);
      if (mounted) showSuccessToast(context, 'Role "${role.name}" deleted.');
      await _loadRoles();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  Future<void> _loadApprovals() async {
    setState(() => _loadingApprovals = true);
    try {
      final results = await Future.wait([
        SettingService.instance.all(),
        ExpenseService.instance.categories(),
      ]);
      if (!mounted) return;
      final settings = results[0] as Map<String, String?>;
      final sigLabelsRaw = settings['per_diem_signature_role_labels'];
      Map<String, dynamic> sigLabels = {};
      if (sigLabelsRaw != null && sigLabelsRaw.isNotEmpty) {
        try { sigLabels = jsonDecode(sigLabelsRaw) as Map<String, dynamic>; } catch (_) {}
      }
      setState(() {
        _thresholdCtrl.text = settings['expense_director_threshold'] ?? '3000000';
        _expenseCategories = results[1] as List<ExpenseCategory>;
        _perDiemDefaultRateCtrl.text = settings['per_diem_default_daily_rate'] ?? '80000';
        _sigTeamLeadCtrl.text = sigLabels['team_lead'] as String? ?? 'Technical supervisor';
        _sigCtoCtrl.text = sigLabels['cto'] as String? ?? 'CTO';
        _sigAccountantCtrl.text = sigLabels['accountant_initiate'] as String? ?? 'Finance';
        _sigFinalReleaseCtrl.text = sigLabels['final_release'] as String? ?? 'Managing director';
        _loadingApprovals = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingApprovals = false);
    }
  }

  Future<void> _saveThreshold() async {
    if (_savingThreshold) return;
    setState(() => _savingThreshold = true);
    try {
      await SettingService.instance.set('expense_director_threshold', _thresholdCtrl.text.trim());
      if (mounted) { setState(() => _savingThreshold = false); showSuccessToast(context, 'Threshold updated.'); }
    } catch (e) {
      if (mounted) { setState(() => _savingThreshold = false); showErrorToast(context, e); }
    }
  }

  Future<void> _saveTravelPlanSettings() async {
    if (_savingTravelPlanSettings) return;
    setState(() { _savingTravelPlanSettings = true; _travelPlanSettingsMsg = null; });
    try {
      await SettingService.instance.set('per_diem_default_daily_rate', _perDiemDefaultRateCtrl.text.trim());
      await SettingService.instance.set('per_diem_signature_role_labels', jsonEncode({
        'team_lead': _sigTeamLeadCtrl.text.trim(),
        'cto': _sigCtoCtrl.text.trim(),
        'accountant_initiate': _sigAccountantCtrl.text.trim(),
        'final_release': _sigFinalReleaseCtrl.text.trim(),
      }));
      if (mounted) setState(() { _savingTravelPlanSettings = false; _travelPlanSettingsMsg = 'Saved.'; });
    } catch (e) {
      if (mounted) setState(() { _savingTravelPlanSettings = false; _travelPlanSettingsMsg = 'Save failed.'; });
    }
  }

  Future<void> _toggleCategoryApproval(ExpenseCategory cat, bool value) async {
    final previous = List<ExpenseCategory>.from(_expenseCategories);
    setState(() {
      _expenseCategories = _expenseCategories.map((c) => c.id == cat.id
          ? ExpenseCategory(id: c.id, name: c.name, accountId: c.accountId, requiresDirectorApproval: value)
          : c).toList();
    });
    try {
      await ExpenseService.instance.setCategoryRequiresDirector(cat.id, value);
    } catch (e) {
      if (mounted) { setState(() => _expenseCategories = previous); showErrorToast(context, e); }
    }
  }

  Future<void> _loadMembers({bool force = false}) async {
    setState(() { _loadingMembers = true; _memberError = null; });
    try {
      final list = await StaffService.instance.list(force: force);
      if (mounted) setState(() { _staffList = list; _loadingMembers = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingMembers = false; _memberError = friendlyError(e); });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _oldPwCtrl.dispose(); _newPwCtrl.dispose();
    _paymentProviderCtrl.dispose(); _paymentAccountNumberCtrl.dispose(); _paymentAccountNameCtrl.dispose();
    _thresholdCtrl.dispose();
    _perDiemDefaultRateCtrl.dispose(); _sigTeamLeadCtrl.dispose(); _sigCtoCtrl.dispose();
    _sigAccountantCtrl.dispose(); _sigFinalReleaseCtrl.dispose();
    _memberSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService.instance.getProfile();
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          if (profile != null) {
            _nameCtrl.text  = profile['name']  as String? ?? '';
            _emailCtrl.text = profile['email'] as String? ?? '';
            final paymentProfile = profile['payment_profile'] as Map<String, dynamic>?;
            if (paymentProfile != null) {
              _paymentProviderCtrl.text      = paymentProfile['provider'] as String? ?? '';
              _paymentAccountNumberCtrl.text = paymentProfile['account_number'] as String? ?? '';
              _paymentAccountNameCtrl.text   = paymentProfile['account_name'] as String? ?? '';
            }
          }
        });
      }
    } catch (_) {
      // getProfile() already catches internally and returns null, but guard
      // here too so a future refactor of that method can't leave this
      // section's spinner stuck forever.
      if (mounted) setState(() => _loadingProfile = false);
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

  Future<void> _savePaymentProfile() async {
    if (_savingPaymentProfile) return;
    setState(() { _savingPaymentProfile = true; _paymentProfileMsg = null; });
    try {
      await ApiClient.instance.dio.put('/auth/payment-profile', data: {
        'provider':       _paymentProviderCtrl.text.trim(),
        'account_number': _paymentAccountNumberCtrl.text.trim(),
        'account_name':   _paymentAccountNameCtrl.text.trim(),
      });
      if (mounted) setState(() { _savingPaymentProfile = false; _paymentProfileMsg = 'Payment details saved.'; });
    } catch (e) {
      if (mounted) setState(() { _savingPaymentProfile = false; _paymentProfileMsg = 'Save failed.'; });
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

  // Index is the real, fixed position _buildSectionContent's switch keys off
  // of — kept stable even when a role can't see every entry. 'adminOnly'
  // sections carry org-wide or secret content (API key, billing, org
  // structure, director-only approval policy) that has no business being
  // visible to an individual contributor, so they're filtered out below for
  // anyone without authority.admin_tier rather than just hidden by CSS.
  static const _sections = [
    {'icon': Symbols.person,        'label': 'Profile'},
    {'icon': Symbols.domain,        'label': 'Workspace',      'adminOnly': true},
    {'icon': Symbols.tune,          'label': 'Preferences'},
    {'icon': Symbols.fact_check,    'label': 'Approvals',       'adminOnly': true},
    {'icon': Symbols.account_tree,  'label': 'Org Chart',       'adminOnly': true},
  ];

  List<MapEntry<int, Map<String, Object>>> get _visibleSections {
    final isAdmin = can('authority.admin_tier');
    return _sections.asMap().entries
        .where((e) => isAdmin || e.value['adminOnly'] != true)
        .toList();
  }

  static const _memberTabs = ['Members', 'Roles', 'Activity'];

  // ── Build ─────────────────────────────────────────────────────────────────
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
              child: Row(children: _visibleSections.map((e) {
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
              ..._visibleSections.map((e) => _SettingsSideItem(
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
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
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
                      valueColor: AlwaysStoppedAnimation(AppColors.teal),
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

  // ── Profile card ──────────────────────────────────────────────────────────
  Widget _profileCard(BuildContext context) => _SCard(
    title: 'My Profile',
    trailing: GestureDetector(
      onTap: _logout,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Symbols.logout, size: 14, color: AppColors.coral),
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

  // ── Password card ─────────────────────────────────────────────────────────

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

  // ── Payment details card (Section 15.7) ─────────────────────────────────
  // Required before any travel plan can be submitted — the account number
  // shown here is your own, never masked (masking only applies when
  // someone ELSE views your plan's payment details).
  Widget _paymentProfileCard(BuildContext context) => _SCard(
    title: 'Payment Details',
    child: _loadingProfile
        ? const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(strokeWidth: 2)))
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Used for travel-plan/per-diem payouts. Required before you can submit a travel plan.',
              style: AppTheme.bodySub.copyWith(fontSize: 12.5, color: AppColors.textDim),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _SettingsField(label: 'Provider', ctrl: _paymentProviderCtrl, hint: 'e.g. SELCOM')),
              const SizedBox(width: 14),
              Expanded(child: _SettingsField(label: 'Account Number', ctrl: _paymentAccountNumberCtrl, hint: '1234567890123')),
            ]),
            const SizedBox(height: 14),
            _SettingsField(label: 'Account Name', ctrl: _paymentAccountNameCtrl, hint: 'Full name on the account'),
            const SizedBox(height: 16),
            Row(children: [
              if (_paymentProfileMsg != null) ...[
                Icon(_paymentProfileMsg!.contains('failed') ? Symbols.error : Symbols.check_circle,
                    size: 14, color: _paymentProfileMsg!.contains('failed') ? AppColors.coral : AppColors.teal),
                const SizedBox(width: 6),
                Text(_paymentProfileMsg!, style: AppTheme.bodySub.copyWith(
                    color: _paymentProfileMsg!.contains('failed') ? AppColors.coral : AppColors.teal, fontSize: 12.5)),
              ],
              const Spacer(),
              _TealBtn(label: 'Save payment details', saving: _savingPaymentProfile, onTap: _savePaymentProfile),
            ]),
          ]),
  );

  // ── Section content ───────────────────────────────────────────────────────
  Widget _buildSectionContent(BuildContext context) => switch (_section) {
    0 => _profileSection(context),
    1 => _workspaceSection(context),
    2 => _preferencesSection(context),
    3 => _approvalsSection(context),
    4 => const OrgChartEditor(),
    _ => const SizedBox.shrink(),
  };

  // ── Section 0: Profile & Security ─────────────────────────────────────────
  Widget _profileSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _profileCard(context),
      const SizedBox(height: 16),
      _paymentProfileCard(context),
      const SizedBox(height: 16),
      _passwordCard(context),
    ],
  );

  // ── Section 6: Approvals ──────────────────────────────────────────────────
  Widget _approvalsSection(BuildContext context) => _loadingApprovals
    ? const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(strokeWidth: 2)))
    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SCard(
        title: 'Expense Escalation Threshold',
        icon: Symbols.trending_up,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Expenses above this amount always require Director approval, even outside a flagged category. Director-only.',
              style: AppTheme.bodySub.copyWith(fontSize: 12)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _SettingsField(label: 'Threshold (TZS)', ctrl: _thresholdCtrl, hint: '3000000')),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _TealBtn(label: 'Save', saving: _savingThreshold, onTap: _saveThreshold),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      _SCard(
        title: 'Categories Requiring Director Approval',
        icon: Symbols.rule_folder,
        child: Column(children: [
          Text('These categories always escalate to the Director, regardless of amount —e.g. new order payments, machine imports.',
              style: AppTheme.bodySub.copyWith(fontSize: 12)),
          const SizedBox(height: 10),
          if (_expenseCategories.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No expense categories found.', style: AppTheme.bodySub))
          else
            ..._expenseCategories.map((cat) => _ToggleRow(
              label: cat.name,
              sub: cat.requiresDirectorApproval ? 'Always requires Director approval' : 'CTO can approve directly (unless over threshold)',
              value: cat.requiresDirectorApproval,
              onChanged: (v) => _toggleCategoryApproval(cat, v),
            )),
        ]),
      ),
      const SizedBox(height: 16),
      _SCard(
        title: 'Travel Plan Settings',
        icon: Symbols.route,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Default per-diem rate pre-fills each new itinerary day. Signature-block labels are the role titles shown on the exported travel plan — the plan\'s real approval chain (Team Lead / CTO / Accountant / final release) doesn\'t change, only what each line is called.',
              style: AppTheme.bodySub.copyWith(fontSize: 12)),
          const SizedBox(height: 14),
          _SettingsField(label: 'Default per-diem rate (TZS/day)', ctrl: _perDiemDefaultRateCtrl, hint: '80000'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _SettingsField(label: 'Team Lead stage label', ctrl: _sigTeamLeadCtrl, hint: 'Technical supervisor')),
            const SizedBox(width: 14),
            Expanded(child: _SettingsField(label: 'CTO stage label', ctrl: _sigCtoCtrl, hint: 'CTO')),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _SettingsField(label: 'Accountant-initiate stage label', ctrl: _sigAccountantCtrl, hint: 'Finance')),
            const SizedBox(width: 14),
            Expanded(child: _SettingsField(label: 'Final-release stage label', ctrl: _sigFinalReleaseCtrl, hint: 'Managing director')),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            if (_travelPlanSettingsMsg != null) ...[
              Icon(_travelPlanSettingsMsg!.contains('failed') ? Symbols.error : Symbols.check_circle,
                  size: 14, color: _travelPlanSettingsMsg!.contains('failed') ? AppColors.coral : AppColors.teal),
              const SizedBox(width: 6),
              Text(_travelPlanSettingsMsg!, style: AppTheme.bodySub.copyWith(
                  color: _travelPlanSettingsMsg!.contains('failed') ? AppColors.coral : AppColors.teal, fontSize: 12.5)),
            ],
            const Spacer(),
            _TealBtn(label: 'Save', saving: _savingTravelPlanSettings, onTap: _saveTravelPlanSettings),
          ]),
        ]),
      ),
    ]);

  // ── Section 0: Workspace ──────────────────────────────────────────────────
  Widget _workspaceSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      1 => _rolesTab(context),
      2 => _activityTab(context),
      _ => const SizedBox.shrink(),
    },
  ]);

  // ── Tab 0: Members ────────────────────────────────────────────────────────
  Widget _memberSearchField(BuildContext context) => Container(
    height: 32,
    decoration: BoxDecoration(color: context.pal.surface1,
        borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(children: [
      Icon(Symbols.search, size: 14, color: context.pal.textDim),
      const SizedBox(width: 6),
      Expanded(child: TextField(
        controller: _memberSearchCtrl,
        style: AppTheme.bodySub.copyWith(fontSize: 12),
        decoration: InputDecoration(
          isDense: false, border: InputBorder.none, contentPadding: EdgeInsets.zero,
          hintText: 'Search members…',
          hintStyle: AppTheme.bodySub.copyWith(fontSize: 12),
        ),
        onChanged: (v) => setState(() => _memberSearch = v),
      )),
    ]),
  );

  Widget _memberRoleFilterDropdown(BuildContext context) {
    final roleNames = _roles.map((r) => r.name).toList()..sort();
    final items = ['All', ...roleNames];
    final value = items.contains(_memberRoleFilter) ? _memberRoleFilter : 'All';
    return SizedBox(
      width: 180,
      child: AppSelectField<String>(
        value: value,
        items: items.map((r) => AppSelectItem(value: r, label: r == 'All' ? 'All' : _roleLabel(r))).toList(),
        onChanged: (v) => setState(() => _memberRoleFilter = v),
      ),
    );
  }

  Widget _membersTab(BuildContext context) => Column(children: [
    LayoutBuilder(builder: (ctx2, cst2) {
      final n2 = cst2.maxWidth < 520;
      final searchBox = _memberSearchField(context);
      final roleFilter = _memberRoleFilterDropdown(context);
      final refreshBtn = Tooltip(
        message: 'Refresh from server — this list is cached per device/session, so a member added elsewhere won\'t show up until refreshed.',
        child: GestureDetector(
          onTap: _loadingMembers ? null : () => _loadMembers(force: true),
          child: Container(
            height: 32, width: 32, alignment: Alignment.center,
            decoration: BoxDecoration(color: context.pal.surface1, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
            child: _loadingMembers
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: context.pal.textMute))
                : Icon(Symbols.refresh, size: 16, color: context.pal.textMute),
          ),
        ),
      );
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
          Row(children: [roleFilter, const Spacer(), refreshBtn, const SizedBox(width: 8), inviteBtn]),
        ]);
      }
      return Row(children: [
        SizedBox(width: 260, child: searchBox), const SizedBox(width: 10),
        roleFilter, const Spacer(), refreshBtn, const SizedBox(width: 8), inviteBtn,
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
                  if (_filteredStaffList.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No members found.')))
                  else
                    ..._filteredStaffList.map((m) => _MemberRow(
                      member: m,
                      canManage: can('roles.manage'),
                      onEditRole: () => _showEditMemberRoleDialog(context, m),
                      onManagePermissions: () => _showManagePermissionsDialog(context, m),
                      onResetPassword: () => _showResetPasswordDialog(context, m),
                      onDeactivate: () => _showDeactivateMemberDialog(context, m),
                    )),
                ])),
    ),
  ]);

  void _showEditMemberRoleDialog(BuildContext context, StaffMember member) {
    showDialog(context: context, builder: (_) => _EditMemberRoleDialog(
      member: member,
      roleNames: _roles.map((r) => r.name).toList(),
      onSave: (role) async {
        await StaffService.instance.update(member.id, {'role': role});
        StaffService.instance.invalidateCache();
        await _loadMembers();
      },
    ));
  }

  void _showManagePermissionsDialog(BuildContext context, StaffMember member) {
    showDialog(context: context, builder: (_) => _ManagePermissionsDialog(
      member: member,
      catalog: _permissionCatalog,
    ));
  }

  void _showResetPasswordDialog(BuildContext context, StaffMember member) {
    showDialog(context: context, builder: (dialogCtx) => AlertDialog(
      backgroundColor: context.pal.surface1,
      title: Text('Reset Password', style: AppTheme.cardTitle),
      content: SizedBox(width: 320, child: Text(
        "Reset ${member.name}'s password back to the default? "
        "They'll need to be given the default password and should change it themselves afterward.",
        style: AppTheme.bodySm,
      )),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            Navigator.of(dialogCtx).pop();
            try {
              await StaffService.instance.resetPassword(member.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("${member.name}'s password was reset to the default."),
                  backgroundColor: AppColors.teal,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              }
            } catch (e) {
              if (context.mounted) showErrorToast(context, e);
            }
          },
          child: const Text('Reset'),
        ),
      ],
    ));
  }

  void _showDeactivateMemberDialog(BuildContext context, StaffMember member) {
    showDialog(context: context, builder: (dialogCtx) => AlertDialog(
      backgroundColor: context.pal.surface1,
      title: Text('Deactivate Staff Member', style: AppTheme.cardTitle),
      content: SizedBox(width: 320, child: Text(
        "Deactivate ${member.name}? They'll no longer be able to sign in. "
        "This doesn't delete their history — it can be reversed by an admin later if needed.",
        style: AppTheme.bodySm,
      )),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
          onPressed: () async {
            Navigator.of(dialogCtx).pop();
            try {
              await StaffService.instance.delete(member.id);
              StaffService.instance.invalidateCache();
              await _loadMembers();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${member.name} was deactivated.'),
                  backgroundColor: AppColors.coral,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              }
            } catch (e) {
              if (context.mounted) showErrorToast(context, e);
            }
          },
          child: const Text('Deactivate'),
        ),
      ],
    ));
  }

  // ── Tab 2: Roles ──────────────────────────────────────────────────────────
  static List<Color> get _rolePalette => [
    AppColors.teal, AppColors.blue, AppColors.violet, AppColors.amber,
    AppColors.coral, AppColors.info, AppColors.textDim,
  ];

  String _permLabel(String key) {
    for (final items in _permissionCatalog.values) {
      for (final p in items) {
        if (p.key == key) return p.label;
      }
    }
    return key;
  }

  Widget _rolesTab(BuildContext context) {
    final canManage = can('roles.manage');

    if (_loadingRoles) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: CircularProgressIndicator(strokeWidth: 2),
      ));
    }
    if (_rolesError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Text(_rolesError!, style: AppTheme.bodySub),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Row(children: [
        Expanded(child: Text('${_roles.length} roles defined',
            style: AppTheme.bodySub)),
        Container(
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.pal.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.pal.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _RolesViewToggleBtn(
              icon: Symbols.list, label: 'List',
              active: !_rolesGraphView,
              onTap: () => setState(() => _rolesGraphView = false),
            ),
            _RolesViewToggleBtn(
              icon: Symbols.hub, label: 'Graph',
              active: _rolesGraphView,
              onTap: () => setState(() => _rolesGraphView = true),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        if (canManage)
          _OutlineBtn(label: 'New Role', saving: false,
              onTap: () => _showNewRoleDialog(context)),
      ]),
      const SizedBox(height: 12),
      if (_rolesGraphView)
        RolesGraphView(roles: _roles, catalog: _permissionCatalog, overrides: _auditLog)
      else
        ..._roles.asMap().entries.map((entry) {
        final role  = entry.value;
        final color = _rolePalette[entry.key % _rolePalette.length];
        return Container(
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
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_roleLabel(role.name), style: AppTheme.bodyStrong.copyWith(
                  color: color, fontSize: 12.5)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('${role.permissionCount} permission${role.permissionCount == 1 ? '' : 's'}',
                style: AppTheme.bodySub.copyWith(fontSize: 12))),
            if (canManage) ...[
              GestureDetector(
                onTap: () => _showEditRoleDialog(context, role),
                child: Icon(Symbols.edit, size: 15, color: context.pal.textDim)),
              if (!role.isSystem) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _deleteRole(role),
                  child: Icon(Symbols.delete, size: 15, color: context.pal.textDim)),
              ],
            ],
          ]),
          if (role.permissionKeys.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: role.permissionKeys.map((key) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                ),
                child: Text(_permLabel(key), style: AppTheme.monoXs.copyWith(
                    fontSize: 10.5, color: AppColors.teal)),
              );
            }).toList()),
          ],
        ]),
      );
      }),
    ]);
  }

  void _showNewRoleDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (dialogCtx) => AlertDialog(
      backgroundColor: context.pal.surface1,
      title: Text('New Role', style: AppTheme.cardTitle),
      content: SizedBox(width: 320, child: TextField(
        controller: ctrl,
        autofocus: true,
        style: AppTheme.bodySm,
        decoration: const InputDecoration(labelText: 'Role name (e.g. regional_sales_lead)'),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = ctrl.text.trim();
            if (name.isEmpty) return;
            Navigator.of(dialogCtx).pop();
            _createRole(name);
          },
          child: const Text('Create'),
        ),
      ],
    ));
  }

  void _showEditRoleDialog(BuildContext context, RoleSummary role) {
    showDialog(context: context, builder: (_) => _EditRolePermissionsDialog(
      role: role,
      catalog: _permissionCatalog,
      onSave: (keys) => _saveRolePermissions(role, keys),
    ));
  }

  // ── Tab 3: Activity ───────────────────────────────────────────────────────
  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    if (parts.isNotEmpty && parts.first.isNotEmpty) return parts.first[0].toUpperCase();
    return '?';
  }

  Widget _activityTab(BuildContext context) {
    final log = _filteredAuditLog;

    return Column(children: [
      Row(children: [
        GestureDetector(
          onTap: () => setState(() => _auditThisWeekOnly = !_auditThisWeekOnly),
          child: Container(
            height: 32, padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _auditThisWeekOnly ? AppColors.tealSoft : context.pal.surface1,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _auditThisWeekOnly
                  ? AppColors.teal.withValues(alpha: 0.4) : context.pal.border),
            ),
            child: Center(child: Text(
              _auditThisWeekOnly ? 'This week' : 'All time',
              style: AppTheme.bodySub.copyWith(fontSize: 12,
                  color: _auditThisWeekOnly ? AppColors.teal : context.pal.text),
            )),
          ),
        ),
        const Spacer(),
        _OutlineBtn(label: 'Export log', saving: false, onTap: _exportAuditLog),
      ]),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: context.pal.surface1,
            borderRadius: BorderRadius.circular(AppColors.rLg),
            border: Border.all(color: context.pal.border)),
        child: _loadingAudit
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : log.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No permission grants or denials yet.',
                        style: AppTheme.bodySub.copyWith(color: context.pal.textDim))))
                : Column(children: log.asMap().entries.map((e) {
                    final entry  = e.value;
                    final isLast = e.key == log.length - 1;
                    final allow  = entry.effect == 'allow';
                    final dt     = entry.createdAt != null ? DateTime.tryParse(entry.createdAt!) : null;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: isLast ? null : BoxDecoration(
                          border: Border(bottom: BorderSide(color: context.pal.divider))),
                      child: Row(children: [
                        AvatarWidget(
                          initials: _initialsOf(entry.userName ?? '?'),
                          size: 30,
                          variant: allow ? AvatarVariant.teal : AvatarVariant.coral,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(entry.userName ?? 'Unknown', style: AppTheme.bodyStrong.copyWith(fontSize: 12.5)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                              '${allow ? 'granted' : 'denied'} "${entry.label}"',
                              style: AppTheme.bodySub.copyWith(fontSize: 12,
                                  color: allow ? AppColors.teal : AppColors.coral),
                              overflow: TextOverflow.ellipsis,
                            )),
                          ]),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (entry.createdByName != null) 'by ${entry.createdByName}',
                              if (entry.reason != null && entry.reason!.isNotEmpty) entry.reason!,
                            ].join(' —'),
                            style: AppTheme.bodySub.copyWith(fontSize: 11.5, color: context.pal.textDim),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ])),
                        const SizedBox(width: 12),
                        Text(dt != null ? timeAgo(dt) : '—', style: AppTheme.monoXs.copyWith(
                            color: context.pal.textDim, fontSize: 10.5)),
                      ]),
                    );
                  }).toList()),
      ),
    ]);
  }

  Future<void> _exportAuditLog() async {
    try {
      final path = await CsvExport.permissionAuditLog(_filteredAuditLog);
      if (path != null && mounted) showSuccessToast(context, 'Exported ${_filteredAuditLog.length} entries to CSV');
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  // ── Section 5: Preferences ────────────────────────────────────────────────
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
              SizedBox(
                width: 220,
                child: Container(
                  decoration: BoxDecoration(color: context.pal.surface2,
                      borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(child: DropdownButton<AppThemeMode>(
                    value: mode,
                    isExpanded: true, dropdownColor: context.pal.surface2, style: AppTheme.bodySm,
                    icon: Icon(Symbols.expand_more, size: 16, color: context.pal.textDim),
                    items: AppTheme.pickerOrder.map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2))).toList(),
                    onChanged: (v) { if (v != null) themeNotifier.value = v; },
                  )),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<TextSizePref>(
          valueListenable: textSizeNotifier,
          builder: (_, sizePref, _) => Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Text Size', style: AppTheme.bodyStrong),
                  const SizedBox(height: 2),
                  Text('Adjust text size across the whole app', style: AppTheme.bodySub),
                ],
              )),
              const SizedBox(width: 16),
              SegmentedButton<TextSizePref>(
                segments: const [
                  ButtonSegment(value: TextSizePref.small,  label: Text('Small')),
                  ButtonSegment(value: TextSizePref.medium, label: Text('Medium')),
                  ButtonSegment(value: TextSizePref.large,  label: Text('Large')),
                ],
                selected: {sizePref},
                onSelectionChanged: (s) => textSizeNotifier.value = s.first,
                showSelectedIcon: false,
              ),
            ],
          ),
        ),
      ]),
    ),
  ]);

}

// ── Data classes ────────────────────────────────────────────────────────────

class _EditMemberRoleDialog extends StatefulWidget {
  const _EditMemberRoleDialog({required this.member, required this.roleNames, required this.onSave});
  final StaffMember member;
  final List<String> roleNames;
  final Future<void> Function(String role) onSave;

  @override
  State<_EditMemberRoleDialog> createState() => _EditMemberRoleDialogState();
}

class _EditMemberRoleDialogState extends State<_EditMemberRoleDialog> {
  late String _role = widget.roleNames.contains(widget.member.role)
      ? widget.member.role
      : (widget.roleNames.isNotEmpty ? widget.roleNames.first : widget.member.role);
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_role);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) { setState(() => _saving = false); showErrorToast(context, e); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedRoles = [...widget.roleNames]..sort();
    return AlertDialog(
      backgroundColor: context.pal.surface1,
      title: Text('Edit Role — ${widget.member.name}', style: AppTheme.cardTitle),
      content: SizedBox(
        width: 320,
        child: _HDropdown(
          label: 'Role',
          value: _role,
          items: sortedRoles,
          display: sortedRoles.map(_roleLabel).toList(),
          onChanged: (v) => setState(() => _role = v),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _ManagePermissionsDialog extends StatefulWidget {
  const _ManagePermissionsDialog({required this.member, required this.catalog});
  final StaffMember member;
  final Map<String, List<PermissionCatalogItem>> catalog;

  @override
  State<_ManagePermissionsDialog> createState() => _ManagePermissionsDialogState();
}

class _ManagePermissionsDialogState extends State<_ManagePermissionsDialog> {
  bool _loading = true;
  List<UserPermission> _effective = [];
  List<UserPermissionOverride> _overrides = [];
  String? _newKey;
  String _newEffect = 'allow';
  final _reasonCtrl = TextEditingController();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _permLabel(String key) {
    for (final items in widget.catalog.values) {
      for (final p in items) {
        if (p.key == key) return p.label;
      }
    }
    return key;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final effF = PermissionService.instance.fetchForUser(widget.member.id);
      final ovrF = PermissionService.instance.overridesForUser(widget.member.id);
      final eff = await effF;
      final ovr = await ovrF;
      if (!mounted) return;
      setState(() { _effective = eff; _overrides = ovr; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); showErrorToast(context, e); }
    }
  }

  Future<void> _addOverride() async {
    if (_newKey == null || _adding) return;
    setState(() => _adding = true);
    try {
      await PermissionService.instance.addOverride(
        widget.member.id,
        key: _newKey!,
        effect: _newEffect,
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      _reasonCtrl.clear();
      _newKey = null;
      await _load();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeOverride(UserPermissionOverride o) async {
    try {
      await PermissionService.instance.removeOverride(widget.member.id, o.id);
      await _load();
    } catch (e) {
      if (mounted) showErrorToast(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPerms = widget.catalog.values.expand((v) => v).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final overriddenKeys = _overrides.map((o) => o.key).toSet();
    final roleGranted = _effective.where((p) => !overriddenKeys.contains(p.key)).toList();

    return AlertDialog(
      backgroundColor: context.pal.surface1,
      title: Text('Manage Permissions — ${widget.member.name}', style: AppTheme.cardTitle),
      content: SizedBox(
        width: 460,
        height: 520,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FROM ROLE (${_roleLabel(widget.member.role)})', style: AppTheme.labelCaps),
                  const SizedBox(height: 8),
                  roleGranted.isEmpty
                      ? Text('No permissions from role.', style: AppTheme.bodySub.copyWith(fontSize: 12))
                      : Wrap(spacing: 6, runSpacing: 6, children: roleGranted.map((p) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(5)),
                          child: Text(_permLabel(p.key), style: AppTheme.monoXs.copyWith(fontSize: 10.5)),
                        )).toList()),
                  const SizedBox(height: 20),
                  Text('INDIVIDUAL OVERRIDES', style: AppTheme.labelCaps),
                  const SizedBox(height: 8),
                  if (_overrides.isEmpty)
                    Text('No individual overrides.', style: AppTheme.bodySub.copyWith(fontSize: 12))
                  else
                    ..._overrides.map((o) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: (o.effect == 'allow' ? AppColors.teal : AppColors.coral).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: (o.effect == 'allow' ? AppColors.teal : AppColors.coral).withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Icon(o.effect == 'allow' ? Symbols.add_circle : Symbols.block, size: 14,
                            color: o.effect == 'allow' ? AppColors.teal : AppColors.coral),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o.label, style: AppTheme.bodySm.copyWith(fontSize: 12)),
                          if (o.reason != null)
                            Text(o.reason!, style: AppTheme.bodySub.copyWith(fontSize: 10.5)),
                        ])),
                        GestureDetector(
                          onTap: () => _removeOverride(o),
                          child: Icon(Symbols.close, size: 14, color: context.pal.textDim)),
                      ]),
                    )),
                  const SizedBox(height: 16),
                  Text('ADD OVERRIDE', style: AppTheme.labelCaps),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: context.pal.surface2,
                        borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
                    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Choose a permission'),
                      dropdownColor: context.pal.surface2,
                      value: _newKey,
                      items: allPerms.map((p) => DropdownMenuItem(value: p.key, child: Text(p.label))).toList(),
                      onChanged: (v) => setState(() => _newKey = v),
                    )),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    ChoiceChip(label: const Text('Allow'), selected: _newEffect == 'allow',
                        onSelected: (_) => setState(() => _newEffect = 'allow')),
                    const SizedBox(width: 8),
                    ChoiceChip(label: const Text('Deny'), selected: _newEffect == 'deny',
                        onSelected: (_) => setState(() => _newEffect = 'deny')),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: _reasonCtrl,
                      decoration: const InputDecoration(labelText: 'Reason (optional)')),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: FilledButton(
                    onPressed: _newKey == null || _adding ? null : _addOverride,
                    child: _adding
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Add Override'),
                  )),
                ]),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}

class _EditRolePermissionsDialog extends StatefulWidget {
  const _EditRolePermissionsDialog({required this.role, required this.catalog, required this.onSave});
  final RoleSummary role;
  final Map<String, List<PermissionCatalogItem>> catalog;
  final ValueChanged<List<String>> onSave;

  @override
  State<_EditRolePermissionsDialog> createState() => _EditRolePermissionsDialogState();
}

class _EditRolePermissionsDialogState extends State<_EditRolePermissionsDialog> {
  late final Set<String> _selected = widget.role.permissionKeys.toSet();

  @override
  Widget build(BuildContext context) {
    final modules = widget.catalog.keys.toList()..sort();
    return AlertDialog(
      backgroundColor: context.pal.surface1,
      title: Text('Edit Permissions — ${widget.role.name}', style: AppTheme.cardTitle),
      content: SizedBox(
        width: 420,
        height: 480,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final module in modules) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(module.toUpperCase(), style: AppTheme.labelCaps),
              ),
              ...widget.catalog[module]!.map((p) => CheckboxListTile(
                value: _selected.contains(p.key),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(p.label, style: AppTheme.bodySm),
                subtitle: p.description != null
                    ? Text(p.description!, style: AppTheme.bodySub.copyWith(fontSize: 11))
                    : null,
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(p.key);
                  } else {
                    _selected.remove(p.key);
                  }
                }),
              )),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSave(_selected.toList());
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ── Shared card wrapper ─────────────────────────────────────────────────────
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

// ── Button helpers ──────────────────────────────────────────────────────────
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

class _RolesViewToggleBtn extends StatelessWidget {
  const _RolesViewToggleBtn({
    required this.icon, required this.label, required this.active, required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.tealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: active ? Border.all(color: AppColors.teal.withValues(alpha: 0.3)) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: active ? AppColors.teal : context.pal.textMute),
        const SizedBox(width: 5),
        Text(label, style: AppTheme.bodySm.copyWith(
          fontSize: 12, color: active ? AppColors.teal : context.pal.textMute,
          fontWeight: FontWeight.w500)),
      ]),
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

// ── Dropdown helper ─────────────────────────────────────────────────────────
// ── Existing shared widgets (unchanged) ─────────────────────────────────────
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    this.canManage = false,
    this.onEditRole,
    this.onManagePermissions,
    this.onResetPassword,
    this.onDeactivate,
  });
  final StaffMember member;
  final bool canManage;
  final VoidCallback? onEditRole;
  final VoidCallback? onManagePermissions;
  final VoidCallback? onResetPassword;
  final VoidCallback? onDeactivate;

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
                      decoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
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
                  Icon(Symbols.verified_user, size: 14, color: AppColors.teal),
                  const SizedBox(width: 4),
                  Text('Enabled', style: AppTheme.bodySub.copyWith(color: AppColors.teal, fontSize: 11.5)),
                ])
              : Row(children: [
                  Icon(Symbols.warning, size: 14, color: AppColors.amber),
                  const SizedBox(width: 4),
                  Text('Off', style: AppTheme.bodySub.copyWith(color: AppColors.amber, fontSize: 11.5)),
                ]),
        )),
        Expanded(flex: 1, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(_lastActiveLabel(), style: AppTheme.monoXs.copyWith(fontSize: 11)),
        )),
        SizedBox(
          width: 60,
          child: canManage
              ? PopupMenuButton<String>(
                  icon: Icon(Symbols.more_horiz, size: 16, color: context.pal.textDim),
                  onSelected: (v) {
                    if (v == 'role') onEditRole?.call();
                    if (v == 'perms') onManagePermissions?.call();
                    if (v == 'reset') onResetPassword?.call();
                    if (v == 'deactivate') onDeactivate?.call();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'role', child: Text('Edit Role')),
                    const PopupMenuItem(value: 'perms', child: Text('Manage Permissions')),
                    const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                    PopupMenuItem(value: 'deactivate', child: Text('Deactivate', style: TextStyle(color: AppColors.coral))),
                  ],
                )
              : Icon(Symbols.more_horiz, size: 16, color: context.pal.textDim),
        ),
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
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: ctrl, obscureText: obscure, style: AppTheme.bodySm,
        decoration: InputDecoration(hintText: hint,
            hintStyle: AppTheme.bodySm.copyWith(color: context.pal.textDim),
            border: InputBorder.none, isDense: false, contentPadding: EdgeInsets.zero),
      ),
    ),
  ]);
}

// ── Invite dialog ───────────────────────────────────────────────────────────
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
  String  _role  = 'technician';
  String _group = 'field';
  String _zone  = 'Dar es Salaam';
  bool   _saving = false;
  String? _error;

  List<String> _roleNames = ['technician'];

  static const _groups = ['field', 'office', 'admin'];
  static const _groupLabels = ['Field Technician', 'Office / Sales', 'Admin'];
  static const _zones  = [
    'Dar es Salaam', 'Arusha', 'Kilimanjaro', 'Mwanza', 'Mbeya',
    'Dodoma', 'Tanga', 'Morogoro', 'HQ · Dar es Salaam',
  ];

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await RoleService.instance.list();
      if (!mounted || roles.isEmpty) return;
      setState(() {
        _roleNames = roles.map((r) => r.name).toList();
        _role = _roleNames.contains('technician') ? 'technician' : _roleNames.first;
      });
    } catch (_) {
      // Non-fatal —keeps the single-item fallback list so the dialog stays usable.
    }
  }

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
        'role':    _role,
        'group':   _group,
        'zone':    _zone,
        'workload': 0.0,
        'is_active': true,
      });
      StaffService.instance.invalidateCache();
      widget.onSaved?.call();
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = friendlyError(e); });
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
                Icon(Symbols.person_add, size: 18, color: AppColors.teal),
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
                  Expanded(child: _HDropdown(label: 'Role', value: _role, items: _roleNames,
                      display: _roleNames.map(_roleLabel).toList(),
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
                  Text(_error!, style: TextStyle(color: AppColors.coral, fontSize: 12.5)),
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
      decoration: BoxDecoration(color: context.pal.surface2,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: context.pal.border)),
      height: 38,
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
