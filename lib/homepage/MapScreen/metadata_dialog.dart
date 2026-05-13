import 'dart:io';
import 'package:flutter/material.dart';

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
        backgroundColor: const Color(0xFFE8F5E9),
        title: const Text('Kép adatai'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null)
                Container(
                  height: 160,
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB9F6CA), Color(0xFF69F0AE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
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
                      decoration: const InputDecoration(labelText: 'Fajta'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Kötelező' : null,
                    ),
                    TextFormField(
                      controller: weightCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tömeg (kg)',
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
                          decoration: const InputDecoration(labelText: 'Csali'),
                        ),
                        TextFormField(
                          controller: feedCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Etetőanyag',
                          ),
                        ),
                        TextFormField(
                          controller: tempCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Víz hőmérséklet (°C)',
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        TextFormField(
                          controller: oxygenCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Oxigén tartalom (mg/L)',
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        TextFormField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Leírás',
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
              backgroundColor: const Color.fromARGB(255, 14, 66, 18),
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
