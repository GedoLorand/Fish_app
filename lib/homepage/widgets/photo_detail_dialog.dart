import 'dart:math';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/homepage/MapScreen/route_helper.dart';
import 'package:get/get.dart';

class PhotoDetailDialog extends StatefulWidget {
  final String? url;
  final Map<String, dynamic>? doc;

  const PhotoDetailDialog({Key? key, this.url, this.doc}) : super(key: key);

  @override
  State<PhotoDetailDialog> createState() => _PhotoDetailDialogState();
}

class _PhotoDetailDialogState extends State<PhotoDetailDialog> {
  String? _avatarBase64;
  String? _uploaderName;
  String? _ownerId;
  String? _imageDocId;
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      // Try to fetch avatar of the uploader (ownerId) from Firestore
      final ownerId = widget.doc != null && widget.doc!.containsKey('ownerId')
          ? (widget.doc!['ownerId'] as String?)
          : null;
      if (ownerId != null && ownerId.trim().isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(ownerId)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data();
            if (data != null) {
              if (data['avatar'] != null) {
                final avatar = data['avatar'] as String?;
                if (!mounted) return;
                setState(() => _avatarBase64 = avatar);
                return;
              }
              if (data['name'] != null &&
                  (data['name'] as String).trim().isNotEmpty) {
                // prefer storing uploader name from user doc so renames are reflected
                if (!mounted) return;
                setState(() => _uploaderName = data['name'] as String?);
                // don't return; still allow prefs fallback for avatar
              }
            }
          }
        } catch (_) {}
      }
      // store ownerId and imageDocId for chat/actions
      _ownerId = ownerId;
      _imageDocId = widget.doc != null && widget.doc!.containsKey('docId')
          ? (widget.doc!['docId'] as String?)
          : (widget.doc != null && widget.doc!.containsKey('fileName')
                ? (widget.doc!['fileName'] as String?)
                : null);
      // Fallback: use local user avatar from shared preferences
      final prefs = await SharedPreferences.getInstance();
      // try to load a cached per-owner avatar in prefs before falling back to generic
      String? a;
      if (ownerId != null && ownerId.trim().isNotEmpty) {
        a = prefs.getString('user_avatar_$ownerId');
      } else {
        a = null;
      }
      if (!mounted) return;
      setState(() => _avatarBase64 = a);
    } catch (_) {}
  }

  // Ensure user docs (avatar/name) are cached for all senders found in messages.
  // This batches missing user fetches and falls back to SharedPreferences when Firestore doc is absent.
  bool _fetchingUsers = false;
  Future<void> _ensureUsersCached(List<QueryDocumentSnapshot> docs) async {
    if (_fetchingUsers) return;
    final missing = <String>{};
    for (final d in docs) {
      try {
        final m = d.data() as Map<String, dynamic>;
        final s = m['senderUid'] as String?;
        if (s != null && !_userCache.containsKey(s)) missing.add(s);
      } catch (_) {}
    }
    if (missing.isEmpty) return;
    _fetchingUsers = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final futures = missing.map((uid) async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (doc.exists && doc.data() != null)
            return MapEntry(uid, doc.data()!);
        } catch (_) {}
        // fallback to prefs keys
        final avatar = prefs.getString('user_avatar_$uid');
        final name = prefs.getString('user_name_$uid');
        final map = <String, dynamic>{};
        if (avatar != null) map['avatar'] = avatar;
        if (name != null) map['name'] = name;
        return MapEntry(uid, map);
      }).toList();

      final results = await Future.wait(futures);
      final Map<String, Map<String, dynamic>> updates = {};
      for (final e in results) updates[e.key] = e.value;
      if (!mounted) return;
      setState(() {
        _userCache.addAll(updates);
      });
    } finally {
      _fetchingUsers = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.9;

    // build ordered list of detail entries excluding common storage fields
    final doc = widget.doc;
    final details = <MapEntry<String, dynamic>>[];
    if (doc != null) {
      final order = [
        'species',
        'weight',
        'bait',
        'feed',
        'waterTemp',
        'oxygen',
        'notes',
      ];
      for (final k in order) {
        if (doc.containsKey(k) && doc[k] != null) {
          details.add(MapEntry(k, doc[k]));
        }
      }
      // append any other fields that are not in the ordered list
      doc.forEach((k, v) {
        // exclude fields that should not be shown in the dynamic details list
        if (k == 'url' ||
            k == 'createdAt' ||
            k == 'point' ||
            k == 'fileName' ||
            k == 'storagePath' ||
            k == 'docId' ||
            k == 'uid' ||
            k == 'location' ||
            k == 'ownerId' ||
            k == 'public' ||
            k == 'uploaderName' ||
            k == 'userDocPath')
          return;
        if (order.contains(k)) return;
        if (v == null) return;
        details.add(MapEntry(k, v));
      });
    }

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: mq.size.width * 0.95,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: AppTheme.primaryColor, width: 4.0),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageHeight = widget.url != null
                  ? min(360.0, constraints.maxHeight * 0.55)
                  : 0.0;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.url != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8.0),
                              topRight: Radius.circular(8.0),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: widget.url!,
                              fit: BoxFit.contain,
                              height: imageHeight,
                              width: double.infinity,
                              placeholder: (c, u) => Container(
                                width: double.infinity,
                                height: imageHeight,
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                  ),
                                ),
                              ),
                              errorWidget: (c, u, e) => Container(
                                width: double.infinity,
                                height: imageHeight,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                          // report button in top-left corner
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _openReportSheet(context),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.report,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // location button under the report button
                          Positioned(
                            top: 48,
                            left: 8,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () {
                                  // simple feedback for now; further behaviour will be added later
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Location')),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () =>
                                        RouteHelper.requestRouteFromDoc(
                                          context,
                                          widget.doc,
                                        ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Show uploader name prominently with avatar if available
                          // prefer the name stored on the user's Firestore doc so
                          // renames are immediately reflected across existing photos;
                          // fall back to the uploaderName stored on the image doc.
                          (() {
                            final docName =
                                doc != null &&
                                    doc['uploaderName'] != null &&
                                    (doc['uploaderName'] as String)
                                        .trim()
                                        .isNotEmpty
                                ? doc['uploaderName'] as String
                                : null;
                            final displayName = _uploaderName ?? docName;
                            if (displayName == null ||
                                displayName.trim().isEmpty)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${'uploader'.tr}: $displayName',
                                      style: TextStyle(
                                        color: AppTheme.textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // circle avatar from user settings if set (after name)
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.grey.shade800,
                                    backgroundImage: _avatarBase64 != null
                                        ? (_avatarBase64!.startsWith('http')
                                              ? NetworkImage(_avatarBase64!)
                                                    as ImageProvider
                                              : MemoryImage(
                                                  base64Decode(_avatarBase64!),
                                                ))
                                        : null,
                                    child: _avatarBase64 == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                ],
                              ),
                            );
                          })(),
                          // header removed per UX request
                          // render all available details dynamically
                          for (final e in details)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                '${_labelForKey(e.key)}: ${_displayValueForKey(e.key, e.value)}',
                                style: TextStyle(color: AppTheme.textColor),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.message,
                                  color: AppTheme.primaryColor,
                                ),
                                tooltip: 'private_message'.tr,
                                onPressed: _openPrivateChat,
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(
                                  'cancel'.tr,
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openReportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        final reasons = [
          'reason_poor_quality'.tr,
          'reason_wrong_image'.tr,
          'reason_not_fish'.tr,
          'reason_fake_data'.tr,
          'reason_fraud'.tr,
          'reason_other'.tr,
        ];
        String? selected;
        final TextEditingController noteCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (c, setState) {
            // ensure sheet can grow above keyboard and be scrollable
            final mq = MediaQuery.of(ctx);
            return Padding(
              padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'report_reason'.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final r in reasons)
                          RadioListTile<String>(
                            value: r,
                            groupValue: selected,
                            title: Text(
                              r,
                              style: TextStyle(color: AppTheme.textColor),
                            ),
                            onChanged: (v) => setState(() => selected = v),
                          ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: noteCtrl,
                          style: TextStyle(color: AppTheme.textColor),
                          decoration: InputDecoration(
                            labelText: 'report_note_optional'.tr,
                            labelStyle: TextStyle(
                              color: AppTheme.textColor.withOpacity(0.7),
                            ),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text('cancel'.tr),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: selected == null
                                  ? null
                                  : () async {
                                      // keep sheet visible while sending to ensure UX
                                      await _sendReport(
                                        selected!,
                                        noteCtrl.text.trim(),
                                      );
                                      if (mounted) Navigator.of(ctx).pop();
                                    },
                              child: Text('report_submit'.tr),
                            ),
                          ],
                        ),
                        // (private message button moved below into the details area)
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendReport(String reason, String note) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final reporterUid = user?.uid;
      final reporterEmail = user?.email;
      final reporterName = user?.displayName;

      final imageDocId = widget.doc != null && widget.doc!['docId'] != null
          ? widget.doc!['docId']
          : (widget.doc != null && widget.doc!['fileName'] != null
                ? widget.doc!['fileName']
                : null);

      final data = {
        'reporterUid': reporterUid,
        'reporterEmail': reporterEmail,
        'reporterName': reporterName,
        'imageDocId': imageDocId,
        'imageUrl': widget.url,
        'imageOwnerUid': widget.doc != null
            ? (widget.doc!['uid'] ?? widget.doc!['ownerId'])
            : null,
        'imageOwnerName': widget.doc != null
            ? widget.doc!['uploaderName']
            : null,
        'reason': reason,
        'note': note.isEmpty ? null : note,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('reports').add(data);

      // Optionally: trigger a mailto fallback for immediate manual email by user
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('report_sent'.tr)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'error_occurred'.tr}: ${e.toString()}')),
      );
    }
  }

  String _labelForKey(String key) {
    // simple mapping / beautifier for known fields
    switch (key) {
      case 'species':
        return 'species_label'.tr;
      case 'weight':
        return 'weight_kg'.tr;
      case 'notes':
        return 'description'.tr;
      case 'description':
        return 'description'.tr;
      case 'feed':
        return 'feed'.tr;
      case 'oxygen':
        return 'oxygen'.tr;
      case 'bait':
        return 'bait'.tr;
      case 'waterTemp':
        return 'water_temp'.tr;
      default:
        // convert camelCase / snake_case to spaced label
        return key
            .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}')
            .replaceAll('_', ' ')
            .replaceFirst(key[0], key[0].toUpperCase());
    }
  }

  String _displayValueForKey(String key, dynamic value) {
    if (value == null) return '-';
    switch (key) {
      case 'weight':
        double? v;
        if (value is num)
          v = value.toDouble();
        else if (value is String)
          v = double.tryParse(value.replaceAll(',', '.'));
        if (v == null) return value.toString();
        return '${v.toStringAsFixed(3)} kg';
      case 'waterTemp':
        return '${value.toString()}°C';
      default:
        return value.toString();
    }
  }

  void _openPrivateChat() {
    if (_imageDocId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('chat_unavailable'.tr)));
      return;
    }

    final imageMessagesRef = FirebaseFirestore.instance
        .collection('images')
        .doc(_imageDocId)
        .collection('messages');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        final TextEditingController ctrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: imageMessagesRef
                        .orderBy('createdAt', descending: false)
                        .snapshots(includeMetadataChanges: true),
                    builder: (c, snap) {
                      if (snap.hasError) {
                        final err = snap.error;
                        // ignore: avoid_print
                        print('Firestore image messages stream error: $err');
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'error_loading_messages: ${err.toString()}',
                            ),
                          ),
                        );
                      }
                      if (snap.connectionState == ConnectionState.waiting &&
                          (snap.data?.docs ?? []).isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty)
                        return Center(child: Text('no_messages'.tr));
                      // batch-fetch missing user profiles for avatars/names
                      _ensureUsersCached(docs);
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final m = docs[i].data() as Map<String, dynamic>;
                          final sender = m['senderUid'] as String?;
                          final text = m['text'] as String? ?? '';
                          final isMe =
                              sender == FirebaseAuth.instance.currentUser?.uid;

                          final userData = sender != null
                              ? _userCache[sender]
                              : null;
                          final avatarStr = userData != null
                              ? userData['avatar'] as String?
                              : null;
                          final displayName = userData != null
                              ? (userData['name'] as String?)
                              : null;

                          ImageProvider? avatarImage;
                          if (avatarStr != null && avatarStr.isNotEmpty) {
                            try {
                              avatarImage = avatarStr.startsWith('http')
                                  ? NetworkImage(avatarStr)
                                  : MemoryImage(base64Decode(avatarStr))
                                        as ImageProvider;
                            } catch (_) {
                              avatarImage = null;
                            }
                          }

                          final bubble = Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.blueAccent
                                  : Colors.grey.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe &&
                                    displayName != null &&
                                    displayName.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                Text(
                                  text,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          );

                          return Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: isMe
                                ? [
                                    // my message: bubble then my small avatar
                                    Flexible(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.75,
                                        ),
                                        child: bubble,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.grey.shade800,
                                      backgroundImage: avatarImage,
                                      child: avatarImage == null
                                          ? const Icon(Icons.person, size: 16)
                                          : null,
                                    ),
                                  ]
                                : [
                                    // other's message: avatar then bubble
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.grey.shade800,
                                      backgroundImage: avatarImage,
                                      child: avatarImage == null
                                          ? const Icon(Icons.person, size: 16)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.75,
                                        ),
                                        child: bubble,
                                      ),
                                    ),
                                  ],
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.text,
                            enableSuggestions: true,
                            autocorrect: true,
                            cursorColor: Colors.black,
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              hintText: 'type_message'.tr,
                              hintStyle: TextStyle(color: Colors.black54),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final text = ctrl.text.trim();
                          if (text.isEmpty) return;
                          final currentUid =
                              FirebaseAuth.instance.currentUser?.uid;
                          if (currentUid == null) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('not_signed_in'.tr)),
                            );
                            return;
                          }
                          try {
                            // build participants list (include sender and owner if available)
                            final participants = <String>{currentUid};
                            if (_ownerId != null && _ownerId!.trim().isNotEmpty)
                              participants.add(_ownerId!);

                            // DEBUG: log target path and payload to help find where messages are written
                            // (remove these prints after debugging)
                            // ignore: avoid_print
                            print(
                              'DEBUG: writing message to: ${imageMessagesRef.path}',
                            );
                            // ignore: avoid_print
                            print(
                              'DEBUG: message payload: ' +
                                  {
                                    'senderUid': currentUid,
                                    'text': text,
                                    'participants': participants.toList(),
                                  }.toString(),
                            );

                            await imageMessagesRef.add({
                              'senderUid': currentUid,
                              'text': text,
                              'participants': participants.toList(),
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            ctrl.clear();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${'send_failed'.tr}: ${e.toString()}',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
