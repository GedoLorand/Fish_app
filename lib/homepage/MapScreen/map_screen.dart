import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:login_fish_app/homepage/MapScreen/metadata_dialog.dart';
import 'package:login_fish_app/homepage/MapScreen/cluster_sheet.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/homepage/GalleryScreen/Gallery.dart';
import 'package:login_fish_app/homepage/widgets/photo_detail_dialog.dart';
import 'package:login_fish_app/homepage/MapScreen/photo_marker.dart';

String _formatWeight(dynamic w) {
  if (w == null) return '-';
  double? v;
  if (w is num)
    v = w.toDouble();
  else if (w is String)
    v = double.tryParse(w.replaceAll(',', '.'));
  if (v == null) return w.toString();
  return v.toStringAsFixed(3);
}

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
  // store photo entries (point + url + doc id) so we can build markers and
  // look up entries when clusters are tapped
  List<Map<String, dynamic>> _photoEntries = [];
  late final StreamSubscription<QuerySnapshot> _imagesSub;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _determinePosition();
    // Listen for uploaded images (all users) and create a list of entries
    _imagesSub = FirebaseFirestore.instance
        .collectionGroup('images')
        .snapshots()
        .listen(
          (snap) {
            final List<Map<String, dynamic>> entries = [];
            for (final doc in snap.docs) {
              final data = doc.data() as Map<String, dynamic>;
              GeoPoint? gp = data['location'] as GeoPoint?;
              LatLng? pt;
              if (gp != null) {
                pt = LatLng(gp.latitude, gp.longitude);
              }
              final url = data['url'] as String? ?? '';
              entries.add({'point': pt, 'url': url, 'doc': data, 'id': doc.id});
            }
            setState(() => _photoEntries = entries);
          },
          onError: (e) {
            // Log error but keep existing entries so map icons remain visible.
            print('images subscription error: $e');
          },
        );
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
      // Start upload (metadata will be requested after server suggestions)
      await _uploadPhoto(_imageFile!);

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
      final user = FirebaseAuth.instance.currentUser;
      // Debug: print current user so we can see auth state when uploading
      // ignore: avoid_print
      print(
        'uploadPhoto: currentUser=' +
            (user == null ? 'null' : '${user.uid} / ${user.email}'),
      );
      if (user == null) throw Exception('User not signed in');

      final String uid = user.uid;
      // Debug: get ID token so we can verify token exists client-side
      String? debugIdToken;
      try {
        debugIdToken = await user.getIdToken();
        final int idTokenLen = debugIdToken?.length ?? 0;
        // ignore: avoid_print
        print('debug: currentUser=${user.uid}, idToken length=$idTokenLen');
      } catch (e) {
        // ignore: avoid_print
        print('debug: failed to get idToken: $e');
      }
      final String filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Store file under a user-scoped folder in Storage
      final ref = FirebaseStorage.instance.ref().child(
        'user_images/$uid/$filename',
      );
      final uploadTask = await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // DEBUG: directly invoke function via HTTP with ID token to test auth forwarding
      if (debugIdToken != null) {
        // ignore: avoid_print
        print(
          'debug: invoking HTTP with idToken length=${debugIdToken.length}',
        );
        await _debugInvokeFunctionViaHttp(url, debugIdToken);
      } else {
        // ignore: avoid_print
        print('debug: no idToken available for HTTP invoke');
      }

      // Call server-side verification to check if image contains a fish
      bool isFish = false;
      String? serverError;
      try {
        final callable = FirebaseFunctions.instanceFor(
          region: 'us-central1',
        ).httpsCallable('analyzeImageForFish');
        final res = await callable.call(<String, dynamic>{'imageUrl': url});
        final Map data = Map<String, dynamic>.from(res.data as Map);
        isFish = data['isFish'] == true;
      } catch (e, st) {
        // Capture server error to show to the user for debugging
        serverError = e.toString();
        // Also print full stack for local debugging
        // ignore: avoid_print
        print('analyzeImageForFish error: $serverError\n$st');
        isFish = false;
      }

      if (!isFish) {
        // remove uploaded file since it's not acceptable
        try {
          await ref.delete();
        } catch (_) {}
        if (!mounted) return;
        // If we have a server error, show it to help debugging; otherwise show generic message
        if (serverError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Szerverhiba: ${serverError}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A kép nem hal — feltöltés megszakítva.'),
            ),
          );
        }
        return;
      }

      // If it's a fish, open metadata dialog (user must input species manually)
      Map<String, dynamic>? finalMetadata;
      try {
        finalMetadata = await showMetadataDialog(context, _imageFile);
      } catch (e) {
        finalMetadata = null;
      }

      if (finalMetadata == null) {
        // user cancelled metadata entry — delete uploaded image and stop
        try {
          await ref.delete();
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Feltöltés megszakítva.')));
        return;
      }

      // Try to get current location to attach to the photo
      GeoPoint? photoPoint;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        photoPoint = GeoPoint(pos.latitude, pos.longitude);
      } catch (_) {
        // ignore location errors; leave photoPoint null
      }

      final docData = <String, dynamic>{
        'url': url,
        'createdAt': FieldValue.serverTimestamp(),
      };
      // Use provided species from finalMetadata or fallback to generic 'hal'
      String speciesValue = 'hal';
      if (finalMetadata != null &&
          finalMetadata.containsKey('species') &&
          (finalMetadata['species'] as String).trim().isNotEmpty) {
        speciesValue = finalMetadata['species'] as String;
      }
      docData['species'] = speciesValue;
      // Merge any metadata passed programmatically first
      if (metadata != null) {
        final copy = Map<String, dynamic>.from(metadata);
        copy.remove('species');
        docData.addAll(copy);
      }
      // Merge values entered in the dialog (finalMetadata) so they take precedence
      if (finalMetadata != null) {
        final copy2 = Map<String, dynamic>.from(finalMetadata);
        copy2.remove('species');
        // If weight provided, ensure it's stored under 'weight'
        if (copy2.containsKey('weight')) {
          docData['weight'] = copy2['weight'];
          copy2.remove('weight');
        }
        docData.addAll(copy2);
      }
      // location is not stored per user request

      // Save metadata under /users/{uid}/images/{autoId} so it matches Firestore rules
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('images')
          .add(docData);

      // (No automatic suggestion collection — user-entered species is authoritative)

      // Immediately append the new entry locally so the map updates without re-opening
      final LatLng entryPoint = (photoPoint != null)
          ? LatLng(photoPoint.latitude, photoPoint.longitude)
          : _initialPosition;
      final localDoc = Map<String, dynamic>.from(docData);
      // Replace server timestamp with current local time for immediate UI
      localDoc['createdAt'] = DateTime.now();
      final newEntry = {
        'point': entryPoint,
        'url': url,
        'doc': localDoc,
        'id': docRef.id,
      };
      setState(() {
        _photoEntries = List<Map<String, dynamic>>.from(_photoEntries)
          ..add(newEntry);
      });

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

  // Optional debug helper: invoke the deployed function directly with an ID token.
  // WARNING: only use for debugging. Keep commented out in production.
  Future<void> _debugInvokeFunctionViaHttp(
    String imageUrl,
    String idToken,
  ) async {
    try {
      final uri = Uri.parse(
        'https://us-central1-fish-app-release.cloudfunctions.net/analyzeImageForFish',
      );
      final body = {
        'data': {'imageUrl': imageUrl},
      };
      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      // ignore: avoid_print
      print('debug HTTP invoke status=${resp.statusCode}, body=${resp.body}');
    } catch (e) {
      // ignore: avoid_print
      print('debug HTTP invoke failed: $e');
    }
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
              // Cluster layer for photo markers
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  markers: [
                    if (_locationLoaded)
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
                    // build markers from entries
                    ..._photoEntries.map((e) {
                      final LatLng markerPoint =
                          (e['point'] as LatLng?) ?? _initialPosition;
                      // If the original doc lacked a location, we place a fallback marker
                      // at the user's current known position so the icon is visible for testing.
                      final bool hadLocation = (e['point'] as LatLng?) != null;
                      return Marker(
                        width: 44,
                        height: 44,
                        point: markerPoint,
                        child: PhotoMarker(
                          size: hadLocation ? 36 : 40,
                          onTap: () => _showPhotoDialog(
                            e['url'] as String,
                            e['doc'] as Map<String, dynamic>,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                  builder: (context, markers) {
                    return GestureDetector(
                      onTap: () async {
                        try {
                          final clusterPoints = markers
                              .map((m) => m.point)
                              .toSet();
                          final clusterEntries = _photoEntries.where((e) {
                            final LatLng? p = e['point'] as LatLng?;
                            return p != null && clusterPoints.contains(p);
                          }).toList();
                          await showClusterEntries(
                            context,
                            clusterEntries,
                            (entry) => _showPhotoDialog(
                              entry['url'] as String,
                              entry['doc'] as Map<String, dynamic>,
                            ),
                          );
                        } catch (_) {}
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // cluster icon from assets
                          Image.asset(
                            'assets/icon/in_map_icon.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          // count badge (subtle)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              width: 20,
                              height: 20,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  markers.length.toString(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onClusterTap: (cluster) {
                    // find matching entries by point
                    final clusterPoints = cluster.markers
                        .map((m) => m.point)
                        .toSet();
                    final clusterEntries = _photoEntries
                        .where(
                          (e) => clusterPoints.contains(e['point'] as LatLng),
                        )
                        .toList();
                    // show a full, scrollable list so user can browse multiple catches without zooming
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: 0.75,
                        minChildSize: 0.4,
                        maxChildSize: 0.95,
                        expand: false,
                        builder: (context, scrollCtrl) {
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Képek a környéken (${clusterEntries.length})',
                                        style: TextStyle(
                                          color: AppTheme.textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          color: AppTheme.textColor,
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    controller: scrollCtrl,
                                    itemCount: clusterEntries.length,
                                    itemBuilder: (ctx, idx) {
                                      final item = clusterEntries[idx];
                                      final doc =
                                          item['doc'] as Map<String, dynamic>;
                                      final url = item['url'] as String;
                                      DateTime? dt;
                                      final created = doc['createdAt'];
                                      try {
                                        if (created is Timestamp)
                                          dt = created.toDate();
                                        else if (created is String)
                                          dt = DateTime.tryParse(created);
                                      } catch (_) {}
                                      final dateText = dt != null
                                          ? dt
                                                .toLocal()
                                                .toString()
                                                .split('.')
                                                .first
                                          : '';
                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        color: AppTheme.surfaceColor,
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            _showPhotoDialog(url, doc);
                                          },
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(8),
                                                    ),
                                                child: CachedNetworkImage(
                                                  imageUrl: url,
                                                  width: double.infinity,
                                                  height: 220,
                                                  fit: BoxFit.cover,
                                                  placeholder: (c, u) => Container(
                                                    width: double.infinity,
                                                    height: 220,
                                                    color: Colors.grey.shade300,
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2.0,
                                                          ),
                                                    ),
                                                  ),
                                                  errorWidget: (c, u, e) =>
                                                      Container(
                                                        width: double.infinity,
                                                        height: 220,
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                        child: const Icon(
                                                          Icons.broken_image,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  12.0,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (doc['species'] != null)
                                                      Text(
                                                        'Fajta: ${doc['species']}',
                                                        style: TextStyle(
                                                          color: AppTheme
                                                              .textColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    if (doc['weight'] != null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 6.0,
                                                            ),
                                                        child: Text(
                                                          'Tömeg: ${_formatWeight(doc['weight'])} kg',
                                                          style: TextStyle(
                                                            color: AppTheme
                                                                .textColor,
                                                          ),
                                                        ),
                                                      ),
                                                    if (dateText.isNotEmpty)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 6.0,
                                                            ),
                                                        child: Text(
                                                          dateText,
                                                          style: TextStyle(
                                                            color: AppTheme
                                                                .textColor
                                                                .withOpacity(
                                                                  0.8,
                                                                ),
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                  onMarkerTap: (marker) {
                    try {
                      final LatLng mp = marker.point;
                      final match = _photoEntries.firstWhere((e) {
                        final LatLng? p = e['point'] as LatLng?;
                        return p != null &&
                            p.latitude == mp.latitude &&
                            p.longitude == mp.longitude;
                      }, orElse: () => {});
                      if (match is Map<String, dynamic>) {
                        _showPhotoDialog(
                          match['url'] as String,
                          match['doc'] as Map<String, dynamic>,
                        );
                      }
                    } catch (_) {}
                  },
                ),
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
                heroTag: 'gallery_fab',
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
            heroTag: 'camera_fab',
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

  @override
  void dispose() {
    try {
      _imagesSub.cancel();
    } catch (_) {}
    super.dispose();
  }

  void _showPhotoDialog(String url, Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (_) => PhotoDetailDialog(url: url, doc: doc),
    );
  }
}
