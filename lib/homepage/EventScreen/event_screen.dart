import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EventScreen extends StatelessWidget {
  const EventScreen({super.key});

  String _formatTs(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate().toLocal();
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowTs = Timestamp.fromDate(now);

    final stream = FirebaseFirestore.instance
        .collection('events')
        .where('startTime', isLessThanOrEqualTo: nowTs)
        .orderBy('startTime', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Aktív események')),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Hiba: ${snap.error}'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs.where((d) {
            try {
              final data = d.data() as Map<String, dynamic>;
              final end = data['endTime'];
              if (end is Timestamp) {
                return end.toDate().isAfter(now) || end.toDate().isAtSameMomentAs(now);
              }
              return true;
            } catch (_) {
              return false;
            }
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text('Nincsenek aktív események'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final d = docs[idx];
              final data = d.data() as Map<String, dynamic>;
              final title = (data['title'] as String?) ?? 'Esemény';
              final desc = (data['description'] as String?) ?? '';
              final start = data['startTime'] as Timestamp?;
              final end = data['endTime'] as Timestamp?;
              return ListTile(
                title: Text(title),
                subtitle: Text(desc.isNotEmpty ? desc : '${_formatTs(start)} — ${_formatTs(end)}'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(title),
                      content: SingleChildScrollView(
                        child: ListBody(
                          children: [
                            if (desc.isNotEmpty) Text(desc),
                            const SizedBox(height: 8),
                            Text('Kezdés: ${_formatTs(start)}'),
                            Text('Befejezés: ${_formatTs(end)}'),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Bezár'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
