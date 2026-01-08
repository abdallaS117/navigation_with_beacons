import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

class UserArrow extends StatelessWidget {
  final double x;
  final double y;
  final double heading;
  final bool isAnimating;

  const UserArrow({
    super.key,
    required this.x,
    required this.y,
    this.heading = 0,
    this.isAnimating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - AppConstants.arrowSize / 2,
      top: y - AppConstants.arrowSize / 2,
      child: AnimatedContainer(
        duration: AppConstants.arrowMovementDuration,
        curve: Curves.easeInOut,
        child: Transform.rotate(
          angle: heading * pi / 180,
          child: CustomPaint(
            size: const Size(AppConstants.arrowSize, AppConstants.arrowSize),
            painter: _UserArrowPainter(isAnimating: isAnimating),
          ),
        ),
      ),
    );
  }
}

class _UserArrowPainter extends CustomPainter {
  final bool isAnimating;

  _UserArrowPainter({this.isAnimating = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw subtle outer glow (very light)
    final glowPaint = Paint()
      ..color = AppColors.userArrow.withAlpha(40)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, size.width / 2, glowPaint);

    // Draw arrow background circle (white, clean)
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, size.width / 2 - 2, bgPaint);

    // Draw arrow body (simple blue dot with direction indicator)
    final arrowPaint = Paint()
      ..color = AppColors.userArrow
      ..style = PaintingStyle.fill;

    // Simple directional arrow
    final arrowPath = Path();
    final arrowWidth = size.width * 0.35;
    final arrowHeight = size.height * 0.4;

    arrowPath.moveTo(center.dx, center.dy - arrowHeight / 2);
    arrowPath.lineTo(center.dx + arrowWidth / 2, center.dy + arrowHeight / 3);
    arrowPath.lineTo(center.dx, center.dy + arrowHeight / 8);
    arrowPath.lineTo(center.dx - arrowWidth / 2, center.dy + arrowHeight / 3);
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);

    // Draw subtle border
    final borderPaint = Paint()
      ..color = AppColors.userArrowBorder.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppConstants.arrowBorderWidth;

    canvas.drawCircle(center, size.width / 2 - 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _UserArrowPainter oldDelegate) {
    return oldDelegate.isAnimating != isAnimating;
  }
}

class AnimatedUserArrow extends StatefulWidget {
  final double x;
  final double y;
  final double heading;

  const AnimatedUserArrow({
    super.key,
    required this.x,
    required this.y,
    this.heading = 0,
  });

  @override
  State<AnimatedUserArrow> createState() => _AnimatedUserArrowState();
}

class _AnimatedUserArrowState extends State<AnimatedUserArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _xAnimation;
  late Animation<double> _yAnimation;
  double _previousX = 0;
  double _previousY = 0;

  @override
  void initState() {
    super.initState();
    _previousX = widget.x;
    _previousY = widget.y;
    _controller = AnimationController(
      duration: AppConstants.arrowMovementDuration,
      vsync: this,
    );
    _setupAnimations();
  }

  void _setupAnimations() {
    _xAnimation = Tween<double>(
      begin: _previousX,
      end: widget.x,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _yAnimation = Tween<double>(
      begin: _previousY,
      end: widget.y,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(AnimatedUserArrow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.x != widget.x || oldWidget.y != widget.y) {
      _previousX = _xAnimation.value;
      _previousY = _yAnimation.value;
      _setupAnimations();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return UserArrow(
          x: _xAnimation.value,
          y: _yAnimation.value,
          heading: widget.heading,
          isAnimating: _controller.isAnimating,
        );
      },
    );
  }
}
