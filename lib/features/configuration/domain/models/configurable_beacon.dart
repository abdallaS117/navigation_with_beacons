import 'package:equatable/equatable.dart';

/// Represents a physical beacon device that can be configured dynamically.
/// This model is JSON-ready for backend or file-based configuration.
class ConfigurableBeacon extends Equatable {
  final String id;
  final String uuid;
  final int? major;
  final int? minor;
  final String name;
  final double? x;
  final double? y;
  final int? floor;
  final double txPower;
  final String? linkedNodeId;
  final Map<String, dynamic> metadata;
  final bool isPlaced;

  const ConfigurableBeacon({
    required this.id,
    required this.uuid,
    this.major,
    this.minor,
    required this.name,
    this.x,
    this.y,
    this.floor,
    this.txPower = -59.0,
    this.linkedNodeId,
    this.metadata = const {},
    this.isPlaced = false,
  });

  ConfigurableBeacon copyWith({
    String? id,
    String? uuid,
    int? major,
    int? minor,
    String? name,
    double? x,
    double? y,
    int? floor,
    double? txPower,
    String? linkedNodeId,
    Map<String, dynamic>? metadata,
    bool? isPlaced,
  }) {
    return ConfigurableBeacon(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      major: major ?? this.major,
      minor: minor ?? this.minor,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      floor: floor ?? this.floor,
      txPower: txPower ?? this.txPower,
      linkedNodeId: linkedNodeId ?? this.linkedNodeId,
      metadata: metadata ?? this.metadata,
      isPlaced: isPlaced ?? this.isPlaced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'major': major,
      'minor': minor,
      'name': name,
      'x': x,
      'y': y,
      'floor': floor,
      'txPower': txPower,
      'linkedNodeId': linkedNodeId,
      'metadata': metadata,
      'isPlaced': isPlaced,
    };
  }

  factory ConfigurableBeacon.fromJson(Map<String, dynamic> json) {
    return ConfigurableBeacon(
      id: json['id'] as String,
      uuid: json['uuid'] as String,
      major: json['major'] as int?,
      minor: json['minor'] as int?,
      name: json['name'] as String,
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      floor: json['floor'] as int?,
      txPower: (json['txPower'] as num?)?.toDouble() ?? -59.0,
      linkedNodeId: json['linkedNodeId'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      isPlaced: json['isPlaced'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, uuid, major, minor, name, x, y, floor, txPower, linkedNodeId, metadata, isPlaced];
}
