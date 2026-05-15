import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class PhotoDetailDialog extends StatelessWidget {
  final String? url;
  final Map<String, dynamic>? doc;

  const PhotoDetailDialog({Key? key, this.url, this.doc}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.9;

    // build ordered list of detail entries excluding common storage fields
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
        if (doc!.containsKey(k) && doc![k] != null) {
          details.add(MapEntry(k, doc![k]));
        }
      }
      // append any other fields that are not in the ordered list
      doc!.forEach((k, v) {
        // exclude fields that should not be shown in the dynamic details list
        if (k == 'url' ||
            k == 'createdAt' ||
            k == 'point' ||
            k == 'fileName' ||
            k == 'uid' ||
            k == 'location' ||
            k == 'ownerId' ||
            k == 'public' ||
            k == 'uploaderName')
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
              final imageHeight = url != null
                  ? min(360.0, constraints.maxHeight * 0.55)
                  : 0.0;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (url != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8.0),
                          topRight: Radius.circular(8.0),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: url!,
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
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Show uploader name prominently if available
                          if (doc != null &&
                              doc!['uploaderName'] != null &&
                              (doc!['uploaderName'] as String)
                                  .trim()
                                  .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Feltöltő: ${doc!['uploaderName']}',
                                style: TextStyle(
                                  color: AppTheme.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
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
                                'Bezár',
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

  String _labelForKey(String key) {
    // simple mapping / beautifier for known fields
    switch (key) {
      case 'species':
        return 'Fajta';
      case 'weight':
        return 'Tömeg';
      case 'notes':
        return 'Leírás';
      case 'description':
        return 'Leírás';
      case 'feed':
        return 'Etető';
      case 'oxygen':
        return 'Oxigén tartalom';
      case 'bait':
        return 'Csali';
      case 'waterTemp':
        return 'Víz hőmérséklet';
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
