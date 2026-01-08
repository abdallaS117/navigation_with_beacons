import 'package:flutter/material.dart';
import '../../domain/entities/department.dart';
import '../../core/constants/app_colors.dart';

class DestinationSelector extends StatelessWidget {
  final List<Department> departments;
  final Department? selectedDepartment;
  final Function(Department) onDepartmentSelected;

  const DestinationSelector({
    super.key,
    required this.departments,
    required this.onDepartmentSelected,
    this.selectedDepartment,
  });

  @override
  Widget build(BuildContext context) {
    // Group departments by floor
    final Map<int, List<Department>> departmentsByFloor = {};
    for (final dept in departments) {
      departmentsByFloor.putIfAbsent(dept.floor, () => []).add(dept);
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Icon(Icons.location_on, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Select Destination',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Department list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: departmentsByFloor.length,
              itemBuilder: (context, index) {
                final floor = departmentsByFloor.keys.toList()[index];
                final floorDepartments = departmentsByFloor[floor]!;
                
                return _FloorSection(
                  floor: floor,
                  departments: floorDepartments,
                  selectedDepartment: selectedDepartment,
                  onDepartmentSelected: onDepartmentSelected,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FloorSection extends StatelessWidget {
  final int floor;
  final List<Department> departments;
  final Department? selectedDepartment;
  final Function(Department) onDepartmentSelected;

  const _FloorSection({
    required this.floor,
    required this.departments,
    required this.onDepartmentSelected,
    this.selectedDepartment,
  });

  String get floorName {
    switch (floor) {
      case 1:
        return 'Ground Floor';
      case 2:
        return 'First Floor';
      case 3:
        return 'Second Floor';
      default:
        return 'Floor $floor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            floorName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...departments.map((dept) => _DepartmentTile(
              department: dept,
              isSelected: dept.id == selectedDepartment?.id,
              onTap: () => onDepartmentSelected(dept),
            )),
        const Divider(height: 1),
      ],
    );
  }
}

class _DepartmentTile extends StatelessWidget {
  final Department department;
  final bool isSelected;
  final VoidCallback onTap;

  const _DepartmentTile({
    required this.department,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: department.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          department.icon,
          color: department.color,
          size: 24,
        ),
      ),
      title: Text(
        department.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      subtitle: department.description != null
          ? Text(
              department.description!,
              style: const TextStyle(fontSize: 12),
            )
          : null,
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.1),
      onTap: onTap,
    );
  }
}
