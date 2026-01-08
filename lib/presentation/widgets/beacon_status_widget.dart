import 'package:flutter/material.dart';
import '../../data/datasources/hybrid_beacon_datasource.dart';
import '../../core/constants/app_colors.dart';

class BeaconStatusWidget extends StatelessWidget {
  final Stream<BeaconStatus> statusStream;
  final bool isVisible;
  final VoidCallback onToggle;

  const BeaconStatusWidget({
    super.key,
    required this.statusStream,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status Panel (collapsible)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: isVisible
              ? StreamBuilder<BeaconStatus>(
                  stream: statusStream,
                  builder: (context, snapshot) {
                    final status = snapshot.data;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                status?.isScanning == true
                                    ? Icons.bluetooth_searching
                                    : Icons.bluetooth_disabled,
                                color: status?.isScanning == true
                                    ? Colors.blue
                                    : Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                status?.isScanning == true
                                    ? 'Scanning...'
                                    : 'Not Scanning',
                                style: TextStyle(
                                  color: status?.isScanning == true
                                      ? Colors.blue
                                      : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Location
                          if (status?.currentLocation != null) ...[
                            Text(
                              status!.currentLocation!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          
                          // Beacon A Status
                          _BeaconRow(
                            label: 'Beacon A (Reception)',
                            rssi: status?.beaconARssi,
                            distance: status?.distanceA,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 6),
                          
                          // Beacon B Status
                          _BeaconRow(
                            label: 'Beacon B (X-Ray)',
                            rssi: status?.beaconBRssi,
                            distance: status?.distanceB,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    );
                  },
                )
              : const SizedBox.shrink(),
        ),
        
        // Toggle Button
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isVisible ? Colors.black87 : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVisible ? Icons.bluetooth : Icons.bluetooth_outlined,
                  size: 14,
                  color: isVisible ? Colors.blue : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  isVisible ? 'Hide' : 'BLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isVisible ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BeaconRow extends StatelessWidget {
  final String label;
  final int? rssi;
  final double? distance;
  final Color color;

  const _BeaconRow({
    required this.label,
    required this.rssi,
    required this.distance,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDetected = rssi != null;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status indicator
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isDetected ? color : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        
        // Info
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDetected ? Colors.white70 : Colors.grey,
                fontSize: 10,
              ),
            ),
            if (isDetected)
              Text(
                'RSSI: $rssi dBm | ~${distance?.toStringAsFixed(1)}m',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              const Text(
                'Not detected',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
