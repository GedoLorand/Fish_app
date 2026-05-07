import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class GlobalHeader extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
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
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
