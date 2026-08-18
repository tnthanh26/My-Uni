import './models/weather_models.dart';

class CampusData {
  static const Map<String, CampusLocation> campuses = {
    'us_cs1': CampusLocation(
      campusId: 'us_cs1',
      name: 'VNU - HCMUS (CS1)',
      latitude: 10.76302530132863,
      longitude: 106.68242875691931,
    ),
    'us_cs2': CampusLocation(
      campusId: 'us_cs2',
      name: 'VNU - HCMUS (CS2)',
      latitude: 10.875512473779988,
      longitude: 106.79823254628613,
    ),
  };

  static CampusLocation? getCampusById(String campusId) {
    return campuses[campusId];
  }

  static String? mapUniversityToCampusId(String university) {
    switch (university.trim()) {
      case 'VNU - HCMUS (CS1)':
        return 'us_cs1';
      case 'VNU - HCMUS (CS2)':
        return 'us_cs2';
      default:
        return null;
    }
  }

  static List<CampusLocation> getCampusesForSchoolOf(String userUniversity) {
    final trimmed = userUniversity.trim();
    if (trimmed.isEmpty) return campuses.values.toList();

    String schoolPrefix = trimmed;
    final parenIndex = trimmed.indexOf(' (');
    if (parenIndex != -1) {
      schoolPrefix = trimmed.substring(0, parenIndex);
    }

    final matching = campuses.values.where((c) {
      return c.name.startsWith(schoolPrefix);
    }).toList();

    if (matching.isEmpty) {
      final directMatch = campuses.values.firstWhere(
        (c) => c.name.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => campuses.values.first,
      );
      return [directMatch];
    }
    return matching;
  }
}
