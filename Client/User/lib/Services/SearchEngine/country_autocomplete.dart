import 'country_suggestion.dart';
import 'base_autocomplete.dart';
import 'package:flutter/material.dart';

class CountryAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool hasError;
  final bool plainStyle;
  final Function(String)? onSelected;

  const CountryAutocompleteField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.onSelected,
    this.hasError = false,
    this.plainStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final service = CountrySuggestionService();

    return BaseAutocompleteField(
      controller: controller,
      hint: hint,
      icon: icon,
      hasError: hasError,
      plainStyle: plainStyle,
      onSelected: onSelected,
      optionsBuilder: (query) {
        return service.getSuggestions(query);
      },
    );
  }
}
