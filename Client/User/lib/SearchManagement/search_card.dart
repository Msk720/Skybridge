import 'package:flutter/material.dart';
import 'package:skybridge02/Services/SearchEngine/city_autocomplete.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/custom_inputfield.dart';
import 'package:skybridge02/Services/SearchEngine/country_autocomplete.dart';
import 'package:skybridge02/Theme/app_color.dart';

class SearchCard extends StatefulWidget {
  final TextEditingController fromCountry;
  final TextEditingController toCountry;
  final TextEditingController fromCity;
  final TextEditingController toCity;
  final TextEditingController weightController;
  final TextEditingController dateController;
  final bool allowCityWithoutCountry;
  final VoidCallback onSearch;
  final VoidCallback onDateTap;
  final String activeTab;
  final Function(String) onTabChange;

  const SearchCard({
    super.key,
    required this.fromCountry,
    required this.toCountry,
    required this.fromCity,
    required this.toCity,
    required this.weightController,
    required this.dateController,
    this.allowCityWithoutCountry = false,
    required this.onSearch,
    required this.onDateTap,
    required this.activeTab,
    required this.onTabChange,
  });

  @override
  State<SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends State<SearchCard> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: CountryAutocompleteField(
                      controller: widget.fromCountry,
                      hint: "From country...",
                      hasError: false,
                      icon: Icons.public,
                      plainStyle: true,
                      onSelected: (val) {
                        setState(() {
                          widget.fromCity.clear();
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: CountryAutocompleteField(
                      controller: widget.toCountry,
                      hint: "To country...",
                      hasError: false,
                      icon: Icons.public,
                      plainStyle: true,
                      onSelected: (val) {
                        setState(() {
                          widget.toCity.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Expanded(
                    child: CityAutocompleteField(
                      countryController: widget.fromCountry,
                      cityController: widget.fromCity,
                      otherCityController: widget.toCity,
                      hint: "From City",
                      enabled: true,
                      icon: Icons.location_city,
                      plainStyle: true,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: CityAutocompleteField(
                      countryController: widget.toCountry,
                      cityController: widget.toCity,
                      otherCityController: widget.fromCity,
                      hint: "To City",
                      enabled: true,
                      icon: Icons.location_city,
                      plainStyle: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Expanded(
                    child: CustomInputField(
                      controller: widget.weightController,
                      hint: "Weight  (kg)",
                      plainStyle: true,
                      icon: Icons.scale_outlined,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: CustomInputField(
                        plainStyle: true,
                        controller: widget.dateController,
                        hint: "Date",
                        icon: Icons.calendar_today,
                        readOnly: true,
                        onTap: widget.onDateTap),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: ['Shipments', 'Trips'].map((tab) {
                    final active = widget.activeTab == tab;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          widget.onTabChange(tab);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: active ? AppColors.primary : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tab,
                            style: TextStyle(
                              color: active ? Colors.white : Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 40,
                width: double.infinity,
                child: appPrimaryButton(
                  text: 'Search',
                  onPressed: widget.onSearch,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
