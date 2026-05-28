import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/MapScreen/metadata_dialog.dart';
import 'package:login_fish_app/homepage/MapScreen/cluster_sheet.dart';
import 'package:login_fish_app/homepage/MapScreen/cluster_statistics.dart';
import 'package:login_fish_app/homepage/EventScreen/event_screen.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/homepage/GalleryScreen/Gallery.dart';
import 'package:login_fish_app/homepage/widgets/photo_detail_dialog.dart';
import 'package:login_fish_app/homepage/MapScreen/photo_marker.dart';
import 'package:login_fish_app/homepage/FilterScreen/filter.dart'
    as filter_screen;
import 'package:login_fish_app/homepage/AIScreen/ai_assistant.dart';
import 'package:login_fish_app/services/filter_bus.dart';
import 'package:login_fish_app/homepage/widgets/fish_loader.dart';

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

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  LatLng _initialPosition = LatLng(47.4979, 19.0402); // Deefault: Budapest
  bool _locationLoaded = false;
  late final MapController _mapController;
  bool _mapReady = false;
  bool _filterOnlyMine = false;
  bool _filtersActive = false;
  late final AnimationController _hintAnimController;
  late final Animation<double> _hintOpacity;
  late final AnimationController _eventPulseController;
  late final Animation<double> _eventPulseAnimation;
  late final AnimationController _eventSparkleController;
  bool _showPanelPulse = false;
  bool _showArrowHint = false;
  bool _suppressNextClearHint = false;
  File? _imageFile;
  bool _uploading = false;
  Timer? _locationTimer;
  Timer? _burstRefreshTimer;
  double _currentZoom = 14.0;
  // store photo entries (point + url + doc id) so we can build markers and
  // look up entries when clusters are tapped
  List<Map<String, dynamic>> _photoEntries = [];
  StreamSubscription<QuerySnapshot>? _topImagesSub;
  StreamSubscription<QuerySnapshot>? _userImagesSub;
  QuerySnapshot? _lastTopSnap;
  QuerySnapshot? _lastUserSnap;
  StreamSubscription<DocumentSnapshot>? _imagesPingSub;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _determinePosition();
    _hintAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _hintOpacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _hintAnimController, curve: Curves.easeInOut),
    );
    // Event button pulse animation
    _eventPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _eventPulseAnimation = Tween<double>(begin: 0.95, end: 1.12).animate(
      CurvedAnimation(parent: _eventPulseController, curve: Curves.easeInOut),
    );
    try {
      _eventPulseController.repeat(reverse: true);
    } catch (_) {}
    // sparkles
    _eventSparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    try {
      _eventSparkleController.repeat();
    } catch (_) {}
    // Start periodic location refresh (every 10 seconds)
    _startLocationTimer();
    // Subscribe to top-level /images and the current user's /users/{uid}/images
    // and merge results client-side. This avoids relying on collectionGroup
    // queries which may be blocked by security rules.
    _subscribeToImageStreams();

    // Listen to a lightweight "ping" document so other clients can be
    // notified quickly when a new image is published. This avoids aggressive
    // polling while ensuring near-instant updates on other devices.
    _imagesPingSub = FirebaseFirestore.instance
        .collection('meta')
        .doc('images_last_update')
        .snapshots()
        .listen(
          (doc) async {
            try {
              // When the ping doc changes, force-refresh from server and optionally
              // show a short debug hint so we can tell whether other devices react.
              await _refreshPhotoEntriesFromServer();
              final int count = _photoEntries.length;
              if (kDebugMode && mounted) {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text('images ping received — entries: $count'),
                    ),
                  );
                } catch (_) {}
              }
            } catch (e) {
              // ignore errors here
            }
          },
          onError: (e) {
            // ignore ping listener errors
            // ignore: avoid_print
            print('images ping listen error: $e');
          },
        );
    // Listen for filter updates from Filter screen
    FilterBus.instance.stream.listen((filter) {
      try {
        if (!mounted) return;
        setState(() {
          // If the incoming filter requests owner-only results, set the
          // local _filterOnlyMine flag and remove the marker from the
          // stored filter so UI summaries don't show it.
          if (filter != null && filter['ownerOnly'] == true) {
            _filterOnlyMine = true;
            final copy = Map<String, dynamic>.from(filter);
            copy.remove('ownerOnly');
            _currentFilter = copy;
          } else {
            _currentFilter = filter;
          }
          if (_currentFilter == null) {
            _filtersActive = false;
            _showPanelPulse = false;
            // If this clear was triggered locally by the clear FAB, suppress
            // the automatic arrow hint once. Otherwise show a short arrow pulse.
            if (_suppressNextClearHint) {
              _suppressNextClearHint = false;
              _showArrowHint = false;
              try {
                _hintAnimController.stop();
              } catch (_) {}
            } else {
              _showArrowHint = true;
              _hintAnimController.repeat(reverse: true);
              Future.delayed(const Duration(seconds: 3), () {
                if (!mounted) return;
                setState(() {
                  _showArrowHint = false;
                });
                try {
                  _hintAnimController.stop();
                } catch (_) {}
              });
            }
          } else {
            _filtersActive = true;
            // show panel pulse until filters change
            _showPanelPulse = true;
            // also show a short arrow hint pointing to the clear-filter FAB
            // so the user sees how to remove filters immediately after apply
            _showArrowHint = true;
            _hintAnimController.repeat(reverse: true);
            // hide only the arrow after a short period but keep the panel pulse
            Future.delayed(const Duration(seconds: 4), () {
              if (!mounted) return;
              setState(() {
                _showArrowHint = false;
              });
            });
          }
        });
      } catch (_) {}
    });
    // Ensure hint is not running initially
    try {
      _hintAnimController.stop();
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ensure event pulse keeps running if needed when dependencies change
    try {
      if (!_eventPulseController.isAnimating)
        _eventPulseController.repeat(reverse: true);
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      _topImagesSub?.cancel();
    } catch (_) {}
    try {
      _userImagesSub?.cancel();
    } catch (_) {}
    try {
      _imagesPingSub?.cancel();
    } catch (_) {}
    try {
      _locationTimer?.cancel();
    } catch (_) {}
    try {
      _burstRefreshTimer?.cancel();
    } catch (_) {}
    try {
      _hintAnimController.dispose();
    } catch (_) {}
    try {
      _eventPulseController.dispose();
    } catch (_) {}
    try {
      _eventSparkleController.dispose();
    } catch (_) {}
    super.dispose();
  }

  Map<String, dynamic>? _currentFilter;

  String _formatTimeMap(Map? t) {
    if (t == null) return '-';
    try {
      final h = (t['hour'] as int?) ?? 0;
      final m = (t['minute'] as int?) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  String _buildFilterSummary() {
    if (_currentFilter == null) return '';
    final parts = <String>[];
    try {
      final sp = _currentFilter!['species'] as String?;
      if (sp != null && sp.trim().isNotEmpty) parts.add(sp);
      final wmin = _currentFilter!['weightMin'];
      final wmax = _currentFilter!['weightMax'];
      if (wmin != null || wmax != null) {
        final a = wmin?.toString() ?? '-';
        final b = wmax?.toString() ?? '-';
        parts.add('${'weight_kg'.tr}: $a—$b');
      }
      final month = _currentFilter!['month'];
      final year = _currentFilter!['year'];
      if (month != null || year != null)
        parts.add('${'time_interval'.tr}: ${month ?? '-'} / ${year ?? '-'}');
      final st = _currentFilter!['startTime'];
      final et = _currentFilter!['endTime'];
      if (st != null || et != null)
        parts.add(
          '${'start_time'.tr}: ${_formatTimeMap(st)} — ${'end_time'.tr}: ${_formatTimeMap(et)}',
        );
      final date = _currentFilter!['date'] as String?;
      if (date != null) parts.add('${'date'.tr}: $date');
    } catch (_) {}
    return parts.join(' · ');
  }

  List<String> _buildFilterParts() {
    if (_currentFilter == null) return [];
    final parts = <String>[];
    try {
      final sp = _currentFilter!['species'] as String?;
      if (sp != null && sp.trim().isNotEmpty) parts.add(sp);
      final wmin = _currentFilter!['weightMin'];
      final wmax = _currentFilter!['weightMax'];
      if (wmin != null || wmax != null) {
        final a = wmin?.toString() ?? '-';
        final b = wmax?.toString() ?? '-';
        parts.add('${'weight_kg'.tr}: $a—$b');
      }
      final month = _currentFilter!['month'];
      final year = _currentFilter!['year'];
      if (month != null || year != null)
        parts.add('${'time_interval'.tr}: ${month ?? '-'} / ${year ?? '-'}');
      final st = _currentFilter!['startTime'];
      final et = _currentFilter!['endTime'];
      if (st != null || et != null)
        parts.add(
          '${'start_time'.tr}: ${_formatTimeMap(st)} — ${'end_time'.tr}: ${_formatTimeMap(et)}',
        );
      final date = _currentFilter!['date'] as String?;
      if (date != null) parts.add('${'date'.tr}: $date');
    } catch (_) {}
    return parts;
  }

  // Fallback fetch: try top-level /images and per-user /users/{uid}/images when
  // collectionGroup queries are not permitted by rules. Merge results and avoid duplicates.
  Future<void> _fallbackFetchImages() async {
    try {
      final List<Map<String, dynamic>> entries = [];
      final seen = <String>{};

      // Try top-level /images first
      try {
        final top = await FirebaseFirestore.instance
            .collection('images')
            .where('public', isEqualTo: true)
            .get();
        for (final doc in top.docs) {
          if (seen.contains(doc.id)) continue;
          final data = doc.data() as Map<String, dynamic>;
          GeoPoint? gp = data['location'] as GeoPoint?;
          LatLng? pt;
          if (gp != null) pt = LatLng(gp.latitude, gp.longitude);
          final url = data['url'] as String? ?? '';
          entries.add({'point': pt, 'url': url, 'doc': data, 'id': doc.id});
          seen.add(doc.id);
        }
      } catch (e) {
        print('fallback: top-level /images read failed: $e');
      }

      // Try current user's images (if signed in)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final userSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('images')
              .get();
          for (final doc in userSnap.docs) {
            if (seen.contains(doc.id)) continue;
            final data = doc.data() as Map<String, dynamic>;
            GeoPoint? gp = data['location'] as GeoPoint?;
            LatLng? pt;
            if (gp != null) pt = LatLng(gp.latitude, gp.longitude);
            final url = data['url'] as String? ?? '';
            entries.add({'point': pt, 'url': url, 'doc': data, 'id': doc.id});
            seen.add(doc.id);
          }
        } catch (e) {
          print('fallback: user images read failed: $e');
        }
      }

      if (!mounted) return;
      setState(() => _photoEntries = entries);
    } catch (e) {
      print('fallbackFetchImages failed: $e');
    }
  }

  // Subscribe to top-level /images and current user's /users/{uid}/images
  // merge snapshots client-side so we don't rely on collectionGroup permissions.
  void _subscribeToImageStreams() {
    // Top-level images (public)
    try {
      _topImagesSub = FirebaseFirestore.instance
          .collection('images')
          .where('public', isEqualTo: true)
          .snapshots()
          .listen(
            (snap) {
              _lastTopSnap = snap;
              _mergeImageSnapshots();
            },
            onError: (e) {
              // fallback to fetch on error
              // ignore: avoid_print
              print('top images listen error: $e');
              _fallbackFetchImages();
            },
          );
    } catch (e) {
      // ignore silent
    }

    // Current user's images (if signed in)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userImagesSub = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('images')
            .snapshots()
            .listen(
              (snap) {
                _lastUserSnap = snap;
                _mergeImageSnapshots();
              },
              onError: (e) {
                // ignore: avoid_print
                print('user images listen error: $e');
                _fallbackFetchImages();
              },
            );
      }
    } catch (e) {
      // ignore
    }
  }

  void _mergeImageSnapshots() {
    try {
      final List<Map<String, dynamic>> entries = [];
      final seen = <String>{};
      if (_lastTopSnap != null) {
        for (final doc in _lastTopSnap!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          GeoPoint? gp = data['location'] as GeoPoint?;
          LatLng? pt;
          if (gp != null) pt = LatLng(gp.latitude, gp.longitude);
          final url = data['url'] as String? ?? '';
          entries.add({'point': pt, 'url': url, 'doc': data, 'id': doc.id});
          seen.add(doc.id);
        }
      }
      if (_lastUserSnap != null) {
        for (final doc in _lastUserSnap!.docs) {
          if (seen.contains(doc.id)) continue;
          final data = doc.data() as Map<String, dynamic>;
          GeoPoint? gp = data['location'] as GeoPoint?;
          LatLng? pt;
          if (gp != null) pt = LatLng(gp.latitude, gp.longitude);
          final url = data['url'] as String? ?? '';
          entries.add({'point': pt, 'url': url, 'doc': data, 'id': doc.id});
        }
      }
      if (!mounted) return;
      setState(() => _photoEntries = entries);
    } catch (e) {
      // ignore
    }
  }

  // Debug: run quick server-side checks and show a dialog with counts and sample ids
  Future<void> _runDebugChecks() async {
    try {
      final serverGroup = await FirebaseFirestore.instance
          .collectionGroup('images')
          .where('public', isEqualTo: true)
          .get(GetOptions(source: Source.server));
      final topLevel = await FirebaseFirestore.instance
          .collection('images')
          .where('public', isEqualTo: true)
          .get(GetOptions(source: Source.server));
      final userImages = FirebaseAuth.instance.currentUser != null
          ? await FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('images')
                .get(GetOptions(source: Source.server))
          : null;

      final sampleServerIds = serverGroup.docs
          .take(5)
          .map((d) => d.id)
          .toList();
      final sampleTopIds = topLevel.docs.take(5).map((d) => d.id).toList();
      final sampleUserIds = userImages?.docs.take(5).map((d) => d.id).toList();

      // Prepare small sample of document fields for display
      Map<String, dynamic>? serverSample;
      Map<String, dynamic>? topSample;
      Map<String, dynamic>? userSample;
      if (serverGroup.docs.isNotEmpty)
        serverSample = serverGroup.docs.first.data();
      if (topLevel.docs.isNotEmpty) topSample = topLevel.docs.first.data();
      if (userImages != null && userImages.docs.isNotEmpty)
        userSample = userImages.docs.first.data();

      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Debug: Firestore állapot'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                  'collectionGroup images (server): ${serverGroup.docs.length}',
                ),
                Text('top-level /images: ${topLevel.docs.length}'),
                Text(
                  'your /users/{uid}/images: ${userImages?.docs.length ?? 'not signed in'}',
                ),
                const SizedBox(height: 8),
                Text('server sample ids: ${sampleServerIds.join(', ')}'),
                Text('top sample ids: ${sampleTopIds.join(', ')}'),
                Text('user sample ids: ${sampleUserIds?.join(', ') ?? ''}'),
                const SizedBox(height: 12),
                const Text(
                  '--- Server sample document (first) ---',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  serverSample != null
                      ? _formatDocSummary(serverSample)
                      : 'n/a',
                ),
                const SizedBox(height: 8),
                const Text(
                  '--- Top-level sample document (first) ---',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(topSample != null ? _formatDocSummary(topSample) : 'n/a'),
                const SizedBox(height: 8),
                const Text(
                  '--- Your user sample document (first) ---',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  userSample != null ? _formatDocSummary(userSample) : 'n/a',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e, st) {
      // Log full error for debugging
      // ignore: avoid_print
      print('debugChecks failed: $e\n$st');
      if (!mounted) return;
      // Show a dialog with the error so the tester can copy it
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Debug lekérdezés sikertelen'),
          content: SingleChildScrollView(
            child: SelectableText('Error: $e\n\nStack:\n$st'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
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
      // After we obtain location, perform a short burst of refreshes so
      // nearby devices see newly uploaded images quickly without running
      // an extremely aggressive permanent poll (10 ms). Default burst:
      // 200 ms interval for 2 seconds.
      _startBurstRefresh(intervalMs: 200, durationMs: 2000);
    });
    // Ha már létrejött a térkép, egyszerűen állítsuk be az initial position-t (flutter_map használja)
  }

  void _startLocationTimer() {
    // refresh user's position every 10 seconds while the screen is mounted
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        if (!mounted) return;
        final newPos = LatLng(pos.latitude, pos.longitude);
        // update local state and move map if map already ready
        setState(() {
          _initialPosition = newPos;
          _locationLoaded = true;
        });
        if (_mapReady) {
          try {
            _mapController.move(newPos, _currentZoom);
          } catch (_) {}
        }
        // Also refresh photo entries from server so other users' uploads appear quickly
        try {
          await _refreshPhotoEntriesFromServer();
        } catch (_) {}
      } catch (_) {
        // ignore location errors silently
      }
    });
  }

  // Short burst refresh: run repeated server refreshes for a short duration.
  // This is used right after location is obtained so the map populates
  // immediately on other devices that might have missed realtime events.
  void _startBurstRefresh({int intervalMs = 200, int durationMs = 2000}) {
    try {
      _burstRefreshTimer?.cancel();
      final int iterations = (durationMs / intervalMs).ceil();
      int count = 0;
      _burstRefreshTimer = Timer.periodic(Duration(milliseconds: intervalMs), (
        t,
      ) async {
        try {
          await _refreshPhotoEntriesFromServer();
        } catch (_) {}
        count++;
        if (count >= iterations) {
          try {
            t.cancel();
          } catch (_) {}
        }
      });
    } catch (_) {}
  }

  // Force-refresh the list of photo entries from server (no local cache)
  Future<void> _refreshPhotoEntriesFromServer() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collectionGroup('images')
          .get(GetOptions(source: Source.server));
      final List<Map<String, dynamic>> entries = [];
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        GeoPoint? gp = data['location'] as GeoPoint?;
        LatLng? pt;
        if (gp != null) pt = LatLng(gp.latitude, gp.longitude);
        final url = data['url'] as String? ?? '';
        entries.add({'point': pt, 'url': url, 'doc': data, 'id': doc.id});
      }
      if (!mounted) return;
      setState(() => _photoEntries = entries);
    } catch (e) {
      // ignore fetch errors but log for debugging
      // ignore: avoid_print
      print('refreshPhotoEntriesFromServer failed: $e');
    }
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
            SnackBar(
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              content: Text('Szerverhiba: ${serverError}'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              content: const Text('A kép nem hal — feltöltés megszakítva.'),
            ),
          );
        }
        return;
      }

      // If it's a fish, open metadata dialog (user must input species manually)
      Map<String, dynamic>? finalMetadata;
      try {
        // Stop showing the global uploading overlay while the user fills metadata
        if (mounted) setState(() => _uploading = false);
        finalMetadata = await showMetadataDialog(context, _imageFile);
      } catch (e) {
        finalMetadata = null;
      } finally {
        // If the user provided metadata and we continue, show uploading again while saving
        if (mounted && finalMetadata != null) setState(() => _uploading = true);
      }

      if (finalMetadata == null) {
        // user cancelled metadata entry — delete uploaded image and stop
        try {
          await ref.delete();
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            content: const Text('Feltöltés megszakítva.'),
          ),
        );
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
      // Save storage path and original file name to help reliable deletions
      docData['storagePath'] = 'user_images/$uid/$filename';
      docData['fileName'] = filename;
      // Try to include uploader name and owner id for other users to see
      String uploaderName = user.displayName ?? '';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          final d = userDoc.data();
          if (d != null &&
              d['name'] != null &&
              (d['name'] as String).trim().isNotEmpty) {
            uploaderName = d['name'] as String;
          }
        }
      } catch (_) {}
      docData['uploaderName'] = uploaderName;
      docData['ownerId'] = uid;
      // Make uploads visible globally by default
      docData['public'] = true;
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
      // Store location if we were able to obtain it so the photo appears on the map
      if (photoPoint != null) {
        docData['location'] = photoPoint;
      }

      // Save metadata under /users/{uid}/images/{autoId} so it matches Firestore rules
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('images')
          .add(docData);

      // Store the generated doc id inside the document for reliable later reference
      try {
        await docRef.update({'docId': docRef.id});
      } catch (_) {}

      // (No automatic suggestion collection — user-entered species is authoritative)

      // Immediately append the new entry locally so the map updates without re-opening
      // If the photo had no location, do not create a local marker (point == null).
      final LatLng? entryPoint = (photoPoint != null)
          ? LatLng(photoPoint.latitude, photoPoint.longitude)
          : null;
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
      // If the uploaded photo included location, center the map to it so user can verify
      if (entryPoint != null) {
        try {
          if (_mapReady) _mapController.move(entryPoint, 16.0);
        } catch (_) {}
      }

      // Also write a top-level /images/{id} document so uploads are visible globally
      try {
        await FirebaseFirestore.instance
            .collection('images')
            .doc(docRef.id)
            .set({
              ...docData,
              'userDocPath': '/users/$uid',
              'docId': docRef.id,
            });
        // Also update a lightweight meta "ping" document so other clients
        // that may not immediately receive collectionGroup updates will
        // trigger a server refresh via the ping listener added in initState.
        try {
          await FirebaseFirestore.instance
              .collection('meta')
              .doc('images_last_update')
              .set({'ts': FieldValue.serverTimestamp()});
        } catch (e) {
          // ignore meta update failures but log for debugging
          // ignore: avoid_print
          print('warning: failed to update images_last_update ping: $e');
        }
      } catch (e) {
        // Don't fail the upload flow if mirror write fails; log and inform the user
        // ignore: avoid_print
        print('warning: failed to write top-level images doc: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Figyelmeztetés: nem sikerült globális tükör létrehozása: $e',
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          content: const Text('Sikeres képfeltöltés — mentve a galériába'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          content: const Text('Hiba a feltöltés során'),
        ),
      );
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
    final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: _currentZoom,
              onMapReady: () {
                _mapReady = true;
                if (_locationLoaded) {
                  try {
                    _mapController.move(_initialPosition, _currentZoom);
                  } catch (_) {}
                }
                setState(() {});
              },
              onPositionChanged: (pos, hasGesture) {
                try {
                  _currentZoom = pos.zoom;
                } catch (_) {}
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'ro.catchpoint',
              ),
              // User location marker (separate, not clustered) - draw first so photo markers are on top
              if (_locationLoaded)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 44,
                      height: 44,
                      point: _initialPosition,
                      child: Image.asset(
                        'assets/icon/person_icon.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.my_location,
                          size: 36,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              // Cluster layer for photo markers
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  // build markers from entries that have a valid geo-point
                  markers: [
                    ..._photoEntries
                        .where((e) {
                          final LatLng? p = e['point'] as LatLng?;
                          if (p == null) return false;
                          if (_filterOnlyMine) {
                            try {
                              final doc = e['doc'] as Map<String, dynamic>?;
                              return doc != null &&
                                  doc['ownerId'] == _currentUid;
                            } catch (_) {
                              return false;
                            }
                          }
                          // apply advanced filter if present
                          if (_currentFilter != null) {
                            try {
                              final doc = e['doc'] as Map<String, dynamic>?;
                              if (doc == null) return false;
                              final species =
                                  _currentFilter?['species'] as String?;
                              if (species != null &&
                                  species.trim().isNotEmpty) {
                                final ds = (doc['species'] ?? '').toString();
                                if (!ds.toLowerCase().contains(
                                  species.toLowerCase(),
                                ))
                                  return false;
                              }
                              final wMin =
                                  (_currentFilter?['weightMin'] as num?)
                                      ?.toDouble();
                              final wMax =
                                  (_currentFilter?['weightMax'] as num?)
                                      ?.toDouble();
                              if (wMin != null || wMax != null) {
                                double? w;
                                final val = doc['weight'];
                                if (val is num)
                                  w = val.toDouble();
                                else if (val is String)
                                  w = double.tryParse(val.replaceAll(',', '.'));
                                if (w == null) return false;
                                if (wMin != null && w < wMin) return false;
                                if (wMax != null && w > wMax) return false;
                              }
                              final dateIso =
                                  _currentFilter?['date'] as String?;
                              if (dateIso != null) {
                                try {
                                  final docCreated = doc['createdAt'];
                                  DateTime? created;
                                  if (docCreated is Timestamp)
                                    created = docCreated.toDate();
                                  else if (docCreated is DateTime)
                                    created = docCreated;
                                  if (created == null) return false;
                                  final filterDate = DateTime.parse(dateIso);
                                  if (!(created.year == filterDate.year &&
                                      created.month == filterDate.month &&
                                      created.day == filterDate.day))
                                    return false;
                                } catch (_) {
                                  return false;
                                }
                              }
                            } catch (_) {
                              return false;
                            }
                          }
                          return true;
                        })
                        .map((e) {
                          final LatLng markerPoint = e['point'] as LatLng;
                          return Marker(
                            width: 44,
                            height: 44,
                            point: markerPoint,
                            child: PhotoMarker(
                              size: 36,
                              onTap: () => _showPhotoDialog(
                                e['url'] as String,
                                e['doc'] as Map<String, dynamic>,
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ],
                  builder: (context, markers) {
                    return GestureDetector(
                      onTap: () async {
                        try {
                          // Debug: log how many markers the cluster reports
                          // and how many matching entries we find in _photoEntries.
                          final points = markers.map((m) => m.point).toList();
                          if (points.isEmpty) return;
                          double minLat = points.first.latitude;
                          double maxLat = points.first.latitude;
                          double minLng = points.first.longitude;
                          double maxLng = points.first.longitude;
                          for (final p in points) {
                            if (p.latitude < minLat) minLat = p.latitude;
                            if (p.latitude > maxLat) maxLat = p.latitude;
                            if (p.longitude < minLng) minLng = p.longitude;
                            if (p.longitude > maxLng) maxLng = p.longitude;
                          }
                          const double eps = 0.0005; // ~50m buffer
                          final clusterEntries = _photoEntries.where((e) {
                            final LatLng? p = e['point'] as LatLng?;
                            if (p == null) return false;
                            final inBox =
                                p.latitude >= (minLat - eps) &&
                                p.latitude <= (maxLat + eps) &&
                                p.longitude >= (minLng - eps) &&
                                p.longitude <= (maxLng + eps);
                            if (!inBox) return false;
                            if (_filterOnlyMine) {
                              try {
                                final doc = e['doc'] as Map<String, dynamic>?;
                                return doc != null &&
                                    doc['ownerId'] == _currentUid;
                              } catch (_) {
                                return false;
                              }
                            }
                            return true;
                          }).toList();
                          // sort cluster entries by weight (descending) so heaviest appear first
                          double _parseWeightFromEntry(
                            Map<String, dynamic>? e,
                          ) {
                            try {
                              final doc = e == null
                                  ? null
                                  : e['doc'] as Map<String, dynamic>?;
                              final raw = doc != null
                                  ? doc['weight']
                                  : e?['weight'];
                              if (raw == null) return double.negativeInfinity;
                              if (raw is num) return raw.toDouble();
                              if (raw is String) {
                                final s = raw.replaceAll(',', '.');
                                final v = double.tryParse(s);
                                return v ?? double.negativeInfinity;
                              }
                            } catch (_) {}
                            return double.negativeInfinity;
                          }

                          clusterEntries.sort(
                            (a, b) => _parseWeightFromEntry(
                              b,
                            ).compareTo(_parseWeightFromEntry(a)),
                          );
                          // ignore: avoid_print
                          print(
                            'cluster builder tapped: plugin markers=${markers.length}, bbox matched entries=${clusterEntries.length}',
                          );
                          // compute visible count for these entries (doc or url present)
                          final clusterVisibleCount = clusterEntries.where((e) {
                            if (e == null) return false;
                            final doc = e['doc'] as Map<String, dynamic>?;
                            final url = e['url'] as String?;
                            return (doc != null) ||
                                (url != null && url.isNotEmpty);
                          }).length;
                          final showStats =
                              clusterVisibleCount >= 10 ||
                              clusterEntries.length >= 10 ||
                              markers.length >= 10;
                          // Show a simple modal with count and list (simplified behavior)
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
                                              'Képek a környéken',
                                              style: TextStyle(
                                                color: AppTheme.textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (showStats)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 8.0,
                                                        ),
                                                    child: ElevatedButton.icon(
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                AppTheme
                                                                    .primaryColor,
                                                          ),
                                                      icon: const Icon(
                                                        Icons.bar_chart,
                                                      ),
                                                      label: const Text(
                                                        'Statisztikák',
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(
                                                          context,
                                                        ).push(
                                                          MaterialPageRoute(
                                                            builder: (c) =>
                                                                ClusterStatisticsScreen(
                                                                  entries:
                                                                      clusterEntries,
                                                                ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                IconButton(
                                                  icon: Icon(
                                                    Icons.close,
                                                    color: AppTheme.textColor,
                                                  ),
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(),
                                                ),
                                              ],
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
                                            final url =
                                                item['url'] as String? ?? '';
                                            final doc =
                                                item['doc']
                                                    as Map<String, dynamic>? ??
                                                {};
                                            return Card(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              color: AppTheme.surfaceColor,
                                              child: InkWell(
                                                onTap: () {
                                                  Navigator.of(context).pop();
                                                  _showPhotoDialog(
                                                    item['url'] as String,
                                                    item['doc']
                                                        as Map<String, dynamic>,
                                                  );
                                                },
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    if (url.isNotEmpty)
                                                      ClipRRect(
                                                        borderRadius:
                                                            const BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                        child: CachedNetworkImage(
                                                          imageUrl: url,
                                                          width:
                                                              double.infinity,
                                                          height: 180,
                                                          fit: BoxFit.cover,
                                                          placeholder: (c, u) => Container(
                                                            width:
                                                                double.infinity,
                                                            height: 180,
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                            child: const Center(
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2.0,
                                                                  ),
                                                            ),
                                                          ),
                                                          errorWidget:
                                                              (
                                                                c,
                                                                u,
                                                                e,
                                                              ) => Container(
                                                                width: double
                                                                    .infinity,
                                                                height: 180,
                                                                color: Colors
                                                                    .grey
                                                                    .shade300,
                                                                child: const Icon(
                                                                  Icons
                                                                      .broken_image,
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            12.0,
                                                          ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          if (doc['species'] !=
                                                              null)
                                                            Text(
                                                              'Fajta: ${doc['species']}',
                                                              style: TextStyle(
                                                                color: AppTheme
                                                                    .textColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          if (doc['weight'] !=
                                                              null)
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    top: 6.0,
                                                                  ),
                                                              child: Text(
                                                                'Tömeg: ${doc['weight']} kg',
                                                                style: TextStyle(
                                                                  color: AppTheme
                                                                      .textColor,
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
                    final points = cluster.markers.map((m) => m.point).toList();
                    if (points.isEmpty) return;
                    double minLat = points.first.latitude;
                    double maxLat = points.first.latitude;
                    double minLng = points.first.longitude;
                    double maxLng = points.first.longitude;
                    for (final p in points) {
                      if (p.latitude < minLat) minLat = p.latitude;
                      if (p.latitude > maxLat) maxLat = p.latitude;
                      if (p.longitude < minLng) minLng = p.longitude;
                      if (p.longitude > maxLng) maxLng = p.longitude;
                    }
                    const double eps = 0.0005;
                    final clusterEntries = _photoEntries.where((e) {
                      final LatLng? p = e['point'] as LatLng?;
                      if (p == null) return false;
                      final inBox =
                          p.latitude >= (minLat - eps) &&
                          p.latitude <= (maxLat + eps) &&
                          p.longitude >= (minLng - eps) &&
                          p.longitude <= (maxLng + eps);
                      if (!inBox) return false;
                      if (_filterOnlyMine) {
                        try {
                          final doc = e['doc'] as Map<String, dynamic>?;
                          return doc != null && doc['ownerId'] == _currentUid;
                        } catch (_) {
                          return false;
                        }
                      }
                      return true;
                    }).toList();
                    // Debug: log counts when cluster is tapped
                    // ignore: avoid_print
                    print(
                      'onClusterTap: plugin markers=${cluster.markers.length}, bbox matched entries=${clusterEntries.length}',
                    );
                    // compute visible count (entries with doc or url)
                    final clusterVisibleCount = clusterEntries.where((e) {
                      if (e == null) return false;
                      final doc = e['doc'] as Map<String, dynamic>?;
                      final url = e['url'] as String?;
                      return (doc != null) || (url != null && url.isNotEmpty);
                    }).length;
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
                                        'Képek a környéken',
                                        style: TextStyle(
                                          color: AppTheme.textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (clusterVisibleCount >= 10 ||
                                              clusterEntries.length >= 10 ||
                                              cluster.markers.length >= 10)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8.0,
                                              ),
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppTheme.primaryColor,
                                                ),
                                                icon: const Icon(
                                                  Icons.bar_chart,
                                                ),
                                                label: const Text(
                                                  'Statisztikák',
                                                ),
                                                onPressed: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (c) =>
                                                          ClusterStatisticsScreen(
                                                            entries:
                                                                clusterEntries,
                                                          ),
                                                    ),
                                                  );
                                                },
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12.0,
                                                      vertical: 8.0,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        doc['uploaderName'] ??
                                                            'Ismeretlen',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      dateText,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
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
              // (User marker moved earlier so photo markers render above)
            ],
          ),
          // Left-side active filters panel (under header)
          if (_currentFilter != null)
            Positioned(
              left: MediaQuery.of(context).padding.left + 8,
              top: MediaQuery.of(context).padding.top + 8,
              child: GestureDetector(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const filter_screen.Filter(),
                    ),
                  );
                },
                child: FadeTransition(
                  opacity: _showPanelPulse
                      ? _hintOpacity
                      : AlwaysStoppedAnimation(1.0),
                  child: Card(
                    color: AppTheme.surfaceColor.withOpacity(0.5),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._buildFilterParts().map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                p,
                                style: TextStyle(
                                  color: AppTheme.textColor,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!_locationLoaded || !_mapReady)
            const Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: CircularProgressIndicator(),
              ),
            ),
          if (_uploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: Center(child: FishLoader(size: 120)),
              ),
            ),
          // Gallery button top-right
          // Event button top-left (under header) - placeholder icon, behaviour to be added
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _eventSparkleController,
                builder: (context, child) {
                  final t = _eventSparkleController.value * math.pi * 2;
                  const int count = 6;
                  const double radius = 20.0;
                  return SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (int i = 0; i < count; i++)
                          Positioned(
                            left:
                                36 +
                                math.cos(t + (i / count) * math.pi * 2) *
                                    radius -
                                4,
                            top:
                                36 +
                                math.sin(t + (i / count) * math.pi * 2) *
                                    radius -
                                4,
                            child: Opacity(
                              opacity:
                                  0.2 + 0.8 * (0.5 + 0.5 * math.sin(t * 2 + i)),
                              child: Transform.rotate(
                                angle: t + i,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9A825),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFF9A825,
                                        ).withOpacity(1.0),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ScaleTransition(
                          scale: _eventPulseAnimation,
                          child: FloatingActionButton(
                            heroTag: 'event_fab',
                            mini: true,
                            backgroundColor: const Color(0xFF8BC34A),
                            shape: const CircleBorder(
                              side: BorderSide(color: Colors.black, width: 2),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EventScreen(),
                                ),
                              );
                            },
                            child: Image.asset(
                              'assets/icon/event_icon.png',
                              width: 22,
                              height: 22,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => _outlinedIcon(
                                Icons.event,
                                size: 20,
                                color: AppTheme.textColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: FloatingActionButton(
                heroTag: 'gallery_fab',
                mini: true,
                backgroundColor: AppTheme.primaryColor,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.black, width: 2),
                ),
                onPressed: () async {
                  final res = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const Gallery()),
                  );
                  try {
                    if (res is Map && res['showOnlyMine'] == true) {
                      setState(() {
                        _filterOnlyMine = true;
                        // show arrow hint pointing to the clear-filter FAB for a short period
                        _showArrowHint = true;
                        _hintAnimController.repeat(reverse: true);
                        Future.delayed(const Duration(seconds: 6), () {
                          if (!mounted) return;
                          setState(() {
                            _showArrowHint = false;
                          });
                          try {
                            _hintAnimController.stop();
                          } catch (_) {}
                        });
                      });
                    }
                  } catch (_) {}
                },
                child: _outlinedIcon(
                  Icons.photo_library,
                  size: 20,
                  color: AppTheme.textColor,
                ),
              ),
            ),
          ),
          // AI Assistant button placed between Gallery and Clear-filter
          Positioned(
            // place with larger spacing between gallery (top:16) and clear-filter (now top:112)
            top: 64,
            right: 16,
            child: SafeArea(
              child: FloatingActionButton(
                heroTag: 'ai_assist_fab',
                mini: true,
                backgroundColor: AppTheme.primaryColor,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.black, width: 2),
                ),
                onPressed: () async {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AIAssistantScreen(),
                    ),
                  );
                },
                child: Image.asset(
                  'assets/icon/chatbot.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Clear filter button when only-my-items or advanced filters are active
          if (_filterOnlyMine || _filtersActive)
            Positioned(
              top: 112,
              right: 16,
              child: SafeArea(
                child: FloatingActionButton(
                  heroTag: 'clear_filter_fab',
                  mini: true,
                  backgroundColor: AppTheme.primaryColor,
                  shape: const CircleBorder(
                    side: BorderSide(color: Colors.black, width: 2),
                  ),
                  onPressed: () {
                    setState(() {
                      _filterOnlyMine = false;
                      _filtersActive = false;
                      _currentFilter = null;
                    });
                    // notify other screens that filters were cleared; suppress
                    // the automatic clear hint for this user-initiated action
                    try {
                      _suppressNextClearHint = true;
                      FilterBus.instance.publish(null);
                    } catch (_) {}
                  },
                  child: _filterOffIcon(size: 20),
                ),
              ),
            ),
          // Hint overlay pointing to the clear-filter FAB when active
          if (_showArrowHint)
            Positioned(
              top: 116,
              right: 68,
              child: FadeTransition(
                opacity: _hintOpacity,
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Text(
                          'clear_filter'.tr,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // red arrow with black outline
                      _outlinedIcon(
                        Icons.arrow_right_alt,
                        size: 28,
                        color: Colors.red.shade200,
                        // _outlinedIcon's outlineColor defaults to black, keep it
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // (debug FAB removed)
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
        child: SizedBox(
          width: 88,
          height: 88,
          child: FloatingActionButton(
            heroTag: 'camera_fab',
            backgroundColor: AppTheme.primaryColor,
            shape: const CircleBorder(
              side: BorderSide(color: Colors.black, width: 2),
            ),
            elevation: 8,
            child: _outlinedIcon(
              Icons.camera_alt,
              size: 60,
              color: AppTheme.textColor,
            ),
            onPressed: _takePhoto,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Helper to draw an icon with a black outline by drawing several
  // slightly-offset black copies beneath the main (foreground) icon.
  Widget _outlinedIcon(
    IconData icon, {
    required double size,
    required Color color,
    Color outlineColor = Colors.black,
  }) {
    const offsets = [
      Offset(-1.2, -1.2),
      Offset(0, -1.2),
      Offset(1.2, -1.2),
      Offset(-1.2, 0),
      Offset(1.2, 0),
      Offset(-1.2, 1.2),
      Offset(0, 1.2),
      Offset(1.2, 1.2),
    ];
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final off in offsets)
            Transform.translate(
              offset: off,
              child: Icon(icon, size: size, color: outlineColor),
            ),
          Icon(icon, size: size * 0.88, color: color),
        ],
      ),
    );
  }

  // Draw a filter-off icon: base filter icon with a red slash that has a black outline.
  Widget _filterOffIcon({double size = 20}) {
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // base filter icon (outlined)
          _outlinedIcon(
            Icons.filter_alt,
            size: size,
            color: AppTheme.textColor,
          ),
          // red slash with black outline painted on top
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _SlashPainter(
                color: Colors.red.shade400,
                outlineColor: Colors.black,
                strokeFraction: 0.18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhotoDialog(String url, Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (_) => PhotoDetailDialog(url: url, doc: doc),
    );
  }

  String _formatDocSummary(Map<String, dynamic> doc) {
    final url = doc['url'] ?? 'no-url';
    final owner = doc['ownerId'] ?? 'no-owner';
    final isPublic = doc['public'] ?? false;
    final location = doc['location'];
    String locText = 'no-location';
    try {
      if (location is GeoPoint)
        locText = 'GeoPoint(${location.latitude}, ${location.longitude})';
      else if (location is Map)
        locText = location.toString();
    } catch (_) {}
    return 'url: $url\nownerId: $owner\npublic: $isPublic\nlocation: $locText';
  }
}

class _SlashPainter extends CustomPainter {
  final Color color;
  final Color outlineColor;
  final double strokeFraction;

  _SlashPainter({
    required this.color,
    required this.outlineColor,
    this.strokeFraction = 0.16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pBlack = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * (strokeFraction + 0.06);
    final pRed = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * strokeFraction;

    // Draw slash from bottom-left towards top-right a bit inset
    final start = Offset(size.width * 0.18, size.height * 0.78);
    final end = Offset(size.width * 0.82, size.height * 0.22);
    canvas.drawLine(start, end, pBlack);
    canvas.drawLine(start, end, pRed);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
