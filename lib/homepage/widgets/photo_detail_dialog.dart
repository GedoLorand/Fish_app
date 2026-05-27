import 'dart:math';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final a = prefs.getString('user_avatar');
      if (!mounted) return;
      setState(() => _avatarBase64 = a);
    } catch (_) {}
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
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Show uploader name prominently with avatar if available
                          if (doc != null &&
                              doc['uploaderName'] != null &&
                              (doc['uploaderName'] as String).trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${'uploader'.tr}: ${doc['uploaderName']}',
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
                                        ? MemoryImage(
                                            base64Decode(_avatarBase64!),
                                          )
                                        : null,
                                    child: _avatarBase64 == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'cancel'.tr,
                                style: TextStyle(color: AppTheme.primaryColor),
                              ),
                            ),
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
}
