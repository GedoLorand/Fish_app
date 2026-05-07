import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class ThemeController extends GetxController {
  final RxBool isDark = true.obs;

  @override
  void onInit() {
    super.onInit();
    // Start in dark mode by default
    Get.changeThemeMode(ThemeMode.dark);
  }

  void toggle() {
    isDark.value = !isDark.value;
    Get.changeThemeMode(isDark.value ? ThemeMode.dark : ThemeMode.light);
    // Also update the ThemeData explicitly so widgets using Theme.of(context) update
    Get.changeTheme(isDark.value ? AppTheme.theme : AppTheme.lightTheme);
  }
}
