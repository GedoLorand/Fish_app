import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

/// A small bottom bar that shows the current distance from origin to [target]
/// and refreshes every [refreshInterval].
class RouteDistanceBar extends StatefulWidget {
  final LatLng target;
  final Future<LatLng> Function() getOrigin;
  final Duration refreshInterval;
  final String mode; // 'driving'|'walking' etc.
  final List<LatLng>? routePoints;
  final VoidCallback? onCancel;

  const RouteDistanceBar({
    Key? key,
    required this.target,
    required this.getOrigin,
    this.refreshInterval = const Duration(minutes: 1),
    this.mode = 'driving',
    this.routePoints,
    this.onCancel,
  }) : super(key: key);

  @override
  State<RouteDistanceBar> createState() => _RouteDistanceBarState();
}

class _RouteDistanceBarState extends State<RouteDistanceBar> {
  double? _distanceKm;
  DateTime? _lastUpdated;
  Timer? _timer;
  double? _totalKm;
  double? _remainingKm;
  double? _progress; // 0.0..1.0

  final Distance _dist = const Distance();

  @override
  void initState() {
    super.initState();
    _updateDistance();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _updateDistance());
  }

  Future<void> _updateDistance() async {
    try {
      final origin = await widget.getOrigin();
      // compute distance along route if routePoints provided, otherwise straight-line
      double remaining = 0.0;
      double total = 0.0;
      if (widget.routePoints != null && widget.routePoints!.length > 1) {
        final pts = widget.routePoints!;
        // compute total length
        for (int i = 0; i < pts.length - 1; i++) {
          total += _dist.as(LengthUnit.Kilometer, pts[i], pts[i + 1]);
        }
        // find index of point closest to origin
        int closest = 0;
        double best = double.infinity;
        for (int i = 0; i < pts.length; i++) {
          final dd = _dist.as(LengthUnit.Kilometer, origin, pts[i]);
          if (dd < best) {
            best = dd;
            closest = i;
          }
        }
        // remaining length from closest to end
        for (int i = closest; i < pts.length - 1; i++) {
          remaining += _dist.as(LengthUnit.Kilometer, pts[i], pts[i + 1]);
        }
      } else {
        remaining = _dist.as(LengthUnit.Kilometer, origin, widget.target);
        total = remaining;
      }

      final traveled = (total - remaining).clamp(0.0, total);
      final prog = (total > 0) ? (traveled / total) : 0.0;

      setState(() {
        _distanceKm = remaining;
        _totalKm = total;
        _remainingKm = remaining;
        _progress = prog;
        _lastUpdated = DateTime.now();
      });
    } catch (_) {
      setState(() {
        _distanceKm = null;
        _totalKm = null;
        _remainingKm = null;
        _progress = null;
        _lastUpdated = DateTime.now();
      });
    }
  }

  @override
  void dispose() {
    try {
      _timer?.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _distanceKm != null
        ? '${_distanceKm!.toStringAsFixed(2)} km'
        : '-- km';
    final updated = _lastUpdated != null
        ? 'Frissítve: ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}'
        : '';

    // estimate ETA from mode
    String etaText = '';
    if (_remainingKm != null) {
      double speedKmh;
      switch (widget.mode) {
        case 'walking':
          speedKmh = 5.0;
          break;
        case 'bicycling':
          speedKmh = 15.0;
          break;
        default:
          speedKmh = 50.0; // driving default
      }
      final minutes = (_remainingKm! / speedKmh) * 60.0;
      final int h = minutes ~/ 60;
      final int m = (minutes % 60).round();
      if (h > 0)
        etaText = '${h}h ${m}m';
      else
        etaText = '${m} min';
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Material(
          color: AppTheme.surfaceColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8.0),
          elevation: 6.0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place, color: AppTheme.textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Távolság: $text',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (etaText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          'ETA: $etaText',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    // cancel button
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close, color: AppTheme.textColor),
                      onPressed: widget.onCancel,
                      tooltip: 'Útvonal bezárása',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  updated,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                // Progress bar showing proportion traveled
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (_progress ?? 0.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _totalKm != null
                          ? 'Megvan: ${((_totalKm! - (_remainingKm ?? 0.0)).clamp(0.0, _totalKm!)).toStringAsFixed(2)} km'
                          : 'Megvan: -- km',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _remainingKm != null
                          ? 'Hátra: ${_remainingKm!.toStringAsFixed(2)} km'
                          : 'Hátra: -- km',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
