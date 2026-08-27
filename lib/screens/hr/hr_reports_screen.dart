import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'hr_reports_tab.dart';

/// Own top-level destination now (was a tab on the old HrStaffScreen).
/// Distinct from the general `reports_screen.dart` — this is HR-only, the
/// 7-category breakdown (Staff/Headcount, Leave, Recruitment, Contracts &
/// Attendance, Discipline, Payroll, Career Progression).
class HrReportsScreen extends StatelessWidget {
  const HrReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, cst) {
    final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('HR Reports', style: AppTheme.pageTitle),
          const SizedBox(height: 4),
          Text('Staff, leave, recruitment, contracts, discipline, and career analytics', style: AppTheme.bodySub),
        ]),
      ),
      const SizedBox(height: 16),
      const Expanded(child: HrReportsTab()),
    ]);
  });
}
