import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/backend-login/homepage.dart';
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
          // Close the drawer only if it's open (avoid popping a normal route)
          final scaffoldState = Scaffold.maybeOf(context);
          if (scaffoldState != null && scaffoldState.isDrawerOpen) {
            Navigator.of(context).pop();
            await Future.delayed(const Duration(milliseconds: 250));
          }

          // Use Get to clear stack and open Homepage (map), forcing a reload
          Get.offAll(() => Homepage());
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
