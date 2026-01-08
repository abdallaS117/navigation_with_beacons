class AppConstants {
  AppConstants._();

  // Map dimensions
  static const double mapWidth = 800.0;
  static const double mapHeight = 600.0;
  static const double minZoom = 0.5;
  static const double maxZoom = 3.0;
  static const double defaultZoom = 1.0;

  // Animation durations
  static const Duration arrowMovementDuration = Duration(milliseconds: 600);
  static const Duration routeDrawDuration = Duration(milliseconds: 1500);
  static const Duration floorTransitionDuration = Duration(milliseconds: 300);
  static const Duration beaconSimulationInterval = Duration(seconds: 3);

  // Route styling (thinner, calmer)
  static const double routeLineWidth = 4.0;
  static const double routeGlowWidth = 8.0;
  static const double routeDashLength = 10.0;
  static const double routeGapLength = 6.0;

  // User arrow (smaller, subtle)
  static const double arrowSize = 28.0;
  static const double arrowBorderWidth = 2.0;

  // Beacon detection
  static const double beaconDetectionRadius = 50.0;
  static const int beaconRssiThreshold = -70;

  // Floor numbers
  static const int floor1 = 1;
  static const int floor2 = 2;
  static const int floor3 = 3;

  // Department IDs
  static const String entranceId = 'entrance';
  static const String receptionId = 'reception';
  static const String radiologyId = 'radiology';
  static const String clinicsId = 'clinics';
  static const String labsId = 'labs';
  static const String heartDepartmentId = 'heart_department';
  static const String elevatorId = 'elevator';
  static const String stairsId = 'stairs';
}
