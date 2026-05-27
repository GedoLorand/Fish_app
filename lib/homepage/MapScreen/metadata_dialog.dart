import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

// TextInputFormatter that normalizes comma to dot, allows only digits and a single
// decimal separator and limits fraction length to 3 digits.
class WeightInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String src = newValue.text.replaceAll(',', '.');
    if (src.isEmpty) return newValue.copyWith(text: '');

    final buffer = StringBuffer();
    bool dotSeen = false;
    for (var i = 0; i < src.length; i++) {
      final ch = src[i];
      if (ch == '.') {
        if (!dotSeen) {
          dotSeen = true;
          buffer.write('.');
        } else {
          // skip additional dots
        }
      } else if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        buffer.write(ch);
      } else {
        // skip any other character
      }
    }

    String result = buffer.toString();
    if (dotSeen) {
      final parts = result.split('.');
      if (parts.length > 1 && parts[1].length > 3) {
        final frac = parts[1].substring(0, 3);
        result = '${parts[0]}.$frac';
      }
    }

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

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
        title: Text('photo_details'.tr, style: TextStyle(color: AppTheme.textColor)),
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
                        labelText: 'species_label'.tr,
                        labelStyle: TextStyle(
                          color: AppTheme.textColor.withOpacity(0.85),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'required'.tr : null,
                    ),
                    TextFormField(
                      controller: weightCtrl,
                      style: TextStyle(color: AppTheme.textColor),
                      decoration: InputDecoration(
                        labelText: 'weight_kg'.tr,
                        labelStyle: TextStyle(
                          color: AppTheme.textColor.withOpacity(0.85),
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                        WeightInputFormatter(),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'required'.tr;
                        final txt = v.trim().replaceAll(',', '.');
                        final parsed = double.tryParse(txt);
                        if (parsed == null) return 'invalid_number'.tr;
                        final parts = txt.split('.');
                        if (parts.length > 1 && parts[1].length > 3) {
                          return 'max_decimals'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8.0),
                    ExpansionTile(
                      title: Text('more'.tr),
                      children: [
                        TextFormField(
                          controller: baitCtrl,
                          style: TextStyle(color: AppTheme.textColor),
                          decoration: InputDecoration(
                            labelText: 'bait'.tr,
                            labelStyle: TextStyle(
                              color: AppTheme.textColor.withOpacity(0.85),
                            ),
                          ),
                        ),
                        TextFormField(
                          controller: feedCtrl,
                          style: TextStyle(color: AppTheme.textColor),
                          decoration: InputDecoration(
                            labelText: 'feed'.tr,
                            labelStyle: TextStyle(
                              color: AppTheme.textColor.withOpacity(0.85),
                            ),
                          ),
                        ),
                        TextFormField(
                          controller: tempCtrl,
                          style: TextStyle(color: AppTheme.textColor),
                          decoration: InputDecoration(
                            labelText: 'water_temp'.tr,
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
                            labelText: 'oxygen'.tr,
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
                            labelText: 'description'.tr,
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
            child: Text('cancel'.tr),
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
                  'bait': baitCtrl.text.trim().isEmpty ? null : baitCtrl.text.trim(),
                  'feed': feedCtrl.text.trim().isEmpty ? null : feedCtrl.text.trim(),
                  'waterTemp': tempCtrl.text.trim().isEmpty ? null : tempCtrl.text.trim(),
                  'oxygen': oxygenCtrl.text.trim().isEmpty ? null : oxygenCtrl.text.trim(),
                  'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                };
                Navigator.of(context).pop(data);
              }
            },
            child: Text('save'.tr),
          ),
        ],
      );
    },
  );
}
