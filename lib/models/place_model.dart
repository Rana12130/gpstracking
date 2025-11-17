// lib/models/place_model.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Place {
  final String name;
  final LatLng coord;
  final String description;
  final String type;

  const Place({
    required this.name,
    required this.coord,
    required this.description,
    required this.type,
  });

  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      name: map['name'] as String,
      coord: map['coord'] as LatLng,
      description: map['description'] as String,
      type: map['type'] as String,
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'coord': coord,
      'description': description,
      'type': type,
    };
  }
}
