import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

/// A small widget that displays a photo marker icon and handles taps.
/// Kept intentionally minimal so it can be reused by the map screen.
class PhotoMarker extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final String assetName;

  const PhotoMarker({
    super.key,
    required this.onTap,
    this.size = 36,
    this.assetName = 'assets/icon/in_map_icon.png',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          assetName,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) =>
              Icon(Icons.photo, size: size, color: Colors.orange),
        ),
      ),
    );
  }
}
