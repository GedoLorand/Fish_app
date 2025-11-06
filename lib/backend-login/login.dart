import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/backend-login/signup.dart';
import 'package:login_fish_app/backend-login/forgot.dart';
import 'package:login_fish_app/backend-login/wrapper.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: email,
              decoration: InputDecoration(hintText: 'Enter email'),
            ),
            TextField(
              controller: password,
              decoration: InputDecoration(hintText: 'Enter password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(onPressed: signIn, child: Text("Login")),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Get.to(Signup()),
              child: Text("Register now"),
            ),
            TextButton(
              onPressed: () => Get.to(Forgot()),
              child: Text("Forgot password?"),
            ),
          ],
        ),
      ),
    );
  }
}
