import 'package:equatable/equatable.dart';
import 'department.dart';
import 'map_element.dart';

class FloorMap extends Equatable {
  final int floorNumber;
  final String name;
  final List<Department> departments;
  final List<MapElement> walls;
  final List<MapElement> corridors;
  final double width;
  final double height;

  const FloorMap({
    required this.floorNumber,
    required this.name,
    required this.departments,
    required this.walls,
    required this.corridors,
    this.width = 800,
    this.height = 600,
  });

  @override
  List<Object?> get props => [floorNumber, name, departments, walls, corridors, width, height];
}
