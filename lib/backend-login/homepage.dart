import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/MapScreen/map_screen.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';

class Homepage extends StatelessWidget {
  Homepage({super.key});

  signout() async {
    await FirebaseAuth.instance.signOut();
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
