import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

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

                  return ListView.builder(
                    itemCount: entriesRaw.length,
                    itemBuilder: (context, index) {
                      final dynamic raw = entriesRaw[index];
                      final Map<String, dynamic> entry = (raw is Map)
                          ? Map<String, dynamic>.from(raw)
                          : {};
                      final weight = entry['weight'] ?? 0;
                      final url = entry['url'] ?? '';
                      final uploader = entry['uploaderName'] ?? '';
                      final docId = entry['docId'] ?? '';
                      final titleText = uploader.isNotEmpty
                          ? '$weight kg · $uploader'
                          : '$weight kg';

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(titleText),
                          subtitle: Text(docId.isNotEmpty ? docId : '—'),
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
