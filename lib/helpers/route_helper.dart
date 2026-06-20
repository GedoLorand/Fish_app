import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

/// Helper for requesting routes from Google Directions API and decoding polylines.
///
/// Usage:
/// final route = await RouteHelper.getRoute(
///   origin: LatLng(47.4979, 19.0402),
///   destination: LatLng(47.5, 19.045),
///   apiKey: 'YOUR_API_KEY_HERE',
/// );
class RouteHelper {
  /// Requests a route from Google Directions and returns a list of LatLng points
  /// following the roads. Returns empty list on error or if no route found.
  static Future<List<LatLng>> getRoute({
    required LatLng origin,
    required LatLng destination,
    required String apiKey,
    String mode = 'driving',
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${origin.latitude},${origin.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&mode=$mode'
      '&key=$apiKey',
    );

    try {
      debugPrint('RouteHelper: requesting URL: $url');
      final res = await http.get(url);
      debugPrint('RouteHelper: HTTP ${res.statusCode}');
      debugPrint('RouteHelper: response body: ${res.body}');
      if (res.statusCode != 200) {
        debugPrint('RouteHelper: HTTP ${res.statusCode} ${res.body}');
        return [];
      }

      final body = json.decode(res.body) as Map<String, dynamic>;
      // log Directions API status/error_message if present
      try {
        final status = body['status'];
        if (status != null)
          debugPrint('RouteHelper: directions status: $status');
        final err = body['error_message'];
        if (err != null)
          debugPrint('RouteHelper: directions error_message: $err');
      } catch (_) {}
      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return [];

      final overview = routes[0]['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String?;
      if (encoded == null || encoded.isEmpty) return [];

      final decoded = PolylinePoints().decodePolyline(encoded);
      return decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
    } catch (e, st) {
      debugPrint('RouteHelper: exception $e\n$st');
      return [];
    }
  }

  /// Builds a `Polyline` object ready to add to a `GoogleMap` `polylines` set.
  static Polyline toPolyline(
    List<LatLng> points, {
    String id = 'route',
    Color color = Colors.blue,
    int width = 6,
    bool geodesic = false,
  }) {
    return Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: width,
      geodesic: geodesic,
    );
  }
}
