import 'dart:io';
import 'package:flutter/material.dart';

/// Widget that displays map images from local files only
class SmartMapImage extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SmartMapImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return _buildPlaceholder('No map image set', 'Pick an image to get started');
    }

    // Display local file
    return _buildFileImage(imagePath!);
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
