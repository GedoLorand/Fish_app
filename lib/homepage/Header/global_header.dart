import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:login_fish_app/backend-login/homepage.dart';
import 'package:login_fish_app/controllers/theme_controller.dart';

// Helper widgets for outlined icons/text used in the header.
class _OutlinedIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color foreground;
  final Color innerOutline;
  final Color outerOutline;

  const _OutlinedIcon(
    this.icon, {
    Key? key,
    this.size = 24,
    required this.foreground,
    required this.innerOutline,
    this.outerOutline = Colors.black,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const innerOffsets = [
      Offset(-1.2, -1.2),
      Offset(0, -1.2),
      Offset(1.2, -1.2),
      Offset(-1.2, 0),
      Offset(1.2, 0),
      Offset(-1.2, 1.2),
      Offset(0, 1.2),
      Offset(1.2, 1.2),
    ];
    const outerOffsets = [
      Offset(-2.4, -2.4),
      Offset(0, -2.4),
      Offset(2.4, -2.4),
      Offset(-2.4, 0),
      Offset(2.4, 0),
      Offset(-2.4, 2.4),
      Offset(0, 2.4),
      Offset(2.4, 2.4),
    ];

    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final off in outerOffsets)
            Transform.translate(
              offset: off,
              child: Icon(icon, size: size, color: outerOutline),
            ),
          for (final off in innerOffsets)
            Transform.translate(
              offset: off,
              child: Icon(icon, size: size, color: innerOutline),
            ),
          // draw foreground slightly smaller to make it appear thinner
          Icon(icon, size: (size * 0.82), color: foreground),
        ],
      ),
    );
  }
}

class _OutlinedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color innerOutline;
  final Color outerOutline;

  const _OutlinedText(
    this.text, {
    Key? key,
    required this.style,
    required this.innerOutline,
    this.outerOutline = Colors.black,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const innerOffsets = [
      Offset(-1.5, -1.5),
      Offset(0, -1.5),
      Offset(1.5, -1.5),
      Offset(-1.5, 0),
      Offset(1.5, 0),
      Offset(-1.5, 1.5),
      Offset(0, 1.5),
      Offset(1.5, 1.5),
    ];
    const outerOffsets = [
      Offset(-3.0, -3.0),
      Offset(0, -3.0),
      Offset(3.0, -3.0),
      Offset(-3.0, 0),
      Offset(3.0, 0),
      Offset(-3.0, 3.0),
      Offset(0, 3.0),
      Offset(3.0, 3.0),
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        for (final off in outerOffsets)
          Transform.translate(
            offset: off,
            child: Text(text, style: style.copyWith(color: outerOutline)),
          ),
        for (final off in innerOffsets)
          Transform.translate(
            offset: off,
            child: Text(text, style: style.copyWith(color: innerOutline)),
          ),
        // draw foreground slightly smaller to appear thinner
        Text(
          text,
          style: style.copyWith(
            fontSize: (style.fontSize ?? 14) - 1.5,
            fontWeight: FontWeight.w500,
            color: style.color,
          ),
        ),
      ],
    );
  }
}

class GlobalHeader extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find();
    // slightly darken primary color for the inner outline in header
    final Color headerInnerOrange =
        Color.lerp(AppTheme.primaryColor, Colors.black, 0.14) ??
        AppTheme.primaryColor;

    return AppBar(
      backgroundColor: AppTheme.surfaceColor,
      centerTitle: true,
      leading: Builder(
        builder: (context) => IconButton(
          icon: _OutlinedIcon(
            Icons.menu,
            size: 26,
            foreground: AppTheme.textColor,
            innerOutline: Colors.black,
            outerOutline: headerInnerOrange,
          ),
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
        child: _OutlinedText(
          'map_title'.tr,
          style: TextStyle(
            color: AppTheme.textColor,
            fontFamily: AppTheme.fontFamily,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
          innerOutline: Colors.black,
          outerOutline: headerInnerOrange,
        ),
      ),
      actions: [
        Obx(
          () => IconButton(
            icon: _OutlinedIcon(
              themeController.isDark.value ? Icons.nights_stay : Icons.wb_sunny,
              size: 22,
              foreground: AppTheme.textColor,
              innerOutline: Colors.black,
              outerOutline: headerInnerOrange,
            ),
            tooltip: themeController.isDark.value
                ? 'theme_dark'.tr
                : 'theme_light'.tr,
            onPressed: () => themeController.toggle(),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
