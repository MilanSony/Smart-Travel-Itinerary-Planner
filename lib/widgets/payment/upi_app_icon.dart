import 'package:flutter/material.dart';

enum UpiAppType { googlePay, phonePe, paytm, other }

extension UpiAppTypeX on UpiAppType {
  String get label => switch (this) {
        UpiAppType.googlePay => 'Google Pay',
        UpiAppType.phonePe => 'PhonePe',
        UpiAppType.paytm => 'PayTM',
        UpiAppType.other => 'Other',
      };
}

/// Stylized UPI app icons for the Razorpay-style checkout UI.
class UpiAppIcon extends StatelessWidget {
  const UpiAppIcon({
    super.key,
    required this.app,
    this.size = 44,
  });

  final UpiAppType app;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: switch (app) {
        UpiAppType.googlePay => _GooglePayIcon(size: size),
        UpiAppType.phonePe => _PhonePeIcon(size: size),
        UpiAppType.paytm => _PaytmIcon(size: size),
        UpiAppType.other => _OtherUpiIcon(size: size),
      },
    );
  }
}

class _GooglePayIcon extends StatelessWidget {
  const _GooglePayIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: CustomPaint(
        painter: _GoogleGPayPainter(),
        size: Size.square(size),
      ),
    );
  }
}

class _GoogleGPayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.42;
    final cy = size.height * 0.5;
    final r = size.width * 0.22;

    void arc(Color color, double start, double sweep) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start,
        sweep,
        false,
        paint,
      );
    }

    arc(const Color(0xFFEA4335), -0.4, 1.6);
    arc(const Color(0xFFFBBC04), 1.2, 1.6);
    arc(const Color(0xFF34A853), 2.8, 1.6);
    arc(const Color(0xFF4285F4), 4.4, 1.6);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + r * 0.15, cy),
      Offset(cx + r * 1.05, cy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PhonePeIcon extends StatelessWidget {
  const _PhonePeIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF5F259F),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Text(
        'Pe',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
          height: 1,
        ),
      ),
    );
  }
}

class _PaytmIcon extends StatelessWidget {
  const _PaytmIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00BAF2), Color(0xFF002970)],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: Text(
        'Paytm',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.24,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _OtherUpiIcon extends StatelessWidget {
  const _OtherUpiIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: CustomPaint(
        painter: _UpiArrowsPainter(),
        size: Size.square(size),
      ),
    );
  }
}

class _UpiArrowsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B7280)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.18;

    void arrow(double ox, double oy, bool flip) {
      final path = Path();
      if (flip) {
        path.moveTo(cx + ox + s, cy + oy);
        path.lineTo(cx + ox, cy + oy - s);
        path.lineTo(cx + ox, cy + oy + s);
      } else {
        path.moveTo(cx + ox - s, cy + oy);
        path.lineTo(cx + ox, cy + oy - s);
        path.lineTo(cx + ox, cy + oy + s);
      }
      path.close();
      canvas.drawPath(path, paint..style = PaintingStyle.fill);
    }

    arrow(-s * 0.3, 0, false);
    arrow(s * 0.3, 0, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// NPCI-style UPI badge used in payment method rows.
class UpiBrandBadge extends StatelessWidget {
  const UpiBrandBadge({super.key, this.height = 22});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.35),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF097939), Color(0xFF0B5E2E)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        'UPI',
        style: TextStyle(
          color: Colors.white,
          fontSize: height * 0.52,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
