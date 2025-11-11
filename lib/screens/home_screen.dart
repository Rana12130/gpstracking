// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../constants/app_constants.dart';
import '../models/place_model.dart';
import '../widgets/status_card.dart';
import '../widgets/control_buttons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.mounted = true;
      appState.initServices(context);
    });
  }

  @override
  void dispose() {
    Provider.of<AppState>(context, listen: false).mounted = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // agar koi dialog open hai to usay band kar do
      if (Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
      // phir dobara permission check aur restart karo
      Provider.of<AppState>(context, listen: false).locationService.checkAndRestartLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.statusText.contains("denied") || appState.statusText.contains("disabled")) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (appState.statusText.contains("disabled")) {
              appState.showLocationServicesDialog(context);
            } else {
              appState.showPermissionDialog(context);
            }
          });
        }

        final LatLng initialPos = appState.currentPosition == null
            ? appState.places.first.coord
            : LatLng(appState.currentPosition!.latitude, appState.currentPosition!.longitude);

        return Scaffold(
          appBar: AppBar(
            title: const Text("Location Voice Assistant"),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          body: Stack(
            children: [
              // Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialPos,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  appState.setMapController(controller);
                  // Apply custom map style if needed
                  controller.setMapStyle('''
                    [
                      {
                        "featureType": "poi.business",
                        "stylers": [{"visibility": "off"}]
                      }
                    ]
                  ''');
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false, // Custom button instead
                compassEnabled: true,
                mapToolbarEnabled: false,
                zoomControlsEnabled: false,
                markers: {
                  // Place markers
                  for (final Place place in appState.places)
                    Marker(
                      markerId: MarkerId(place.name),
                      position: place.coord,
                      infoWindow: InfoWindow(
                        title: place.name,
                        snippet: place.description,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        appState.visitedPlaces.contains(place.name)
                            ? BitmapDescriptor.hueGreen
                            : BitmapDescriptor.hueRed,
                      ),
                    ),
                },
                circles: {
                  // Geofence circles
                  for (final Place place in appState.places)
                    Circle(
                      circleId: CircleId(place.name),
                      center: place.coord,
                      radius: AppConstants.radiusM,
                      fillColor: appState.getPlaceColor(place.type).withOpacity(
                        appState.activePlace == place.name ? 0.4 : 0.2,
                      ),
                      strokeColor: appState.getPlaceColor(place.type),
                      strokeWidth: appState.activePlace == place.name ? 3 : 2,
                    ),
                },
                polylines: const <Polyline>{}, // Can add routes later
              ),

              // Status Card
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: StatusCard(appState: appState),
              ),

              // Control Buttons
              Positioned(
                bottom: 20,
                right: 20,
                child: ControlButtons(appState: appState),
              ),
            ],
          ),
        );
      },
    );
  }
}