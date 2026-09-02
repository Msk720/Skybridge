import 'location_list.dart';

class CountrySuggestionService {
  bool isValidCountry(String value) {
    return countries.contains(value);
  }

  List<String> getSuggestions(String query,
      {int minChars = 2, int limit = 10}) {
    if (query.length < minChars) return [];

    final q = query.toLowerCase();

    final results = countries.where((country) {
      return country.toLowerCase().contains(q);
    }).toList();

    return results.take(limit).toList();
  }
}
