import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/backend-login/wrapper.dart';

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
      appBar: AppBar(title: Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Név
            TextField(
              controller: name,
              decoration: InputDecoration(
                hintText: 'Full name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),

            // Email
            TextField(
              controller: email,
              decoration: InputDecoration(
                hintText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 10),

            // Jelszó
            TextField(
              controller: password,
              decoration: InputDecoration(
                hintText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            SizedBox(height: 10),

            // Nem
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: InputDecoration(
                hintText: 'Select Gender',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
            SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Birth Date',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 5),
                  GestureDetector(
                    onTap: () => _selectBirthDate(context),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 20),
                        SizedBox(width: 10),
                        Text(
                          _selectedBirthDate == null
                              ? 'Select your birth date'
                              : '${_selectedBirthDate!.year}-${_selectedBirthDate!.month}-${_selectedBirthDate!.day}',
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedBirthDate == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedBirthDate != null) ...[
              SizedBox(height: 10),
              Text(
                'Age: ${_calculateAge(_selectedBirthDate!)} years old',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],

            SizedBox(height: 20),

            // Regisztráció gomb
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: signup,
                    child: Text("Sign Up"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
