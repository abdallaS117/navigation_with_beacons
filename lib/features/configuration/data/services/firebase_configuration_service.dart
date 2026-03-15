import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/navigation_config.dart';
import '../../domain/models/map_layout_config.dart';

/// Service for storing and retrieving navigation configuration from Firebase Firestore
class FirebaseConfigurationService {
  final FirebaseFirestore _firestore;
  final String collectionName;
  final String documentId;

  FirebaseConfigurationService({
    FirebaseFirestore? firestore,
    this.collectionName = 'navigation_configs',
    this.documentId = 'default_config',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Upload configuration to Firestore
  /// Returns true if successful, false otherwise
  /// Encodes local floor images to Base64 before uploading
  Future<bool> uploadConfiguration(NavigationConfig config) async {
    try {
      // Encode floor images to Base64 before uploading
      final configWithEncodedImages = await _encodeFloorImages(config);
      
      final data = configWithEncodedImages.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['version'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection(collectionName)
          .doc(documentId)
          .set(data, SetOptions(merge: true));

      debugPrint('✅ Configuration uploaded to Firestore successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error uploading configuration to Firestore: $e');
      return false;
    }
  }

  /// Encode local floor images to Base64 for Firestore storage
  Future<NavigationConfig> _encodeFloorImages(NavigationConfig config) async {
    final floors = <FloorConfig>[];
    
    for (final floor in config.mapConfig.floors) {
      // If there's a local file path, encode it to Base64
      if (floor.imagePath != null && 
          floor.imagePath!.isNotEmpty &&
          !floor.imagePath!.startsWith('assets/') &&
          !floor.imagePath!.startsWith('packages/')) {
        try {
          final file = File(floor.imagePath!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final base64String = base64Encode(bytes);
            
            // Check size (Firestore doc limit is ~1MB, Base64 adds ~33% overhead)
            final sizeKB = base64String.length / 1024;
            if (sizeKB > 900) {
              debugPrint('⚠️ Floor ${floor.floorNumber} image is too large (${sizeKB.toStringAsFixed(0)}KB). Consider compressing.');
            }
            
            debugPrint('📷 Encoded floor ${floor.floorNumber} image to Base64 (${sizeKB.toStringAsFixed(0)}KB)');
            
            floors.add(FloorConfig(
              floorNumber: floor.floorNumber,
              name: floor.name,
              imagePath: null, // Clear local path for remote storage
              imageBase64: base64String,
              isActive: floor.isActive,
            ));
            continue;
          }
        } catch (e) {
          debugPrint('⚠️ Failed to encode floor ${floor.floorNumber} image: $e');
        }
      }
      
      // Keep existing floor config (may already have imageBase64)
      floors.add(floor);
    }
    
    final updatedMapConfig = config.mapConfig.copyWith(floors: floors);
    return config.copyWith(mapConfig: updatedMapConfig);
  }

  /// Download configuration from Firestore
  /// Returns null if not found or error occurs
  Future<NavigationConfig?> downloadConfiguration() async {
    try {
      final docSnapshot = await _firestore
          .collection(collectionName)
          .doc(documentId)
          .get();

      if (!docSnapshot.exists) {
        print('⚠️ No configuration found in Firestore');
        return null;
      }

      final data = docSnapshot.data();
      if (data == null) {
        print('⚠️ Configuration data is null');
        return null;
      }

      // Remove Firestore-specific fields before parsing
      data.remove('updatedAt');
      data.remove('version');

      final config = NavigationConfig.fromJson(data);
      print('✅ Configuration downloaded from Firestore successfully');
      print('   Beacons: ${config.beacons.length}');
      print('   Nodes: ${config.nodes.length}');
      print('   Routes: ${config.routes.length}');

      return config;
    } catch (e) {
      print('❌ Error downloading configuration from Firestore: $e');
      return null;
    }
  }

  /// Stream configuration changes from Firestore
  /// Useful for real-time updates
  Stream<NavigationConfig?> streamConfiguration() {
    return _firestore
        .collection(collectionName)
        .doc(documentId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      try {
        final data = Map<String, dynamic>.from(snapshot.data()!);
        data.remove('updatedAt');
        data.remove('version');
        return NavigationConfig.fromJson(data);
      } catch (e) {
        print('❌ Error parsing configuration stream: $e');
        return null;
      }
    });
  }

  /// Delete configuration from Firestore
  Future<bool> deleteConfiguration() async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(documentId)
          .delete();

      print('✅ Configuration deleted from Firestore');
      return true;
    } catch (e) {
      print('❌ Error deleting configuration from Firestore: $e');
      return false;
    }
  }

  /// Check if configuration exists in Firestore
  Future<bool> configurationExists() async {
    try {
      final docSnapshot = await _firestore
          .collection(collectionName)
          .doc(documentId)
          .get();

      return docSnapshot.exists;
    } catch (e) {
      print('❌ Error checking configuration existence: $e');
      return false;
    }
  }

  /// Get last update timestamp
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final docSnapshot = await _firestore
          .collection(collectionName)
          .doc(documentId)
          .get();

      if (!docSnapshot.exists) {
        return null;
      }

      final data = docSnapshot.data();
      final timestamp = data?['updatedAt'] as Timestamp?;
      return timestamp?.toDate();
    } catch (e) {
      print('❌ Error getting last update time: $e');
      return null;
    }
  }
}
