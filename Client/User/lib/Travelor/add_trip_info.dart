import 'package:skybridge02/Buyer/Component/tour_card.dart';
import 'package:skybridge02/Services/build_info_card.dart';
import 'package:skybridge02/Services/custom_inputfield.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/section_label.dart';
import 'package:skybridge02/Travelor/v.dart';
import 'package:skybridge02/Services/app_imports.dart';

class TripCreateScreen extends StatefulWidget {
  const TripCreateScreen({super.key});

  @override
  State<TripCreateScreen> createState() => _TripCreateScreenState();
}

class _TripCreateScreenState extends State<TripCreateScreen> {
  final fromCountryController = TextEditingController();
  final fromCityController = TextEditingController();
  final toCountryController = TextEditingController();
  final toCityController = TextEditingController();
  final noteController = TextEditingController();
  final additionalInfoController = TextEditingController();
  final dateController = TextEditingController();
  final quantityController = TextEditingController();
  final weightController = TextEditingController();
  final timeController = TextEditingController();

  FocusNode weightFocus = FocusNode();
  bool isFocused = false;

  bool isEditMode = false;
  bool _isInitialized = false;
  String? requestId;

  DateTime? deliveryDate;

  String? fromCountryError;
  String? fromCityError;
  String? toCountryError;
  String? toCityError;
  String? quantityError;
  String? weightError;
  bool dateError = false;
  bool timeError = false;

  bool _loading = false;

  @override
  void initState() {
    super.initState();

    weightFocus.addListener(() {
      setState(() {
        isFocused = weightFocus.hasFocus;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInitialized) return;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic>) {
      isEditMode = args['isEdit'] == true;

      if (isEditMode) {
        requestId = args['id'];
        fromCountryController.text = args['fromCountry'] ?? '';
        fromCityController.text = args['fromCity'] ?? '';
        toCountryController.text = args['toCountry'] ?? '';
        toCityController.text = args['toCity'] ?? '';
        additionalInfoController.text = args['note'] ?? '';
        quantityController.text = (args['quantity'] ?? 1).toString();
        weightController.text = (args['availableWeight'] ?? '').toString();

        deliveryDate = DateTime.tryParse(args['departureDate'] ?? '');

        if (deliveryDate != null) {
          dateController.text = _formatInputDate(deliveryDate!);
        }
        timeController.text = args['departureTime'] ?? '';
      }
    }

    _isInitialized = true;
  }

  String _formatInputDate(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}";
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
        dateController.text = _formatInputDate(picked);
      });
    }
  }

  Future<void> selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? "AM" : "PM";

      setState(() {
        timeController.text = "$hour:$minute $period";
      });
    }
  }

  bool validateAllFields() {
    final fromCountry = fromCountryController.text.trim();
    final fromCity = fromCityController.text.trim();
    final toCountry = toCountryController.text.trim();
    final toCity = toCityController.text.trim();
    final weight = weightController.text.trim();

    String? fromCountryErr;
    String? fromCityErr;
    String? toCountryErr;
    String? toCityErr;
    String? weightErr;

    /// FROM
    if (fromCountry.isEmpty) {
      fromCountryErr = "Required";
      fromCityErr = "Select country first";
    } else if (!ValidationHelper.isValidCountry(fromCountry)) {
      fromCountryErr = "Invalid";
      fromCountryController.clear();
      fromCityController.clear();
    } else {
      if (fromCity.isEmpty) {
        fromCityErr = "Required";
      } else if (!ValidationHelper.isValidCity(fromCountry, fromCity)) {
        fromCityErr = "Invalid";
        fromCityController.clear();
      }
    }

    /// TO
    if (toCountry.isEmpty) {
      toCountryErr = "Required";
      toCityErr = "Select country first";
    } else if (!ValidationHelper.isValidCountry(toCountry)) {
      toCountryErr = "Invalid";
      toCountryController.clear();
      toCityController.clear();
    } else {
      if (toCity.isEmpty) {
        toCityErr = "Required";
      } else if (!ValidationHelper.isValidCity(toCountry, toCity)) {
        toCityErr = "Invalid";
        toCityController.clear();
      }
    }

    /// WEIGHT
    if (weight.isEmpty) {
      weightErr = "???";
      weightController.clear();
    } else {
      final wt = double.tryParse(weight);
      if (wt == null || wt <= 0) {
        weightErr = "Invalid";
        weightController.clear();
      } else if (wt > 20) {
        weightErr = "Max 20";
        weightController.clear();
      }
    }
    if (dateController.text.isEmpty) {
      dateError = true;
    } else {
      dateError = false;
    }

    if (timeController.text.isEmpty) {
      timeError = true;
    } else {
      timeError = false;
    }

    setState(() {
      fromCountryError = fromCountryErr;
      fromCityError = fromCityErr;
      toCountryError = toCountryErr;
      toCityError = toCityErr;
      weightError = weightErr;
    });

    return fromCountryErr == null &&
        fromCityErr == null &&
        toCountryErr == null &&
        toCityErr == null &&
        weightErr == null &&
        !dateError &&
        !timeError;
  }

  Future<void> updateTrip() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login required")),
      );
      return;
    }

    if (!validateAllFields()) return;

    if (requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing trip ID")),
      );
      return;
    }

    setState(() => _loading = true);
    final currentUserId = user.uid;
    final availableWeight = weightController.text.trim();

    final payload = {
      "fromCountry": fromCountryController.text.trim(),
      "fromCity": fromCityController.text.trim(),
      "toCountry": toCountryController.text.trim(),
      "toCity": toCityController.text.trim(),
      "availableWeight": double.parse(availableWeight),
      'departureDate': deliveryDate?.toIso8601String() ?? '',
      "departureTime": timeController.text.trim(),
      "userId": currentUserId,
    };

    try {
      await ApiService.post(
        "/updateData",
        {
          "collection": "trips",
          "id": requestId,
          "data": payload,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip updated")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update trip")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> createTrip() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login required")),
      );
      return;
    }

    final currentUserId = user.uid;
    final availableWeight = weightController.text.trim();
    if (!validateAllFields()) return;

    setState(() => _loading = true);
    final payload = {
      "fromCountry": fromCountryController.text.trim(),
      "fromCity": fromCityController.text.trim(),
      "toCountry": toCountryController.text.trim(),
      "toCity": toCityController.text.trim(),
      "availableWeight": double.parse(availableWeight),
      'departureDate': deliveryDate?.toIso8601String() ?? '',
      "departureTime": timeController.text.trim(),
      "status": "Active",
      "userId": currentUserId,
    };

    try {
      await ApiService.post(
        "/createData",
        {
          "collection": "trips",
          "data": payload,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip created")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to create trip")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 234, 235, 236),
      appBar: dashboardAppBar(
        title: isEditMode ? "Edit Trip " : "Create Trip",
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
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
            const SizedBox(height: 15),
            infoCard([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionLabel(
                    'TRIP DETAILS',
                    icon: Icons.flight_takeoff_rounded,
                  ),

                  const SizedBox(height: 12),

                  /// WEIGHT
                  const Text(
                    "Available Weight",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 5),

                  _buildInputField(
                    hasError: weightError != null,
                    controller: weightController,
                    hint: weightError ?? "0.0",
                    icon: Icons.scale,
                    keyboardType: TextInputType.number,
                    suffixText: "kg",
                  ),

                  const SizedBox(height: 15),

                  /// DATE + TIME
                  Row(
                    children: [
                      Expanded(
                        child: CustomInputField(
                          controller: dateController,
                          hint: "DATE",
                          icon: Icons.calendar_today,
                          readOnly: true,
                          onTap: selectDate,
                          hasError: dateError,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: CustomInputField(
                          controller: timeController,
                          hint: "TIME",
                          icon: Icons.access_time,
                          readOnly: true,
                          onTap: selectTime,
                          hasError: timeError,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            if (_loading) const CircularProgressIndicator(),
            if (!_loading)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: appPrimaryButton(
                  text: isEditMode ? 'Update' : 'Create Trip',
                  onPressed: isEditMode ? updateTrip : createTrip,
                ),
              ),

              SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool hasError,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;

          return Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: hasFocus ? const Color(0xFFD1D5DB) : Colors.transparent,
            ),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFocus
                      ? const Color(0xFF6B7280)
                      : const Color(0xFFE5E7EB),
                  width: 1.2,
                ),
                boxShadow: hasFocus
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        )
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),

                  /// 🔹 INPUT
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      textAlign: suffixText != null
                          ? TextAlign.center
                          : TextAlign.left,
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          color: hasError ? Colors.red : Colors.grey,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  if (suffixText != null)
                    Text(
                      suffixText,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
