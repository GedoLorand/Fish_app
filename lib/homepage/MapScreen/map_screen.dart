import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  LatLng _initialPosition = const LatLng(47.4979, 19.0402); // Default: Budapest
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
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

    // Ha már létrejött a térkép, kamera mozgatása
    mapController?.animateCamera(CameraUpdate.newLatLng(_initialPosition));
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;

    if (_locationLoaded) {
      mapController!.animateCamera(CameraUpdate.newLatLng(_initialPosition));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: GoogleMap(
          mapType: MapType.hybrid,
          initialCameraPosition: CameraPosition(target: LatLng(26, 42)),
          onMapCreated: (GoogleMapController controller) {},
        ),
      ),
    );
    return Scaffold(
      body: _locationLoaded
          ? GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 14.0,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            )
          : const Center(child: CircularProgressIndicator()),

      floatingActionButton: SizedBox(
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
