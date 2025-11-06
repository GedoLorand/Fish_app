import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';

class User extends StatefulWidget {
  const User({super.key});

  @override
  State<User> createState() => _UserState();
}

class _UserState extends State<User> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalHeader(),
      drawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Regisztráció",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              /// Felhasználónév
              const Text(
                "Felhasználónév",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              TextField(
                controller: _usernameController,
                autofillHints: const [], // teljesen kikapcsolva
                decoration: const InputDecoration(
                  hintText: "Add meg a felhasználóneved",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              /// Jelszó
              const Text(
                "Jelszó",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [], // teljesen kikapcsolva
                decoration: InputDecoration(
                  hintText: "Add meg a jelszavad",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              /// Regisztráció gomb
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 14, 66, 18),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {
                    String username = _usernameController.text;
                    String password = _passwordController.text;

                    print("Felhasználónév: $username");
                    print("Jelszó: $password");
                  },
                  child: const Text("Regisztráció"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
