import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import 'app_button.dart';

/// Content-area width below which list screens switch to their phone layout
/// (cards instead of tables, detail as its own page, stacked header).
const double kPhoneBreakpoint = 600;

bool isPhoneWidth(double width) => width < kPhoneBreakpoint;

/// A header action: the primary one becomes a button, the rest go behind an
/// icon (one action) or a ⋮ menu (several).
class PageAction {
  const PageAction({required this.label, required this.icon, required this.onPressed, this.shortLabel});
  final String label;
  /// Label for the phone button when [label] is too long ("New Order" → "New").
  final String? shortLabel;
  final IconData icon;
  final VoidCallback? onPressed;
}

/// Phone version of a list screen's header:
///
///   Title                      [⋮] [+ New]
///   subtitle
///   [ search ……………………………………………… ]
///   (All) (Open) (Closed) …  ← one swipeable line
///
/// Each screen keeps its own desktop header and uses this below
/// [kPhoneBreakpoint], so desktop layouts are unchanged.
class PhonePageHeader extends StatelessWidget {
  const PhonePageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.primary,
    this.secondary = const [],
    this.search,
    this.filters = const [],
  });

  final String title;
  final String? subtitle;
  final PageAction? primary;
  final List<PageAction> secondary;
  /// Full-width search field (pass a SearchField without a width).
  final Widget? search;
  /// Chips / dropdowns, laid out on one horizontally scrolling line.
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.border))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTheme.pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTheme.bodySub, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ])),
        if (secondary.length == 1)
          IconButton(
            tooltip: secondary.first.label,
            onPressed: secondary.first.onPressed,
            icon: Icon(secondary.first.icon, size: 20, color: context.pal.textMute),
          )
        else if (secondary.length > 1)
          PopupMenuButton<int>(
            tooltip: 'More actions',
            color: context.pal.surface1,
            icon: Icon(Symbols.more_vert, size: 20, color: context.pal.textMute),
            onSelected: (i) => secondary[i].onPressed?.call(),
            itemBuilder: (_) => [
              for (final (i, a) in secondary.indexed)
                PopupMenuItem(value: i, enabled: a.onPressed != null, child: Row(children: [
                  Icon(a.icon, size: 18, color: context.pal.textMute),
                  const SizedBox(width: 12),
                  Text(a.label, style: AppTheme.bodySm),
                ])),
            ],
          ),
        if (primary != null) ...[
          const SizedBox(width: 4),
          AppButton(
            label: primary!.shortLabel ?? primary!.label,
            icon: primary!.icon,
            variant: BtnVariant.primary,
            onPressed: primary!.onPressed,
          ),
        ],
      ]),
      if (search != null) ...[
        const SizedBox(height: 10),
        search!,
      ],
      if (filters.isNotEmpty) ...[
        const SizedBox(height: 10),
        PhoneScrollRow(children: filters),
      ],
    ]),
  );
}

/// One swipeable line of chips/controls — replaces a [Wrap] that would take
/// two or three rows of a phone screen.
class PhoneScrollRow extends StatelessWidget {
  const PhoneScrollRow({super.key, required this.children, this.spacing = 6});
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [
      for (final (i, c) in children.indexed) ...[
        if (i > 0) SizedBox(width: spacing),
        c,
      ],
    ]),
  );
}

/// A record as a phone card — the phone stand-in for one table row:
///
///   [lead]  Title                         [badge]
///           subtitle
///           meta · meta · meta              amount
class PhoneRecordCard extends StatelessWidget {
  const PhoneRecordCard({
    super.key,
    required this.title,
    this.subtitle,
    this.lead,
    this.badge,
    this.meta = const [],
    this.amount,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  /// Small leading visual (icon tile, avatar).
  final Widget? lead;
  /// Status pill, top-right.
  final Widget? badge;
  /// Short facts shown on the last line, joined with " · ".
  final List<String> meta;
  /// Emphasised value, bottom-right (a total, a quantity).
  final String? amount;
  final bool selected;
  final VoidCallback? onTap;
  /// Replaces [amount] when a widget is needed (e.g. a ⋮ menu).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final metaText = meta.where((m) => m.trim().isNotEmpty).join('  ·  ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: selected ? context.pal.surface2 : context.pal.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.teal.withValues(alpha: 0.5) : context.pal.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (lead != null) ...[lead!, const SizedBox(width: 12)],
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(title, style: AppTheme.bodyStrong.copyWith(fontSize: 14),
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
                  if (badge != null) ...[const SizedBox(width: 8), badge!],
                ]),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: AppTheme.bodySub.copyWith(fontSize: 12.5),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                if (metaText.isNotEmpty || amount != null || trailing != null) ...[
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: Text(metaText,
                        style: AppTheme.bodySub.copyWith(fontSize: 11.5, color: context.pal.textDim),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                    if (trailing != null) trailing!
                    else if (amount != null) ...[
                      const SizedBox(width: 8),
                      Text(amount!, style: AppTheme.bodyStrong.copyWith(fontSize: 13.5)),
                    ],
                  ]),
                ],
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Opens [panel] — a screen's existing desktop detail panel — as its own
/// page inside the content area, so back returns to the list where it was.
/// The panel's own close button should pop (pass `() => Navigator.pop(ctx)`).
Future<void> pushPhoneDetail(BuildContext context, Widget Function(BuildContext ctx) panel) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => Scaffold(
      backgroundColor: ctx.pal.bg,
      body: panel(ctx),
    )));

/// Small coloured status pill used on phone cards.
class PhonePill extends StatelessWidget {
  const PhonePill(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: AppTheme.bodySub.copyWith(
        fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}
