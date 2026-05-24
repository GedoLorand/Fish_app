import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/backend-login/wrapper.dart';
import 'package:login_fish_app/backend-login/auth_service.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:login_fish_app/backend-login/complete_profile.dart';
import 'package:login_fish_app/backend-login/login.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController name = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;

  DateTime? _selectedBirthDate;

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  signup() async {
    if (email.text.isEmpty ||
        password.text.isEmpty ||
        name.text.isEmpty ||
        _selectedGender == null ||
        _selectedBirthDate == null) {
      Get.snackbar('Error', 'Please fill all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🚀 Starting registration...');

      // 1. Authentication
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.text.trim(),
            password: password.text.trim(),
          );

      final userId = userCredential.user!.uid;
      print('✅ Auth success - User ID: $userId');

      final age = _calculateAge(_selectedBirthDate!);

      final userData = {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'gender': _selectedGender,
        'birthDate': _selectedBirthDate!,
        'age': age,
        'createdAt': FieldValue.serverTimestamp(),
      };

      print('📊 Data to save: $userData');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(userData);

      print('🎉 Firestore success - Data saved!');

      Get.offAll(Wrapper());
    } on FirebaseAuthException catch (e) {
      print('❌ Auth error: ${e.code}');
      Get.snackbar(
        'Error',
        e.code == 'email-already-in-use'
            ? 'Email already in use'
            : 'Registration error',
      );
    } catch (e) {
      print('❌ General error: $e');
      Get.snackbar('Error', 'Something went wrong: $e');
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
                  'assets/icon/app_icon_uszo.png',
                  width: 100,
                  height: 100,
                ),
              ),
              const SizedBox(height: 20),

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
                      TextField(
                        controller: name,
                        style: TextStyle(
                          color: AppTheme.textColor.withOpacity(0.95),
                        ),
                        cursorColor: AppTheme.textColor,
                        decoration: InputDecoration(
                          hintText: 'Név',
                          hintStyle: TextStyle(
                            color: AppTheme.textColor.withOpacity(0.6),
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: email,
                        style: TextStyle(
                          color: AppTheme.textColor.withOpacity(0.95),
                        ),
                        cursorColor: AppTheme.textColor,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          hintStyle: TextStyle(
                            color: AppTheme.textColor.withOpacity(0.6),
                          ),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        style: TextStyle(
                          color: AppTheme.textColor.withOpacity(0.95),
                        ),
                        cursorColor: AppTheme.textColor,
                        decoration: InputDecoration(
                          hintText: 'Jelszó',
                          hintStyle: TextStyle(
                            color: AppTheme.textColor.withOpacity(0.6),
                          ),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: InputDecoration(
                          hintText: 'Nem',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Férfi')),
                          DropdownMenuItem(value: 'female', child: Text('Nő')),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Egyéb'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedGender = value),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _selectBirthDate(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _selectedBirthDate == null
                                ? 'Születési dátum kiválasztása'
                                : '${_selectedBirthDate!.year}-${_selectedBirthDate!.month}-${_selectedBirthDate!.day}',
                            style: TextStyle(
                              color: _selectedBirthDate == null
                                  ? Colors.grey
                                  : AppTheme.textColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: signup,
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
                                child: const Text('Regisztráció'),
                              ),
                            ),
                      const SizedBox(height: 12),
                      // Button to go back to the login screen
                      TextButton(
                        onPressed: () => Get.to(() => Login()),
                        child: Text(
                          'Vissza a bejelentkezéshez',
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            setState(() => _isLoading = true);
                            try {
                              // Sign in with Firebase using Google. This will throw
                              // if the email is already registered with a different method.
                              final cred = await AuthService.signInWithGoogle();
                              if (cred.user != null) {
                                final userId = cred.user!.uid;
                                final userDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .get();
                                if (!userDoc.exists) {
                                  Get.to(
                                    CompleteProfile(
                                      uid: userId,
                                      email: cred.user!.email,
                                      name: cred.user!.displayName,
                                    ),
                                  );
                                } else {
                                  Get.offAll(Wrapper());
                                }
                              }
                            } on FirebaseAuthException catch (e) {
                              if (e.code ==
                                      'account-exists-with-different-credential' ||
                                  e.code ==
                                      'ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL') {
                                Get.snackbar(
                                  'Hiba',
                                  'Ezzel az email-címmel már létezik fiók. Kérlek jelentkezz be e-maillel.',
                                );
                                await GoogleSignIn().signOut();
                              } else {
                                Get.snackbar(
                                  'Error',
                                  'Google sign up failed: ${e.message ?? e.code}',
                                );
                              }
                            } catch (e) {
                              Get.snackbar(
                                'Error',
                                'Google sign up failed: $e',
                              );
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          },
                          icon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Image.asset(
                              'assets/icon/google.png',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          label: const Text(
                            'Regisztráció Google-lal',
                            style: TextStyle(color: Colors.black87),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
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
