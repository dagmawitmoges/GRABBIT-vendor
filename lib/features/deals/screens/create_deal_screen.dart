import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grabbit_vendor_app/core/config/env.dart';
import 'package:grabbit_vendor_app/core/data/vendor_repository.dart';
import 'package:grabbit_vendor_app/core/theme/vendor_theme.dart';
import 'package:grabbit_vendor_app/router/app_shell.dart';
import 'package:grabbit_vendor_app/core/network/dio_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;

class CreateDealScreen extends StatefulWidget {
  const CreateDealScreen({super.key});

  @override
  State<CreateDealScreen> createState() => _CreateDealScreenState();
}

class _CreateDealScreenState extends State<CreateDealScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final originalPriceController = TextEditingController();
  final discountPriceController = TextEditingController();
  final quantityController = TextEditingController();

  // State
  XFile? selectedImage;
  Uint8List? _imagePreviewBytes;
  String? selectedCategoryId;
  String? selectedSubcityId;
  DateTime? expiryDate;
  bool isLoading = false;
  String? imageErrorMessage;
  bool _catalogLoading = true;
  List<Map<String, String>> _categories = [];
  List<Map<String, String>> _locations = [];

  static const _fallbackCategories = [
    {'id': '1', 'name': 'Electronics'},
    {'id': '2', 'name': 'Fashion'},
    {'id': '3', 'name': 'Food & Beverage'},
    {'id': '4', 'name': 'Home & Garden'},
    {'id': '5', 'name': 'Beauty'},
  ];

  static const _fallbackLocations = [
    {'id': '1', 'name': 'Addis Ketema'},
    {'id': '2', 'name': 'Arada'},
    {'id': '3', 'name': 'Bole'},
    {'id': '4', 'name': 'Kolfe Keranio'},
    {'id': '5', 'name': 'Kirkos'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    if (!Env.hasSupabase) {
      setState(() {
        _categories = List<Map<String, String>>.from(_fallbackCategories);
        _locations = List<Map<String, String>>.from(_fallbackLocations);
        _catalogLoading = false;
      });
      return;
    }
    try {
      final repo = VendorRepository();
      final c = await repo.getCategories();
      final l = await repo.getLocations();
      if (!mounted) return;
      setState(() {
        _categories = c
            .map((e) => {
                  'id': e['id'].toString(),
                  'name': e['name']?.toString() ?? '',
                })
            .toList();
        _locations = l.map((e) {
          final sub = e['sub_city']?.toString().trim();
          final city = e['city']?.toString().trim();
          final parts = <String>[];
          if (sub != null && sub.isNotEmpty) parts.add(sub);
          if (city != null && city.isNotEmpty) parts.add(city);
          final label =
              parts.isEmpty ? (city ?? 'Location') : parts.join(', ');
          return {
            'id': e['id'].toString(),
            'name': label,
          };
        }).toList();
        _catalogLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _categories = List<Map<String, String>>.from(_fallbackCategories);
          _locations = List<Map<String, String>>.from(_fallbackLocations);
          _catalogLoading = false;
        });
      }
    }
  }

  /// 🔹 Check if image picker is available
  Future<bool> _isImagePickerAvailable() async {
    try {
      final available = await _imagePicker.supportsImageSource(ImageSource.gallery);
      return available;
    } catch (e) {
      return false;
    }
  }

  /// 🔹 Pick Image from Gallery with Enhanced Error Handling
  Future<void> pickImageFromGallery() async {
    try {
      // Check if plugin is available
      final isAvailable = await _isImagePickerAvailable();
      if (!isAvailable) {
        _showErrorDialog(
          'Image Picker Not Available',
          'The image picker plugin is not properly installed. '
          'Please follow the setup guide in IMAGE_PICKER_FIX.md',
        );
        setState(() {
          imageErrorMessage = 'Image picker plugin not configured';
        });
        return;
      }

      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked != null) {
        final fileSize = await picked.length();
        if (fileSize > 5 * 1024 * 1024) {
          setState(() {
            imageErrorMessage =
                "Image size must be less than 5MB (current: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB)";
            selectedImage = null;
            _imagePreviewBytes = null;
          });
          return;
        }

        final bytes = await picked.readAsBytes();
        setState(() {
          selectedImage = picked;
          _imagePreviewBytes = bytes;
          imageErrorMessage = null;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Image selected successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } on PlatformException catch (e) {
      _handlePlatformException(e);
    } catch (e) {
      _handleGeneralError(e);
    }
  }

  /// 🔹 Pick Image from Camera with Enhanced Error Handling
  Future<void> pickImageFromCamera() async {
    try {
      // Check if plugin is available
      final isAvailable = await _isImagePickerAvailable();
      if (!isAvailable) {
        _showErrorDialog(
          'Camera Not Available',
          'Camera access is not properly configured. '
          'Please check your permissions and plugin setup.',
        );
        return;
      }

      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (picked != null) {
        final fileSize = await picked.length();
        if (fileSize > 5 * 1024 * 1024) {
          setState(() {
            imageErrorMessage = 'Image too large (max 5MB)';
            selectedImage = null;
            _imagePreviewBytes = null;
          });
          return;
        }
        final bytes = await picked.readAsBytes();
        setState(() {
          selectedImage = picked;
          _imagePreviewBytes = bytes;
          imageErrorMessage = null;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Photo captured successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } on PlatformException catch (e) {
      _handlePlatformException(e);
    } catch (e) {
      _handleGeneralError(e);
    }
  }

  /// 🔹 Handle Platform Exceptions (permission denied, plugin issues, etc)
  void _handlePlatformException(PlatformException e) {
    String errorMessage = "Image picker error: ${e.message}";
    String errorCode = e.code;

    // Handle common error codes
    if (errorCode == 'photo_access_denied') {
      errorMessage = "Permission denied: Please allow gallery access in settings";
    } else if (errorCode == 'camera_access_denied') {
      errorMessage = "Permission denied: Please allow camera access in settings";
    } else if (errorCode == 'no_plugin') {
      errorMessage = "Image picker plugin not installed. Run: flutter pub get";
    } else if (errorCode == 'activity_result_error') {
      errorMessage = "Failed to access image. Please try again.";
    }

    setState(() {
      imageErrorMessage = errorMessage;
      selectedImage = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 🔹 Handle General Errors
  void _handleGeneralError(dynamic e) {
    String errorMessage = "Failed to pick image: ${e.toString()}";

    setState(() {
      imageErrorMessage = errorMessage;
      selectedImage = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 🔹 Show error dialog with instructions
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// 🔹 Show image picker options
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.photo_library, color: VendorTheme.forest),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                pickImageFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: VendorTheme.forest),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                pickImageFromCamera();
              },
            ),
            if (selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Image'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedImage = null;
                    _imagePreviewBytes = null;
                    imageErrorMessage = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Validate form and create deal
  Future<void> createDeal() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a product image")),
      );
      return;
    }

    if (expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an expiry date")),
      );
      return;
    }

    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a category")),
      );
      return;
    }

    if (selectedSubcityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a location")),
      );
      return;
    }

    if (_catalogLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Still loading categories — try again.')),
      );
      return;
    }

    // Validate prices
    try {
      int originalPrice = int.parse(originalPriceController.text);
      int discountPrice = int.parse(discountPriceController.text);

      if (discountPrice >= originalPrice) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Discount price must be less than original price"),
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid price format")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final imageBytes =
          _imagePreviewBytes ?? await selectedImage!.readAsBytes();
      if (imageBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read image. Please select again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => isLoading = false);
        return;
      }

      final title = titleController.text.trim();
      final description = descController.text.trim();
      final originalPrice = num.parse(originalPriceController.text);
      final discountedPrice = num.parse(discountPriceController.text);
      final quantity = int.parse(quantityController.text);
      final categoryId = selectedCategoryId!;
      final locationId = selectedSubcityId!;
      final expiry = expiryDate!;
      final fileName = selectedImage!.name.isNotEmpty
          ? selectedImage!.name
          : '${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (Env.hasSupabase) {
        await VendorRepository().createDeal(
          title: title,
          description: description,
          originalPrice: originalPrice,
          discountedPrice: discountedPrice,
          quantity: quantity,
          categoryId: categoryId,
          locationId: locationId,
          expiryTime: expiry,
          imageBytes: imageBytes,
          imageFileName: fileName,
        );
      } else {
        final formData = FormData.fromMap({
          'title': title,
          'description': description,
          'original_price': originalPrice,
          'discount_price': discountedPrice,
          'quantity_available': quantity,
          'total_quantity': quantity,
          'category_id': categoryId,
          'subcity_id': locationId,
          'expiry_date': expiry.toIso8601String(),
          'image': MultipartFile.fromBytes(
            imageBytes,
            filename: fileName,
          ),
        });
        await DioClient.instance.post('/api/deals', data: formData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✨ Deal created successfully!'),
            backgroundColor: VendorTheme.forest,
            duration: const Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on StorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Storage error: ${e.message}. Create bucket "${Env.supabaseDealImagesBucket}" and policies.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on DioException catch (e) {
      String errorMessage = "Failed to create deal";
      if (e.response?.data != null) {
        errorMessage = e.response?.data['message'] ?? errorMessage;
      } else if (e.message != null) {
        errorMessage = "Network error: ${e.message}";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  /// 🔹 Pick expiry date with better validation
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: VendorTheme.forest,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => expiryDate = picked);
    }
  }

  /// 🔹 Calculate discount percentage
  String getDiscountPercentage() {
    try {
      int original = int.parse(originalPriceController.text);
      int discount = int.parse(discountPriceController.text);
      if (original == 0) return "0%";
      int percentage = ((original - discount) / original * 100).toInt();
      return "$percentage%";
    } catch (e) {
      return "0%";
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    originalPriceController.dispose();
    discountPriceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPad = appShellBodyBottomPadding(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create New Deal'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Column(
          children: [
            // Header section with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, VendorTheme.forestLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Product Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill in the information below to create your deal',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            ),
            // Form content
            Padding(
              padding: const EdgeInsets.all(20),
                child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_catalogLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(),
                      ),
                    // 🔥 IMAGE PICKER SECTION
                    _buildImagePickerSection(),
                    const SizedBox(height: 28),

                    // TITLE
                    _buildInputField(
                      controller: titleController,
                      label: 'Product Title',
                      hint: 'e.g., Premium Wireless Headphones',
                      prefixIcon: Icons.shopping_bag,
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Title is required";
                        if (v.length < 3) return "Title must be at least 3 characters";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // DESCRIPTION
                    _buildInputField(
                      controller: descController,
                      label: 'Description',
                      hint: 'Describe your product features and benefits',
                      prefixIcon: Icons.description,
                      maxLines: 3,
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Description is required";
                        if (v.length < 10) return "Description must be at least 10 characters";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // CATEGORY DROPDOWN
                    _buildDropdown(
                      label: 'Category',
                      value: selectedCategoryId,
                      items: _categories,
                      onChanged: (value) {
                        setState(() => selectedCategoryId = value);
                      },
                      prefixIcon: Icons.category,
                    ),
                    const SizedBox(height: 16),

                    // SUBCITY DROPDOWN
                    _buildDropdown(
                      label: 'Location',
                      value: selectedSubcityId,
                      items: _locations,
                      onChanged: (value) {
                        setState(() => selectedSubcityId = value);
                      },
                      prefixIcon: Icons.location_on,
                    ),
                    const SizedBox(height: 24),

                    // PRICES SECTION
                    Text(
                      'Pricing',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: originalPriceController,
                            label: 'Original Price',
                            hint: '0',
                            prefixIcon: Icons.attach_money,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return "Original price is required";
                              if (int.parse(v) <= 0) return "Must be > 0";
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            controller: discountPriceController,
                            label: 'Discount Price',
                            hint: '0',
                            prefixIcon: Icons.local_offer,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return "Discount price is required";
                              if (int.parse(v) < 0) return "Invalid";
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Discount badge
                    if (originalPriceController.text.isNotEmpty &&
                        discountPriceController.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: VendorTheme.limeMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: VendorTheme.lime.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'Discount: ${getDiscountPercentage()} off',
                          style: TextStyle(
                            color: VendorTheme.forest,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // QUANTITY
                    _buildInputField(
                      controller: quantityController,
                      label: 'Quantity Available',
                      hint: '0',
                      prefixIcon: Icons.inventory_2,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Quantity is required";
                        if (int.parse(v) <= 0) return "Must be > 0";
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // EXPIRY DATE
                    Text(
                      'Offer Expiry',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildDatePicker(),
                    const SizedBox(height: 32),

                    // CREATE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: isLoading ? null : createDeal,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Create Deal',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Build image picker section
  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Image',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selectedImage == null
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.35)
                    : VendorTheme.lime.withValues(alpha: 0.8),
                width: 2,
              ),
              color: selectedImage == null
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.06)
                  : VendorTheme.limeMuted,
            ),
            child: selectedImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 48,
                        color: VendorTheme.forest,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to add product image',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: VendorTheme.forest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, PNG (Max 5MB)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _imagePreviewBytes != null
                            ? Image.memory(
                                _imagePreviewBytes!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : const SizedBox.expand(),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: _showImagePickerOptions,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: VendorTheme.forest,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (imageErrorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    imageErrorMessage!,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 🔹 Build text input field
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator ?? (v) => v!.isEmpty ? "$label is required" : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: VendorTheme.forest, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  /// 🔹 Build dropdown field
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
    IconData? prefixIcon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Select $label'),
        ),
        ...items.map((item) {
          return DropdownMenuItem<String>(
            value: item['id'],
            child: Text(item['name']!),
          );
        }).toList(),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: VendorTheme.forest, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  /// 🔹 Build date picker section
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: VendorTheme.forest,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expiry Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expiryDate == null
                        ? 'Select expiry date'
                        : DateFormat('MMM dd, yyyy').format(expiryDate!),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: expiryDate == null
                          ? Colors.grey[600]
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            if (expiryDate != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  setState(() => expiryDate = null);
                },
                color: Colors.grey[600],
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}