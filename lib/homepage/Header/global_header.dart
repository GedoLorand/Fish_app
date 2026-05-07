import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/controllers/theme_controller.dart';

class GlobalHeader extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find();

    return AppBar(
      backgroundColor: AppTheme.surfaceColor,
      centerTitle: true,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: AppTheme.textColor),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: GestureDetector(
        onTap: () async {
          // Először bezárjuk a Drawer-t, ha nyitva van
          Navigator.of(context).maybePop(); // becsukja a drawer-t ha kell

          // Megvárjuk, hogy az animáció befejeződjön
          await Future.delayed(const Duration(milliseconds: 250));

          // Ezután visszanavigálunk az első (main.dart) oldalra
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        child: Text(
          "MAP",
          style: TextStyle(
            color: AppTheme.textColor,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ),
      actions: [
        Obx(
          () => IconButton(
            icon: Icon(
              themeController.isDark.value ? Icons.nights_stay : Icons.wb_sunny,
              color: AppTheme.textColor,
            ),
            tooltip: themeController.isDark.value
                ? 'Éjszakai mód'
                : 'Nappali mód',
            onPressed: () => themeController.toggle(),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
