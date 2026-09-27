import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../screens/approvals/approvals_screen.dart';
import '../../screens/customers/customers_screen.dart';
import '../../screens/dashboard/unified_dashboard_screen.dart';
import '../../screens/email/email_screen.dart';
import '../../screens/finance/bank_reconciliation_screen.dart';
import '../../screens/finance/chart_of_accounts_screen.dart';
import '../../screens/finance/expenses_screen.dart';
import '../../screens/finance/finance_dashboard_screen.dart';
import '../../screens/finance/finance_reports_screen.dart';
import '../../screens/finance/vendor_bills_screen.dart';
import '../../screens/finance/vendor_fees_screen.dart';
import '../../screens/hospitals/hospital_list_screen.dart';
import '../../screens/hr/hr_approval_screen.dart';
import '../../screens/hr/hr_attendance_screen.dart';
import '../../screens/hr/hr_dashboard_screen.dart';
import '../../screens/hr/hr_directory_screen.dart';
import '../../screens/hr/hr_leave_calendar_screen.dart';
import '../../screens/hr/hr_payroll_screen.dart';
import '../../screens/hr/hr_recruitment_screen.dart';
import '../../screens/hr/hr_reports_screen.dart';
import '../../screens/hr/hr_settings_screen.dart';
import '../../screens/hr/my_leave_screen.dart';
import '../../screens/inventory/flagged_units_screen.dart';
import '../../screens/inventory/inventory_items_screen.dart';
import '../../screens/inventory/locations_screen.dart';
import '../../screens/inventory/suppliers_screen.dart';
import '../../screens/inventory/stock_movements_screen.dart';
import '../../screens/inventory/requisitions_screen.dart';
import '../../screens/inventory/purchase_orders_screen.dart';
import '../../screens/machines/machine_detail_screen.dart';
import '../../screens/machines/machine_list_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/revenue/revenue_screen.dart';
import '../../screens/self_service/my_service_reports_screen.dart';
import '../../screens/self_service/my_travel_plans_screen.dart';
import '../../screens/sales/sales_screen.dart';
import '../../screens/sales/invoices_screen.dart';
import '../../screens/sales/quotations_screen.dart';
import '../../screens/sales/sales_dashboard_screen.dart';
import '../../screens/sales/sales_orders_screen.dart';
import '../../screens/sales/sales_history_screen.dart';
import '../../screens/sales/team_screen.dart';
import '../../screens/performance/my_performance_screen.dart';
import '../../screens/performance/team_performance_screen.dart';
import '../../screens/service/service_ticket_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/settings/delegations_screen.dart';
import '../../screens/settings/notification_templates_screen.dart';
import '../../screens/settings/activity_log_screen.dart';
import '../../screens/settings/downloads_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/procurement/device_registrations_screen.dart';
import '../../screens/procurement/tenders_screen.dart';
import '../../screens/staff/staff_screen.dart';
import '../../main.dart' show trialNotifier, userRoleNotifier, allowedScreenKeys, defaultScreenKey;
import '../../models/notification.dart';
import '../../models/search_result.dart';
import '../../screens/trial/trial_expired_screen.dart';
import '../../services/background_sync.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'sidebar.dart';
import 'sidebar_rail.dart';
import 'top_bar.dart';
import 'update_widgets.dart' show UpdateBanner;

import '../../theme/app_palette.dart';
// ── Breakpoints (content-area width) ──────────────────────────────────────────
//   < 720   → Mobile   : bottom tab bar + drawer overflow
//   720–1099 → Tablet  : 64 px icon-rail sidebar + compact top bar (+ drawer)
//   ≥ 1100  → Desktop  : full 232 px labeled sidebar + full top bar

/// Root shell — adapts navigation chrome to three device classes.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late String _activeKey;
  int _selectedMachineId = 0;

  // Set only via _navigateToEntity — carries an optional target for the
  // screen being navigated to (a specific entity id, or which tab to open).
  // _navigate() clears both so a stale deep-link target never leaks into a
  // plain sidebar click.
  int? _pendingEntityId;
  int? _pendingTabIndex;

  @override
  void initState() {
    super.initState();
    _activeKey = defaultScreenKey(userRoleNotifier.value);
    BackgroundSync.instance.start();
  }

  @override
  void dispose() {
    BackgroundSync.instance.stop();
    super.dispose();
  }

  // ── Screen router ─────────────────────────────────────────────────────────

  // Sub-module keys use the parent module as the permission gate.
  String _gatedKey(String key) {
    final allowed = allowedScreenKeys(userRoleNotifier.value);
    String permKey = key;
    if (key.startsWith('inventory_')) permKey = 'inventory';
    if (key.startsWith('sales_'))     permKey = 'sales';
    if (key.startsWith('finance_'))   permKey = 'finance';
    if (key == 'machines_map')        permKey = 'machines';
    if (key == 'tender_devices')      permKey = 'tenders';
    return (allowed == null || allowed.contains(permKey))
        ? key
        : defaultScreenKey(userRoleNotifier.value);
  }

  void _navigate(String key) {
    setState(() {
      _activeKey = _gatedKey(key);
      _pendingEntityId = null;
      _pendingTabIndex = null;
    });
  }

  /// Like [_navigate], but also carries a specific entity id and/or tab
  /// index for the target screen to pick up (e.g. a notification's "open
  /// this exact ticket" or "open Approvals on the Per Diem tab").
  void _navigateToEntity(String key, {int? entityId, int? tabIndex}) {
    setState(() {
      _activeKey = _gatedKey(key);
      _pendingEntityId = entityId;
      _pendingTabIndex = tabIndex;
    });
  }

  /// Routes a tapped notification to wherever its recipient acts on it.
  /// `n == null` means "View all" with no specific entity in mind.
  void _openNotification(AppNotification? n) {
    if (n == null) {
      _navigate('notifications');
      return;
    }
    final entityId = int.tryParse(n.entityId ?? '');
    switch (n.type) {
      case NotificationType.leaveRequested:
        _navigateToEntity('hr_approvals', tabIndex: 0);
      case NotificationType.stockOutRequested:
      case NotificationType.stockOutApproved:
      case NotificationType.stockOutRejected:
        _navigateToEntity('approvals', tabIndex: 0);
      case NotificationType.perDiemPending:
      case NotificationType.perDiemApproved:
      case NotificationType.perDiemRejected:
        _navigateToEntity('approvals', tabIndex: 1);
      case NotificationType.expensePending:
      case NotificationType.expenseApproved:
      case NotificationType.expenseRejected:
        _navigateToEntity('approvals', tabIndex: 2);
      case NotificationType.ticketAssigned:
      case NotificationType.ticketUpdated:
      case NotificationType.serviceDue:
        _navigateToEntity('service', entityId: entityId);
      case NotificationType.leaveApproved:
      case NotificationType.leaveRejected:
        _navigate('my_leave');
      case NotificationType.lateArrival:
        _navigateToEntity('hr_approvals', tabIndex: 2);
      case NotificationType.leadFollowUp:
      case NotificationType.dealUpdated:
        _navigateToEntity('sales', entityId: entityId);
      case NotificationType.taskAssigned:
      case NotificationType.taskCompleted:
        _navigateToEntity('staff', entityId: entityId);
      case NotificationType.stockPullRequired:
        _navigate('sales_orders');
      case NotificationType.tenderDeadline:
      case NotificationType.tenderOverdue:
        _navigateToEntity('tenders', entityId: entityId);
      case NotificationType.deviceRenewal:
        _navigateToEntity('tender_devices', entityId: entityId);
      default:
        _navigate('notifications');
    }
  }

  /// Routes a tapped global-search result to wherever it lives. Types with
  /// an existing "deep link to one record" hook (machine, service ticket,
  /// sales lead) land on that exact record; everything else opens the right
  /// list screen — still the correct destination, just not pre-scrolled.
  void _openSearchResult(SearchResult r) {
    switch (r.type) {
      case 'machine':
        setState(() {
          _selectedMachineId = r.id;
          _activeKey = _gatedKey('detail');
          _pendingEntityId = null;
          _pendingTabIndex = null;
        });
      case 'service_ticket':
        _navigateToEntity('service', entityId: r.id);
      case 'sales_lead':
        _navigateToEntity('sales', entityId: r.id);
      case 'hospital':
        _navigate('hospitals');
      case 'inventory_item':
        _navigate('inventory_items');
      case 'supplier':
        _navigate('inventory_suppliers');
      case 'location':
        _navigate('inventory_locations');
      case 'staff':
        _navigate('staff');
      case 'quotation':
        _navigate('sales_quotations');
      case 'sales_order':
        _navigate('sales_orders');
      case 'invoice':
        _navigate('sales_invoices');
      case 'contact':
        _navigate('customers');
      case 'vendor_bill':
        _navigate('finance_bills');
      case 'expense':
        _navigate('finance_expenses');
    }
  }

  Widget _buildScreen() => switch (_activeKey) {
    'dashboard' => UnifiedDashboardScreen(onNavigateTo: _navigate),
    'machines' || 'machines_map' => MachineListScreen(
        initialMapView: _activeKey == 'machines_map',
        onMachineSelected: (id) => setState(() {
          _selectedMachineId = id;
          _activeKey         = 'detail';
        }),
      ),
    'detail'    => MachineDetailScreen(
        machineId: _selectedMachineId,
        onBack: () => setState(() => _activeKey = 'machines'),
      ),
    'hospitals' => const HospitalListScreen(),
    'service'                => ServiceTicketScreen(initialTicketId: _pendingEntityId),
    'inventory' || 'inventory_items' => const InventoryItemsScreen(),
    'inventory_suppliers'    => const SuppliersScreen(),
    'inventory_movements'    => const StockMovementsScreen(),
    'inventory_requisitions' => const RequisitionsScreen(),
    'inventory_orders'       => const PurchaseOrdersScreen(),
    'inventory_locations'    => const LocationsScreen(),
    'inventory_flagged'      => const FlaggedUnitsScreen(),
    'revenue'                => const RevenueScreen(),
    'finance' || 'finance_dashboard' => FinanceDashboardScreen(onNavigateTo: _navigate),
    'finance_expenses'       => const ExpensesScreen(),
    'finance_bills'          => const VendorBillsScreen(),
    'finance_ledger'         => const ChartOfAccountsScreen(),
    'finance_reports'        => const FinanceReportsScreen(),
    'finance_bank_rec'       => const BankReconciliationScreen(),
    'vendor_fees'            => const VendorFeesScreen(),
    'tenders'                => TendersScreen(key: ValueKey('tenders-$_pendingEntityId'), initialTenderId: _pendingEntityId),
    'tender_devices'         => DeviceRegistrationsScreen(key: ValueKey('devices-$_pendingEntityId'), initialDeviceId: _pendingEntityId),
    'email'     => const EmailScreen(),
    'sales' || 'sales_leads' => SalesScreen(initialLeadId: _pendingEntityId),
    'sales_dashboard'         => SalesDashboardScreen(onNavigateTo: _navigate),
    'sales_quotations'       => const QuotationsScreen(),
    'sales_orders'           => SalesOrdersScreen(onNavigateTo: _navigate),
    'sales_invoices'         => InvoicesScreen(onNavigateTo: _navigate),
    'sales_history'          => const SalesHistoryScreen(),
    'sales_team'             => const TeamScreen(),
    'team_performance'       => const TeamPerformanceScreen(),
    'my_performance'         => const MyPerformanceScreen(),
    'customers' => const CustomersScreen(),
    'staff'          => StaffScreen(initialTaskId: _pendingEntityId),
    'my_leave'       => const MyLeaveScreen(),
    'my_service_reports' => MyServiceReportsScreen(onOpenTicket: (id) => _navigateToEntity('service', entityId: id)),
    'my_travel_plans'    => MyTravelPlansScreen(onOpenTicket: (id) => _navigateToEntity('service', entityId: id)),
    'hr_approvals'   => HrApprovalScreen(initialTabIndex: _pendingTabIndex),
    'hr_settings'    => const HrSettingsScreen(),
    'hr_dashboard'   => const HrDashboardScreen(),
    'hr_directory'   => HrDirectoryScreen(onNavigateTo: _navigate),
    'hr_recruitment' => const HrRecruitmentScreen(),
    'hr_leave_calendar' => HrLeaveCalendarScreen(onNavigateTo: _navigate),
    'hr_attendance'  => const HrAttendanceScreen(),
    'hr_payroll'     => const HrPayrollScreen(),
    'hr_reports'     => const HrReportsScreen(),
    'approvals'      => ApprovalsScreen(initialTabIndex: _pendingTabIndex),
    'notifications'  => NotificationsScreen(onOpenNotification: _openNotification),
    'reports'        => ReportsScreen(onNavigateTo: _navigate),
    'settings'  => SettingsScreen(onNavigateTo: _navigate),
    'delegations' => const DelegationsScreen(),
    'notification_templates' => const NotificationTemplatesScreen(),
    'activity_log' => const ActivityLogScreen(),
    'downloads' => const DownloadsScreen(),
    _ => _PlaceholderScreen(title: _activeKey),
  };

  // Resolved sidebar key:
  // - machine detail → highlight "machines"
  // - inventory sub-keys → sidebar uses the sub-key directly for child highlighting
  String get _sidebarKey {
    if (_activeKey == 'detail' || _activeKey == 'machines_map') return 'machines';
    if (_activeKey == 'inventory') return 'inventory_items';
    if (_activeKey == 'sales')     return 'sales_leads';
    if (_activeKey == 'finance')   return 'finance_dashboard';
    return _activeKey;
  }

  // "More" tab is active when the current screen isn't in the 4 primary tabs
  bool get _moreActive {
    const primary = {'dashboard', 'machines', 'machines_map', 'detail', 'service', 'revenue'};
    return !primary.contains(_activeKey);
  }

  // ── Shared drawer ─────────────────────────────────────────────────────────

  Widget _buildDrawer() => Drawer(
    width: 272,
    backgroundColor: context.pal.sidebarBg,
    child: Column(children: [
      // Drawer header with close button
      Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.pal.border)),
        ),
        child: Row(children: [
          Text('Navigation', style: AppTheme.bodyStrong),
          const Spacer(),
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.closeDrawer(),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: context.pal.surface2,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Symbols.close, size: 16, color: context.pal.textDim),
            ),
          ),
        ]),
      ),
      // Full nav sections (reuses Sidebar, fills drawer width)
      Expanded(
        child: Sidebar(
          width: 272,
          activeKey: _sidebarKey,
          onSelect: (k) {
            _scaffoldKey.currentState?.closeDrawer();
            _navigate(k);
          },
        ),
      ),
    ]),
  );

  // ── Trial banner ──────────────────────────────────────────────────────────

  Widget _trialBanner() => ValueListenableBuilder(
    valueListenable: trialNotifier,
    builder: (_, trial, _) => trial.showBanner
        ? TrialBanner(status: trial)
        : const SizedBox.shrink(),
  );

  // ── Layouts ───────────────────────────────────────────────────────────────

  /// Paints the active theme's diagonal wash (aurora) behind the shell body,
  /// or just its flat [AppPalette.bg] for every other theme — same visual
  /// result as before for themes with no [AppPalette.bgGradient] set.
  Decoration _bgDecoration(BuildContext context) {
    final grad = context.pal.bgGradient;
    if (grad == null) return BoxDecoration(color: context.pal.bg);
    return BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad,
    ));
  }

  /// Desktop (≥ 1100 px) — persistent 232 px labeled sidebar.
  Widget _buildDesktop() => Scaffold(
    backgroundColor: context.pal.bg,
    body: DecoratedBox(
      decoration: _bgDecoration(context),
      child: Column(
        children: [
          TopBar(onOpenNotification: _openNotification, onOpenSearchResult: _openSearchResult),
          const UpdateBanner(),
          _trialBanner(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Sidebar(
                  activeKey: _sidebarKey,
                  onSelect: (k) => _navigate(k),
                ),
                Expanded(child: ClipRect(child: _buildScreen())),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  /// Tablet (720–1099 px) — 64 px icon rail + compact top bar + drawer.
  Widget _buildTablet() => Scaffold(
    key: _scaffoldKey,
    backgroundColor: context.pal.bg,
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: TopBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onOpenNotification: _openNotification,
        onOpenSearchResult: _openSearchResult,
      ),
    ),
    drawer: _buildDrawer(),
    body: DecoratedBox(
      decoration: _bgDecoration(context),
      child: Column(
        children: [
          const UpdateBanner(),
          _trialBanner(),
          Expanded(child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SidebarRail(
                activeKey: _sidebarKey,
                onSelect: (k) => _navigate(k),
              ),
              Expanded(child: ClipRect(child: _buildScreen())),
            ],
          )),
        ],
      ),
    ),
  );

  /// Mobile (< 720 px) — bottom tab bar + drawer for overflow.
  Widget _buildMobile() => Scaffold(
    key: _scaffoldKey,
    backgroundColor: context.pal.bg,
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: TopBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onOpenNotification: _openNotification,
        onOpenSearchResult: _openSearchResult,
      ),
    ),
    drawer: _buildDrawer(),
    bottomNavigationBar: _BottomTabBar(
      activeKey: _activeKey,
      moreActive: _moreActive,
      onSelect: (k) => _navigate(k),
      onMore: () => _scaffoldKey.currentState?.openDrawer(),
    ),
    body: DecoratedBox(
      decoration: _bgDecoration(context),
      child: Column(
        children: [
          _trialBanner(),
          Expanded(child: ClipRect(child: _buildScreen())),
        ],
      ),
    ),
  );

  // ── Root build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1100) return _buildDesktop();
    if (width >= 720)  return _buildTablet();
    return _buildMobile();
  }
}

// ── Bottom tab bar (mobile) ────────────────────────────────────────────────────

class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({
    required this.activeKey,
    required this.moreActive,
    required this.onSelect,
    required this.onMore,
  });

  final String activeKey;
  final bool moreActive;
  final ValueChanged<String> onSelect;
  final VoidCallback onMore;

  bool _active(String key) {
    if (key == 'dashboard') return activeKey == 'dashboard';
    if (key == 'machines')  return activeKey == 'machines' || activeKey == 'detail';
    return activeKey == key;
  }

  @override
  Widget build(BuildContext context) {
    // Bottom safe area so the bar clears the iOS home indicator / Android gesture bar.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 64 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: context.pal.bg,
        border: Border(top: BorderSide(color: context.pal.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _BottomTab(
            icon: Symbols.space_dashboard,
            label: 'Home',
            active: _active('dashboard'),
            onTap: () => onSelect('dashboard'),
          ),
          _BottomTab(
            icon: Symbols.precision_manufacturing,
            label: 'Machines',
            active: _active('machines'),
            onTap: () => onSelect('machines'),
          ),
          _BottomTab(
            icon: Symbols.build_circle,
            label: 'Service',
            active: _active('service'),
            onTap: () => onSelect('service'),
          ),
          _BottomTab(
            icon: Symbols.payments,
            label: 'Revenue',
            active: _active('revenue'),
            onTap: () => onSelect('revenue'),
          ),
          _BottomTab(
            icon: Symbols.menu,
            label: 'More',
            active: moreActive,
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: active ? AppColors.teal : context.pal.textMute,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: active ? AppColors.teal : context.pal.textMute,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Placeholder ───────────────────────────────────────────────────────────────

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      Text(title, style: TextStyle(color: context.pal.textMute, fontSize: 18)),
    ]),
  );
}
