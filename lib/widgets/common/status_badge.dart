import 'package:flutter/material.dart';
import '../../models/machine.dart';
import '../../models/service_ticket.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
/// Pill badge mirroring the CSS `.badge` classes
class StatusBadge extends StatelessWidget {
  const StatusBadge.machine(this._machineStatus, {super.key, this.large = false})
      : _ticketStatus = null;

  const StatusBadge.ticket(this._ticketStatus, {super.key, this.large = false})
      : _machineStatus = null;

  final MachineStatus? _machineStatus;
  final TicketStatus?  _ticketStatus;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, Color border, String label) = _resolve();
    final double fs = large ? 13 : 11.5;
    final EdgeInsets pad = large
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 9, vertical: 3);

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 8 : 6,
            height: large ? 8 : 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.bodySub.copyWith(
            color: fg, fontSize: fs, fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }

  (Color, Color, Color, String) _resolve() {
    if (_machineStatus != null) {
      return switch (_machineStatus) {
        MachineStatus.operational  => (AppColors.teal,     AppColors.tealSoft,   const Color(0x4000D4AA), 'Operational'),
        MachineStatus.needsService => (AppColors.amber,    AppColors.amberSoft,  const Color(0x40F59E0B), 'Service'),
        MachineStatus.down         => (AppColors.coral,    AppColors.coralSoft,  const Color(0x40FF5252), 'Down'),
        MachineStatus.warranty     => (AppColors.blue,     AppColors.blueSoft,   const Color(0x4D5B8DEF), 'Warranty'),
        MachineStatus.idle         => (AppColors.textMute, const Color(0x0AFFFFFF), AppColors.border, 'Idle'),
      };
    }
    return switch (_ticketStatus) {
      TicketStatus.open       => (AppColors.amber,    AppColors.amberSoft,  const Color(0x40F59E0B), 'Open'),
      TicketStatus.inProgress => (AppColors.blue,     AppColors.blueSoft,   const Color(0x4D5B8DEF), 'Active'),
      TicketStatus.resolved   => (AppColors.teal,     AppColors.tealSoft,   const Color(0x4000D4AA), 'Resolved'),
      TicketStatus.overdue    => (AppColors.coral,    AppColors.coralSoft,  const Color(0x40FF5252), 'Overdue'),
      null                    => (AppColors.textMute, const Color(0x0AFFFFFF), AppColors.border, '—'),
    };
  }
}
