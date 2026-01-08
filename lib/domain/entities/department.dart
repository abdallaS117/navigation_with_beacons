import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Department extends Equatable {
  final String id;
  final String name;
  final int floor;
  final Color color;
  final Rect bounds;
  final String? description;
  final IconData icon;

  const Department({
    required this.id,
    required this.name,
    required this.floor,
    required this.color,
    required this.bounds,
    this.description,
    this.icon = Icons.local_hospital,
  });

  @override
  List<Object?> get props => [id, name, floor, color, bounds, description, icon];
}
