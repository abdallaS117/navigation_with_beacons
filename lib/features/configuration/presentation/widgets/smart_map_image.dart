import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Widget that displays map images from local files or Base64 encoded strings
class SmartMapImage extends StatelessWidget {
  final String? imagePath;
  final String? imageBase64;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SmartMapImage({
    super.key,
    this.imagePath,
    this.imageBase64,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    // Priority 1: Base64 encoded image (from Firestore)
    if (imageBase64 != null && imageBase64!.isNotEmpty) {
      return _buildBase64Image(imageBase64!);
    }

    // Priority 2: Local file path
    if (imagePath == null || imagePath!.isEmpty) {
      return _buildPlaceholder('No map image set', 'Pick an image to get started');
    }

    // Check if it's an asset path (either assets/ or packages/ prefix)
    if (imagePath!.startsWith('assets/') || imagePath!.startsWith('packages/')) {
      return _buildAssetImage(imagePath!);
    }

    // Display local file
    return _buildFileImage(imagePath!);
  }

  Widget _buildBase64Image(String base64String) {
    try {
      final Uint8List bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Error loading Base64 image: $error');
          return _buildPlaceholder('Failed to decode image', 'Image data may be corrupted');
        },
      );
    } catch (e) {
      debugPrint('❌ Error decoding Base64 image: $e');
      return _buildPlaceholder('Invalid image data', 'Failed to decode Base64');
    }
  }

  Widget _buildAssetImage(String path) {
    try {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading asset image: $error');
          return _buildPlaceholder('Failed to load asset image', 'Asset may not be registered in pubspec.yaml');
        },
      );
    } catch (e) {
      print('❌ Error creating asset image: $e');
      return _buildPlaceholder('Invalid asset path', 'Please check the asset path');
    }
  }

  Widget _buildFileImage(String path) {
    try {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading file image: $error');
          return _buildPlaceholder('Failed to load local image', 'File may have been moved or deleted');
        },
      );
    } catch (e) {
      print('❌ Error creating file image: $e');
      return _buildPlaceholder('Invalid file path', 'Please select a new image');
    }
  }

  Widget _buildPlaceholder(String title, String subtitle) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
