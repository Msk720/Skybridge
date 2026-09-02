import 'package:skybridge02/Services/SearchEngine/location_list.dart';

class ValidationHelper {
  static String? validateRequired(String value) {
    return value.isEmpty ? "Required" : null;
  }

  static String? validateNumber(String value) {
    if (value.isEmpty) return "Required";
    final numVal = double.tryParse(value);
    if (numVal == null || numVal <= 0) return "Invalid";
    return null;
  }

  static bool isValidCountry(String value) {
    return countries.contains(value);
  }

  static bool isValidCity(String country, String city) {
    if (!citiesByCountry.containsKey(country)) return false;

    return citiesByCountry[country]!.contains(city);
  }
}
