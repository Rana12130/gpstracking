// lib/widgets/status_card.dart
import 'package:flutter/material.dart';
import '../providers/app_state.dart';

class StatusCard extends StatelessWidget {
  final AppState appState;

  const StatusCard({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  appState.isListening
                      ? Icons.mic
                      : (appState.scenarioActive
                      ? Icons.place
                      : Icons.location_searching),
                  color: appState.isListening
                      ? Colors.red
                      : Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appState.statusText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (appState.isListening)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
            if (appState.scenarioActive && appState.arrivalTime != null) ...[
              const SizedBox(height: 8),
              Text(
                "Arrived: ${appState.formatTime(appState.arrivalTime!)}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (appState.visitedPlaces.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Visited: ${appState.visitedPlaces.length} place(s)",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}