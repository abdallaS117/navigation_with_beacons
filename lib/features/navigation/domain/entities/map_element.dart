import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum MapElementType {
  wall,
  corridor,
  room,
  door,
  elevator,
  stairs,
}

class MapElement extends Equatable {
  final String id;
  final MapElementType type;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isFilled;

  const MapElement({
    required this.id,
    required this.type,
    required this.points,
    required this.color,
    this.strokeWidth = 2.0,
    this.isFilled = false,
  });

  @override
  List<Object?> get props => [id, type, points, color, strokeWidth, isFilled];
}
