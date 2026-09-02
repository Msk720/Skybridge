import 'package:skybridge02/Services/DashBoardHelper/api_service.dart';
import 'package:skybridge02/Services/app_imports.dart';
import 'dart:io';
import 'package:skybridge02/Services/custom_inputfield.dart';
import 'package:skybridge02/Services/field_display_tile.dart';
import 'package:skybridge02/Services/app_button.dart';
import 'package:skybridge02/Services/dashboard_header.dart';
import 'package:skybridge02/Services/image_picker_uploader.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final uploaderKey = GlobalKey<ImagePickerUploaderState>();

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController contactController;
  late TextEditingController addressController;

  String? profileImageUrl;

  int orders = 0;
  int shipments = 0;
  int trips = 0;
  double ratingAverage = 0;
  int ratingCount = 0;

  bool loading = true;

  Map<String, dynamic>? profile;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController();
    contactController = TextEditingController();
    addressController = TextEditingController();

    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    contactController.dispose();
    addressController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool _hasText(dynamic value) {
    return value != null && value.toString().trim().isNotEmpty;
  }

  bool get _hasCompleteProfile {
    final p = profile;
    if (p == null) return false;

    final hasRequiredDetails = _hasText(p['name']) &&
        _hasText(p['contact']) &&
        _hasText(p['address']) &&
        _hasText(p['profilePicUrl']);

    return p['isComplete'] == true || hasRequiredDetails;
  }

  bool _requestedEditMode(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map && args['edit'] == true;
  }

  bool _validateFields() {
    final name = nameController.text.trim();
    final contact = contactController.text.trim();
    final address = addressController.text.trim();

    final nameRegex = RegExp(r'^[A-Za-z]+(?: [A-Za-z]+)*$');
    final phoneRegex = RegExp(r'^[0-9]{7,15}$');

    if (name.isEmpty || contact.isEmpty || address.isEmpty) {
      _showError('All fields are required');
      return false;
    }

    if (!nameRegex.hasMatch(name)) {
      _showError('Name can only contain letters and spaces');
      return false;
    }

    if (!phoneRegex.hasMatch(contact)) {
      _showError('Please enter a valid contact number');
      return false;
    }

    final uploader = uploaderKey.currentState;

    if ((uploader?.file == null) &&
        (profileImageUrl == null || profileImageUrl!.isEmpty)) {
      _showError('Enter profile image to complete');
      return false;
    }

    return true;
  }

  int _toStatInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toStatDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> loadProfile() async {
    if (user == null) {
      if (!mounted) return;

      setState(() {
        profile = <String, dynamic>{};
        ratingAverage = 0;
        ratingCount = 0;
        loading = false;
      });

      return;
    }

    setState(() => loading = true);

    try {
      final raw = await ApiService.get('/getProfile');
      final p =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

      if (!mounted) return;

      final hasSavedProfile = _hasText(p['name']) ||
          _hasText(p['contact']) ||
          _hasText(p['address']) ||
          _hasText(p['profilePicUrl']);

      setState(() {
        profile = p;

        if (hasSavedProfile) {
          nameController.text = p['name']?.toString() ?? '';
          emailController.text = p['email']?.toString() ?? user?.email ?? '';
          contactController.text = p['contact']?.toString() ?? '';
          addressController.text = p['address']?.toString() ?? '';
          profileImageUrl = p['profilePicUrl']?.toString();
        } else {
          nameController.clear();
          emailController.text = user?.email ?? '';
          contactController.clear();
          addressController.clear();
          profileImageUrl = null;
        }

        ratingAverage = _toStatDouble(p['ratingAverage']);
        ratingCount = _toStatInt(p['ratingCount']);
        loading = false;
      });

      await loadProfileStats();
    } catch (e) {
      debugPrint('Load profile error: $e');

      if (!mounted) return;

      setState(() {
        profile = <String, dynamic>{};
        emailController.text = user?.email ?? '';
        loading = false;
      });

      _showError('Unable to load profile. Please try again.');
    }
  }

  Future<void> loadProfileStats() async {
    if (user == null) return;

    try {
      final raw = await ApiService.get('/getProfileStats');
      final response =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

      final data = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'])
          : response;

      if (!mounted) return;

      setState(() {
        orders = _toStatInt(data['orders'] ?? data['deals']);
        shipments = _toStatInt(data['shipments']);
        trips = _toStatInt(data['trips']);
      });
    } catch (e) {
      debugPrint('Load profile stats error: $e');
    }
  }

  Future<void> saveProfile() async {
    if (user == null) return;
    if (!_validateFields()) return;

    setState(() => loading = true);

    String? imageUrl = profileImageUrl;

    try {
      final uploadedUrl = await uploaderKey.currentState?.uploadAndReturn();
      imageUrl = uploadedUrl ?? profileImageUrl;
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      _showError('Image upload failed. Please try again.');
      return;
    }

    final body = {
      'name': nameController.text.trim(),
      'email': user!.email,
      'contact': contactController.text.trim(),
      'address': addressController.text.trim(),
      'profilePicUrl': imageUrl,
      'isComplete': true,
    };

    try {
      await ApiService.post('/saveProfile', body);

      if (!mounted) return;

      setState(() => loading = false);
      Navigator.pushNamedAndRemoveUntil(context, '/gate', (_) => false);
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInitialLoading = loading && profile == null;
    final requestedEdit = _requestedEditMode(context);
    final isCompleteProfileMode =
        !requestedEdit && !isInitialLoading && !_hasCompleteProfile;
    final isEditing = requestedEdit || isCompleteProfileMode;
    final pageTitle = isInitialLoading
        ? (requestedEdit ? 'Edit Profile' : 'Complete Profile')
        : isCompleteProfileMode
            ? 'Complete Profile'
            : isEditing
                ? 'Edit Profile'
                : 'My Profile';
    final showBackButton =
        !(isCompleteProfileMode || (isInitialLoading && !requestedEdit));

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: dashboardAppBar(
        title: pageTitle,
        leading: showBackButton
            ? Container(
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
              )
            : null,
      ),
      body: isInitialLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
              child: Column(
                children: [
                  _profileHeader(allowImageEdit: isEditing),
                  const SizedBox(height: 18),
                  _profileStatsCard(),
                  const SizedBox(height: 22),
                  isEditing ? _editProfileSection() : _viewProfileSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _profileHeader({required bool allowImageEdit}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: _buildProfileImage(),
                  ),
                ),
              ),
              if (allowImageEdit)
                GestureDetector(
                  onTap: () async {
                    await uploaderKey.currentState?.pickImage();
                    setState(() {});
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 17, color: Colors.white),
                  ),
                ),
            ],
          ),
          SizedBox.shrink(
            child: ImagePickerUploader(
              key: uploaderKey,
              initialImage: profileImageUrl,
              onChanged: (value) {
                profileImageUrl = value;
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            nameController.text.trim().isEmpty
                ? 'Username'
                : nameController.text.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 21),
              const SizedBox(width: 4),
              Text(
                ratingCount > 0
                    ? '${ratingAverage.toStringAsFixed(1)} • $ratingCount ratings'
                    : 'No ratings yet',
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewProfileSection() {
    return Column(
      children: [
        _infoCard(
          title: 'Profile Information',
          children: [
            _infoTile(Icons.email_outlined, 'Email', emailController.text),
            _infoTile(Icons.person_outline, 'Name', nameController.text),
            _infoTile(Icons.phone_outlined, 'Contact', contactController.text),
            _infoTile(
                Icons.location_on_outlined, 'Address', addressController.text),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: appPrimaryButton(
            text: 'Edit Profile',
            loading: false,
            height: 54,
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                '/profile',
                arguments: {'edit': true},
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _editProfileSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Details',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          _profileField(
            Icons.email,
            'Email',
            emailController,
            enabled: false,
            keyboardType: TextInputType.emailAddress,
            maxLines: 1,
          ),
          _profileField(
            Icons.person,
            'Name',
            nameController,
            onChanged: (_) => setState(() {}),
          ),
          _profileField(
            Icons.phone,
            'Contact',
            contactController,
            keyboardType: TextInputType.phone,
          ),
          _profileField(
            Icons.location_on,
            'Address',
            addressController,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: appPrimaryButton(
              text: 'Save Changes',
              loading: loading,
              height: 54,
              onPressed: saveProfile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return FieldDisplayTile(
      icon: icon,
      label: label,
      value: value,
    );
  }

  Widget _profileField(
    IconData icon,
    String hint,
    TextEditingController controller, {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: maxLines == 1 ? 64.0 : null,
        child: CustomInputField(
          controller: controller,
          hint: hint,
          icon: icon,
          enabled: enabled,
          readOnly: !enabled,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _profileStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _statBlock('Orders', orders)),
          _verticalDivider(),
          Expanded(child: _statBlock('Shipments', shipments)),
          _verticalDivider(),
          Expanded(child: _statBlock('Trips', trips)),
        ],
      ),
    );
  }

  Widget _statBlock(String label, int value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(height: 40, width: 1, color: AppColors.kDarkDivider);
  }

  Widget _buildProfileImage() {
    final uploader = uploaderKey.currentState;

    if (uploader?.file != null) {
      if (kIsWeb) {
        return Image.network(
          uploader!.file!.path,
          fit: BoxFit.cover,
        );
      } else {
        return Image.file(
          File(uploader!.file!.path),
          fit: BoxFit.cover,
        );
      }
    }

    if (profileImageUrl?.isNotEmpty == true) {
      return Image.network(profileImageUrl!, fit: BoxFit.cover);
    }

    return Container(
      color: Colors.grey.shade300,
      child: const Icon(Icons.person, size: 60),
    );
  }
}
