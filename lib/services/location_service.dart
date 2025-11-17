// lib/services/location_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/app_state.dart';
import '../models/place_model.dart';
import '../constants/app_constants.dart';

class LocationService {
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  bool _isInitialized = false;
  AppState? _appState;

  Position? get currentPosition => _currentPosition;
  bool get isInitialized => _isInitialized;

  void init(AppState appState, BuildContext context) {
    _appState = appState;
    _initialize(context);
  }

  Future<void> _initialize(BuildContext context) async {
    try {
      _appState!.setStatusText("Requesting permissions...");

      // Request permissions
      final permissions = await [
        Permission.microphone,
        Permission.notification,
        Permission.locationAlways,
      ].request();

      // Check if all permissions are granted
      final bool allGranted = permissions.values.every(
            (status) => status == PermissionStatus.granted,
      );

      if (!allGranted) {
        _appState!.setStatusText("Some permissions were denied");
        _appState!.showPermissionDialog(context);
        return;
      }

      // Check location services
      final bool svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) {
        _appState!.setStatusText("Location services disabled");
        _appState!.showLocationServicesDialog(context);
        return;
      }

      // Check location permission specifically
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _appState!.setStatusText("Location permission denied forever");
        await Geolocator.openAppSettings();
        return;
      }

      _isInitialized = true;
      _appState!.setStatusText("Ready - Monitoring locations");
      _appState!.setInitialized(true);

      // Start location tracking
      await _checkInitialPosition();
      _startLocationStream();
    } catch (e) {
      _appState!.setStatusText("Error: ${e.toString()}");
      if (kDebugMode) print("Initialization error: $e");
    }
  }

  Future<void> _checkInitialPosition() async {
    try {
      final Position p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: AppConstants.locationTimeout,
      );

      _currentPosition = p;

      // Check if already inside any geofence
      for (final Place place in _appState!.places) {
        final double d = Geolocator.distanceBetween(
          p.latitude,
          p.longitude,
          place.coord.latitude,
          place.coord.longitude,
        );

        if (d <= AppConstants.radiusM && !_appState!.scenarioActive) {
          _enterGeofence(place);
          break;
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error getting initial position: $e");
      _appState!.setStatusText("Error getting location");
    }
  }

  void _startLocationStream() {
    _positionSubscription?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,  // Set to 0 for testing (every change triggers update)
      ),
    ).listen(
          (Position p) {
        _currentPosition = p;
        if (_isInitialized) {
          _appState!.setStatusText(_appState!.scenarioActive
              ? "At: ${_appState!.activePlace}"
              : "Monitoring locations");
        }

        // Check geofences
        _checkGeofences(p);
      },
      onError: (error) {
        if (kDebugMode) print("Location stream error: $error");
        _appState!.setStatusText("Location error");
      },
    );
  }

  void _checkGeofences(Position p) {
    bool insideAnyGeofence = false;

    for (final Place place in _appState!.places) {
      final double d = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        place.coord.latitude,
        place.coord.longitude,
      );
      if (kDebugMode) print("Distance to ${place.name}: ${d.toStringAsFixed(2)}m");  // Debug log

      if (d <= AppConstants.radiusM) {
        insideAnyGeofence = true;

        // Enter geofence if not already active
        if (!_appState!.scenarioActive || _appState!.activePlace != place.name) {
          _enterGeofence(place);
        }
        break;
      }
    }

    if (kDebugMode) print("Inside any geofence: $insideAnyGeofence | Scenario active: ${_appState!.scenarioActive}");  // Debug

    // Exit geofence if we were inside but now outside all geofences
    if (_appState!.scenarioActive && !insideAnyGeofence) {
      // Check with exit radius (slightly larger) to avoid flutter
      bool reallyOutside = true;
      for (final Place place in _appState!.places) {
        if (place.name == _appState!.activePlace) {
          final double d = Geolocator.distanceBetween(
            p.latitude,
            p.longitude,
            place.coord.latitude,
            place.coord.longitude,
          );
          if (kDebugMode) print("Exit check dist to ${place.name}: ${d.toStringAsFixed(2)}m");  // Debug
          if (d <= AppConstants.exitRadiusM) {
            reallyOutside = false;
            break;
          }
        }
      }

      if (reallyOutside) {
        if (kDebugMode) print("Triggering auto checkout!");  // Debug
        _exitGeofence();
      }
    }
  }

  void _enterGeofence(Place place) {
    _appState!.setScenarioActive(true);
    _appState!.setActivePlace(place.name);
    _appState!.setArrivalTime(DateTime.now());
    _appState!.setRetryCount(0);
    _appState!.triggerScenario(place);
  }

  void _exitGeofence() {
    if (_appState!.scenarioActive && _appState!.arrivalTime != null) {
      final Duration duration = DateTime.now().difference(_appState!.arrivalTime!);
      _appState!.notificationService.showNotification(
        "Auto Checkout: ${_appState!.activePlace}",
        "You have checked out from ${_appState!.activePlace}. Stayed for ${duration.inMinutes} minutes.",
      );
      _appState!.speechService.speak("Checked out from ${_appState!.activePlace}. Goodbye!");
    }

    _appState!.setScenarioActive(false);
    _appState!.setActivePlace(null);
    _appState!.setArrivalTime(null);
    _appState!.speechService.cancelRepeatTimer();
    _appState!.setRetryCount(0);

    _appState!.setStatusText("Monitoring locations");
  }

  void exitGeofence() {
    _exitGeofence();
  }

  Future<void> checkAndRestartLocation() async {
    final bool svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) {
      _appState!.setStatusText("Location services disabled");
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      _appState!.setStatusText("Location permission denied forever");
      await Geolocator.openAppSettings();
      return;
    }

    // ab sab ok hai to dialog band ho chuka hoga aur location monitoring resume
    _appState!.setStatusText("Monitoring locations");
    await _checkInitialPosition();
    _startLocationStream();
  }

  void dispose() {
    _positionSubscription?.cancel();
  }
}
