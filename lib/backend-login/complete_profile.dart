import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/backend-login/wrapper.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class CompleteProfile extends StatefulWidget {
  final String uid;
  final String? email;
  final String? name;

  const CompleteProfile({super.key, required this.uid, this.email, this.name});

  @override
  State<CompleteProfile> createState() => _CompleteProfileState();
}

class _CompleteProfileState extends State<CompleteProfile> {
  String? _selectedGender;
  DateTime? _selectedBirthDate;
  bool _isLoading = false;

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedBirthDate = picked);
  }

  Future<void> _finish() async {
    if (_selectedGender == null || _selectedBirthDate == null) {
      Get.snackbar('Hiba', 'Kérlek töltsd ki a nemet és a születési dátumot');
      return;
    }

    setState(() => _isLoading = true);
    final age = DateTime.now().year - _selectedBirthDate!.year;

    final data = {
      'name': widget.name ?? '',
      'email': widget.email ?? '',
      'gender': _selectedGender,
      'birthDate': _selectedBirthDate!,
      'age': age,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set(data);
      Get.offAll(const Wrapper());
    } catch (e) {
      Get.snackbar('Hiba', 'Mentés sikertelen: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Profil kiegészítése'),
        backgroundColor: AppTheme.surfaceColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            color: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Email: ${widget.email ?? '-'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Név: ${widget.name ?? '-'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Nem',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Férfi')),
                      DropdownMenuItem(value: 'female', child: Text('Nő')),
                      DropdownMenuItem(value: 'other', child: Text('Egyéb')),
                    ],
                    onChanged: (v) => setState(() => _selectedGender = v),
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
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedBirthDate == null
                            ? 'Születési dátum kiválasztása'
                            : '${_selectedBirthDate!.year}-${_selectedBirthDate!.month}-${_selectedBirthDate!.day}',
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _finish,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: AppTheme.textColor,
                            ),
                            child: const Text('Befejezés'),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
