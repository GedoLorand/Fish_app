import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng _initialPosition = LatLng(47.4979, 19.0402); // Deefault: Budapest
  bool _locationLoaded = false;
  late final MapController _mapController;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // GPS be van-e kapcsolva
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return; // Később lehet hibaüzenetet írni
    }

    // Jogosultság lekérése
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    // Pozíció lekérése
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _initialPosition = LatLng(position.latitude, position.longitude);
      _locationLoaded = true;
    });
    // Try to move after the current frame in case map needs a rebuild first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mapReady) {
        try {
          _mapController.move(_initialPosition, 14.0);
        } catch (_) {}
      }
    });
    // Ha már létrejött a térkép, egyszerűen állítsuk be az initial position-t (flutter_map használja)
  }

  // FlutterMap nem igényel külön controller beállítást itt

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 14.0,
              onMapReady: () {
                _mapReady = true;
                if (_locationLoaded) {
                  try {
                    _mapController.move(_initialPosition, 14.0);
                  } catch (_) {}
                }
                setState(() {});
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.login_fish_app',
              ),
              MarkerLayer(
                markers: _locationLoaded
                    ? [
                        Marker(
                          width: 40,
                          height: 40,
                          point: _initialPosition,
                          child: const Icon(
                            Icons.location_on,
                            size: 40,
                            color: Colors.red,
                          ),
                        ),
                      ]
                    : [],
              ),
            ],
          ),
          if (!_locationLoaded || !_mapReady)
            const Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
        child: SizedBox(
          width: 68,
          height: 68,
          child: FloatingActionButton(
            backgroundColor: const Color.fromARGB(255, 14, 66, 18),
            elevation: 8,
            child: const Icon(
              Icons.camera_alt,
              color: AppTheme.textColor,
              size: 50,
            ),
            onPressed: () {
              // ide jön majd a fénykép funkció
            },
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
