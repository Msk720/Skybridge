import 'package:skybridge02/Buyer/Component/tour_card.dart';
import 'package:skybridge02/Services/app_imports.dart';

import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/custom_inputfield.dart';
import 'package:skybridge02/Services/build_info_card.dart';
import 'package:skybridge02/Services/SearchEngine/location_list.dart';
import 'package:skybridge02/Services/pricing_service.dart';
import 'package:skybridge02/Services/section_label.dart';
import 'package:skybridge02/Services/SearchEngine/country_suggestion.dart';

class ShippingFormScreen extends StatefulWidget {
  const ShippingFormScreen({super.key});

  @override
  State<ShippingFormScreen> createState() => _ShippingFormScreenState();
}

class _ShippingFormScreenState extends State<ShippingFormScreen> {
  Map<String, dynamic> baseDetails = {};

  bool isEditMode = false;
  bool _isInitialized = false;

  String? requestId;
  double itemPrice = 0.0;
  double travelerReward = 0.0;
  double totalPrice = 0.0;

  final fromCountryController = TextEditingController();
  final fromCityController = TextEditingController();
  final toCountryController = TextEditingController();
  final toCityController = TextEditingController();
  final additionalInfoController = TextEditingController();
  final suggestionService = CountrySuggestionService();
  final dateController = TextEditingController();
  final quantityController = TextEditingController();
  final weightController = TextEditingController();

  DateTime? deliveryDate;
  String? fromCountryError;
  String? fromCityError;
  String? toCountryError;
  String? toCityError;
  String? weightError;
  String? quantityError;

  bool dateError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInitialized) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic>) {
      isEditMode = args['isEdit'] == true;
      baseDetails = args;

      if (isEditMode) {
        requestId = args['id'];
        fromCountryController.text = args['fromCountry'] ?? '';
        fromCityController.text = args['fromCity'] ?? '';
        toCountryController.text = args['toCountry'] ?? '';
        toCityController.text = args['toCity'] ?? '';
        additionalInfoController.text = args['note'] ?? '';
        quantityController.text = (args['quantity'] ?? 1).toString();
        weightController.text = (args['weight'] ?? '').toString();

        deliveryDate = DateTime.tryParse(args['date'] ?? '');

        if (deliveryDate != null) {
          dateController.text =
              "${deliveryDate!.month.toString().padLeft(2, '0')}/${deliveryDate!.day.toString().padLeft(2, '0')}/${deliveryDate!.year}";
        }
      }
    }

    _isInitialized = true;
  }

  void calculatePrice() {
    final result = PricingService.calculate(
      price: double.tryParse(baseDetails['price']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(quantityController.text) ??
          (baseDetails['quantity'] ?? 1),
      weight: double.tryParse(weightController.text) ??
          (baseDetails['weight'] ?? 0.0),
      fromCountry: fromCountryController.text,
      toCountry: toCountryController.text,
      preference: baseDetails['preference'] ?? 'risky',
    );

    setState(() {
      itemPrice = result["itemPrice"] ?? 0.0;
      travelerReward = result["travelerReward"] ?? 0.0;
      totalPrice = result["totalPrice"] ?? 0.0;
    });
  }

  bool isValidCountry(String value) {
    return countries.contains(value);
  }

  bool isValidCity(String country, String city) {
    if (!citiesByCountry.containsKey(country)) return false;

    return citiesByCountry[country]!.contains(city);
  }

  bool validateRouteFields({bool requireItemDetails = false}) {
    final fromCountry = fromCountryController.text.trim();
    final fromCity = fromCityController.text.trim();
    final toCountry = toCountryController.text.trim();
    final toCity = toCityController.text.trim();
    final quantity = quantityController.text.trim();
    final weight = weightController.text.trim();

    String? fromCountryErr;
    String? fromCityErr;
    String? toCountryErr;
    String? toCityErr;
    String? quantityErr;
    String? weightErr;

    bool dateErr = deliveryDate == null;

    if (fromCountry.isEmpty) {
      fromCountryErr = "Required";
      fromCityErr = "Select country first";
    } else if (!isValidCountry(fromCountry)) {
      fromCountryErr = "Invalid country";
      fromCountryController.clear();
      fromCityController.clear();
    } else {
      if (fromCity.isEmpty) {
        fromCityErr = "Required";
      } else if (!isValidCity(fromCountry, fromCity)) {
        fromCityErr = "Invalid city";
        fromCityController.clear();
      }
    }

    if (toCountry.isEmpty) {
      toCountryErr = "Required";
      toCityErr = "Select country first";
    } else if (!isValidCountry(toCountry)) {
      toCountryErr = "Invalid country";
      toCountryController.clear();
      toCityController.clear();
    } else {
      if (toCity.isEmpty) {
        toCityErr = "Required";
      } else if (!isValidCity(toCountry, toCity)) {
        toCityErr = "Invalid city";
        toCityController.clear();
      }
    }

    if (requireItemDetails) {
      if (quantity.isEmpty) {
        quantityErr = "Required";
        quantityController.clear();
      } else {
        final qty = int.tryParse(quantity);
        if (qty == null || qty <= 0) {
          quantityErr = "Invalid";
          quantityController.clear();
        }
      }

      /// WEIGHT
      if (weight.isEmpty) {
        weightErr = "Required";
        weightController.clear();
      } else {
        final qty = int.tryParse(quantity) ?? 0;
        final wt = double.tryParse(weight);

        if (wt == null || wt <= 0) {
          weightErr = "Invalid";
          weightController.clear();
        } else {
          if ((wt * qty) > 20) {
            weightErr = "Max !";
            weightController.clear();
          }
        }
      }
    }

    setState(() {
      fromCountryError = fromCountryErr;
      fromCityError = fromCityErr;
      toCountryError = toCountryErr;
      toCityError = toCityErr;
      quantityError = quantityErr;
      weightError = weightErr;
      dateError = dateErr;
    });

    return fromCountryErr == null &&
        fromCityErr == null &&
        toCountryErr == null &&
        toCityErr == null &&
        quantityErr == null &&
        weightErr == null &&
        !dateErr;
  }

  Future<void> handleUpdate() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login required")),
      );
      return;
    }

    if (requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing request ID")),
      );
      return;
    }

    if (!validateRouteFields(requireItemDetails: true)) return;
    calculatePrice();

    final weightTotal = (double.tryParse(weightController.text) ?? 0.0) *
        (int.tryParse(quantityController.text) ?? 1);

    final payload = {
      "fromCountry": fromCountryController.text.trim(),
      "fromCity": fromCityController.text.trim(),
      "toCountry": toCountryController.text.trim(),
      "toCity": toCityController.text.trim(),
      "note": additionalInfoController.text.trim(),
      'date': deliveryDate?.toIso8601String() ?? '',
      "userId": user.uid,
      "quantity": int.tryParse(quantityController.text) ?? 1,
      "weight": double.tryParse(weightController.text),
      'itemPrice': itemPrice,
      'totalPrice': totalPrice,
      'weightTotal': weightTotal
    };

    try {
      await ApiService.post(
        "/updateData",
        {
          "collection": "items",
          "id": requestId.toString(),
          "data": payload,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Updated successfully")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Update failed")),
      );
    }
  }

  void validateAndSubmit() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login required")),
      );
      return;
    }

    if (!validateRouteFields()) return;
    calculatePrice();
    final combined = {
      ...baseDetails,
      'fromCountry': fromCountryController.text.trim(),
      'fromCity': fromCityController.text.trim(),
      'toCountry': toCountryController.text.trim(),
      'toCity': toCityController.text.trim(),
      'date': deliveryDate?.toIso8601String() ?? '',
      'note': additionalInfoController.text.trim(),
      'itemPrice': itemPrice,
      'travelerReward': travelerReward,
      'totalPrice': totalPrice,
    };

    Navigator.pushNamed(
      context,
      '/OrderConfirmation',
      arguments: combined,
    );
  }

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: deliveryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );

    if (picked != null) {
      setState(() {
        deliveryDate = picked;
        dateController.text = "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: isEditMode ? "Edit Details " : "Shipping Details",
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          child: IconButton(
            iconSize: 20,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  TourCard(
                    fromCountryController: fromCountryController,
                    fromCityController: fromCityController,
                    toCountryController: toCountryController,
                    toCityController: toCityController,
                    fromCountryError: fromCountryError,
                    fromCityError: fromCityError,
                    toCountryError: toCountryError,
                    toCityError: toCityError,
                  ),
                  if (isEditMode) ...[
                    const SizedBox(height: 15),
                    infoCard([
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionLabel('ITEM DETAILS', icon: Icons.inventory_2),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: CustomInputField(
                                  controller: quantityController,
                                  hint: quantityError ?? " Quantity...",
                                  icon: Icons.numbers,
                                  hasError: quantityError != null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomInputField(
                                  controller: weightController,
                                  hint: weightError ?? " Weight...",
                                  icon: Icons.scale_outlined,
                                  hasError: weightError != null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ]),
                  ],
                  const SizedBox(height: 15),
                  infoCard([
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionLabel('NEEDED BEFORE',
                            icon: Icons.hourglass_bottom),
                        const SizedBox(height: 8),
                        CustomInputField(
                          controller: dateController,
                          hint: 'mm/dd/yyyy',
                          icon: Icons.calendar_today,
                          readOnly: true,
                          onTap: selectDate,
                          hasError: dateError,
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 15),
                  infoCard([
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionLabel(
                          'NOTES',
                          icon: Icons.notes,
                        ),
                        const SizedBox(height: 8),
                        CustomInputField(
                          controller: additionalInfoController,
                          hint: 'Add any special instructions...',
                          maxLines: 2,
                          hasError: false,
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: appPrimaryButton(
                      text: isEditMode ? 'Update' : 'Verify & Confirm',
                      onPressed: isEditMode ? handleUpdate : validateAndSubmit,
                    ),
                  ),
                  const SizedBox(height: 50),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
