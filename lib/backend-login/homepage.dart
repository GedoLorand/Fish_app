import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/MapScreen/map_screen.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';

class Homepage extends StatelessWidget {
  Homepage({super.key});

  signout() async {
    await FirebaseAuth.instance.signOut();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_avatar');
      await prefs.remove('user_name');
    } catch (_) {}
  }

  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalHeader(),
      drawer: CustomDrawer(),
      body: const MapScreen(),
    );
  }
}
