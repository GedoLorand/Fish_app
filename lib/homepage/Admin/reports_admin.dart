import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class ReportsAdminScreen extends StatefulWidget {
  const ReportsAdminScreen({Key? key}) : super(key: key);

  @override
  State<ReportsAdminScreen> createState() => _ReportsAdminScreenState();
}

class _ReportsAdminScreenState extends State<ReportsAdminScreen> {
  final _reportsRef = FirebaseFirestore.instance.collection('reports');
  Stream<QuerySnapshot>? _reportsStream;
  bool _attemptedTokenRefresh = false;

  @override
  void initState() {
    super.initState();
    _prepareReportsStream();
  }

  Future<void> _prepareReportsStream() async {
    try {
      // Force-refresh ID token so custom claims (admin) are present
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.getIdTokenResult(true);
        } catch (_) {}
      }
    } catch (_) {}
    // Create the stream after token refresh so server permissions evaluate correctly
    try {
      setState(() {
        _reportsStream = _reportsRef
            .orderBy('createdAt', descending: true)
            .snapshots();
      });
    } catch (_) {
      setState(() {
        _reportsStream = const Stream.empty();
      });
    }
  }

  Future<void> _deleteReport(String docId) async {
    await _reportsRef.doc(docId).delete();
  }

  Future<void> _deleteImageFromFirestoreAndStorage(
    Map<String, dynamic> reportData,
  ) async {
    try {
      final String? imageDocId = reportData['imageDocId'] as String?;
      final String? ownerUid = reportData['imageOwnerUid'] as String?;
      final String? imageUrl = reportData['imageUrl'] as String?;

      // Try to delete Firestore document in users/{owner}/images/{id}
      if (ownerUid != null && imageDocId != null && !imageDocId.contains('/')) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(ownerUid)
              .collection('images')
              .doc(imageDocId)
              .delete();
        } catch (_) {}

        // Also try top-level images collection
        try {
          await FirebaseFirestore.instance
              .collection('images')
              .doc(imageDocId)
              .delete();
        } catch (_) {}
      }

      // If imageDocId looked like a fileName (not a doc id), also try to find
      // and delete any per-user docs that have fileName == imageDocId
      try {
        if (ownerUid != null && imageDocId != null) {
          final q = await FirebaseFirestore.instance
              .collection('users')
              .doc(ownerUid)
              .collection('images')
              .where('fileName', isEqualTo: imageDocId)
              .get();
          for (final d in q.docs) {
            try {
              final data = d.data();
              if (data['storagePath'] != null) {
                try {
                  await FirebaseStorage.instance
                      .ref()
                      .child(data['storagePath'] as String)
                      .delete();
                } catch (_) {}
              }
            } catch (_) {}
            try {
              await d.reference.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}

      // If imageDocId looks like a storage path (contains '/'), try deleting storage object
      if (imageDocId != null && imageDocId.contains('/')) {
        try {
          await FirebaseStorage.instance.ref().child(imageDocId).delete();
        } catch (_) {}
      }

      // Also try to find any documents in any images subcollections that reference this URL or fileName
      try {
        if (imageUrl != null && imageUrl.isNotEmpty) {
          final cg = await FirebaseFirestore.instance
              .collectionGroup('images')
              .where('url', isEqualTo: imageUrl)
              .get();
          for (final d in cg.docs) {
            try {
              final data = d.data();
              // If storagePath present, try to delete storage object
              try {
                if (data is Map && data['storagePath'] != null) {
                  final sp = data['storagePath'] as String;
                  await FirebaseStorage.instance.ref().child(sp).delete();
                }
              } catch (_) {}
              await d.reference.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}

      // Also try matching by fileName/file identifier if present
      try {
        if (imageDocId != null && imageDocId.isNotEmpty) {
          final cg2 = await FirebaseFirestore.instance
              .collectionGroup('images')
              .where('fileName', isEqualTo: imageDocId)
              .get();
          for (final d in cg2.docs) {
            try {
              final data = d.data();
              try {
                if (data is Map && data['storagePath'] != null) {
                  final sp = data['storagePath'] as String;
                  await FirebaseStorage.instance.ref().child(sp).delete();
                }
              } catch (_) {}
              await d.reference.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}

      // As a fallback, if we have imageUrl, try to derive storage path via full path
      if (imageUrl != null && imageUrl.contains('firebase')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
        } catch (_) {}
      }

      // Also attempt to delete any matching top-level /images documents by storagePath, fileName or url
      try {
        final topQuery = FirebaseFirestore.instance.collection('images');
        // By storagePath
        if (reportData['storagePath'] != null) {
          final sp = reportData['storagePath'] as String;
          final q = await topQuery.where('storagePath', isEqualTo: sp).get();
          for (final d in q.docs) {
            try {
              await FirebaseStorage.instance.ref().child(sp).delete();
            } catch (_) {}
            try {
              await d.reference.delete();
            } catch (_) {}
          }
        }
        // By fileName
        if (reportData['fileName'] != null) {
          final fn = reportData['fileName'] as String;
          final q2 = await topQuery.where('fileName', isEqualTo: fn).get();
          for (final d in q2.docs) {
            final data = d.data();
            try {
              if (data is Map && data['storagePath'] != null) {
                await FirebaseStorage.instance
                    .ref()
                    .child(data['storagePath'] as String)
                    .delete();
              }
            } catch (_) {}
            try {
              await d.reference.delete();
            } catch (_) {}
          }
        }
        // By url
        if (imageUrl != null && imageUrl.isNotEmpty) {
          final q3 = await topQuery.where('url', isEqualTo: imageUrl).get();
          for (final d in q3.docs) {
            final data = d.data();
            try {
              if (data is Map && data['storagePath'] != null) {
                await FirebaseStorage.instance
                    .ref()
                    .child(data['storagePath'] as String)
                    .delete();
              } else if (imageUrl.contains('firebase')) {
                try {
                  final ref = FirebaseStorage.instance.refFromURL(imageUrl);
                  await ref.delete();
                } catch (_) {}
              }
            } catch (_) {}
            try {
              await d.reference.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}

      // Notify other clients by updating the images_last_update ping doc so map listeners refresh
      try {
        await FirebaseFirestore.instance
            .collection('meta')
            .doc('images_last_update')
            .set({'ts': FieldValue.serverTimestamp()});
      } catch (_) {}
    } catch (e) {
      // ignore errors; admin action should be best-effort
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports (admin)'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: _reportsStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _reportsStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  // If permission denied, attempt one token refresh and recreate stream
                  final err = snap.error?.toString() ?? '';
                  if (!_attemptedTokenRefresh &&
                      err.contains('permission-denied')) {
                    _attemptedTokenRefresh = true;
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        user.getIdTokenResult(true).whenComplete(() {
                          try {
                            setState(() {
                              _reportsStream = _reportsRef
                                  .orderBy('createdAt', descending: true)
                                  .snapshots();
                            });
                          } catch (_) {}
                        });
                      } else {
                        try {
                          setState(() {
                            _reportsStream = _reportsRef
                                .orderBy('createdAt', descending: true)
                                .snapshots();
                          });
                        } catch (_) {}
                      }
                    } catch (_) {}
                    return const Center(
                      child: Text('Jogosultság frissítése, újrapróbálkozás...'),
                    );
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Hiba a jelentések lekérésekor: ${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snap.hasData || snap.data!.docs.isEmpty)
                  return const Center(child: Text('Nincsenek jelentések'));

                return ListView.separated(
                  itemCount: snap.data!.docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final doc = snap.data!.docs[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final reason = data['reason'] ?? '-';
                    final note = data['note'] ?? '';
                    final reporter =
                        data['reporterName'] ?? data['reporterEmail'] ?? 'Anon';
                    final imageUrl = data['imageUrl'] as String?;

                    return ListTile(
                      leading: imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (c, u) =>
                                    Container(color: Colors.grey.shade300),
                              ),
                            )
                          : const SizedBox(width: 60, height: 60),
                      title: Text('$reason — $reporter'),
                      subtitle: Text(note.toString()),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'delete_report') {
                            await _deleteReport(doc.id);
                            try {
                              await FirebaseFirestore.instance
                                  .collection('meta')
                                  .doc('images_last_update')
                                  .set({'ts': FieldValue.serverTimestamp()});
                            } catch (_) {}
                          } else if (v == 'delete_image') {
                            await _deleteImageFromFirestoreAndStorage(data);
                            // also remove the report after image deletion
                            await _deleteReport(doc.id);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'delete_report',
                            child: Text('Töröld a jelentést'),
                          ),
                          const PopupMenuItem(
                            value: 'delete_image',
                            child: Text('Töröld a képet (Firestore+Storage)'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
