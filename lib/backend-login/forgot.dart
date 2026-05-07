import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class Forgot extends StatefulWidget {
  const Forgot({super.key});

  @override
  State<Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<Forgot> {
  final email = TextEditingController();
  bool _isLoading = false;

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  reset() async {
    final trimmedEmail = email.text.trim();

    if (trimmedEmail.isEmpty) {
      Get.snackbar('Hiba', 'Add meg az email címed');
      return;
    }

    if (!_isValidEmail(trimmedEmail)) {
      Get.snackbar('Hiba', 'Érvénytelen email formátum');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: trimmedEmail);
      Get.snackbar(
        'Sikeres',
        'Link elküldve a $trimmedEmail címre',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.back(); // Vissza a loginhoz
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        'Hiba',
        e.code == 'user-not-found' ? 'Nincs ilyen felhasználó' : 'Hiba történt',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 100,
                  height: 100,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: AppTheme.surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Add meg az email címed a jelszó visszaállításhoz',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: email,
                        decoration: const InputDecoration(
                          hintText: 'Email cím',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: reset,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: AppTheme.textColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Link küldése'),
                              ),
                            ),
                      TextButton(
                        onPressed: Get.back,
                        child: const Text('Vissza'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
