import 'package:flutter/material.dart';
import '../../domain/entities/navigation_route.dart';
import '../../domain/entities/department.dart';
import '../../core/constants/app_colors.dart';

class NavigationInfoPanel extends StatefulWidget {
  final NavigationRoute route;
  final Department destination;
  final int currentInstructionIndex;
  final VoidCallback onCancel;
  final bool hasArrived;

  const NavigationInfoPanel({
    super.key,
    required this.route,
    required this.destination,
    required this.currentInstructionIndex,
    required this.onCancel,
    this.hasArrived = false,
  });

  @override
  State<NavigationInfoPanel> createState() => _NavigationInfoPanelState();
}

class _NavigationInfoPanelState extends State<NavigationInfoPanel> {
  bool _isExpanded = false;

  String _formatTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = (seconds / 60).ceil();
    return '${minutes}min';
  }

  IconData get _currentDirectionIcon {
    if (widget.route.instructions.isEmpty ||
        widget.currentInstructionIndex >= widget.route.instructions.length) {
      return Icons.arrow_upward;
    }
    final instruction =
        widget.route.instructions[widget.currentInstructionIndex].toLowerCase();
    if (instruction.contains('left')) return Icons.turn_left;
    if (instruction.contains('right')) return Icons.turn_right;
    if (instruction.contains('elevator')) return Icons.elevator;
    if (instruction.contains('stairs')) return Icons.stairs;
    if (instruction.contains('arrived')) return Icons.flag;
    return Icons.arrow_upward;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasArrived) {
      return _ArrivedPanel(
          destination: widget.destination, onDismiss: widget.onCancel);
    }

    final currentInstruction = widget.route.instructions.isNotEmpty &&
            widget.currentInstructionIndex < widget.route.instructions.length
        ? widget.route.instructions[widget.currentInstructionIndex]
        : 'Follow the route';

    // Compact navigation bar
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expandable details panel
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _isExpanded
                ? Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _CompactStat(
                              icon: Icons.straighten,
                              value:
                                  '${widget.route.totalDistance.toStringAsFixed(0)}m',
                            ),
                            _CompactStat(
                              icon: Icons.timer,
                              value: _formatTime(
                                  widget.route.estimatedTimeSeconds),
                            ),
                            _CompactStat(
                              icon: Icons.layers,
                              value: '${widget.route.floorsInRoute.length} fl',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        _ProgressBar(
                          progress: (widget.currentInstructionIndex + 1) /
                              widget.route.instructions.length,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Main compact instruction bar
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Direction icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _currentDirectionIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Instruction text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentInstruction,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.destination.name} • ${widget.route.totalDistance.toStringAsFixed(0)}m',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand/collapse indicator
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  // Cancel button
                  GestureDetector(
                    onTap: widget.onCancel,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _CompactStat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final String instruction;
  final int stepNumber;
  final int totalSteps;

  const _InstructionCard({
    required this.instruction,
    required this.stepNumber,
    required this.totalSteps,
  });

  IconData get _directionIcon {
    final lower = instruction.toLowerCase();
    if (lower.contains('left')) return Icons.turn_left;
    if (lower.contains('right')) return Icons.turn_right;
    if (lower.contains('elevator')) return Icons.elevator;
    if (lower.contains('stairs')) return Icons.stairs;
    if (lower.contains('arrived')) return Icons.flag;
    return Icons.arrow_upward;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.routeLine.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _directionIcon,
              color: AppColors.routeLine,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step $stepNumber of $totalSteps',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  instruction,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.routeLine,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ArrivedPanel extends StatelessWidget {
  final Department destination;
  final VoidCallback onDismiss;

  const _ArrivedPanel({
    required this.destination,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.entrance,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.entrance.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You have arrived!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  destination.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onDismiss,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.entrance,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
