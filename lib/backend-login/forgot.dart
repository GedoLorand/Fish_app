import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

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
      appBar: AppBar(title: const Text("Jelszó visszaállítás")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Add meg az email címed a jelszó visszaállításhoz'),
            const SizedBox(height: 20),
            TextField(
              controller: email,
              decoration: const InputDecoration(
                hintText: 'Email cím',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: reset,
                    child: const Text("Link küldése"),
                  ),
            TextButton(onPressed: Get.back, child: const Text('Vissza')),
          ],
        ),
      ),
    );
  }
}
