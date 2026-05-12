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

    // build list of detail entries excluding common storage fields
    final details = <MapEntry<String, dynamic>>[];
    if (doc != null) {
      doc!.forEach((k, v) {
        if (k == 'url' || k == 'createdAt' || k == 'point') return;
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
                          Text(
                            'Kép megtekintése',
                            style: TextStyle(
                              color: AppTheme.textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // render all available details dynamically
                          for (final e in details)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                '${_labelForKey(e.key)}: ${e.value}',
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
        return 'Súly';
      case 'description':
        return 'Leírás';
      case 'bait':
        return 'Csali';
      case 'waterTemp':
        return 'Víz hőm.';
      default:
        // convert camelCase / snake_case to spaced label
        return key
            .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}')
            .replaceAll('_', ' ')
            .replaceFirst(key[0], key[0].toUpperCase());
    }
  }
}
