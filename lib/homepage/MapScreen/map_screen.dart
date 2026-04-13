import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/homepage/GalleryScreen/Gallery.dart';

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
  File? _imageFile;
  bool _uploading = false;

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

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
      );
      if (photo == null) return;

      setState(() {
        _imageFile = File(photo.path);
      });
      // Ask user for metadata (species, weight) and show the image in the dialog
      final metadata = await _showMetadataDialog(_imageFile);
      if (metadata == null) {
        // user cancelled metadata entry
        return;
      }

      // Start upload with metadata
      await _uploadPhoto(_imageFile!, metadata: metadata);

      // After upload we just show the snackbar (preview already visible in dialog)
    } catch (e) {
      // ignore errors for now
    }
  }

  Future<void> _uploadPhoto(File file, {Map<String, dynamic>? metadata}) async {
    setState(() {
      _uploading = true;
    });
    try {
      final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final String filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('photos/$uid/$filename');
      final uploadTask = ref.putFile(file);
      await uploadTask;
      final url = await ref.getDownloadURL();

      final docData = <String, dynamic>{
        'url': url,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (metadata != null) {
        docData.addAll(metadata);
      }

      await FirebaseFirestore.instance.collection('photos').add(docData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kép feltöltve a galériába')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hiba a feltöltés során')));
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _showMetadataDialog(File? image) async {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController speciesCtrl = TextEditingController();
    final TextEditingController weightCtrl = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFE8F5E9), // light green background
          title: const Text('Kép adatai'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (image != null)
                  Container(
                    height: 160,
                    margin: const EdgeInsets.only(bottom: 12.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB9F6CA), Color(0xFF69F0AE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(
                        image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: speciesCtrl,
                        decoration: const InputDecoration(labelText: 'Fajta'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Kötelező' : null,
                      ),
                      TextFormField(
                        controller: weightCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Súly (kg)',
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Kötelező' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Mégse'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 14, 66, 18),
              ),
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  double? weight;
                  final wText = weightCtrl.text.trim();
                  try {
                    weight = double.parse(wText.replaceAll(',', '.'));
                  } catch (_) {
                    weight = null;
                  }
                  final data = <String, dynamic>{
                    'species': speciesCtrl.text.trim(),
                    'weight': weight ?? weightCtrl.text.trim(),
                  };
                  Navigator.of(context).pop(data);
                }
              },
              child: const Text('Mentés'),
            ),
          ],
        );
      },
    );
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
          if (_uploading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
            ),
          // Gallery button top-right
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: FloatingActionButton(
                mini: true,
                backgroundColor: const Color.fromARGB(255, 14, 66, 18),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const Gallery()),
                  );
                },
                child: const Icon(
                  Icons.photo_library,
                  color: AppTheme.textColor,
                ),
              ),
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
            onPressed: _takePhoto,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
