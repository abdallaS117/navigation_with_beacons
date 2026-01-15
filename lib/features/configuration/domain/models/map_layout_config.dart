import 'package:equatable/equatable.dart';

/// Types of map sources supported
enum MapSourceType {
  staticImage,
  autocad,
  svg,
  custom,
}

/// Configuration for a map layout
class MapLayoutConfig extends Equatable {
  final String id;
  final String name;
  final MapSourceType sourceType;
  final String? imagePath;
  final double width;
  final double height;
  final double scale;
  final MapOffset offset;
  final List<FloorConfig> floors;
  final Map<String, dynamic> metadata;

  const MapLayoutConfig({
    required this.id,
    required this.name,
    this.sourceType = MapSourceType.staticImage,
    this.imagePath,
    this.width = 800,
    this.height = 600,
    this.scale = 1.0,
    this.offset = const MapOffset(),
    this.floors = const [],
    this.metadata = const {},
  });

  MapLayoutConfig copyWith({
    String? id,
    String? name,
    MapSourceType? sourceType,
    String? imagePath,
    double? width,
    double? height,
    double? scale,
    MapOffset? offset,
    List<FloorConfig>? floors,
    Map<String, dynamic>? metadata,
  }) {
    return MapLayoutConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      imagePath: imagePath ?? this.imagePath,
      width: width ?? this.width,
      height: height ?? this.height,
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
      floors: floors ?? this.floors,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sourceType': sourceType.name,
      'imagePath': imagePath,
      'width': width,
      'height': height,
      'scale': scale,
      'offset': offset.toJson(),
      'floors': floors.map((f) => f.toJson()).toList(),
      'metadata': metadata,
    };
  }

  factory MapLayoutConfig.fromJson(Map<String, dynamic> json) {
    return MapLayoutConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      sourceType: MapSourceType.values.firstWhere(
        (t) => t.name == json['sourceType'],
        orElse: () => MapSourceType.staticImage,
      ),
      imagePath: json['imagePath'] as String?,
      width: (json['width'] as num?)?.toDouble() ?? 800,
      height: (json['height'] as num?)?.toDouble() ?? 600,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      offset: json['offset'] != null
          ? MapOffset.fromJson(json['offset'] as Map<String, dynamic>)
          : const MapOffset(),
      floors: (json['floors'] as List<dynamic>?)
              ?.map((f) => FloorConfig.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  @override
  List<Object?> get props => [id, name, sourceType, imagePath, width, height, scale, offset, floors, metadata];
}

/// Offset configuration for map positioning
class MapOffset extends Equatable {
  final double x;
  final double y;

  const MapOffset({this.x = 0, this.y = 0});

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory MapOffset.fromJson(Map<String, dynamic> json) {
    return MapOffset(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [x, y];
}

/// Configuration for a single floor
class FloorConfig extends Equatable {
  final int floorNumber;
  final String name;
  final String? imagePath;
  final bool isActive;

  const FloorConfig({
    required this.floorNumber,
    required this.name,
    this.imagePath,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'floorNumber': floorNumber,
      'name': name,
      'imagePath': imagePath,
      'isActive': isActive,
    };
  }

  factory FloorConfig.fromJson(Map<String, dynamic> json) {
    return FloorConfig(
      floorNumber: json['floorNumber'] as int,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [floorNumber, name, imagePath, isActive];
}
