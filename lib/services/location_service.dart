import 'package:geolocator/geolocator.dart';

class LocationState {
  final bool isPermissionGranted;
  final bool isServiceEnabled;
  final Position? currentPosition;
  final double? distanceMeters;
  final bool isInRange;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? enteredGeofenceAt;
  final bool autoCheckedIn;

  const LocationState({
    this.isPermissionGranted = false,
    this.isServiceEnabled = true,
    this.currentPosition,
    this.distanceMeters,
    this.isInRange = false,
    this.isLoading = false,
    this.errorMessage,
    this.enteredGeofenceAt,
    this.autoCheckedIn = false,
  });

  LocationState copyWith({
    bool? isPermissionGranted,
    bool? isServiceEnabled,
    Position? currentPosition,
    double? distanceMeters,
    bool? isInRange,
    bool? isLoading,
    String? errorMessage,
    DateTime? enteredGeofenceAt,
    bool? autoCheckedIn,
    bool clearError = false,
  }) {
    return LocationState(
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      currentPosition: currentPosition ?? this.currentPosition,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      isInRange: isInRange ?? this.isInRange,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      enteredGeofenceAt: enteredGeofenceAt ?? this.enteredGeofenceAt,
      autoCheckedIn: autoCheckedIn ?? this.autoCheckedIn,
    );
  }
}

class LocationService {
  // พิกัดหลัก: Kita Stan Tea สาขาสุราษฎร์ธานี (คิตะ ทีสแตนด์ สุราษฎร์ธานี)
  static const double targetLatitude = 9.1382;
  static const double targetLongitude = 99.3216;
  static const String targetStoreName = 'Kita Stan Tea สาขาสุราษฎร์ธานี';
  static const double geofenceRadiusMeters = 300.0;
  static const int autoCheckInDurationSeconds = 300; // 5 นาที (300 วินาที)

  static double calculateDistance(double startLat, double startLng, {double? targetLat, double? targetLng}) {
    return Geolocator.distanceBetween(
      startLat,
      startLng,
      targetLat ?? targetLatitude,
      targetLng ?? targetLongitude,
    );
  }

  static bool isWithinRadius(double distanceMeters, {double radius = geofenceRadiusMeters}) {
    return distanceMeters <= radius;
  }
}
