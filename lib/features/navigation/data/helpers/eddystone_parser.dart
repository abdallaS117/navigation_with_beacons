import 'package:flutter/foundation.dart';

/// Helper class for parsing Eddystone beacon data.
class EddystoneParser {
  /// Parse Eddystone beacon data and return beacon ID if valid.
  static String? parseEddystoneData(List<int> data) {
    if (data.isEmpty) return null;

    final frameType = data[0];
    debugPrint('🔎 Eddystone frame type: 0x${frameType.toRadixString(16).padLeft(2, '0')}');

    // Eddystone-UID frame (0x00)
    if (frameType == 0x00 && data.length >= 18) {
      return _parseEddystoneUid(data);
    }
    // Eddystone-URL frame (0x10)
    else if (frameType == 0x10 && data.length >= 4) {
      return _parseEddystoneUrl(data);
    }
    // Eddystone-EID frame (0x30)
    else if (frameType == 0x30 && data.length >= 10) {
      return _parseEddystoneEid(data);
    }

    return null;
  }

  /// Parse Eddystone-UID frame.
  static String _parseEddystoneUid(List<int> data) {
    final namespace = data.sublist(2, 12).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    final instance = data.sublist(12, 18).map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

    final beaconId = 'beacon_${namespace}${instance}_0_0';
    debugPrint('🔍 Scanned Eddystone-UID: Namespace=$namespace, Instance=$instance → beaconId=$beaconId');
    return beaconId;
  }

  /// Parse Eddystone-URL frame.
  static String _parseEddystoneUrl(List<int> data) {
    final urlScheme = _getEddystoneUrlScheme(data[2]);
    final urlBytes = data.sublist(3);
    final url = urlScheme + String.fromCharCodes(urlBytes);
    final urlHash = url.hashCode.toRadixString(16).padLeft(8, '0');

    final beaconId = 'beacon_eddystone_url_$urlHash';
    debugPrint('🔍 Scanned Eddystone-URL: URL=$url → beaconId=$beaconId');
    return beaconId;
  }

  /// Parse Eddystone-EID frame.
  static String _parseEddystoneEid(List<int> data) {
    final eid = data.sublist(2, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final beaconId = 'beacon_eddystone_eid_$eid';
    debugPrint('🔍 Scanned Eddystone-EID: EID=$eid → beaconId=$beaconId');
    return beaconId;
  }

  /// Get URL scheme prefix for Eddystone-URL.
  static String _getEddystoneUrlScheme(int schemeByte) {
    switch (schemeByte) {
      case 0x00:
        return 'http://www.';
      case 0x01:
        return 'https://www.';
      case 0x02:
        return 'http://';
      case 0x03:
        return 'https://';
      default:
        return '';
    }
  }

  /// Extract UUID from bytes.
  static String extractUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
