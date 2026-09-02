import 'package:material_symbols_icons/symbols.dart';
import 'package:skybridge02/Services/SearchEngine/city_autocomplete.dart';
import 'package:skybridge02/Services/build_info_card.dart';
import 'package:skybridge02/Services/SearchEngine/location_list.dart';
import 'package:skybridge02/Services/section_label.dart';
import 'package:skybridge02/Services/SearchEngine/country_autocomplete.dart';
import 'package:skybridge02/Services/app_imports.dart';

class TourCard extends StatefulWidget {
  final TextEditingController fromCountryController;
  final TextEditingController fromCityController;
  final TextEditingController toCountryController;
  final TextEditingController toCityController;

  final String? fromCountryError;
  final String? fromCityError;
  final String? toCountryError;
  final String? toCityError;

  const TourCard({
    super.key,
    required this.fromCountryController,
    required this.fromCityController,
    required this.toCountryController,
    required this.toCityController,
    this.fromCountryError,
    this.fromCityError,
    this.toCountryError,
    this.toCityError,
  });

  @override
  State<TourCard> createState() => _RouteFormState();
}

class _RouteFormState extends State<TourCard> {
  bool isValidCountry(String value) {
    return countries.contains(value);
  }

  Widget arrowDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE5E7EB), Colors.transparent],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Symbols.plane_contrails,
              color: Colors.white, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Color(0xFFE5E7EB)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        infoCard([
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionLabel('ORIGIN', dotColor: const Color(0xFF10B981)),
              const SizedBox(height: 7),
              CountryAutocompleteField(
                controller: widget.fromCountryController,
                hint: widget.fromCountryError ?? "Type country...",
                hasError: widget.fromCountryError != null,
                icon: Icons.public,
                onSelected: (val) {
                  setState(() {
                    widget.fromCityController.clear();
                  });
                },
              ),
              const SizedBox(height: 1),
              CityAutocompleteField(
                countryController: widget.fromCountryController,
                cityController: widget.fromCityController,
                otherCityController: widget.toCityController,
                hint: !isValidCountry(widget.fromCountryController.text)
                    ? "Select country first"
                    : (widget.fromCityError ?? "From city..."),
                hasError: widget.fromCityError != null,
                enabled: isValidCountry(widget.fromCountryController.text),
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 6),
              arrowDivider(),
              const SizedBox(height: 6),
              sectionLabel('DESTINATION', dotColor: const Color(0xFFEF4444)),
              const SizedBox(height: 8),
              CountryAutocompleteField(
                controller: widget.toCountryController,
                hint: widget.toCountryError ?? "Type country...",
                hasError: widget.toCountryError != null,
                icon: Icons.public,
                onSelected: (val) {
                  setState(() {
                    widget.toCityController.clear();
                  });
                },
              ),
              CityAutocompleteField(
                countryController: widget.toCountryController,
                cityController: widget.toCityController,
                otherCityController: widget.fromCityController,
                hint: !isValidCountry(widget.toCountryController.text)
                    ? "Select country first"
                    : (widget.toCityError ?? "To city..."),
                hasError: widget.toCityError != null,
                enabled: isValidCountry(widget.toCountryController.text),
                icon: Icons.location_on_outlined,
              ),
            ],
          ),
        ]),
      ],
    );
  }
}
