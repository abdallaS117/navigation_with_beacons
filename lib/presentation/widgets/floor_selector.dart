import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class FloorSelector extends StatelessWidget {
  final int currentFloor;
  final List<int> floors;
  final Function(int) onFloorSelected;
  final List<int>? highlightedFloors;

  const FloorSelector({
    super.key,
    required this.currentFloor,
    required this.floors,
    required this.onFloorSelected,
    this.highlightedFloors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: floors.reversed.map((floor) {
          final isSelected = floor == currentFloor;
          final isHighlighted = highlightedFloors?.contains(floor) ?? false;

          return _FloorButton(
            floor: floor,
            isSelected: isSelected,
            isHighlighted: isHighlighted,
            onTap: () => onFloorSelected(floor),
            isFirst: floor == floors.last,
            isLast: floor == floors.first,
          );
        }).toList(),
      ),
    );
  }
}

class _FloorButton extends StatelessWidget {
  final int floor;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _FloorButton({
    required this.floor,
    required this.isSelected,
    required this.isHighlighted,
    required this.onTap,
    required this.isFirst,
    required this.isLast,
  });

  String get floorLabel {
    switch (floor) {
      case 1:
        return 'G';
      case 2:
        return '1';
      case 3:
        return '2';
      default:
        return floor.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(8) : Radius.zero,
          bottom: isLast ? const Radius.circular(8) : Radius.zero,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.floorSelected
                : AppColors.floorUnselected,
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(8) : Radius.zero,
              bottom: isLast ? const Radius.circular(8) : Radius.zero,
            ),
            border: !isFirst
                ? Border(
                    top: BorderSide(
                      color: Colors.grey.withAlpha(40),
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                floorLabel,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isHighlighted && !isSelected)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.routeLine,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
