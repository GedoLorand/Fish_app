import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:login_fish_app/services/filter_bus.dart';

class RouteHelper {
  /// Extracts coordinates from the image doc and publishes a `routeTo` event
  /// via `FilterBus`. Closes the provided context (dialog) when a route was
  /// requested.
  static void requestRouteFromDoc(BuildContext ctx, Map<String, dynamic>? doc) {
    try {
      if (doc == null) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text('no_location')));
        return;
      }

      double? lat;
      double? lng;
      if (doc.containsKey('point') && doc['point'] is LatLng) {
        final p = doc['point'] as LatLng;
        lat = p.latitude;
        lng = p.longitude;
      } else if (doc.containsKey('location')) {
        final loc = doc['location'];
        try {
          // Firestore GeoPoint-like
          lat = (loc.latitude as double);
          lng = (loc.longitude as double);
        } catch (_) {
          try {
            // Map with lat/lng
            lat = (loc['lat'] as num?)?.toDouble();
            lng = (loc['lng'] as num?)?.toDouble();
          } catch (_) {}
        }
      }

      if (lat == null || lng == null) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text('no_location')));
        return;
      }

      // publish route request
      FilterBus.instance.publish({
        'routeTo': {'lat': lat, 'lng': lng},
      });

      // close dialog if still open
      try {
        Navigator.of(ctx).pop();
      } catch (_) {}
    } catch (e) {
      try {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text('error_occurred: $e')));
      } catch (_) {}
    }
  }
}
