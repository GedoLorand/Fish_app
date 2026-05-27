import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final TextEditingController _nameController = TextEditingController();
  String? _avatarBase64;
  String _language = 'hu';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
      _avatarBase64 = prefs.getString('user_avatar');
      _language = prefs.getString('user_language') ?? 'hu';
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final encoded = base64Encode(bytes);
    setState(() {
      _avatarBase64 = encoded;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text);
    if (_avatarBase64 != null) {
      await prefs.setString('user_avatar', _avatarBase64!);
    }
    await prefs.setString('user_language', _language);
    // Apply locale immediately
    try {
      Get.updateLocale(Locale(_language));
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('settings_saved'.tr)));
  }

  @override
  Widget build(BuildContext context) {
    final avatarWidget = _avatarBase64 != null
        ? CircleAvatar(
            radius: 48,
            backgroundImage: MemoryImage(base64Decode(_avatarBase64!)),
          )
        : const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48));

    return Scaffold(
      appBar: GlobalHeader(),
      drawer: CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'user_settings'.tr,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Avatar
            Center(
              child: Column(
                children: [
                  avatarWidget,
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: Text('upload_image'.tr),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Name
            Text('name'.tr, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'enter_name'.tr,
              ),
            ),
            const SizedBox(height: 20),

            // Language
            Text('language'.tr, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _language,
              items: [
                DropdownMenuItem(value: 'hu', child: Text('lang_hu'.tr)),
                DropdownMenuItem(value: 'ro', child: Text('lang_ro'.tr)),
                DropdownMenuItem(value: 'en', child: Text('lang_en'.tr)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _language = v;
                });
              },
            ),
            const SizedBox(height: 32),

            // Save
            Center(
              child: ElevatedButton(
                onPressed: _saveSettings,
                child: Text('save'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
