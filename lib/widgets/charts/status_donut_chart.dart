import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

import '../../theme/app_palette.dart';

class StatusDonutChart extends StatelessWidget {
  const StatusDonutChart({super.key, this.breakdown, this.total});

  final Map<String, int>? breakdown;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final Map<String, int> data = breakdown ?? const <String, int>{
      'Operational':   0,
      'Needs Service': 0,
      'Down':          0,
      'Warranty':      0,
    };

    final totalCount = total ?? data.values.fold<int>(0, (a, b) => a + b);
    if (totalCount == 0) {
      return SizedBox(
        height: 200,
        child: Center(child: Text('No data', style: TextStyle(color: context.pal.textDim))),
      );
    }

    final colors = [AppColors.teal, AppColors.amber, AppColors.coral, AppColors.blue];
    final entries = data.entries.where((e) => e.value > 0).toList();

    final sections = List.generate(entries.length, (i) => PieChartSectionData(
      value: entries[i].value.toDouble(),
      color: colors[i % colors.length],
      radius: 22,
      showTitle: false,
    ));

    final uptimePct = totalCount == 0
        ? 0.0
        : (data['Operational'] ?? 0) / totalCount * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 180, height: 180,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sections: sections,
                centerSpaceRadius: 64,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(enabled: false),
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${uptimePct.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 26, fontWeight: FontWeight.w700,
                    color: context.pal.text,
                  )),
                Text('UPTIME', style: AppTheme.monoXs.copyWith(letterSpacing: 1.5)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(entries.length, (i) {
          final e = entries[i];
          final pct = (e.value / totalCount * 100).toStringAsFixed(1);
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: i < entries.length - 1
                ? BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.divider)))
                : null,
            child: Row(children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(e.key,
                  style: AppTheme.bodySm.copyWith(fontSize: 12.5))),
              Text('$pct%',
                  style: AppTheme.monoXs.copyWith(
                      color: context.pal.textDim, fontSize: 11)),
              const SizedBox(width: 8),
              Text('${e.value}',
                style: AppTheme.bodyStrong.copyWith(
                  fontSize: 13,
                  fontFeatures: [const FontFeature.tabularFigures()],
                )),
            ]),
          );
        }),
      ],
    );
  }
}
