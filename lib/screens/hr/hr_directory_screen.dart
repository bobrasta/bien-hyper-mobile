import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'hr_directory_tab.dart';

/// Own top-level destination now (was a tab on the old HrStaffScreen) — the
/// design pass moved Directory/Recruitment/Reports out of one tabbed screen
/// into flat sidebar entries, matching the reference dashboards where each
/// is its own destination rather than nested behind tabs.
class HrDirectoryScreen extends StatelessWidget {
  const HrDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, cst) {
    final pad = cst.maxWidth < 560 ? 16.0 : 28.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Directory', style: AppTheme.pageTitle),
          const SizedBox(height: 4),
          Text('Personal info, contracts, discipline, and career progression', style: AppTheme.bodySub),
        ]),
      ),
      const SizedBox(height: 16),
      const Expanded(child: HrDirectoryTab()),
    ]);
  });
}
