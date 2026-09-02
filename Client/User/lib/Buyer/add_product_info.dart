import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/build_info_card.dart';
import 'package:skybridge02/Services/custom_inputfield.dart';

import 'package:skybridge02/Services/image_picker_uploader.dart';
import 'package:skybridge02/Services/section_label.dart';
import '../Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/dashboard_header.dart';

class AddProductInfo extends StatefulWidget {
  const AddProductInfo({super.key});

  @override
  State<AddProductInfo> createState() => _AddProductInfoState();
}

class _AddProductInfoState extends State<AddProductInfo> {
  Map? product;
  String? productId;
  bool isEditMode = false;

  final linkController = TextEditingController();
  final nameController = TextEditingController();
  final storeNameController = TextEditingController();
  final weightController = TextEditingController();
  final priceController = TextEditingController();
  final quantityController = TextEditingController();

  String? _linkError;
  String? _nameError;
  String? _storeNameError;
  String? _weightError;
  String? _priceError;
  String? _quantityError;

  bool _categoryError = false;
  bool _imageError = false;

  String? _imageUrl;
  String? selectedCategory;

  final GlobalKey<ImagePickerUploaderState> _imageKey =
      GlobalKey<ImagePickerUploaderState>();

  static const List<String> categoryValues = [
    'electronics',
    'clothing',
    'shoes',
    'accessories',
    'cosmetics',
    'medicine',
    'home',
    'books',
    'toys',
    'other'
        'fragrance'
  ];

  @override
  void initState() {
    super.initState();

    quantityController.text = "1";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Map && args['isEdit'] == true) {
        isEditMode = true;
        product = args['product'];

        productId = product?['requestId'] ??
            product?['id'] ??
            product?['_id']?.toString();
      } else {
        product = args as Map?;
        productId = product?['productId'];
      }

      if (product != null) {
        linkController.text = product?['storeLink'] ?? '';
        nameController.text = product?['name'] ?? '';
        storeNameController.text = product?['storeName'] ?? '';
        priceController.text = product?['price']?.toString() ?? '';
        weightController.text = product?['weight']?.toString() ?? '';
        quantityController.text = product?['quantity']?.toString() ?? "1";
        _imageUrl = product?['image'];
        final cat = product?['category']?.toString().toLowerCase();
        selectedCategory = categoryValues.contains(cat) ? cat : 'other';
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    linkController.dispose();
    nameController.dispose();
    storeNameController.dispose();
    weightController.dispose();
    priceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  bool isValidUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.isScheme("http") || uri.isScheme("https"));
  }

  bool isValidName(String value) {
    return value.trim().length >= 2;
  }

  bool isValidDouble(String value) => double.tryParse(value) != null;

  bool isValidInt(String value) => int.tryParse(value) != null;

  void clearError(String? value, void Function(String?) setError) {
    if (value != null && value.isNotEmpty) {
      setState(() => setError(null));
    }
  }

  String getPreference(String category) {
    const risky = ["electronics", "other"];

    return risky.contains(category.toLowerCase()) ? "risky" : "easy";
  }

  Future<void> _handleUpdate() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to Proceed')),
      );
      return;
    }

    final uploadedImage = await _imageKey.currentState?.uploadAndReturn();

    if (uploadedImage != null && uploadedImage.isNotEmpty) {
      _imageUrl = uploadedImage;
    }

    if (!mounted) return;

    final link = linkController.text.trim();
    final name = nameController.text.trim();
    final storeName = storeNameController.text.trim();
    final weight = weightController.text.trim();
    final price = priceController.text.trim();
    final qty = quantityController.text.trim();

    setState(() {
      _linkError = null;
      _nameError = null;
      _weightError = null;
      _priceError = null;
      _quantityError = null;
      _categoryError = false;
      _storeNameError = null;

      if (link.isEmpty) {
        _linkError = "Link is required";
      } else if (!isValidUrl(link)) {
        _linkError = "Enter valid URL";
      }

      if (name.isEmpty) {
        _nameError = "Name is required";
      }

      if (storeName.isEmpty) {
        _storeNameError = "Store Name is required";
      }

      if (weight.isEmpty || !isValidDouble(weight)) {
        _weightError = "Invalid";
      }

      if (price.isEmpty || !isValidDouble(price)) {
        _priceError = "Invalid";
      }

      if (qty.isEmpty || !isValidInt(qty)) {
        _quantityError = "Invalid";
      }

      _categoryError = selectedCategory == null || selectedCategory!.isEmpty;
      if (_imageKey.currentState?.file == null &&
          (_imageUrl == null || _imageUrl!.isEmpty)) {
        _imageError = true;
      } else {
        _imageError = false;
      }
      _imageError = _imageUrl == null || _imageUrl!.isEmpty;
    });

    if (_linkError != null ||
        _nameError != null ||
        _storeNameError != null ||
        _weightError != null ||
        _priceError != null ||
        _quantityError != null ||
        _categoryError ||
        _imageError) {
      return;
    }

    final payload = {
      "name": name,
      "image": _imageUrl,
      "storeName": storeName,
      "storeLink": link,
      "price": double.parse(price),
      "weight": double.parse(weight),
      "category": selectedCategory,
      "quantity": int.parse(qty),
      "userId": user.uid,
      "status": product?['status'] ?? "Requested",
      "createdAt": product?['createdAt'],
    };

    await ApiService.post(
      "/updateData",
      {
        "collection": "items",
        "id": productId,
        "data": payload,
      },
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Updated successfully")),
    );

    Navigator.pop(context, true);
  }

  Future<void> _handleNext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to Proceed')),
      );
      return;
    }
    final uploadedImage = await _imageKey.currentState?.uploadAndReturn();

    if (uploadedImage != null && uploadedImage.isNotEmpty) {
      _imageUrl = uploadedImage;
    }

    if (!mounted) return;

    final link = linkController.text.trim();
    final name = nameController.text.trim();
    final storeName = storeNameController.text.trim();
    final weight = weightController.text.trim();
    final price = priceController.text.trim();
    final qty = quantityController.text.trim();

    setState(() {
      _linkError = null;
      _nameError = null;
      _weightError = null;
      _priceError = null;
      _quantityError = null;
      _categoryError = false;

      if (link.isEmpty) {
        _linkError = "Link is required";
        linkController.clear();
      } else if (!isValidUrl(link)) {
        _linkError = "Enter valid URL";
        linkController.clear();
      }

      if (name.isEmpty) {
        _nameError = "Name is required";
        nameController.clear();
      } else if (!isValidName(name)) {
        _nameError = "Enter Valid Name";
        nameController.clear();
      }

      if (storeName.isEmpty) {
        _storeNameError = "Store Name is required";
        storeNameController.clear();
      } else if (!isValidName(storeName)) {
        _storeNameError = "Enter Valid Store Name";
        storeNameController.clear();
      }

      if (weight.isEmpty) {
        _weightError = "Required";
        weightController.clear();
      } else {
        if (weight.isEmpty) {
          _weightError = "Required";
          weightController.clear();
        } else {
          final wt = double.tryParse(weight.trim());
          final quantityVal = int.tryParse(qty);

          if (wt == null || wt <= 0) {
            _weightError = "Invalid";
            weightController.clear();
          } else if (quantityVal == null || quantityVal <= 0) {
            _quantityError = "Invalid";
            quantityController.clear();
          } else if ((wt * quantityVal) > 20) {
            _weightError = "Max !";
            weightController.clear();
          }
        }
      }
      if (price.isEmpty) {
        _priceError = "Required";
        priceController.clear();
      } else {
        final priceValue = double.tryParse(price.trim());

        if (priceValue == null || priceValue <= 0) {
          _priceError = "Invalid";
          priceController.clear();
        }
      }

      if (qty.isEmpty) {
        _quantityError = "Quantity is required";
        quantityController.clear();
      } else if (!isValidInt(qty)) {
        _quantityError = "Enter valid number";
        quantityController.clear();
      }

      _categoryError = selectedCategory == null || selectedCategory!.isEmpty;
      _imageError = _imageKey.currentState?.hasImage != true;
    });

    if (_linkError != null ||
        _nameError != null ||
        _storeNameError != null ||
        _weightError != null ||
        _priceError != null ||
        _quantityError != null ||
        _categoryError ||
        _imageError) {
      return;
    }
    final preference = getPreference(selectedCategory ?? "");
    final details = {
      "name": name,
      "image": _imageUrl,
      "storeName": storeName,
      "storeLink": link,
      "price": double.parse(price),
      "weight": double.parse(weight),
      "category": selectedCategory,
      "tags": [selectedCategory, storeName.toLowerCase()],
      "quantity": int.parse(qty),
      "preference": preference,
    };

    if (productId == null) {
      final productData = Map<String, dynamic>.from(details);

      productData.remove("quantity");

      final result = await ApiService.post(
        "/createData",
        {
          "collection": "Products",
          "data": productData,
        },
      );
      // print("Product created with id: $result");
      if (!mounted) return;

      productId = result["insertedId"];
    }
    Navigator.pushNamed(context, '/ShippingForm', arguments: details);
  }

  void updateQuantity(int change) {
    int value = int.tryParse(quantityController.text) ?? 1;
    value += change;

    if (value < 1) value = 1;

    setState(() {
      quantityController.text = value.toString();
    });
  }

  Widget space() => const SizedBox(height: 20);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: isEditMode ? "Edit Product " : "Create Item Request",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            infoCard([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionLabel('STORE DETAILS',
                      icon: Icons.store_mall_directory_outlined),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      CustomInputField(
                        controller: linkController,
                        hint: _linkError ?? " Item Link...",
                        icon: Icons.link,
                        hasError: _linkError != null,
                      ),
                      CustomInputField(
                        controller: storeNameController,
                        hint: _storeNameError ?? "Store Name",
                        icon: Symbols.home,
                        hasError: _storeNameError != null,
                      ),
                    ],
                  ),
                ],
              ),
            ]),
            space(),
            infoCard([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionLabel('PRODUCT DETAILS', icon: Icons.info_outline),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      CustomInputField(
                        controller: nameController,
                        hint: _nameError ?? " Item Name...",
                        icon: Symbols.package_2,
                        hasError: _nameError != null,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: CustomInputField(
                          controller: weightController,
                          hint: _weightError ?? "Weight (kg)",
                          icon: Icons.scale_outlined,
                          hasError: _weightError != null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomInputField(
                          controller: priceController,
                          hint: _priceError ?? "Price (USD)",
                          icon: Icons.attach_money,
                          hasError: _priceError != null,
                        ),
                      ),
                    ],
                  ),
                  CustomInputField(
                    controller: quantityController,
                    hint: _quantityError ?? "",
                    icon: Icons.numbers,
                    hasError: _quantityError != null,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: () => updateQuantity(-1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () => updateQuantity(1),
                        ),
                      ],
                    ),
                  ),
                  CustomInputField(
                    hint: _categoryError ? "Select Category" : "Item Category",
                    icon: Icons.category_outlined,
                    value: selectedCategory,
                    hasError: _categoryError,
                    categoryItems: const [
                      DropdownMenuItem(
                          value: 'electronics', child: Text('Electronics')),
                      DropdownMenuItem(
                          value: 'clothing', child: Text('Clothing')),
                      DropdownMenuItem(value: 'shoes', child: Text('Shoes')),
                      DropdownMenuItem(
                          value: 'accessories', child: Text('Accessories')),
                      DropdownMenuItem(
                          value: 'cosmetics', child: Text('Cosmetics')),
                      DropdownMenuItem(
                          value: 'medicine', child: Text('Medicine')),
                      DropdownMenuItem(
                          value: 'home', child: Text('Home & Garden')),
                      DropdownMenuItem(value: 'sports', child: Text('Sports')),
                      DropdownMenuItem(value: 'books', child: Text('Books')),
                      DropdownMenuItem(
                          value: 'fragrance', child: Text('Fragrance')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChangedDropdown: (value) {
                      setState(() {
                        selectedCategory = value;
                        _categoryError = false;
                      });
                    },
                  ),
                  space(),
                  ImagePickerUploader(
                    key: _imageKey,
                    initialImage: _imageUrl,
                    hasError: _imageError,
                    onChanged: (url) {
                      setState(() {
                        _imageUrl = url;

                        if (url == null || url.isEmpty) {
                          _imageError = true;
                        } else {
                          _imageError = false;
                        }
                      });
                    },
                  ),
                ],
              ),
            ]),
            space(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: appPrimaryButton(
                text: isEditMode ? 'Update' : 'Proceed',
                onPressed: isEditMode ? _handleUpdate : _handleNext,
              ),
            ),
            space(),
            space()
          ],
        ),
      ),
    );
  }
}
