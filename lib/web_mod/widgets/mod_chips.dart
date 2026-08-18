import 'package:flutter/material.dart';

class ModStatChip extends StatelessWidget {
  const ModStatChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blueGrey,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ModUserInfoChip extends StatelessWidget {
  const ModUserInfoChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ModStatChip(icon: icon, label: label);
  }
}

class ModToxicityBadge extends StatelessWidget {
  const ModToxicityBadge({super.key, required this.toxicity});

  final double toxicity;

  @override
  Widget build(BuildContext context) {
    Color toxicColor = toxicity > 0.5
        ? Colors.redAccent
        : (toxicity > 0.2 ? Colors.orangeAccent : Colors.greenAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: toxicColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "Toxicity: ${toxicity.toStringAsFixed(2)}",
        style: TextStyle(
          color: toxicColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          fontFamily: 'Nunito',
        ),
      ),
    );
  }
}
