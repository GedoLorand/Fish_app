import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RouteControls extends StatelessWidget {
  final bool filterActive;
  final bool showArrowHint;
  final bool showRoute;
  final VoidCallback onClearFilters;
  final VoidCallback onCancelRoute;

  const RouteControls({
    Key? key,
    required this.filterActive,
    required this.showArrowHint,
    required this.showRoute,
    required this.onClearFilters,
    required this.onCancelRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Clear filter FAB (hidden while route is active)
        if (filterActive && !showRoute)
          Positioned(
            top: 112,
            right: 16,
            child: SafeArea(
              child: FloatingActionButton(
                heroTag: 'clear_filter_fab',
                mini: true,
                backgroundColor: Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.black, width: 2),
                ),
                onPressed: onClearFilters,
                child: _FilterOffIcon(size: 20),
              ),
            ),
          ),

        // Arrow hint pointing to the clear-filter FAB
        if (showArrowHint)
          Positioned(
            top: 116,
            right: 68,
            child: FadeTransition(
              // The parent may not provide an animation; for safety, use a
              // simple static opacity by wrapping with AlwaysStoppedAnimation.
              opacity: const AlwaysStoppedAnimation(1.0),
              child: Material(
                color: Colors.transparent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Text(
                        'clear_filter'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _OutlinedIcon(
                      Icons.arrow_right_alt,
                      size: 28,
                      color: Colors.red.shade200,
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Red cancel-route FAB (shows when a route is active)
        if (showRoute)
          Positioned(
            top: 112,
            right: 16,
            child: SafeArea(
              child: FloatingActionButton(
                heroTag: 'cancel_route_fab',
                mini: true,
                backgroundColor: Colors.red.shade600,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.black, width: 2),
                ),
                onPressed: onCancelRoute,
                child: _OutlinedIcon(
                  Icons.my_location,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Reimplement small helper widgets locally to avoid coupling to MapScreen's
// private helpers. These are intentionally lightweight copies.
class _OutlinedIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Color outlineColor;

  const _OutlinedIcon(
    this.icon, {
    Key? key,
    required this.size,
    required this.color,
    this.outlineColor = Colors.black,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const offsets = [
      Offset(-1.2, -1.2),
      Offset(0, -1.2),
      Offset(1.2, -1.2),
      Offset(-1.2, 0),
      Offset(1.2, 0),
      Offset(-1.2, 1.2),
      Offset(0, 1.2),
      Offset(1.2, 1.2),
    ];
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final off in offsets)
            Transform.translate(
              offset: off,
              child: Icon(icon, size: size, color: outlineColor),
            ),
          Icon(icon, size: size * 0.88, color: color),
        ],
      ),
    );
  }
}

class _FilterOffIcon extends StatelessWidget {
  final double size;
  const _FilterOffIcon({Key? key, this.size = 20}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _OutlinedIcon(
            Icons.filter_alt,
            size: size,
            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
          ),
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _SlashPainter(
                color: Colors.red.shade400,
                outlineColor: Colors.black,
                strokeFraction: 0.18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlashPainter extends CustomPainter {
  final Color color;
  final Color outlineColor;
  final double strokeFraction;

  _SlashPainter({
    required this.color,
    required this.outlineColor,
    this.strokeFraction = 0.16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pBlack = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * (strokeFraction + 0.06);
    final pRed = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * strokeFraction;

    final start = Offset(size.width * 0.18, size.height * 0.78);
    final end = Offset(size.width * 0.82, size.height * 0.22);
    canvas.drawLine(start, end, pBlack);
    canvas.drawLine(start, end, pRed);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
