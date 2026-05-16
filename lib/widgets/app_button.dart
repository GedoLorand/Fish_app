import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;

  const AppButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.padding,
    this.borderRadius = 8.0,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    final Color bg = disabled
        ? Colors.grey.shade400
        : (backgroundColor ?? AppTheme.primaryColor);
    final Color textColor = disabled ? Colors.black54 : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding:
                padding ??
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: DefaultTextStyle(
              style: TextStyle(color: textColor),
              child: Center(
                child: child is Text
                    ? _strokedText(child as Text, textColor)
                    : child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _strokedText(Text t, Color textColor) {
    final String data = t.data ?? '';
    final TextStyle baseStyle = t.style ?? TextStyle(color: textColor);
    final double strokeWidth = 4.0;
    final double fontSize = (baseStyle.fontSize ?? 14.0) + 4.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          data,
          style: baseStyle.copyWith(
            fontSize: fontSize,
            foreground: ui.Paint()
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = Colors.black,
          ),
        ),
        Text(
          data,
          style: baseStyle.copyWith(color: textColor, fontSize: fontSize),
        ),
      ],
    );
  }
}
