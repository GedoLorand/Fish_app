import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';
//import 'package:flutterlogin_fish_app/homepage//initialType.dart';

class Settings extends StatelessWidget {
  const Settings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalHeader(),
      drawer: CustomDrawer(),
      body: const Center(child: Text("Itt lesznek a bealitasok")),
    );
  }
}
