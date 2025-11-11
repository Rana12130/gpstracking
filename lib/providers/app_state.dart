// lib/providers/app_state.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place_model.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/speech_service.dart';

class AppState extends ChangeNotifier {
  // Services
  late final LocationService locationService;
  late final NotificationService notificationService;
  late final SpeechService speechService;

  // State
  String? _activePlace;
  bool _scenarioActive = false;
  Set<String> _visitedPlaces = <String>{};
  DateTime? _arrivalTime;
  int _retryCount = 0;
  String _statusText = "Initializing...";
  GoogleMapController? _mapController;
  bool _listening = false;
  bool _isInitialized = false;
  bool mounted = true;

  final List<Place> places = const [
    Place(
      name: "Ivy Interactive Solutions",
      coord: LatLng(33.65836654198089, 73.05812932276187),
      description: "Technology company",
      type: "office",
    ),
    Place(
      name: "Suzuki Islamabad Motors",
      coord: LatLng(33.65764363433742, 73.05687793711189),
      description: "Automotive dealership",
      type: "business",
    ),
    Place(
      name: "Dhamial",
      coord: LatLng(33.577003, 73.031317),
      description: "Local area",
      type: "area",
    ),
  ];

  // Getters
  String? get activePlace => _activePlace;
  bool get scenarioActive => _scenarioActive;
  Set<String> get visitedPlaces => _visitedPlaces;
  DateTime? get arrivalTime => _arrivalTime;
  String get statusText => _statusText;
  GoogleMapController? get mapController => _mapController;
  bool get isListening => _listening;
  bool get isInitialized => _isInitialized;
  Position? get currentPosition => locationService.currentPosition;

  AppState() {
    locationService = LocationService();
    notificationService = NotificationService();
    speechService = SpeechService();
  }

  void initServices(BuildContext context) async {
    await notificationService.init();
    await speechService.init(this);
    locationService.init(this, context);
  }

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    notifyListeners();
  }

  void setStatusText(String text) {
    _statusText = text;
    notifyListeners();
  }

  void setScenarioActive(bool active) {
    _scenarioActive = active;
    notifyListeners();
  }

  void setActivePlace(String? place) {
    _activePlace = place;
    notifyListeners();
  }

  void setArrivalTime(DateTime? time) {
    _arrivalTime = time;
    notifyListeners();
  }

  void setRetryCount(int count) {
    _retryCount = count;
    notifyListeners();
  }

  void addVisitedPlace(String place) {
    _visitedPlaces.add(place);
    notifyListeners();
  }

  void setListening(bool listening) {
    _listening = listening;
    notifyListeners();
  }

  void setInitialized(bool initialized) {
    _isInitialized = initialized;
    notifyListeners();
  }

  void triggerScenario(Place place) async {
    final name = place.name;
    final description = place.description;

    await notificationService.showNotification(
      "📍 Arrived at $name",
      description.isNotEmpty ? description : "Say 'Enter' to confirm or 'Exit' to cancel",
    );

    // Wait for TTS to fully complete before starting mic
    await speechService.speak("You arrived at $name. $description");
    // No additional delay needed as speak() awaits completion

    await speechService.startMicLoop(place, this);
  }

  void centerOnCurrentLocation() {
    final position = locationService.currentPosition;
    if (position != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 17,
          ),
        ),
      );
    }
  }

  Color getPlaceColor(String type) {
    switch (type) {
      case 'office':
        return Colors.blue;
      case 'business':
        return Colors.green;
      case 'area':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  void showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Permissions Required"),
          content: const Text(
            "This app needs location and microphone permissions to work properly. "
                "Please grant all permissions in settings.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text("Open Settings"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                locationService.init(this, context); // Retry
              },
              child: const Text("Retry"),
            ),
          ],
        );
      },
    );
  }

  void showLocationServicesDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Location Services Disabled"),
          content: const Text(
            "Location services are disabled. Please enable them to use this app.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openLocationSettings();
              },
              child: const Text("Open Settings"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                locationService.init(this, context); // Retry
              },
              child: const Text("Retry"),
            ),
          ],
        );
      },
    );
  }

  void showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("How to Use"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This app monitors your location and provides voice assistance when you arrive at registered places.\n"),
            const Text("📍 Red markers: Not visited"),
            const Text("📍 Green markers: Visited"),
            const SizedBox(height: 8),
            const Text("\nVoice Commands:"),
            const Text("• Say 'Enter' to confirm arrival"),
            const Text("• Say 'Exit' to stop voice commands"),
            const SizedBox(height: 8),
            Text(
              "\nVisited Places: ${_visitedPlaces.length}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    locationService.dispose();
    speechService.dispose();
    super.dispose();
  }
}