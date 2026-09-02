import 'package:flutter/material.dart';
import 'base_autocomplete.dart';
import 'package:skybridge02/Services/SearchEngine/location_list.dart';

class CityAutocompleteField extends StatelessWidget {
  final TextEditingController countryController;
  final TextEditingController cityController;
  final String hint;
  final IconData icon;
  final bool hasError;
  final bool enabled;
  final TextEditingController? otherCityController;
  final bool plainStyle;

  const CityAutocompleteField({
    super.key,
    required this.countryController,
    required this.cityController,
    required this.hint,
    required this.icon,
    this.otherCityController,
    this.hasError = false,
    this.enabled = true,
    this.plainStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    return BaseAutocompleteField(
      key: ValueKey(countryController.text),
      controller: cityController,
      hint: hint,
      icon: icon,
      enabled: enabled,
      hasError: hasError,
      plainStyle: plainStyle,
      optionsBuilder: (query) {
        final country = countryController.text;

        if (!citiesByCountry.containsKey(country)) return [];

        final cities = citiesByCountry[country]!;

        final filtered = cities.where(
          (c) => otherCityController?.text != c,
        );

        if (query.isEmpty) return filtered;

        return filtered.where(
          (c) => c.toLowerCase().contains(query.toLowerCase()),
        );
      },
    );
  }
}
