import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'hr_recruitment_tab.dart';

/// Own top-level destination now (was a tab on the old HrStaffScreen).
class HrRecruitmentScreen extends StatelessWidget {
  const HrRecruitmentScreen({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, cst) {
    final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recruitment', style: AppTheme.pageTitle),
          const SizedBox(height: 4),
          Text('Vacancies, applicants, and the hiring pipeline', style: AppTheme.bodySub),
        ]),
      ),
      const SizedBox(height: 16),
      const Expanded(child: HrRecruitmentTab()),
    ]);
  });
}
