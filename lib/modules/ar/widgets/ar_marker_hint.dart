import 'package:flutter/material.dart';

/// Pill petunjuk di bagian bawah layar, tampil selama marker belum terdeteksi.
class ArMarkerHint extends StatelessWidget {
  const ArMarkerHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 40,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xF20B0E1A),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x33FFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.document_scanner_rounded,
                  size: 18,
                  color: Color(0xFF7B4BFF),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
