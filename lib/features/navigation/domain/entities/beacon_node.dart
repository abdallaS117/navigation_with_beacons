import 'package:equatable/equatable.dart';

class BeaconNode extends Equatable {
  final String uid;
  final String name;
  final double x;
  final double y;
  final int floor;
  final String? departmentId;
  final bool isNavigable;
  final List<String> connectedNodes;

  const BeaconNode({
    required this.uid,
    required this.name,
    required this.x,
    required this.y,
    required this.floor,
    this.departmentId,
    this.isNavigable = true,
    this.connectedNodes = const [],
  });

  BeaconNode copyWith({
    String? uid,
    String? name,
    double? x,
    double? y,
    int? floor,
    String? departmentId,
    bool? isNavigable,
    List<String>? connectedNodes,
  }) {
    return BeaconNode(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      floor: floor ?? this.floor,
      departmentId: departmentId ?? this.departmentId,
      isNavigable: isNavigable ?? this.isNavigable,
      connectedNodes: connectedNodes ?? this.connectedNodes,
    );
  }

  @override
  List<Object?> get props => [uid, name, x, y, floor, departmentId, isNavigable, connectedNodes];
}
