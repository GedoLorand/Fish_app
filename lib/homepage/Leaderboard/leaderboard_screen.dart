import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/widgets/photo_detail_dialog.dart';
import 'package:login_fish_app/utils/species_names.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _globalImagesStream() {
    return FirebaseFirestore.instance.collectionGroup('images').snapshots();
  }

  List<Map<String, dynamic>> _buildGlobalTop10(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final byId = <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      final weight = _parseWeight(
        data['weight'] ?? data['weightKg'] ?? data['kg'],
      );
      if (weight == null || weight <= 0) continue;

      data['weight'] = weight;
      data['docPath'] = doc.reference.path;
      data['docId'] = (data['docId'] ?? doc.id).toString();

      final key = data['docId'].toString().isNotEmpty
          ? data['docId'].toString()
          : doc.reference.path;
      final previous = byId[key];
      if (previous == null || weight > (previous['weight'] as num).toDouble()) {
        byId[key] = data;
      }
    }

    final entries = byId.values.toList()
      ..sort((a, b) {
        final weightCompare = (b['weight'] as num).compareTo(
          a['weight'] as num,
        );
        if (weightCompare != 0) return weightCompare;

        final aTime = _createdAtMillis(a['createdAt']);
        final bTime = _createdAtMillis(b['createdAt']);
        return bTime.compareTo(aTime);
      });

    return entries.take(10).toList();
  }

  static double? _parseWeight(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  static int _createdAtMillis(dynamic value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  static String _formatWeight(dynamic value) {
    final parsed = _parseWeight(value);
    if (parsed == null) return value?.toString() ?? '-';
    return parsed.toStringAsFixed(3);
  }

  @override
  Widget build(BuildContext context) {
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
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _globalImagesStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Hiba: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final entries = _buildGlobalTop10(snapshot.data!);
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text('Nincs még adat a toplistához.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final url = (entry['url'] ?? '').toString();
                      final uploader = (entry['uploaderName'] ?? '').toString();
                      final species = displaySpeciesName(entry);
                      final titleText = '${_formatWeight(entry['weight'])} kg';
                      final subtitleParts = <String>[
                        if (species.trim().isNotEmpty) species,
                        if (uploader.trim().isNotEmpty) uploader,
                      ];

                      return Card(
                        child: ListTile(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => PhotoDetailDialog(
                                url: url.isNotEmpty ? url : null,
                                doc: entry,
                                imageDocId: entry['docId']?.toString(),
                              ),
                            );
                          },
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(titleText),
                          subtitle: subtitleParts.isEmpty
                              ? null
                              : Text(subtitleParts.join(' · ')),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
