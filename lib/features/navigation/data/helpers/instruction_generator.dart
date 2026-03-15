import '../../domain/entities/beacon_node.dart';

/// Helper class for generating navigation instructions.
class InstructionGenerator {
  /// Generate navigation instructions from a path.
  static List<String> generateInstructions(List<BeaconNode> path) {
    final List<String> instructions = [];

    if (path.isEmpty) return instructions;

    instructions.add('Start at ${path.first.name}');

    for (int i = 1; i < path.length; i++) {
      final current = path[i];
      final prev = path[i - 1];

      if (current.floor != prev.floor) {
        if (current.departmentId == 'elevator') {
          instructions.add('Take elevator to Floor ${current.floor}');
        } else if (current.departmentId == 'stairs') {
          instructions.add('Take stairs to Floor ${current.floor}');
        } else {
          instructions.add('Go to Floor ${current.floor}');
        }
      } else {
        final direction = _getDirection(prev, current);
        instructions.add('$direction to ${current.name}');
      }
    }

    instructions.add('You have arrived at ${path.last.name}');
    return instructions;
  }

  /// Get direction text based on relative positions.
  static String _getDirection(BeaconNode from, BeaconNode to) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;

    if (dx.abs() > dy.abs()) {
      return dx > 0 ? 'Go right' : 'Go left';
    } else {
      return dy > 0 ? 'Go down' : 'Go up';
    }
  }
}
