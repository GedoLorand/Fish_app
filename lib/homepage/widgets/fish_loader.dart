import 'dart:math';
import 'package:flutter/material.dart';

class FishLoader extends StatefulWidget {
  final double size;
  final String assetPath;
  final double baseRotation; // radians to rotate the image as baseline
  const FishLoader({
    super.key,
    this.size = 80,
    this.assetPath = 'assets/fish_loader_icon.png',
    this.baseRotation = 0.0,
  });

  @override
  State<FishLoader> createState() => _FishLoaderState();
}

class _FishLoaderState extends State<FishLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final radius = size * 0.35;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final angle = _ctrl.value * 2 * pi;
          final x = cos(angle) * radius;
          final y = sin(angle) * radius;
          // tangent direction (direction of motion) is angle + PI/2
          final double tangent = angle + pi / 2;
          // Add a subtle swimming tilt that oscillates as the fish moves
          final double tiltAmplitude = 0.14; // ~8 degrees
          final double tiltFrequency = 2.0; // how many tilt cycles per orbit
          final double tilt = sin(angle * tiltFrequency) * tiltAmplitude;
          final double rotation = tangent + tilt + (widget.baseRotation ?? 0);
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(x, y),
                child: Transform.rotate(
                  angle: rotation,
                  child: SizedBox(
                    width: size * 0.28,
                    height: size * 0.28,
                    child: Image.asset(widget.assetPath, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
