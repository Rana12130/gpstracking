// lib/widgets/control_buttons.dart
import 'package:flutter/material.dart';
import '../providers/app_state.dart';
class ControlButtons extends StatelessWidget {
  final AppState appState;
  const ControlButtons({super.key, required this.appState});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // My Location Button
        FloatingActionButton(
          mini: true,
          heroTag: "location",
          onPressed: appState.centerOnCurrentLocation,
          backgroundColor: Colors.white,
          child: const Icon(
            Icons.my_location,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        // Info Button
        FloatingActionButton(
          mini: true,
          heroTag: "info",
          onPressed: () => appState.showInfoDialog(context),
          backgroundColor: Colors.white,
          child: const Icon(
            Icons.info_outline,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}