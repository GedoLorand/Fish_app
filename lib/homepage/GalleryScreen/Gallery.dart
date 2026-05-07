import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Gallery extends StatefulWidget {
  const Gallery({super.key});

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _photosStream() {
    final uid = _uid;
    if (uid == null) {
      // empty stream if not logged in
      return const Stream.empty();
    }
    // Read images from user-scoped collection to match security rules
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('images')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _showPhotoDetails(Map<String, dynamic> data) {
    final url = data['url'] as String?;
    final species = data['species'] ?? '-';
    final weight = data['weight'] ?? '-';
    DateTime? createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text(
          'Kép részletei',
          style: TextStyle(color: AppTheme.textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (url != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(url, height: 220, fit: BoxFit.cover),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Fajta: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(species.toString())),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Súly: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(weight.toString())),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Feltöltés: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      createdAt != null ? createdAt.toLocal().toString() : '-',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Bezár',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalHeader(),
      drawer: CustomDrawer(),
      body: _uid == null
          ? const Center(
              child: Text('Be kell jelentkezned, hogy lásd a galériát'),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _photosStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Még nincsenek képeid'));
                }
                final docs = snapshot.data!.docs;
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final url = data['url'] as String?;
                      return GestureDetector(
                        onTap: () => _showPhotoDetails(data),
                        child: Card(
                          clipBehavior: Clip.hardEdge,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: url != null
                              ? Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                )
                              : const Center(child: Text('Nincs kép')),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(
            top: BorderSide(color: AppTheme.textColor.withOpacity(0.12)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bal oldali gomb - Filter
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: TextButton(
                onPressed: () {}, // Üres függvény most
                child: Row(
                  children: [
                    Icon(Icons.filter_alt, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Filter',
                      style: TextStyle(
                        color: AppTheme.textColor,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Jobb oldali gomb - My Map
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: TextButton(
                onPressed: () {}, // Üres függvény most
                child: Text(
                  'My Map',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
