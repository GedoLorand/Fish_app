import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class FadingFrame extends StatelessWidget {
  final Widget child;
  final double padding;
  final BorderRadius borderRadius;
  final double borderWidth;

  const FadingFrame({
    Key? key,
    required this.child,
    this.padding = 6.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(8.0)),
    this.borderWidth = 4.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color base = AppTheme.primaryColor;
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: base, width: borderWidth),
        ),
        child: ClipRRect(borderRadius: borderRadius, child: child),
      ),
    );
  }
}
