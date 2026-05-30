import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // Only use the per-user cached avatar when signed in.
    String? localAvatar = uid != null
        ? prefs.getString('user_avatar_$uid')
        : null;
    String? firestoreAvatar;
    String? firestoreName;
    try {
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            if (data['avatar'] != null)
              firestoreAvatar = data['avatar'] as String?;
            if (data['name'] != null) firestoreName = data['name'] as String?;
          }
        }
      }
    } catch (_) {}

    // Determine initial name: prefer Firestore name, then per-user prefs,
    // then auth displayName, then email local-part, else empty.
    String initialName = '';
    final authUser = FirebaseAuth.instance.currentUser;
    if (firestoreName != null && firestoreName.trim().isNotEmpty) {
      initialName = firestoreName;
    } else if (uid != null && prefs.getString('user_name_$uid') != null) {
      initialName = prefs.getString('user_name_$uid')!;
    } else if (authUser?.displayName != null &&
        authUser!.displayName!.trim().isNotEmpty) {
      initialName = authUser!.displayName!;
    } else if (authUser?.email != null) {
      initialName = authUser!.email!.split('@').first;
    }

    setState(() {
      _nameController.text = initialName;
      _avatarBase64 = firestoreAvatar ?? localAvatar;
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
      // keep local base64 to preview until saved (will be uploaded on save)
      _avatarBase64 = encoded;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await prefs.setString('user_name_$uid', _nameController.text);
      try {
        final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
        await docRef.set({
          'name': _nameController.text,
        }, SetOptions(merge: true));
      } catch (_) {}
    } else {
      await prefs.setString('user_name', _nameController.text);
    }
    if (_avatarBase64 != null) {
      // If _avatarBase64 looks like a URL we already saved it; otherwise upload
      if (_avatarBase64!.startsWith('http')) {
        if (uid != null) {
          await prefs.setString('user_avatar_$uid', _avatarBase64!);
        } else {
          await prefs.setString('user_avatar', _avatarBase64!);
        }
      } else {
        // Upload to Firebase Storage and save URL to prefs and Firestore
        try {
          if (uid != null) {
            final bytes = base64Decode(_avatarBase64!);
            final ref = FirebaseStorage.instance.ref().child(
              'avatars/$uid.jpg',
            );
            await ref.putData(
              bytes,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            final url = await ref.getDownloadURL();
            if (uid != null) await prefs.setString('user_avatar_$uid', url);
            _avatarBase64 = url;
            // Save URL to Firestore users/{uid}.avatar
            final docRef = FirebaseFirestore.instance
                .collection('users')
                .doc(uid);
            await docRef.set({'avatar': url}, SetOptions(merge: true));
          } else {
            // no uid; fallback to local storage
            await prefs.setString('user_avatar', _avatarBase64!);
          }
        } catch (_) {
          if (uid != null) {
            await prefs.setString('user_avatar_$uid', _avatarBase64!);
          } else {
            await prefs.setString('user_avatar', _avatarBase64!);
          }
        }
      }
    }
    await prefs.setString('user_language', _language);
    // (avatar saved above) ensure locale applied
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
            backgroundImage: _avatarBase64!.startsWith('http')
                ? NetworkImage(_avatarBase64!) as ImageProvider
                : MemoryImage(base64Decode(_avatarBase64!)),
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
                DropdownMenuItem(
                  value: 'hu',
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icon/hu_icon.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 8),
                      Text('lang_hu'.tr),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'ro',
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icon/ro_icon.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 8),
                      Text('lang_ro'.tr),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icon/en_icon.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 8),
                      Text('lang_en'.tr),
                    ],
                  ),
                ),
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
