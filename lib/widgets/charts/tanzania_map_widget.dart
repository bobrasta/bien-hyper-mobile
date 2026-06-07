import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

import '../../theme/app_palette.dart';
class TanzaniaMapWidget extends StatelessWidget {
  const TanzaniaMapWidget({super.key, this.totalMachines, this.totalHospitals, this.pins = const []});
  final int? totalMachines;
  final int? totalHospitals;
  final List<Map<String, dynamic>> pins;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 296,
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // SVG-equivalent background + outline
            CustomPaint(
              size: Size(w, h),
              painter: _TanzaniaPainter(context.pal),
            ),
            // City pins
            for (final pin in pins)
              Positioned(
                left: pin['x'] * w,
                top:  pin['y'] * h,
                child: _MapPin(
                  city:   pin['city'],
                  count:  pin['count'],
                  status: pin['status'],
                  large:  pin['lg'] == true,
                ),
              ),
            // Bottom stats strip
            Positioned(
              bottom: 8, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xD90F1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.pal.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const _Stat(label: 'REGIONS',      value: '11'),
                    _Stat(label: 'HOSPITALS',   value: '${totalHospitals ?? 42}'),
                    _Stat(label: 'MACHINES',    value: '${totalMachines  ?? 847}'),
                    const _Stat(label: 'ACTIVE TECHS', value: '18'),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.monoXs.copyWith(fontSize: 10)),
        Text(value,
          style: AppTheme.bodyStrong.copyWith(
            fontSize: 14,
            fontFeatures: [const FontFeature.tabularFigures()],
          )),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.city,
    required this.count,
    required this.status,
    this.large = false,
  });
  final String city;
  final int count;
  final String status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'amber' => AppColors.amber,
      'down'  => AppColors.coral,
      _       => AppColors.teal,
    };
    final size = large ? 22.0 : 14.0;

    return Transform.translate(
      offset: Offset(-size / 2, -size / 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label above pin
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: context.pal.surface1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.pal.border),
            ),
            child: Text('$city · $count',
              style: AppTheme.monoXs.copyWith(fontSize: 9.5, color: context.pal.text)),
          ),
          const SizedBox(height: 2),
          // Pin dot
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: context.pal.bg, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12),
                BoxShadow(color: color, blurRadius: 0, spreadRadius: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter — draws Tanzania country outline + lakes + grid
class _TanzaniaPainter extends CustomPainter {
  const _TanzaniaPainter(this.pal);
  final AppPalette pal;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width  / 400;
    final sy = size.height / 300;

    // Grid
    final gridPaint = Paint()
      ..color = const Color(0x06FFFFFF)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (double x = 0; x <= 400; x += 20) {
      canvas.drawLine(Offset(x * sx, 0), Offset(x * sx, size.height), gridPaint);
    }
    for (double y = 0; y <= 300; y += 20) {
      canvas.drawLine(Offset(0, y * sy), Offset(size.width, y * sy), gridPaint);
    }

    // Tanzania outline (from screen1-dashboard.jsx SVG path)
    final raw = [
      Offset(60,80), Offset(100,55), Offset(140,50), Offset(180,45),
      Offset(220,40), Offset(260,50), Offset(290,55), Offset(310,75),
      Offset(320,110), Offset(325,140), Offset(320,170), Offset(310,200),
      Offset(300,225), Offset(290,245), Offset(280,260), Offset(250,265),
      Offset(220,268), Offset(190,270), Offset(160,265), Offset(130,255),
      Offset(100,240), Offset(80,220), Offset(65,190), Offset(55,160),
      Offset(50,130), Offset(55,100), Offset(60,80),
    ];
    final pts = raw.map((p) => Offset(p.dx * sx, p.dy * sy)).toList();

    // Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [pal.surface2, pal.topbarBg],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0x59009D7B)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }
    path.close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Lake Victoria (ellipse)
    final lakePaint = Paint()
      ..color = pal.bg
      ..style = PaintingStyle.fill;
    final lakeBorderPaint = Paint()
      ..color = const Color(0x665B8DEF)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(130*sx, 68*sy), width: 68*sx, height: 36*sy),
      lakePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(130*sx, 68*sy), width: 68*sx, height: 36*sy),
      lakeBorderPaint,
    );

    // "TANZANIA" ghost text
    final tp = TextPainter(
      text: TextSpan(
        text: 'TANZANIA',
        style: TextStyle(
          fontSize: 44 * sx, fontWeight: FontWeight.w700,
          color: const Color(0x0FE8EAF6), letterSpacing: 6 * sx,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, 150 * sy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_TanzaniaPainter old) => old.pal != pal;
}
