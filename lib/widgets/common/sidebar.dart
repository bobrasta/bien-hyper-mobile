import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../main.dart' show userNameNotifier, userRoleNotifier, nameInitials, allowedScreenKeys;
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'avatar_widget.dart';
import '../../theme/app_palette.dart';

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.label,
    required this.key,
    this.count,
  });
  final IconData icon;
  final String label;
  final String key;
  final String? count;
}

const _operations = [
  NavDestination(icon: Symbols.space_dashboard,         label: 'Dashboard',  key: 'dashboard'),
  NavDestination(icon: Symbols.precision_manufacturing, label: 'Machines',   key: 'machines'),
  NavDestination(icon: Symbols.local_hospital,          label: 'Hospitals',  key: 'hospitals'),
  NavDestination(icon: Symbols.build_circle,            label: 'Service',    key: 'service'),
  // 'inventory' key triggers the expandable group — rendered separately below
  NavDestination(icon: Symbols.inventory_2,             label: 'Inventory',  key: 'inventory'),
  NavDestination(icon: Symbols.badge,                   label: 'Staff',      key: 'staff'),
];
const _business = [
  NavDestination(icon: Symbols.payments,                label: 'Revenue',    key: 'revenue'),
  // 'sales' key triggers the expandable group — rendered separately below
  NavDestination(icon: Symbols.trending_up,             label: 'Sales',      key: 'sales'),
  NavDestination(icon: Symbols.groups,                  label: 'Customers',  key: 'customers'),
  NavDestination(icon: Symbols.mail,                    label: 'Email',      key: 'email'),
];

// Sub-items shown when Sales group is expanded
const _salesChildren = [
  (key: 'sales_leads',       icon: Symbols.trending_up,   label: 'Leads'),
  (key: 'sales_quotations',  icon: Symbols.request_quote, label: 'Quotations'),
  (key: 'sales_orders',      icon: Symbols.shopping_cart, label: 'Sales Orders'),
  (key: 'sales_invoices',    icon: Symbols.receipt_long,  label: 'Invoices'),
];
const _system = [
  NavDestination(icon: Symbols.assessment,              label: 'Reports',    key: 'reports'),
  NavDestination(icon: Symbols.settings,                label: 'Settings',   key: 'settings'),
];

// Sub-items shown when Inventory group is expanded
const _inventoryChildren = [
  (key: 'inventory_items',        icon: Symbols.list_alt,            label: 'Items'),
  (key: 'inventory_suppliers',    icon: Symbols.business,            label: 'Suppliers'),
  (key: 'inventory_movements',    icon: Symbols.swap_vert,           label: 'Movements'),
  (key: 'inventory_requisitions', icon: Symbols.assignment,          label: 'Requisitions'),
  (key: 'inventory_orders',       icon: Symbols.receipt_long,        label: 'Purchase Orders'),
  (key: 'inventory_locations',    icon: Symbols.warehouse,           label: 'Locations'),
];

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.activeKey,
    required this.onSelect,
    this.width = 232,
  });

  final String activeKey;
  final ValueChanged<String> onSelect;
  final double width;


  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: userRoleNotifier,
      builder: (_, role, _) {
        final allowed = allowedScreenKeys(role);
        bool canShow(String key) {
          if (allowed == null) return true;
          if (key.startsWith('inventory_')) return allowed.contains('inventory');
          if (key.startsWith('sales_'))     return allowed.contains('sales');
          return allowed.contains(key);
        }

        List<NavDestination> filter(List<NavDestination> items) =>
            items.where((d) => canShow(d.key)).toList();

        final ops = filter(_operations);
        final biz = filter(_business);
        final sys = filter(_system);

        return Container(
          width: width,
          decoration: BoxDecoration(
            color: context.pal.sidebarBg,
            border: Border(right: BorderSide(color: context.pal.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ops.isNotEmpty) ...[
                        _SectionLabel('Operations'),
                        ...ops.map((d) => d.key == 'inventory'
                          ? _InventoryGroup(
                              activeKey: activeKey,
                              onSelect: onSelect,
                            )
                          : _NavItem(d, active: d.key == activeKey, onTap: () => onSelect(d.key))),
                      ],
                      if (biz.isNotEmpty) ...[
                        _SectionLabel('Business'),
                        ...biz.map((d) => d.key == 'sales'
                          ? _SalesGroup(
                              activeKey: activeKey,
                              onSelect: onSelect,
                            )
                          : _NavItem(d, active: d.key == activeKey, onTap: () => onSelect(d.key))),
                      ],
                      if (sys.isNotEmpty) ...[
                        _SectionLabel('System'),
                        ...sys.map((d) => _NavItem(d, active: d.key == activeKey, onTap: () => onSelect(d.key))),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              _SidebarFooter(),
            ],
          ),
        );
      },
    );
  }
}

// ── Expandable Inventory group ─────────────────────────────────────────────────

class _InventoryGroup extends StatefulWidget {
  const _InventoryGroup({required this.activeKey, required this.onSelect});
  final String activeKey;
  final ValueChanged<String> onSelect;

  @override
  State<_InventoryGroup> createState() => _InventoryGroupState();
}

class _InventoryGroupState extends State<_InventoryGroup> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.activeKey.startsWith('inventory_');
  }

  @override
  void didUpdateWidget(_InventoryGroup old) {
    super.didUpdateWidget(old);
    if (widget.activeKey.startsWith('inventory_')) _open = true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (_open) {
              setState(() => _open = false);
            } else {
              setState(() => _open = true);
              widget.onSelect('inventory_items');
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _open ? context.pal.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                if (_open)
                  Positioned(
                    left: -22, top: 4, bottom: 4,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                        boxShadow: [BoxShadow(color: AppColors.tealGlow, blurRadius: 8)],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Icon(Symbols.inventory_2,
                      size: 19,
                      color: _open ? context.pal.text : context.pal.textMute,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text('Inventory',
                        style: AppTheme.bodySm.copyWith(
                          color: _open ? context.pal.text : context.pal.textMute,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        )),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.25 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(Symbols.chevron_right,
                          size: 16, color: context.pal.textDim),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: _open
            ? Column(
                children: _inventoryChildren.map((c) => _SubNavItem(
                  icon:   c.icon,
                  label:  c.label,
                  active: widget.activeKey == c.key,
                  onTap:  () => widget.onSelect(c.key),
                )).toList(),
              )
            : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Expandable Sales group ─────────────────────────────────────────────────────

class _SalesGroup extends StatefulWidget {
  const _SalesGroup({required this.activeKey, required this.onSelect});
  final String activeKey;
  final ValueChanged<String> onSelect;

  @override
  State<_SalesGroup> createState() => _SalesGroupState();
}

class _SalesGroupState extends State<_SalesGroup> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.activeKey.startsWith('sales_');
  }

  @override
  void didUpdateWidget(_SalesGroup old) {
    super.didUpdateWidget(old);
    if (widget.activeKey.startsWith('sales_')) _open = true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (_open) {
              setState(() => _open = false);
            } else {
              setState(() => _open = true);
              widget.onSelect('sales_leads');
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _open ? context.pal.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(children: [
              if (_open)
                Positioned(
                  left: -22, top: 4, bottom: 4,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                      boxShadow: [BoxShadow(color: AppColors.tealGlow, blurRadius: 8)],
                    ),
                  ),
                ),
              Row(children: [
                Icon(Symbols.trending_up,
                  size: 19,
                  color: _open ? context.pal.text : context.pal.textMute,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text('Sales',
                    style: AppTheme.bodySm.copyWith(
                      color: _open ? context.pal.text : context.pal.textMute,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    )),
                ),
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Icon(Symbols.chevron_right,
                      size: 16, color: context.pal.textDim),
                ),
              ]),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: _open
            ? Column(
                children: _salesChildren.map((c) => _SubNavItem(
                  icon:   c.icon,
                  label:  c.label,
                  active: widget.activeKey == c.key,
                  onTap:  () => widget.onSelect(c.key),
                )).toList(),
              )
            : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _SubNavItem extends StatelessWidget {
  const _SubNavItem({
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
    child: Container(
      margin: const EdgeInsets.only(left: 26, right: 12, top: 1, bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: active ? AppColors.tealSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(children: [
        Icon(icon, size: 15,
            color: active ? AppColors.teal : context.pal.textDim),
        const SizedBox(width: 9),
        Expanded(
          child: Text(label,
            style: AppTheme.bodySm.copyWith(
              color: active ? AppColors.teal : context.pal.textMute,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              fontSize: 12.5,
            )),
        ),
      ]),
    ),
  );
}

// ── Standard nav item ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 18, 10, 6),
    child: Text(text.toUpperCase(), style: AppTheme.monoXs.copyWith(letterSpacing: 0.12)),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem(this.dest, {required this.active, required this.onTap});
  final NavDestination dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? context.pal.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            if (active)
              Positioned(
                left: -22, top: 4, bottom: 4,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
                    boxShadow: [BoxShadow(color: AppColors.tealGlow, blurRadius: 8)],
                  ),
                ),
              ),
            Row(
              children: [
                Icon(dest.icon,
                  size: 19,
                  color: active ? context.pal.text : context.pal.textMute,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(dest.label,
                    style: AppTheme.bodySm.copyWith(
                      color: active ? context.pal.text : context.pal.textMute,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.5,
                    )),
                ),
                if (dest.count != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: active ? AppColors.tealSoft : context.pal.surface3,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(dest.count!,
                      style: AppTheme.bodySub.copyWith(
                        fontSize: 11,
                        color: active ? AppColors.teal : context.pal.textMute,
                        fontWeight: FontWeight.w500,
                      )),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Footer ─────────────────────────────────────────────────────────────────────

class _SidebarFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.pal.border)),
      ),
      child: Row(
        children: [
          ValueListenableBuilder<String>(
            valueListenable: userNameNotifier,
            builder: (_, name, _) => AvatarWidget(
              initials: nameInitials(name),
              size: 26,
              variant: AvatarVariant.teal,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: userNameNotifier,
              builder: (_, name, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : 'User',
                    style: AppTheme.bodyStrong.copyWith(fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Admin · Dar es Salaam',
                    style: AppTheme.bodySub.copyWith(fontSize: 10.5, color: context.pal.textDim)),
                ],
              ),
            ),
          ),
          Icon(Symbols.more_horiz, size: 18, color: context.pal.textDim),
        ],
      ),
    );
  }
}
