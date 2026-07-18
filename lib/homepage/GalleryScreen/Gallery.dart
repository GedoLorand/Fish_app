import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:login_fish_app/homepage/widgets/photo_detail_dialog.dart';
import 'package:login_fish_app/homepage/FilterScreen/filter.dart'
    as filter_screen;

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

  void _showPhotoDetails(
    Map<String, dynamic> data, {
    required String imageDocId,
  }) {
    final url = data['url'] as String?;
    final species = data['species'] ?? '-';
    final weight = data['weight'] ?? '-';
    DateTime? createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    }

    showDialog(
      context: context,
      builder: (context) =>
          PhotoDetailDialog(url: url, doc: data, imageDocId: imageDocId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalHeader(),
      drawer: CustomDrawer(),
      body: _uid == null
          ? Center(child: Text('not_logged_in_gallery'.tr))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _photosStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('no_images_yet'.tr));
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
                        onTap: () =>
                            _showPhotoDetails(data, imageDocId: docs[index].id),
                        child: Card(
                          clipBehavior: Clip.hardEdge,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: url != null
                              ? CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  errorWidget: (c, u, e) => const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                                )
                              : Center(child: Text('no_image'.tr)),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 10,
            bottom: (MediaQuery.of(context).padding.bottom + 10) * 0.25,
          ),
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
                padding: const EdgeInsets.only(left: 8.0),
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(72, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const filter_screen.Filter(
                          restrictToCurrentUser: true,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Icon(Icons.filter_alt, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'filters'.tr,
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
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(72, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop({'showOnlyMine': true});
                  },
                  child: Text(
                    'my_map'.tr,
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
      ),
    );
  }
}
