import 'package:flutter/material.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/floor_map.dart';
import '../../domain/entities/map_element.dart';
import '../../core/constants/app_colors.dart';

/// Static map provider that uses hardcoded map data.
class StaticMapProvider {
  final Map<int, FloorMap> _floorMaps = {};
  final List<Department> _departments = [];
  bool _initialized = false;

  void _initializeData() {
    _departments.clear();
    _floorMaps.clear();
    _initializeDepartments();
    _initializeFloorMaps();
  }

  void _initializeDepartments() {
    _departments.addAll([
      // ==================== FLOOR 1 (Ground) ====================
      Department(
        id: 'xray',
        name: 'X-Ray',
        floor: 1,
        color: AppColors.radiology,
        bounds: const Rect.fromLTWH(45, 165, 90, 110),
        description: 'X-Ray room',
        icon: Icons.healing,
      ),
      Department(
        id: 'radiology',
        name: 'Radiology',
        floor: 1,
        color: AppColors.radiology,
        bounds: const Rect.fromLTWH(145, 165, 130, 110),
        description: 'Radiology department',
        icon: Icons.medical_services,
      ),
      Department(
        id: 'pharmacy',
        name: 'Pharmacy',
        floor: 1,
        color: AppColors.pharmacy,
        bounds: const Rect.fromLTWH(45, 425, 90, 150),
        description: 'Hospital pharmacy',
        icon: Icons.local_pharmacy,
      ),
      Department(
        id: 'waiting_1',
        name: 'Waiting Area',
        floor: 1,
        color: AppColors.waitingArea,
        bounds: const Rect.fromLTWH(145, 425, 130, 150),
        description: 'Ground floor waiting',
        icon: Icons.weekend,
      ),
      Department(
        id: 'lab',
        name: 'Laboratory',
        floor: 1,
        color: AppColors.labs,
        bounds: const Rect.fromLTWH(545, 165, 110, 110),
        description: 'Medical laboratory',
        icon: Icons.science,
      ),
      Department(
        id: 'blood_lab',
        name: 'Blood Test',
        floor: 1,
        color: AppColors.labs,
        bounds: const Rect.fromLTWH(665, 165, 90, 110),
        description: 'Blood testing',
        icon: Icons.bloodtype,
      ),
      Department(
        id: 'emergency',
        name: 'Emergency',
        floor: 1,
        color: AppColors.emergency,
        bounds: const Rect.fromLTWH(545, 425, 110, 150),
        description: 'Emergency department',
        icon: Icons.emergency,
      ),
      Department(
        id: 'triage',
        name: 'Triage',
        floor: 1,
        color: AppColors.emergency,
        bounds: const Rect.fromLTWH(665, 425, 90, 150),
        description: 'Triage area',
        icon: Icons.priority_high,
      ),
      Department(
        id: 'stairs',
        name: 'Stairs',
        floor: 1,
        color: AppColors.stairs,
        bounds: const Rect.fromLTWH(345, 165, 50, 60),
        description: 'Staircase',
        icon: Icons.stairs,
      ),
      Department(
        id: 'elevator',
        name: 'Elevator',
        floor: 1,
        color: AppColors.elevator,
        bounds: const Rect.fromLTWH(405, 165, 50, 60),
        description: 'Elevator',
        icon: Icons.elevator,
      ),
      Department(
        id: 'reception',
        name: 'Reception',
        floor: 1,
        color: AppColors.reception,
        bounds: const Rect.fromLTWH(345, 425, 110, 70),
        description: 'Main reception',
        icon: Icons.desk,
      ),
      Department(
        id: 'entrance',
        name: 'Main Entrance',
        floor: 1,
        color: AppColors.entrance,
        bounds: const Rect.fromLTWH(345, 505, 110, 70),
        description: 'Hospital main entrance',
        icon: Icons.door_front_door,
      ),
      // ==================== FLOOR 2 ====================
      Department(
        id: 'clinic_general',
        name: 'General Clinic',
        floor: 2,
        color: AppColors.clinics,
        bounds: const Rect.fromLTWH(45, 165, 90, 110),
        description: 'General medical clinic',
        icon: Icons.medical_information,
      ),
      Department(
        id: 'clinic_internal',
        name: 'Internal Medicine',
        floor: 2,
        color: AppColors.clinics,
        bounds: const Rect.fromLTWH(145, 165, 130, 110),
        description: 'Internal medicine',
        icon: Icons.medical_services,
      ),
      Department(
        id: 'clinic_pediatric',
        name: 'Pediatric',
        floor: 2,
        color: AppColors.clinics,
        bounds: const Rect.fromLTWH(45, 425, 90, 150),
        description: 'Children clinic',
        icon: Icons.child_care,
      ),
      Department(
        id: 'clinic_derma',
        name: 'Dermatology',
        floor: 2,
        color: AppColors.clinics,
        bounds: const Rect.fromLTWH(145, 425, 130, 150),
        description: 'Dermatology clinic',
        icon: Icons.healing,
      ),
      Department(
        id: 'lab_2',
        name: 'Lab Collection',
        floor: 2,
        color: AppColors.labs,
        bounds: const Rect.fromLTWH(545, 165, 110, 110),
        description: 'Sample collection',
        icon: Icons.science,
      ),
      Department(
        id: 'imaging',
        name: 'Imaging',
        floor: 2,
        color: AppColors.radiology,
        bounds: const Rect.fromLTWH(665, 165, 90, 110),
        description: 'Medical imaging',
        icon: Icons.image_search,
      ),
      Department(
        id: 'records',
        name: 'Medical Records',
        floor: 2,
        color: AppColors.reception,
        bounds: const Rect.fromLTWH(545, 425, 110, 150),
        description: 'Medical records',
        icon: Icons.folder,
      ),
      Department(
        id: 'admin',
        name: 'Administration',
        floor: 2,
        color: AppColors.reception,
        bounds: const Rect.fromLTWH(665, 425, 90, 150),
        description: 'Admin office',
        icon: Icons.admin_panel_settings,
      ),
      Department(
        id: 'waiting_2',
        name: 'Waiting Area',
        floor: 2,
        color: AppColors.waitingArea,
        bounds: const Rect.fromLTWH(345, 425, 110, 150),
        description: 'Second floor waiting',
        icon: Icons.weekend,
      ),
      // ==================== FLOOR 3 (Heart Department) ====================
      Department(
        id: 'echo_room',
        name: 'Echo Room',
        floor: 3,
        color: AppColors.heartDepartment,
        bounds: const Rect.fromLTWH(45, 165, 90, 110),
        description: 'Echocardiography',
        icon: Icons.monitor_heart,
      ),
      Department(
        id: 'cardiology',
        name: 'Cardiology',
        floor: 3,
        color: AppColors.heartDepartment,
        bounds: const Rect.fromLTWH(145, 165, 130, 110),
        description: 'Cardiology dept',
        icon: Icons.favorite,
      ),
      Department(
        id: 'cath_lab',
        name: 'Cath Lab',
        floor: 3,
        color: AppColors.heartDepartment,
        bounds: const Rect.fromLTWH(45, 425, 90, 150),
        description: 'Catheterization lab',
        icon: Icons.healing,
      ),
      Department(
        id: 'prep_room',
        name: 'Prep Room',
        floor: 3,
        color: AppColors.heartDepartment,
        bounds: const Rect.fromLTWH(145, 425, 130, 150),
        description: 'Procedure prep',
        icon: Icons.medical_services,
      ),
      Department(
        id: 'heart_surgery',
        name: 'Heart Surgery',
        floor: 3,
        color: AppColors.heartDepartment,
        bounds: const Rect.fromLTWH(545, 165, 110, 110),
        description: 'Cardiac surgery',
        icon: Icons.healing,
      ),
      Department(
        id: 'recovery',
        name: 'Recovery',
        floor: 3,
        color: AppColors.heartDepartment,
        bounds: const Rect.fromLTWH(665, 165, 90, 110),
        description: 'Post-surgery recovery',
        icon: Icons.hotel,
      ),
      Department(
        id: 'icu',
        name: 'ICU',
        floor: 3,
        color: AppColors.emergency,
        bounds: const Rect.fromLTWH(545, 425, 110, 150),
        description: 'Intensive Care Unit',
        icon: Icons.monitor_heart,
      ),
      Department(
        id: 'icu_waiting',
        name: 'ICU Waiting',
        floor: 3,
        color: AppColors.waitingArea,
        bounds: const Rect.fromLTWH(665, 425, 90, 150),
        description: 'ICU waiting area',
        icon: Icons.weekend,
      ),
      Department(
        id: 'heart_department',
        name: 'Heart Dept Reception',
        floor: 3,
        color: AppColors.heartDepartment,
        bounds: const Rect.fromLTWH(345, 425, 110, 150),
        description: 'Heart Dept Main',
        icon: Icons.favorite,
      ),
    ]);
  }

  void _initializeFloorMaps() {
    _floorMaps[1] = FloorMap(
      floorNumber: 1,
      name: 'Ground Floor',
      departments: _departments.where((d) => d.floor == 1).toList(),
      walls: _createWalls(),
      corridors: _createCorridors(),
    );

    _floorMaps[2] = FloorMap(
      floorNumber: 2,
      name: 'First Floor',
      departments: _departments.where((d) => d.floor == 2).toList(),
      walls: _createWalls(),
      corridors: _createCorridors(),
    );

    _floorMaps[3] = FloorMap(
      floorNumber: 3,
      name: 'Second Floor - Cardiology',
      departments: _departments.where((d) => d.floor == 3).toList(),
      walls: _createWalls(),
      corridors: _createCorridors(),
    );
  }

  List<MapElement> _createWalls() {
    return [
      MapElement(
        id: 'wall_outer',
        type: MapElementType.wall,
        points: const [
          Offset(40, 160),
          Offset(760, 160),
          Offset(760, 580),
          Offset(40, 580),
          Offset(40, 160),
        ],
        color: AppColors.walls,
        strokeWidth: 2,
      ),
    ];
  }

  List<MapElement> _createCorridors() {
    return [
      MapElement(
        id: 'corridor_v',
        type: MapElementType.corridor,
        points: const [
          Offset(340, 230),
          Offset(460, 230),
          Offset(460, 580),
          Offset(340, 580),
        ],
        color: AppColors.corridor,
        isFilled: true,
      ),
      MapElement(
        id: 'corridor_h',
        type: MapElementType.corridor,
        points: const [
          Offset(40, 280),
          Offset(760, 280),
          Offset(760, 420),
          Offset(40, 420),
        ],
        color: AppColors.corridor,
        isFilled: true,
      ),
    ];
  }

  FloorMap getFloorMap(int floor) {
    if (!_initialized) {
      _initializeData();
      _initialized = true;
    }
    return _floorMaps[floor] ?? _floorMaps[1]!;
  }

  List<FloorMap> getAllFloorMaps() {
    if (!_initialized) {
      _initializeData();
      _initialized = true;
    }
    return _floorMaps.values.toList()
      ..sort((a, b) => a.floorNumber.compareTo(b.floorNumber));
  }

  List<Department> getAllDepartments() {
    if (!_initialized) {
      _initializeData();
      _initialized = true;
    }
    return List.unmodifiable(_departments);
  }

  Department? getDepartmentById(String id) {
    if (!_initialized) {
      _initializeData();
      _initialized = true;
    }
    try {
      return _departments.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }
}
