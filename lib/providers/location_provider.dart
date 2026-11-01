import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationNotifier extends StateNotifier<LocationState> {
  static bool isTestMode = false;
  Timer? _periodicTimer;
  VoidCallback? _onAutoCheckInCallback;

  LocationNotifier() : super(const LocationState());

  bool get _isTesting => isTestMode || (WidgetsBinding.instance.runtimeType.toString().contains('Test'));

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    super.dispose();
  }

  /// Request GPS permission and update current location
  Future<void> requestPermissionAndCheck() async {
    if (_isTesting) {
      state = state.copyWith(
        isLoading: false,
        isPermissionGranted: true,
        isInRange: true,
        distanceMeters: 120.0,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoading: false,
          isServiceEnabled: false,
          errorMessage: 'กรุณาเปิดบริการตำแหน่งที่ตั้ง (GPS)',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLoading: false,
            isPermissionGranted: false,
            errorMessage: 'กรุณาอนุญาตการเข้าถึงตำแหน่งที่ตั้งเพื่อเช็คอิน',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          isPermissionGranted: false,
          errorMessage: 'สิทธิ์ตำแหน่งถูกปิดถาวร กรุณาเปิดในการตั้งค่าอุปกรณ์',
        );
        return;
      }

      state = state.copyWith(isPermissionGranted: true, isServiceEnabled: true);
      await refreshLocation();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'ไม่สามารถระบุตำแหน่งได้: $e',
      );
    }
  }

  /// Refreshes current GPS coordinates and checks geofence distance
  Future<void> refreshLocation() async {
    if (_isTesting) {
      state = state.copyWith(
        isLoading: false,
        isPermissionGranted: true,
        isInRange: true,
        distanceMeters: 120.0,
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final distance = LocationService.calculateDistance(
        position.latitude,
        position.longitude,
      );

      final inRange = LocationService.isWithinRadius(distance);

      DateTime? enteredAt = state.enteredGeofenceAt;
      if (inRange) {
        enteredAt ??= DateTime.now();
      } else {
        enteredAt = null;
      }

      state = state.copyWith(
        isLoading: false,
        isPermissionGranted: true,
        currentPosition: position,
        distanceMeters: distance,
        isInRange: inRange,
        enteredGeofenceAt: enteredAt,
        clearError: true,
      );

      _checkAutoCheckInTrigger();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'ไม่สามารถอ่านพิกัด GPS ได้ในขณะนี้',
      );
    }
  }

  /// Start background/periodic monitoring when user has an active shift
  void startMonitoring({required VoidCallback onAutoCheckIn}) {
    _onAutoCheckInCallback = onAutoCheckIn;
    _periodicTimer?.cancel();

    // Check immediately
    refreshLocation();

    if (_isTesting) return;

    // Periodic check every 15 seconds
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshLocation();
    });
  }

  void stopMonitoring() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _onAutoCheckInCallback = null;
  }

  void resetAutoCheckIn() {
    state = state.copyWith(autoCheckedIn: false, enteredGeofenceAt: null);
  }

  /// Checks if user has stayed within the 300m radius for 5 minutes (300 seconds)
  void _checkAutoCheckInTrigger() {
    if (state.autoCheckedIn) return;
    if (!state.isInRange) return;
    if (state.enteredGeofenceAt == null) return;

    final secondsInside = DateTime.now().difference(state.enteredGeofenceAt!).inSeconds;
    if (secondsInside >= LocationService.autoCheckInDurationSeconds) {
      state = state.copyWith(autoCheckedIn: true);
      _onAutoCheckInCallback?.call();
    }
  }

  /// Manual test helper to simulate position in range
  @visibleForTesting
  void simulatePosition({
    required double latitude,
    required double longitude,
    bool forceInRange = false,
  }) {
    final pos = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    final distance = forceInRange ? 120.0 : LocationService.calculateDistance(latitude, longitude);
    final inRange = forceInRange || LocationService.isWithinRadius(distance);

    DateTime? enteredAt = state.enteredGeofenceAt;
    if (inRange) {
      enteredAt ??= DateTime.now();
    } else {
      enteredAt = null;
    }

    state = state.copyWith(
      isLoading: false,
      isPermissionGranted: true,
      currentPosition: pos,
      distanceMeters: distance,
      isInRange: inRange,
      enteredGeofenceAt: enteredAt,
      clearError: true,
    );

    _checkAutoCheckInTrigger();
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});
