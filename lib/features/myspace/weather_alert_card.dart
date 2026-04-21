import 'package:flutter/material.dart';
import 'models/weather_models.dart';

class WeatherAlertCard extends StatelessWidget {
  final WeatherAlertResult alert;

  const WeatherAlertCard({
    super.key,
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final _WeatherCardStyle style = _getStyle(alert.level, isDarkMode);

    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            style.icon,
            color: style.iconColor,
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.titleColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  alert.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.subtitleColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _WeatherCardStyle _getStyle(WeatherAlertLevel level, bool isDarkMode) {
    switch (level) {
      case WeatherAlertLevel.thunderstorm:
        return _WeatherCardStyle(
          icon: Icons.thunderstorm_rounded,
          iconColor: Colors.white,
          titleColor: Colors.white,
          subtitleColor: Colors.white.withValues(alpha: 0.92),
          gradientColors: isDarkMode
              ? [const Color(0xFF374151), const Color(0xFF111827)]
              : [const Color(0xFF6B8AF7), const Color(0xFF3E5ED8)],
        );
      case WeatherAlertLevel.heavyRain:
        return _WeatherCardStyle(
          icon: Icons.cloudy_snowing,
          iconColor: Colors.white,
          titleColor: Colors.white,
          subtitleColor: Colors.white.withValues(alpha: 0.92),
          gradientColors: isDarkMode
              ? [const Color(0xFF334155), const Color(0xFF1E293B)]
              : [const Color(0xFF77A7FF), const Color(0xFF4E7DDA)],
        );
      case WeatherAlertLevel.lightRain:
        return _WeatherCardStyle(
          icon: Icons.umbrella_rounded,
          iconColor: isDarkMode ? Colors.white : const Color(0xFF214C9B),
          titleColor: isDarkMode ? Colors.white : const Color(0xFF173B7A),
          subtitleColor:
          isDarkMode ? Colors.white70 : const Color(0xFF2E4A73),
          gradientColors: isDarkMode
              ? [const Color(0xFF28435A), const Color(0xFF1D3142)]
              : [const Color(0xFFE3F1FF), const Color(0xFFC7E0FF)],
        );
      case WeatherAlertLevel.none:
        return _WeatherCardStyle(
          icon: Icons.wb_sunny_outlined,
          iconColor: Colors.black,
          titleColor: Colors.black,
          subtitleColor: Colors.black54,
          gradientColors: [Colors.white, Colors.white],
        );
    }
  }
}

class _WeatherCardStyle {
  final IconData icon;
  final Color iconColor;
  final Color titleColor;
  final Color subtitleColor;
  final List<Color> gradientColors;

  _WeatherCardStyle({
    required this.icon,
    required this.iconColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.gradientColors,
  });
}