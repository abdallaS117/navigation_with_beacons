import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF4A90D9);
  static const Color primaryDark = Color(0xFF3A7BC0);
  static const Color primaryLight = Color(0xFFD6E9FA);

  // Background colors (AutoCAD-style)
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color mapBackground = Color(0xFFFCFCFC);

  // Floor plan colors (AutoCAD blueprint style)
  static const Color floorFill = Color(0xFFF8F9FA);
  static const Color walls = Color(0xFF37474F);
  static const Color wallsLight = Color(0xFF78909C);
  static const Color corridor = Color(0xFFF5F5F5);
  static const Color doorOpening = Color(0xFFFCFCFC);

  // Room fills (very subtle tints)
  static const Color entrance = Color(0xFFE8F5E9);
  static const Color reception = Color(0xFFE3F2FD);
  static const Color radiology = Color(0xFFF3E5F5);
  static const Color clinics = Color(0xFFFFF3E0);
  static const Color labs = Color(0xFFE0F7FA);
  static const Color heartDepartment = Color(0xFFFCE4EC);
  static const Color elevator = Color(0xFFECEFF1);
  static const Color stairs = Color(0xFFEFEBE9);
  static const Color restroom = Color(0xFFF5F5F5);
  static const Color pharmacy = Color(0xFFF1F8E9);
  static const Color emergency = Color(0xFFFFEBEE);
  static const Color waitingArea = Color(0xFFFFFDE7);

  // Route colors
  static const Color routeLine = Color(0xFF1E88E5);
  static const Color routeLineGlow = Color(0x301E88E5);
  static const Color routeCompleted = Color(0xFF43A047);
  static const Color routePending = Color(0xFFE0E0E0);

  // User arrow
  static const Color userArrow = Color(0xFF1E88E5);
  static const Color userArrowBorder = Color(0xFF1565C0);

  // Destination marker
  static const Color destination = Color(0xFFE53935);
  static const Color destinationGlow = Color(0x20E53935);

  // Floor selector
  static const Color floorSelected = Color(0xFF4A90D9);
  static const Color floorUnselected = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFF37474F);
  static const Color textSecondary = Color(0xFF78909C);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color roomLabel = Color(0xFF546E7A);
}
