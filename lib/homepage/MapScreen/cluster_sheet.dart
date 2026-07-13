import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/utils/species_names.dart';

/// Shows a draggable bottom sheet listing photo entries.
///
/// [entries] is a list of maps with keys `url` and `doc` (same shape as in map_screen).
/// [onEntryTap] is called with the tapped entry after the sheet is popped.
Future<void> showClusterEntries(
  BuildContext context,
  List<Map<String, dynamic>> entries,
  void Function(Map<String, dynamic> entry) onEntryTap,
) async {
  String _formatWeight(dynamic w) {
    if (w == null) return '-';
    double? v;
    if (w is num)
      v = w.toDouble();
    else if (w is String)
      v = double.tryParse(w.replaceAll(',', '.'));
    if (v == null) return '-';
    return v.toStringAsFixed(3);
  }

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Találatok',
                        style: TextStyle(
                          color: AppTheme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final item = entries[index];
                    final url = item['url'] as String? ?? '';
                    final doc = item['doc'] as Map<String, dynamic>? ?? {};

                    String dateText = '';
                    if (doc['createdAt'] != null) {
                      try {
                        final dt = (doc['createdAt'] is Timestamp)
                            ? (doc['createdAt'] as Timestamp).toDate()
                            : DateTime.tryParse(doc['createdAt'].toString());
                        if (dt != null)
                          dateText = dt.toLocal().toString().split('.').first;
                      } catch (_) {}
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      color: AppTheme.surfaceColor,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          onEntryTap(item);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (url.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => Container(
                                    width: double.infinity,
                                    height: 220,
                                    color: Colors.grey.shade300,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (c, u, e) => Container(
                                    width: double.infinity,
                                    height: 220,
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
                                  if (doc['species'] != null ||
                                      doc['speciesKey'] != null)
                                    Text(
                                      '${'species_label'.tr}: ${displaySpeciesName(doc)}',
                                      style: TextStyle(
                                        color: AppTheme.textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  if (doc['weight'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        'Tömeg: ${_formatWeight(doc['weight'])} kg',
                                        style: TextStyle(
                                          color: AppTheme.textColor,
                                        ),
                                      ),
                                    ),
                                  if (dateText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        dateText,
                                        style: TextStyle(
                                          color: AppTheme.textColor.withOpacity(
                                            0.8,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: Text(
                                      'Bővebben',
                                      style: TextStyle(
                                        color: AppTheme.textColor,
                                      ),
                                    ),
                                    children: [
                                      if (doc['bait'] != null)
                                        ListTile(
                                          dense: true,
                                          title: Text(
                                            'Csali',
                                            style: TextStyle(
                                              color: AppTheme.textColor
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${doc['bait']}',
                                            style: TextStyle(
                                              color: AppTheme.textColor
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                        ),
                                      if (doc['feed'] != null)
                                        ListTile(
                                          dense: true,
                                          title: Text(
                                            'Etető',
                                            style: TextStyle(
                                              color: AppTheme.textColor
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${doc['feed']}',
                                            style: TextStyle(
                                              color: AppTheme.textColor
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                        ),
                                      if (doc['waterTemp'] != null)
                                        ListTile(
                                          dense: true,
                                          title: Text(
                                            'Víz hőmérséklet',
                                            style: TextStyle(
                                              color: AppTheme.textColor
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${doc['waterTemp']}°C',
                                            style: TextStyle(
                                              color: AppTheme.textColor
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                        ),
                                      if (doc['oxygen'] != null)
                                        ListTile(
                                          dense: true,
                                          title: Text(
                                            'Oxigén tartalom',
                                            style: TextStyle(
                                              color: AppTheme.textColor
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${doc['oxygen']}',
                                            style: TextStyle(
                                              color: AppTheme.textColor
                                                  .withOpacity(0.8),
                                            ),
                                          ),
                                        ),
                                      if (doc['notes'] != null)
                                        ListTile(
                                          dense: true,
                                          title: Text(
                                            'Leírás',
                                            style: TextStyle(
                                              color: AppTheme.textColor
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${doc['notes']}',
                                            style: TextStyle(
                                              color: AppTheme.textColor
                                                  .withOpacity(0.8),
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
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
