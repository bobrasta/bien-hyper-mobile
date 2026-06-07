import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../screens/customers/customers_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/email/email_screen.dart';
import '../../screens/hospitals/hospital_list_screen.dart';
import '../../screens/inventory/inventory_items_screen.dart';
import '../../screens/inventory/suppliers_screen.dart';
import '../../screens/inventory/stock_movements_screen.dart';
import '../../screens/inventory/requisitions_screen.dart';
import '../../screens/inventory/purchase_orders_screen.dart';
import '../../screens/machines/machine_detail_screen.dart';
import '../../screens/machines/machine_list_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/revenue/revenue_screen.dart';
import '../../screens/sales/sales_screen.dart';
import '../../screens/sales/invoices_screen.dart';
import '../../screens/sales/quotations_screen.dart';
import '../../screens/sales/sales_orders_screen.dart';
import '../../screens/service/service_ticket_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/staff/staff_screen.dart';
import '../../main.dart' show trialNotifier, userRoleNotifier, allowedScreenKeys, defaultScreenKey;
import '../../screens/trial/trial_expired_screen.dart';
import '../../services/background_sync.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'sidebar.dart';
import 'sidebar_rail.dart';
import 'top_bar.dart';

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

  void _navigate(String key) {
    final allowed = allowedScreenKeys(userRoleNotifier.value);
    // sub-module keys use the parent module as the permission gate
    String permKey = key;
    if (key.startsWith('inventory_')) permKey = 'inventory';
    if (key.startsWith('sales_'))     permKey = 'sales';
    final target = (allowed == null || allowed.contains(permKey))
        ? key
        : defaultScreenKey(userRoleNotifier.value);
    setState(() => _activeKey = target);
  }

  Widget _buildScreen() => switch (_activeKey) {
    'dashboard' => const DashboardScreen(),
    'machines'  => MachineListScreen(
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
    'service'                => const ServiceTicketScreen(),
    'inventory' || 'inventory_items' => const InventoryItemsScreen(),
    'inventory_suppliers'    => const SuppliersScreen(),
    'inventory_movements'    => const StockMovementsScreen(),
    'inventory_requisitions' => const RequisitionsScreen(),
    'inventory_orders'       => const PurchaseOrdersScreen(),
    'revenue'                => const RevenueScreen(),
    'email'     => const EmailScreen(),
    'sales' || 'sales_leads' => const SalesScreen(),
    'sales_quotations'       => const QuotationsScreen(),
    'sales_orders'           => const SalesOrdersScreen(),
    'sales_invoices'         => const InvoicesScreen(),
    'customers' => const CustomersScreen(),
    'staff'          => const StaffScreen(),
    'notifications'  => const NotificationsScreen(),
    'reports'        => ReportsScreen(onNavigateTo: _navigate),
    'settings'  => const SettingsScreen(),
    _ => _PlaceholderScreen(title: _activeKey),
  };

  // Resolved sidebar key:
  // - machine detail → highlight "machines"
  // - inventory sub-keys → sidebar uses the sub-key directly for child highlighting
  String get _sidebarKey {
    if (_activeKey == 'detail')    return 'machines';
    if (_activeKey == 'inventory') return 'inventory_items';
    if (_activeKey == 'sales')     return 'sales_leads';
    return _activeKey;
  }

  // "More" tab is active when the current screen isn't in the 4 primary tabs
  bool get _moreActive {
    const primary = {'dashboard', 'machines', 'detail', 'service', 'revenue'};
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

  /// Desktop (≥ 1100 px) — persistent 232 px labeled sidebar.
  Widget _buildDesktop() => Scaffold(
    backgroundColor: context.pal.bg,
    body: Column(
      children: [
        TopBar(onViewAllNotifications: () => _navigate('notifications')),
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
  );

  /// Tablet (720–1099 px) — 64 px icon rail + compact top bar + drawer.
  Widget _buildTablet() => Scaffold(
    key: _scaffoldKey,
    backgroundColor: context.pal.bg,
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: TopBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onViewAllNotifications: () => _navigate('notifications'),
      ),
    ),
    drawer: _buildDrawer(),
    body: Column(
      children: [
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
  );

  /// Mobile (< 720 px) — bottom tab bar + drawer for overflow.
  Widget _buildMobile() => Scaffold(
    key: _scaffoldKey,
    backgroundColor: context.pal.bg,
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: TopBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onViewAllNotifications: () => _navigate('notifications'),
      ),
    ),
    drawer: _buildDrawer(),
    bottomNavigationBar: _BottomTabBar(
      activeKey: _activeKey,
      moreActive: _moreActive,
      onSelect: (k) => _navigate(k),
      onMore: () => _scaffoldKey.currentState?.openDrawer(),
    ),
    body: Column(
      children: [
        _trialBanner(),
        Expanded(child: ClipRect(child: _buildScreen())),
      ],
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
