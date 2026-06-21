import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:login_fish_app/homepage/widgets/photo_detail_dialog.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _didCleanup = false;

  @override
  void initState() {
    super.initState();
    // Run a one-time cleanup to remove stale entries from leaderboard/top10
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeCleanupLeaderboard();
    });
  }

  Future<void> _maybeCleanupLeaderboard() async {
    if (_didCleanup) return;
    _didCleanup = true;
    final lbRef = FirebaseFirestore.instance
        .collection('leaderboard')
        .doc('top10');
    try {
      // Read leaderboard doc first (not in transaction) so we can run collectionGroup queries
      final snap = await lbRef.get();
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null || data['entries'] is! List) return;
      List entries = List.from(data['entries']);

      final cleaned = <dynamic>[];
      for (final e in entries) {
        try {
          if (e is Map &&
              e['docId'] is String &&
              (e['docId'] as String).isNotEmpty) {
            final String otherId = e['docId'] as String;
            // Check top-level images doc first
            try {
              final otherSnap = await FirebaseFirestore.instance
                  .collection('images')
                  .doc(otherId)
                  .get(GetOptions(source: Source.server));
              if (otherSnap.exists) {
                cleaned.add(e);
                continue;
              }
            } catch (_) {}
            // Fallback: check any images subcollection that stores docId field
            try {
              final q = await FirebaseFirestore.instance
                  .collectionGroup('images')
                  .where('docId', isEqualTo: otherId)
                  .limit(1)
                  .get(GetOptions(source: Source.server));
              if (q.docs.isNotEmpty) {
                cleaned.add(e);
                continue;
              }
            } catch (_) {}
          }
        } catch (_) {}
        var finalList = cleaned;
        if (finalList.length > 10) finalList = finalList.sublist(0, 10);
        while (finalList.length < 10) {
          finalList.add({
            'docId': '',
            'url': '',
            'weight': 0,
            'uploaderName': '',
            'createdAt': Timestamp.now(),
          });
        }
        await FirebaseFirestore.instance.runTransaction((tx) async {
          tx.set(lbRef, {'entries': finalList}, SetOptions(merge: true));
        });
      }
    } catch (_) {
      // ignore cleanup failures
    }
  }

  @override
  Widget build(BuildContext context) {
    final lbRef = FirebaseFirestore.instance
        .collection('leaderboard')
        .doc('top10');

    return Scaffold(
      appBar: AppBar(title: const Text('Toplista')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 10 legnagyobb fogás',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: lbRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Hiba: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  final data = snapshot.data!.data();
                  final List entriesRaw =
                      (data != null && data['entries'] is List)
                      ? List.from(data['entries'])
                      : [];

                  if (entriesRaw.isEmpty) {
                    return const Center(
                      child: Text('Nincs még adat a toplistához.'),
                    );
                  }
                  // Client-side: sort entries by weight desc and filter out missing docs
                  entriesRaw.sort((a, b) {
                    final da = (a is Map) ? a['weight'] : null;
                    final db = (b is Map) ? b['weight'] : null;
                    final wa = (da is num)
                        ? da.toDouble()
                        : double.negativeInfinity;
                    final wb = (db is num)
                        ? db.toDouble()
                        : double.negativeInfinity;
                    return wb.compareTo(wa);
                  });

                  // Validate existence of referenced image docs (remove stale entries)
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: () async {
                      final valid = <Map<String, dynamic>>[];
                      for (final raw in entriesRaw) {
                        try {
                          if (raw is! Map) continue;
                          final Map<String, dynamic> entry =
                              Map<String, dynamic>.from(raw);
                          final String docId = (entry['docId'] ?? '')
                              .toString();
                          // Skip placeholder / empty docId entries
                          if (docId.isEmpty) continue;
                          // Check top-level images collection for doc existence
                          try {
                            final snap = await FirebaseFirestore.instance
                                .collection('images')
                                .doc(docId)
                                .get();
                            if (snap.exists) {
                              valid.add(entry);
                              continue;
                            }
                          } catch (_) {}
                          // If not found in top-level, check any images subcollection by matching the 'docId' field
                          try {
                            final cg = await FirebaseFirestore.instance
                                .collectionGroup('images')
                                .where('docId', isEqualTo: docId)
                                .limit(1)
                                .get();
                            if (cg.docs.isNotEmpty) {
                              valid.add(entry);
                              continue;
                            }
                          } catch (_) {}
                          // If no document found, drop this entry (stale)
                        } catch (_) {}
                      }
                      return valid;
                    }(),
                    builder: (context, validSnap) {
                      if (validSnap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final List<Map<String, dynamic>> valid =
                          validSnap.data ?? [];
                      if (valid.isEmpty) {
                        return const Center(
                          child: Text('Nincs még adat a toplistához.'),
                        );
                      }

                      return ListView.builder(
                        itemCount: valid.length,
                        itemBuilder: (context, index) {
                          final entry = valid[index];
                          final weight = entry['weight'] ?? 0;
                          final url = entry['url'] ?? '';
                          final uploader = entry['uploaderName'] ?? '';
                          final docId = entry['docId'] ?? '';
                          final titleText = uploader.isNotEmpty
                              ? '$weight kg · $uploader'
                              : '$weight kg';

                          return Card(
                            child: ListTile(
                              onTap: () async {
                                Map<String, dynamic>? fullDoc;
                                try {
                                  if (docId.isNotEmpty) {
                                    final top = await FirebaseFirestore.instance
                                        .collection('images')
                                        .doc(docId)
                                        .get();
                                    if (top.exists)
                                      fullDoc = Map<String, dynamic>.from(
                                        top.data() ?? {},
                                      );
                                  }
                                } catch (_) {}
                                if (fullDoc == null) {
                                  try {
                                    final q = await FirebaseFirestore.instance
                                        .collectionGroup('images')
                                        .where('docId', isEqualTo: docId)
                                        .limit(1)
                                        .get();
                                    if (q.docs.isNotEmpty)
                                      fullDoc = Map<String, dynamic>.from(
                                        q.docs.first.data()
                                            as Map<String, dynamic>,
                                      );
                                  } catch (_) {}
                                }
                                fullDoc ??= {
                                  'docId': docId,
                                  'url': url,
                                  'weight': entry['weight'],
                                  'uploaderName': entry['uploaderName'],
                                };
                                if (!mounted) return;
                                showDialog(
                                  context: context,
                                  builder: (_) => PhotoDetailDialog(
                                    url: url.isNotEmpty ? url : null,
                                    doc: fullDoc,
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                child: Text('${index + 1}'),
                              ),
                              title: Text(titleText),
                              trailing: url.isNotEmpty
                                  ? SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) =>
                                              const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    )
                                  : const SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: Icon(Icons.image_not_supported),
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
