import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/navigation_config.dart';

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
  Future<bool> uploadConfiguration(NavigationConfig config) async {
    try {
      final data = config.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['version'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection(collectionName)
          .doc(documentId)
          .set(data, SetOptions(merge: true));

      print('✅ Configuration uploaded to Firestore successfully');
      return true;
    } catch (e) {
      print('❌ Error uploading configuration to Firestore: $e');
      return false;
    }
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
