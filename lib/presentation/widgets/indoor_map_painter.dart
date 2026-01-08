import 'package:flutter/material.dart';
import '../../domain/entities/floor_map.dart';
import '../../domain/entities/department.dart';
import '../../core/constants/app_colors.dart';

/// AutoCAD-style architectural floor plan painter
class IndoorMapPainter extends CustomPainter {
  final FloorMap floorMap;
  final Department? selectedDepartment;
  final Department? highlightedDepartment;

  IndoorMapPainter({
    required this.floorMap,
    this.selectedDepartment,
    this.highlightedDepartment,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw floor background (clean white)
    final bgPaint = Paint()..color = AppColors.mapBackground;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw floor plate (building footprint)
    _drawFloorPlate(canvas);

    // Draw corridors (walkable areas)
    _drawCorridors(canvas);

    // Draw rooms with very subtle fills
    _drawRooms(canvas);

    // Draw all walls (continuous architectural lines)
    _drawWalls(canvas);

    // Draw door openings
    _drawDoorOpenings(canvas);

    // Draw room labels
    _drawRoomLabels(canvas);

    // Draw selection highlight
    if (selectedDepartment != null) {
      _drawSelectionHighlight(canvas, selectedDepartment!);
    }
  }

  void _drawFloorPlate(Canvas canvas) {
    // Main building outline fill
    final floorPaint = Paint()
      ..color = AppColors.floorFill
      ..style = PaintingStyle.fill;

    final floorPath = Path();

    // Hospital L-shaped floor plate
    floorPath.moveTo(40, 160);
    floorPath.lineTo(760, 160);
    floorPath.lineTo(760, 580);
    floorPath.lineTo(40, 580);
    floorPath.close();

    canvas.drawPath(floorPath, floorPaint);
  }

  void _drawCorridors(Canvas canvas) {
    final corridorPaint = Paint()
      ..color = AppColors.corridor
      ..style = PaintingStyle.fill;

    for (final corridor in floorMap.corridors) {
      if (corridor.points.length >= 4) {
        final path = Path();
        path.moveTo(corridor.points[0].dx, corridor.points[0].dy);
        for (int i = 1; i < corridor.points.length; i++) {
          path.lineTo(corridor.points[i].dx, corridor.points[i].dy);
        }
        path.close();
        canvas.drawPath(path, corridorPaint);
      }
    }
  }

  void _drawRooms(Canvas canvas) {
    for (final department in floorMap.departments) {
      final isSelected = department.id == selectedDepartment?.id;

      // Very subtle room fill
      final fillPaint = Paint()
        ..color = isSelected
            ? department.color.withAlpha(100)
            : department.color.withAlpha(40)
        ..style = PaintingStyle.fill;

      canvas.drawRect(department.bounds, fillPaint);
    }
  }

  void _drawWalls(Canvas canvas) {
    // Main wall paint (thin, technical lines)
    final wallPaint = Paint()
      ..color = AppColors.walls
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    // Outer building walls
    _drawBuildingOutline(canvas, wallPaint);

    // Internal room walls
    _drawInternalWalls(canvas, wallPaint);

    // Room partition walls (lighter)
    final partitionPaint = Paint()
      ..color = AppColors.wallsLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.square;

    _drawPartitionWalls(canvas, partitionPaint);
  }

  void _drawBuildingOutline(Canvas canvas, Paint paint) {
    final outline = Path();

    // Main rectangular outline
    outline.moveTo(40, 160);
    outline.lineTo(760, 160);
    outline.lineTo(760, 580);
    outline.lineTo(40, 580);
    outline.close();

    canvas.drawPath(outline, paint);
  }

  void _drawInternalWalls(Canvas canvas, Paint paint) {
    // Horizontal corridor walls
    canvas.drawLine(const Offset(40, 280), const Offset(340, 280), paint);
    canvas.drawLine(const Offset(460, 280), const Offset(760, 280), paint);

    canvas.drawLine(const Offset(40, 420), const Offset(340, 420), paint);
    canvas.drawLine(const Offset(460, 420), const Offset(760, 420), paint);

    // Vertical corridor walls
    canvas.drawLine(const Offset(340, 160), const Offset(340, 280), paint);
    canvas.drawLine(const Offset(460, 160), const Offset(460, 280), paint);

    canvas.drawLine(const Offset(340, 420), const Offset(340, 580), paint);
    canvas.drawLine(const Offset(460, 420), const Offset(460, 580), paint);

    // Cross corridor connection
    canvas.drawLine(const Offset(340, 280), const Offset(340, 420), paint);
    canvas.drawLine(const Offset(460, 280), const Offset(460, 420), paint);
  }

  void _drawPartitionWalls(Canvas canvas, Paint paint) {
    // Left wing room dividers
    canvas.drawLine(const Offset(140, 280), const Offset(140, 160), paint);
    canvas.drawLine(const Offset(280, 280), const Offset(280, 160), paint);

    canvas.drawLine(const Offset(140, 420), const Offset(140, 580), paint);
    canvas.drawLine(const Offset(280, 420), const Offset(280, 580), paint);

    // Right wing room dividers
    canvas.drawLine(const Offset(540, 280), const Offset(540, 160), paint);
    canvas.drawLine(const Offset(660, 280), const Offset(660, 160), paint);

    canvas.drawLine(const Offset(540, 420), const Offset(540, 580), paint);
    canvas.drawLine(const Offset(660, 420), const Offset(660, 580), paint);

    // Elevator/Stairs area walls
    canvas.drawLine(const Offset(340, 230), const Offset(460, 230), paint);
    canvas.drawLine(const Offset(400, 160), const Offset(400, 230), paint);
  }

  void _drawDoorOpenings(Canvas canvas) {
    final doorPaint = Paint()
      ..color = AppColors.doorOpening
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.butt;

    // Door openings represented as gaps (white lines over walls)
    final doorPositions = [
      // Left wing doors
      const Offset(90, 280), 20.0,
      const Offset(210, 280), 20.0,
      const Offset(90, 420), 20.0,
      const Offset(210, 420), 20.0,

      // Right wing doors
      const Offset(590, 280), 20.0,
      const Offset(710, 280), 20.0,
      const Offset(590, 420), 20.0,
      const Offset(710, 420), 20.0,

      // Main entrance
      const Offset(400, 580), 40.0,

      // Elevator doors
      const Offset(370, 230), 20.0,
      const Offset(430, 230), 20.0,
    ];

    for (int i = 0; i < doorPositions.length; i += 2) {
      final pos = doorPositions[i] as Offset;
      final width = doorPositions[i + 1] as double;

      canvas.drawLine(
        Offset(pos.dx - width / 2, pos.dy),
        Offset(pos.dx + width / 2, pos.dy),
        doorPaint,
      );
    }

    // Draw door swing arcs (architectural detail)
    _drawDoorSwings(canvas);
  }

  void _drawDoorSwings(Canvas canvas) {
    final arcPaint = Paint()
      ..color = AppColors.wallsLight.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Simple arc indicators for doors
    final doorSwings = [
      (const Offset(100, 280), 15.0, 0.0, 1.57),
      (const Offset(220, 280), 15.0, 0.0, 1.57),
      (const Offset(600, 280), 15.0, 1.57, 3.14),
      (const Offset(720, 280), 15.0, 1.57, 3.14),
    ];

    for (final swing in doorSwings) {
      canvas.drawArc(
        Rect.fromCircle(center: swing.$1, radius: swing.$2),
        swing.$3,
        swing.$4,
        false,
        arcPaint,
      );
    }
  }

  void _drawRoomLabels(Canvas canvas) {
    for (final department in floorMap.departments) {
      final textSpan = TextSpan(
        text: department.name,
        style: TextStyle(
          color: AppColors.roomLabel,
          fontSize: 8,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.3,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout(maxWidth: department.bounds.width - 4);

      final textOffset = Offset(
        department.bounds.center.dx - textPainter.width / 2,
        department.bounds.center.dy - textPainter.height / 2,
      );

      textPainter.paint(canvas, textOffset);
    }
  }

  void _drawSelectionHighlight(Canvas canvas, Department department) {
    final highlightPaint = Paint()
      ..color = AppColors.primary.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(department.bounds.inflate(2), highlightPaint);

    // Subtle glow
    final glowPaint = Paint()
      ..color = AppColors.primary.withAlpha(20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawRect(department.bounds.inflate(4), glowPaint);
  }

  @override
  bool shouldRepaint(covariant IndoorMapPainter oldDelegate) {
    return oldDelegate.floorMap != floorMap ||
        oldDelegate.selectedDepartment != selectedDepartment ||
        oldDelegate.highlightedDepartment != highlightedDepartment;
  }
}
