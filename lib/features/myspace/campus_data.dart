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
}