import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/backend-login/signup.dart';
import 'package:login_fish_app/backend-login/forgot.dart';
import 'package:login_fish_app/backend-login/wrapper.dart';
import 'package:login_fish_app/backend-login/auth_service.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();
  bool _isLoading = false;

  signIn() async {
    if (email.text.isEmpty || password.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );
      Get.offAll(Wrapper()); // Sikeres bejelentkezés után navigálás
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        'Hiba',
        e.code == 'user-not-found'
            ? 'Nincs ilyen felhasználó'
            : e.code == 'wrong-password'
            ? 'Hibás jelszó'
            : 'Bejelentkezési hiba',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Hiba', 'Váratlan hiba történt');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await AuthService.signInWithGoogle();
      if (userCredential.user != null) {
        Get.offAll(Wrapper());
      }
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        'Hiba',
        e.message ?? 'Google bejelentkezés hiba',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Hiba',
        'Váratlan hiba történt: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
              // Logo
              Center(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 100,
                  height: 100,
                ),
              ),
              const SizedBox(height: 24),

              // Card for inputs
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
                      const SizedBox(height: 18),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: signIn,
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
                                child: const Text('Bejelentkezés'),
                              ),
                            ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Image.asset(
                              'assets/icon/google.png',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          label: const Text(
                            'Folytatás Google-lal',
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

              const SizedBox(height: 18),
              TextButton(
                onPressed: () => Get.to(Signup()),
                child: Text(
                  'Regisztráció',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
              ),
              TextButton(
                onPressed: () => Get.to(Forgot()),
                child: Text(
                  'Elfelejtetted a jelszavad?',
                  style: TextStyle(color: AppTheme.textColor.withOpacity(0.9)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
