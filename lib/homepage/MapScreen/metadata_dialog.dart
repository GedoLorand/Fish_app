import 'dart:io';
import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

Future<Map<String, dynamic>?> showMetadataDialog(
  BuildContext context,
  File? image,
) async {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController speciesCtrl = TextEditingController();
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController baitCtrl = TextEditingController();
  final TextEditingController feedCtrl = TextEditingController();
  final TextEditingController tempCtrl = TextEditingController();
  final TextEditingController oxygenCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Kép adatai', style: TextStyle(color: AppTheme.textColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null)
                Container(
                  height: 160,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.file(
                      image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: speciesCtrl,
                      style: TextStyle(color: AppTheme.textColor),
                      decoration: InputDecoration(
                        labelText: 'Fajta',
                        labelStyle: TextStyle(
                          color: AppTheme.textColor.withOpacity(0.85),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Kötelező' : null,
                    ),
                    TextFormField(
                      controller: weightCtrl,
                      style: TextStyle(color: AppTheme.textColor),
                      decoration: InputDecoration(
                        labelText: 'Tömeg (kg)',
                        labelStyle: TextStyle(
                          color: AppTheme.textColor.withOpacity(0.85),
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Kötelező' : null,
                    ),
                    const SizedBox(height: 8.0),
                    ExpansionTile(
                      title: const Text('Bővebben'),
                      children: [
                        TextFormField(
                          controller: baitCtrl,
                          style: TextStyle(color: AppTheme.textColor),
                          decoration: InputDecoration(
                            labelText: 'Csali',
                            labelStyle: TextStyle(
                              color: AppTheme.textColor.withOpacity(0.85),
                            ),
                          ),
                        ),
                        TextFormField(
                          controller: feedCtrl,
                          style: TextStyle(color: AppTheme.textColor),
                          decoration: InputDecoration(
                            labelText: 'Etető',
                            labelStyle: TextStyle(
                              color: AppTheme.textColor.withOpacity(0.85),
                            ),
                          ),
                        ),
                        TextFormField(
                          controller: tempCtrl,
                          style: TextStyle(color: AppTheme.textColor),
                          decoration: InputDecoration(
                            labelText: 'Víz hőmérséklet (°C)',
                            labelStyle: TextStyle(
                              color: AppTheme.textColor.withOpacity(0.85),
                            ),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        TextFormField(
                          controller: oxygenCtrl,
                          style: TextStyle(color: AppTheme.textColor),
                          decoration: InputDecoration(
                            labelText: 'Oxigén tartalom (mg/L)',
                            labelStyle: TextStyle(
                              color: AppTheme.textColor.withOpacity(0.85),
                            ),
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        TextFormField(
                          controller: notesCtrl,
                          style: TextStyle(color: AppTheme.textColor),
                          decoration: InputDecoration(
                            labelText: 'Leírás',
                            labelStyle: TextStyle(
                              color: AppTheme.textColor.withOpacity(0.85),
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Mégse'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                double? weight;
                final wText = weightCtrl.text.trim();
                try {
                  final parsed = double.parse(wText.replaceAll(',', '.'));
                  weight = (parsed * 1000).round() / 1000.0;
                } catch (_) {
                  weight = null;
                }
                final data = <String, dynamic>{
                  'species': speciesCtrl.text.trim(),
                  'weight': weight ?? weightCtrl.text.trim(),
                  'bait': baitCtrl.text.trim().isEmpty
                      ? null
                      : baitCtrl.text.trim(),
                  'feed': feedCtrl.text.trim().isEmpty
                      ? null
                      : feedCtrl.text.trim(),
                  'waterTemp': tempCtrl.text.trim().isEmpty
                      ? null
                      : tempCtrl.text.trim(),
                  'oxygen': oxygenCtrl.text.trim().isEmpty
                      ? null
                      : oxygenCtrl.text.trim(),
                  'notes': notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                };
                Navigator.of(context).pop(data);
              }
            },
            child: const Text('Mentés'),
          ),
        ],
      );
    },
  );
}
