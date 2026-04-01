import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class AlertSparkline extends StatelessWidget {
  final List<Map<String, dynamic>> trendData;
  final double threshold;
  final Color color;
  final double height;

  const AlertSparkline({
    super.key,
    required this.trendData,
    required this.threshold,
    this.color = const Color(0xFF42A5F5),
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (trendData.isEmpty) {
      return _buildNoDataView();
    }

    return Container(
      height: height,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF3F3F3F), width: 1),
      ),
      child: CustomPaint(
        painter: _SparklinePainter(
          data: trendData,
          threshold: threshold,
          lineColor: color,
          thresholdColor: AppTheme.criticalColor,
        ),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildNoDataView() {
    return Container(
      height: height,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF3F3F3F), width: 1),
      ),
      child: Center(
        child: Text(
          'No trend data available',
          style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double threshold;
  final Color lineColor;
  final Color thresholdColor;

  _SparklinePainter({
    required this.data,
    required this.threshold,
    required this.lineColor,
    required this.thresholdColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Extract values
    final values = data.map((d) => (d['value'] as num).toDouble()).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final valueRange = maxValue - minValue;

    if (valueRange == 0) return;

    // Draw threshold line
    final thresholdY =
        size.height - ((threshold - minValue) / valueRange) * size.height;
    if (thresholdY >= 0 && thresholdY <= size.height) {
      final thresholdPaint = Paint()
        ..color = thresholdColor.withOpacity(0.5)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final thresholdPath = Path();
      thresholdPath.moveTo(0, thresholdY);
      thresholdPath.lineTo(size.width, thresholdY);
      canvas.drawPath(thresholdPath, thresholdPaint);

      // Draw dashed pattern for threshold
      final dashWidth = 4.0;
      final dashSpace = 4.0;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, thresholdY),
          Offset(math.min(startX + dashWidth, size.width), thresholdY),
          thresholdPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }

    // Draw value line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y =
          size.height - ((values[i] - minValue) / valueRange) * size.height;

      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    canvas.drawPath(linePath, linePaint);

    // Draw fill gradient
    final fillPath = Path.from(linePath);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [lineColor.withOpacity(0.3), lineColor.withOpacity(0.0)],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw current value point
    final lastX = size.width;
    final lastY =
        size.height - ((values.last - minValue) / valueRange) * size.height;

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(lastX, lastY), 4, pointPaint);

    // Draw point border
    final pointBorderPaint = Paint()
      ..color = AppTheme.cardDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(lastX, lastY), 4, pointBorderPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return data != oldDelegate.data ||
        threshold != oldDelegate.threshold ||
        lineColor != oldDelegate.lineColor;
  }
}
