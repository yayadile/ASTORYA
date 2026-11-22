import 'package:flutter/material.dart';

/// Reusable pill-shaped menu button for the ASTORYA home screen.
///
/// Matches the design: cream-to-gold gradient fill, golden-brown border,
/// fully rounded ends, leading icon, bold dark-brown label.
class MenuButton extends StatefulWidget {
  const MenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.fillTop,
    required this.fillBottom,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color fillTop;
  final Color fillBottom;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Slight darkening on press for tactile feedback.
    final double opacity = _pressed ? 0.82 : 1.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 80),
        opacity: opacity,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.fillTop, widget.fillBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: widget.borderColor, width: 1.8),
            boxShadow: [
              BoxShadow(
                color: widget.borderColor.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.textColor, size: 22),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
