// lib/widgets/dashboard/cto_widgets.dart — building blocks for the CTO
// dashboard (desktop 2a, mobile 2b–2d). Theme via AppColors / AppTheme /
// context.pal only; no hard-coded surfaces.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/cto_approval.dart';
import '../../models/cto_overview.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';

// ── Kind styling ─────────────────────────────────────────────
({IconData icon, Color color, String label}) ctoKindStyle(CtoApprovalKind k) => switch (k) {
      CtoApprovalKind.trip    => (icon: Symbols.directions_car, color: AppColors.cyan, label: 'Trip + per diem'),
      CtoApprovalKind.expense => (icon: Symbols.receipt_long, color: AppColors.violet, label: 'Expense'),
      CtoApprovalKind.stock   => (icon: Symbols.inventory_2, color: AppColors.amber, label: 'Stock request'),
    };

String ctoAmount(CtoApproval a, {bool full = false}) {
  if (a.amount == null) return a.qtyLabel ?? '';
  return full ? tshFromDouble(a.amount!.toDouble()) : tshShort(a.amount!);
}

Color slaColor(SlaState s) => switch (s) {
      SlaState.breached => AppColors.coral,
      SlaState.atRisk   => AppColors.amber,
      SlaState.ok       => AppColors.teal,
    };

// ── Small primitives ─────────────────────────────────────────
class CtoPanel extends StatelessWidget {
  const CtoPanel({super.key, required this.icon, required this.iconColor, required this.title, this.trailing, required this.child, this.borderColor});
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pal.surface1,
        borderRadius: BorderRadius.circular(AppColors.rMd),
        border: Border.all(color: borderColor ?? pal.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.divider))),
          child: Row(children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 8),
            Flexible(child: Text(title, style: AppTheme.cardTitle.copyWith(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
            const Spacer(),
            if (trailing != null) trailing!,
          ]),
        ),
        Expanded(child: child),
      ]),
    );
  }
}

class CtoChip extends StatelessWidget {
  const CtoChip(this.text, {super.key, required this.color, this.size = 10});
  final String text;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(5)),
        child: Text(text, style: AppTheme.monoXs.copyWith(fontSize: size, color: color)),
      );
}

class CtoInitials extends StatelessWidget {
  const CtoInitials(this.initials, {super.key, required this.color, this.size = 22});
  final String initials;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(initials, style: AppTheme.monoXs.copyWith(fontSize: size * 0.4, color: AppColors.bg, fontWeight: FontWeight.w600)),
      );
}

Color teamColor(String state, BuildContext c) => switch (state) {
      'en_route' => AppColors.cyan,
      'on_leave' => c.pal.textDim,
      _          => AppColors.teal,
    };

/// Outlined action button. [tone] green = approve, coral = return, null = neutral.
class CtoActionButton extends StatelessWidget {
  const CtoActionButton({super.key, required this.label, required this.icon, this.tone, this.onPressed, this.height = 26, this.expand = false, this.busy = false});
  final String label;
  final IconData icon;
  final Color? tone;
  final VoidCallback? onPressed;
  final double height;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fg = tone ?? pal.textMute;
    final big = height >= 40;
    final child = Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      busy
          ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: fg))
          : Icon(icon, size: big ? 16 : 13, color: fg),
      const SizedBox(width: 6),
      Text(label, style: AppTheme.bodySm.copyWith(fontSize: big ? 13 : 11, color: fg)),
    ]);
    return Material(
      color: tone == AppColors.teal ? AppColors.tealSoft : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(big ? 10 : 7),
        side: BorderSide(color: tone == null ? pal.borderStrong : tone!.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(big ? 10 : 7),
        onTap: busy ? null : onPressed,
        hoverColor: fg.withValues(alpha: 0.08),
        child: Container(height: height, padding: EdgeInsets.symmetric(horizontal: big ? 14 : 10), child: child),
      ),
    );
  }
}

class CtoDecisionChip extends StatelessWidget {
  const CtoDecisionChip({super.key, required this.decision, required this.approval});
  final CtoDecision decision;
  final CtoApproval approval;
  @override
  Widget build(BuildContext context) => CtoChip(
        decision == CtoDecision.approved ? 'Approved' : 'Returned to ${approval.requester}',
        color: decision == CtoDecision.approved ? AppColors.teal : AppColors.coral,
        size: 10.5,
      );
}

// ── Approvals ────────────────────────────────────────────────
class CtoKindIcon extends StatelessWidget {
  const CtoKindIcon(this.kind, {super.key, this.size = 26});
  final CtoApprovalKind kind;
  final double size;
  @override
  Widget build(BuildContext context) {
    final s = ctoKindStyle(kind);
    return Container(
      width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Icon(s.icon, size: size * 0.54, color: s.color),
    );
  }
}

/// Desktop desk list row (2a). Selecting shows it in [CtoApprovalDetail].
class CtoApprovalRow extends StatelessWidget {
  const CtoApprovalRow({super.key, required this.a, required this.selected, this.decision, required this.onTap});
  final CtoApproval a;
  final bool selected;
  final CtoDecision? decision;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = ctoKindStyle(a.kind);
    return Opacity(
      opacity: decision == null ? 1 : 0.55,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
          decoration: BoxDecoration(
            color: selected ? pal.surface2 : null,
            border: Border(
              left: BorderSide(width: 2, color: selected ? AppColors.violet : Colors.transparent),
              bottom: BorderSide(color: pal.divider),
            ),
          ),
          child: Row(children: [
            CtoKindIcon(a.kind),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a.requester} · ${a.title}', style: AppTheme.bodySm.copyWith(fontSize: 12, color: pal.text), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${s.label} · ${a.meta}', style: AppTheme.bodySub.copyWith(fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(ctoAmount(a), style: AppTheme.monoXs.copyWith(fontSize: 11, color: pal.text)),
              const SizedBox(height: 3),
              Text(decision?.name ?? 'pending', style: AppTheme.monoXs.copyWith(
                  fontSize: 9.5,
                  color: decision == null ? pal.textDim : decision == CtoDecision.approved ? AppColors.teal : AppColors.coral)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Detail body — used inline in the desktop desk and full-screen on mobile (2c).
class CtoApprovalDetail extends StatelessWidget {
  const CtoApprovalDetail({
    super.key, required this.a, this.decision, this.busy = false, this.mobile = false,
    required this.onApprove, required this.onReturn, this.onEditDays, this.onTechnicianEdit,
  });
  final CtoApproval a;
  final CtoDecision? decision;
  final bool busy;
  final bool mobile;
  final VoidCallback onApprove;
  final VoidCallback onReturn;
  final VoidCallback? onEditDays;
  final void Function(bool accept)? onTechnicianEdit;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s = ctoKindStyle(a.kind);
    final head = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CtoChip(s.label, color: s.color),
        const SizedBox(width: 8),
        Text(a.ref, style: AppTheme.monoXs.copyWith(fontSize: 10, color: pal.textDim)),
        if (!mobile) ...[
          const Spacer(),
          Text(ctoAmount(a, full: true), style: AppTheme.cardTitle.copyWith(fontSize: 17)),
        ],
      ]),
      const SizedBox(height: 6),
      Text(mobile ? a.title : '${a.requester} · ${a.title}', style: mobile ? AppTheme.pageTitle.copyWith(fontSize: 20) : AppTheme.bodySm.copyWith(fontSize: 13, color: pal.text)),
      if (mobile) ...[
        const SizedBox(height: 4),
        Text('${a.requester} · ${a.meta}', style: AppTheme.bodySub.copyWith(fontSize: 12.5)),
        const SizedBox(height: 8),
        Text(ctoAmount(a, full: true), style: AppTheme.kpiValue.copyWith(fontSize: 26)),
      ],
      if (a.flag != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: mobile ? const EdgeInsets.all(10) : EdgeInsets.zero,
          decoration: mobile ? BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.amber.withValues(alpha: 0.3))) : null,
          child: Row(children: [
            Icon(Symbols.edit_note, size: 14, color: AppColors.amber),
            const SizedBox(width: 6),
            Expanded(child: Text(a.flag!, style: AppTheme.bodySub.copyWith(fontSize: mobile ? 12 : 11, color: AppColors.amber))),
          ]),
        ),
        if (a.pendingRevisionId != null && onTechnicianEdit != null && decision == null) ...[
          const SizedBox(height: 8),
          Row(children: [
            CtoActionButton(label: 'Accept edit', icon: Symbols.check, tone: AppColors.teal, onPressed: () => onTechnicianEdit!(true)),
            const SizedBox(width: 6),
            CtoActionButton(label: 'Reject edit', icon: Symbols.close, onPressed: () => onTechnicianEdit!(false)),
          ]),
        ],
      ],
    ]);

    final lines = Column(children: [
      for (final l in a.lines)
        Container(
          padding: EdgeInsets.symmetric(vertical: mobile ? 11 : 6, horizontal: mobile ? 12 : 0),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.divider))),
          child: Row(children: [
            SizedBox(width: 48, child: Text(l.a, style: AppTheme.monoXs.copyWith(fontSize: 10, color: pal.textDim))),
            const SizedBox(width: 10),
            Expanded(child: Text(l.b, style: AppTheme.bodySub.copyWith(fontSize: mobile ? 12.5 : 11.5, color: pal.textMute), maxLines: mobile ? 2 : 1, overflow: TextOverflow.ellipsis)),
            if (l.c.isNotEmpty) Text(l.c, style: AppTheme.monoXs.copyWith(fontSize: 11, color: pal.text)),
          ]),
        ),
    ]);

    final chain = CtoApprovalChain(steps: a.steps, decision: decision, vertical: mobile);

    final actions = decision != null
        ? Row(children: [
            CtoDecisionChip(decision: decision!, approval: a),
            const SizedBox(width: 8),
            Expanded(child: Text(decision == CtoDecision.approved ? a.nextAfterApprove : 'Requester notified',
                style: AppTheme.bodySub.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis)),
          ])
        : mobile
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                CtoActionButton(label: a.approveLabel, icon: Symbols.check, tone: AppColors.teal, height: 48, expand: true, busy: busy, onPressed: onApprove),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: CtoActionButton(label: 'Return', icon: Symbols.undo, tone: AppColors.coral, height: 44, expand: true, onPressed: busy ? null : onReturn)),
                  if (a.canEditDays && onEditDays != null) ...[
                    const SizedBox(width: 8),
                    Expanded(child: CtoActionButton(label: 'Edit days', icon: Symbols.edit, height: 44, expand: true, onPressed: busy ? null : onEditDays)),
                  ],
                ]),
              ])
            : Row(children: [
                CtoActionButton(label: a.approveLabel, icon: Symbols.check, tone: AppColors.teal, height: 32, busy: busy, onPressed: onApprove),
                if (a.canEditDays && onEditDays != null) ...[
                  const SizedBox(width: 8),
                  CtoActionButton(label: 'Edit days', icon: Symbols.edit, height: 32, onPressed: busy ? null : onEditDays),
                ],
                const Spacer(),
                CtoActionButton(label: 'Return', icon: Symbols.undo, tone: AppColors.coral, height: 32, onPressed: busy ? null : onReturn),
              ]);

    if (mobile) {
      return Column(children: [
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          head,
          const SizedBox(height: 14),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: pal.surface1, borderRadius: BorderRadius.circular(AppColors.rMd), border: Border.all(color: pal.border)),
            child: lines,
          ),
          const SizedBox(height: 16),
          Text('APPROVAL CHAIN', style: AppTheme.labelCaps.copyWith(fontSize: 9.5)),
          const SizedBox(height: 8),
          chain,
        ])),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(color: pal.surface2, border: Border(top: BorderSide(color: pal.border))),
          child: SafeArea(top: false, child: actions),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), child: head),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 14), children: [
        lines,
        const SizedBox(height: 10),
        chain,
        const SizedBox(height: 6),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.divider))),
        child: actions,
      ),
    ]);
  }
}

class CtoApprovalChain extends StatelessWidget {
  const CtoApprovalChain({super.key, required this.steps, this.decision, this.vertical = false});
  final List<CtoApprovalStep> steps;
  final CtoDecision? decision;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    (Color, Color, String?) look(CtoApprovalStep s) {
      if (s.state == CtoStepState.current) {
        return switch (decision) {
          CtoDecision.approved => (AppColors.teal, pal.textMute, 'Approved'),
          CtoDecision.returned => (AppColors.coral, AppColors.coral, 'Returned'),
          null                 => (AppColors.violet, AppColors.violet, null),
        };
      }
      return s.state == CtoStepState.done ? (AppColors.teal, pal.textMute, null) : (pal.borderStrong, pal.textDim, null);
    }

    if (vertical) {
      return Column(children: [
        for (final s in steps)
          Builder(builder: (_) {
            final (line, fg, over) = look(s);
            return Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
              decoration: BoxDecoration(border: Border(left: BorderSide(width: 2, color: line))),
              child: Row(children: [
                Expanded(child: Text(s.label, style: AppTheme.bodySub.copyWith(fontSize: 12.5, color: pal.textMute))),
                Text(over ?? s.sub, style: AppTheme.bodySub.copyWith(fontSize: 12, color: fg)),
              ]),
            );
          }),
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final s in steps)
        Expanded(child: Builder(builder: (_) {
          final (line, fg, over) = look(s);
          return Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(border: Border(top: BorderSide(width: 2, color: line))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.label.toUpperCase(), style: AppTheme.labelCaps.copyWith(fontSize: 9)),
              const SizedBox(height: 3),
              Text(over ?? s.sub, style: AppTheme.bodySub.copyWith(fontSize: 10.5, color: fg), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          );
        })),
    ]);
  }
}

/// Mobile home card (2b): tap the body to open 2c; 44 px buttons.
class CtoApprovalCard extends StatelessWidget {
  const CtoApprovalCard({super.key, required this.a, this.decision, this.busy = false, required this.onOpen, required this.onApprove, required this.onReturn});
  final CtoApproval a;
  final CtoDecision? decision;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Opacity(
      opacity: decision == null ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: pal.surface1, borderRadius: BorderRadius.circular(AppColors.rMd), border: Border.all(color: pal.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: onOpen,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CtoKindIcon(a.kind, size: 32),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: AppTheme.bodySm.copyWith(fontSize: 13, color: pal.text)),
                Text('${a.requester} · ${a.meta}', style: AppTheme.bodySub.copyWith(fontSize: 11.5)),
              ])),
              Text(ctoAmount(a), style: AppTheme.monoXs.copyWith(fontSize: 11.5, color: pal.text)),
            ]),
          ),
          if (a.flag != null) ...[
            const SizedBox(height: 8),
            Text(a.flag!, style: AppTheme.bodySub.copyWith(fontSize: 11.5, color: AppColors.amber)),
          ],
          const SizedBox(height: 10),
          decision != null
              ? Align(alignment: Alignment.centerLeft, child: CtoDecisionChip(decision: decision!, approval: a))
              : Row(children: [
                  Expanded(child: CtoActionButton(label: 'Return', icon: Symbols.undo, height: 44, expand: true, onPressed: busy ? null : onReturn)),
                  const SizedBox(width: 8),
                  Expanded(child: CtoActionButton(label: (a.expense?.requiresDirectorApproval ?? false) ? 'Forward' : 'Approve', icon: Symbols.check, tone: AppColors.teal, height: 44, expand: true, busy: busy, onPressed: onApprove)),
                ]),
        ]),
      ),
    );
  }
}

/// Prompt for a return reason. Per-diem needs ≥ 10 chars (server rule).
Future<String?> showCtoReturnDialog(BuildContext context, CtoApproval a) {
  final ctrl = TextEditingController();
  final min = a.returnNeedsReason ? 10 : 1;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      final ok = ctrl.text.trim().length >= min;
      return AlertDialog(
        backgroundColor: ctx.pal.surface1,
        title: Text('Return to ${a.requester}', style: AppTheme.cardTitle),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl, autofocus: true, maxLines: 3, onChanged: (_) => set(() {}),
            decoration: InputDecoration(
              hintText: a.returnNeedsReason ? 'What needs to change? (min. 10 characters)' : 'Reason',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: ok ? () => Navigator.pop(ctx, ctrl.text.trim()) : null,
            child: const Text('Return'),
          ),
        ],
      );
    }),
  );
}

// ── Trip calendar (2a bottom-left, 2d) ───────────────────────
class CtoTripCalendar extends StatelessWidget {
  const CtoTripCalendar({
    super.key, required this.team, required this.start, required this.days, required this.today,
    this.tripDecisions = const {}, this.rowHeight = 30, this.nameWidth = 118, this.showNames = true,
  });
  final List<TeamMember> team;
  final DateTime start;
  final int days;
  final DateTime today;
  final Map<int, CtoDecision> tripDecisions; // perDiemRequestId → local decision
  final double rowHeight;
  final double nameWidth;
  final bool showNames;

  static const _dn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final s0 = _day(start);
    final todayIdx = _day(today).difference(s0).inDays;
    return LayoutBuilder(builder: (ctx, cst) {
      final trackW = cst.maxWidth - nameWidth;
      final colW = trackW / days;
      // Scrolls when the team outgrows the fixed-height desktop panel.
      return SingleChildScrollView(child: Column(children: [
        Row(children: [
          SizedBox(width: nameWidth),
          for (var i = 0; i < days; i++)
            SizedBox(
              width: colW,
              child: Text('${_dn[s0.add(Duration(days: i)).weekday - 1]} ${s0.add(Duration(days: i)).day}',
                  textAlign: TextAlign.center,
                  style: AppTheme.monoXs.copyWith(
                    fontSize: 9.5,
                    color: i == todayIdx ? AppColors.teal : (s0.add(Duration(days: i)).weekday > 5 ? pal.textDim.withValues(alpha: 0.6) : pal.textDim),
                  )),
            ),
        ]),
        const SizedBox(height: 4),
        for (final m in team)
          Container(
            height: rowHeight,
            decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.divider))),
            child: Row(children: [
              SizedBox(
                width: nameWidth,
                child: Row(children: [
                  CtoInitials(m.initials, color: teamColor(m.state, context), size: showNames ? 18 : 22),
                  if (showNames) ...[
                    const SizedBox(width: 7),
                    Expanded(child: Text(m.name, style: AppTheme.bodySub.copyWith(fontSize: 11, color: pal.textMute), overflow: TextOverflow.ellipsis)),
                  ],
                ]),
              ),
              SizedBox(
                width: trackW,
                child: Stack(children: [
                  if (todayIdx >= 0 && todayIdx < days)
                    Positioned(left: todayIdx * colW, width: colW, top: 0, bottom: 0, child: ColoredBox(color: AppColors.teal.withValues(alpha: 0.06))),
                  for (final b in m.bars) ..._bar(context, b, s0, colW),
                ]),
              ),
            ]),
          ),
      ]));
    });
  }

  List<Widget> _bar(BuildContext context, TripBar b, DateTime s0, double colW) {
    var a = _day(b.start).difference(s0).inDays;
    var e = _day(b.end).difference(s0).inDays + 1;
    a = a.clamp(0, days);
    e = e.clamp(0, days);
    if (e <= a) return const [];
    var kind = b.kind;
    final dec = b.perDiemRequestId == null ? null : tripDecisions[b.perDiemRequestId];
    if (kind == TripBarKind.pendingCto && dec == CtoDecision.approved) kind = TripBarKind.approved;
    final returned = kind == TripBarKind.pendingCto && dec == CtoDecision.returned;
    final pal = context.pal;
    final (fill, line, fg, dashed) = switch (kind) {
      TripBarKind.approved   => (AppColors.cyan.withValues(alpha: 0.22), AppColors.cyan.withValues(alpha: 0.45), AppColors.cyan, false),
      TripBarKind.pendingCto => returned
          ? (AppColors.coral.withValues(alpha: 0.08), AppColors.coral.withValues(alpha: 0.5), AppColors.coral, true)
          : (AppColors.amber.withValues(alpha: 0.08), AppColors.amber, AppColors.amber, true),
      TripBarKind.leave      => (pal.text.withValues(alpha: 0.07), pal.border, pal.textDim, false),
    };
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Align(alignment: Alignment.centerLeft,
          child: Text(b.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.bodySub.copyWith(fontSize: 10, color: fg))),
    );
    return [
      Positioned(
        left: a * colW, width: (e - a) * colW - 3, top: 4, bottom: 4,
        child: dashed
            ? CustomPaint(painter: _DashedRRect(line), child: Container(decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6)), child: label))
            : Container(decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6), border: Border.all(color: line)), child: label),
      ),
    ];
  }
}

class _DashedRRect extends CustomPainter {
  _DashedRRect(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, (d + 4).clamp(0, m.length)), p);
      }
    }
  }
  @override
  bool shouldRepaint(_DashedRRect old) => old.color != color;
}

class CtoCalendarLegend extends StatelessWidget {
  const CtoCalendarLegend({super.key});
  @override
  Widget build(BuildContext context) {
    Widget item(Color fill, Color? line, String l) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 6, decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(2), border: line == null ? null : Border.all(color: line))),
          const SizedBox(width: 5),
          Text(l, style: AppTheme.bodySub.copyWith(fontSize: 10.5, color: context.pal.textMute)),
        ]);
    return Wrap(spacing: 12, children: [
      item(AppColors.cyan.withValues(alpha: 0.55), null, 'Approved'),
      item(Colors.transparent, AppColors.amber, 'Awaiting you'),
      item(context.pal.text.withValues(alpha: 0.12), null, 'Leave'),
    ]);
  }
}

// ── SLA + spares rows ────────────────────────────────────────
class CtoSlaRow extends StatelessWidget {
  const CtoSlaRow({super.key, required this.t, this.onAssign, this.onTap, this.mobile = false});
  final SlaTicket t;
  final VoidCallback? onAssign;
  final VoidCallback? onTap;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = slaColor(t.state);
    if (mobile) {
      return InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.divider))),
          child: Row(children: [
            Container(width: 3, height: 30, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t.title} — ${t.hospital}', style: AppTheme.bodySm.copyWith(fontSize: 12.5, color: pal.text), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(t.whoLabel, style: AppTheme.bodySub.copyWith(fontSize: 11, color: t.unassigned ? AppColors.coral : pal.textDim)),
            ])),
            Text(t.leftLabel, style: AppTheme.monoXs.copyWith(fontSize: 11, color: c)),
          ]),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.divider))),
        child: Column(children: [
          Row(children: [
            Text(t.number, style: AppTheme.monoXs.copyWith(fontSize: 10, color: pal.textDim)),
            const SizedBox(width: 8),
            Expanded(child: Text('${t.title} — ${t.hospital}', style: AppTheme.bodySm.copyWith(fontSize: 11.5, color: pal.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (t.unassigned && onAssign != null) ...[
              CtoActionButton(label: 'Assign', icon: Symbols.person_add, tone: AppColors.teal, height: 22, onPressed: onAssign),
              const SizedBox(width: 8),
            ],
            Text(t.leftLabel, style: AppTheme.monoXs.copyWith(fontSize: 10, color: c)),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: t.usedFraction, minHeight: 3, backgroundColor: pal.border, valueColor: AlwaysStoppedAnimation(c)),
            )),
            const SizedBox(width: 8),
            SizedBox(width: 150, child: Text(t.whoLabel, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTheme.bodySub.copyWith(fontSize: 10, color: t.unassigned ? AppColors.coral : pal.textDim))),
          ]),
        ]),
      ),
    );
  }
}

class CtoSpareRow extends StatelessWidget {
  const CtoSpareRow({super.key, required this.s});
  final SpareAlert s;
  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = switch (s.severity) { 'critical' => AppColors.coral, 'ok' => AppColors.teal, _ => AppColors.amber };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: pal.divider))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: AppTheme.bodySm.copyWith(fontSize: 11.5, color: pal.text), overflow: TextOverflow.ellipsis),
          Text(s.note, style: AppTheme.bodySub.copyWith(fontSize: 10), overflow: TextOverflow.ellipsis),
        ])),
        Text('${s.qty}', style: AppTheme.cardTitle.copyWith(fontSize: 16, color: c)),
      ]),
    );
  }
}
