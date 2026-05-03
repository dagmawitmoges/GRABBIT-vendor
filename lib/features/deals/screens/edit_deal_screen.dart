import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit_vendor_app/core/config/env.dart';
import 'package:grabbit_vendor_app/core/data/vendor_repository.dart';
import 'package:grabbit_vendor_app/core/theme/vendor_theme.dart';
import 'package:grabbit_vendor_app/router/app_shell.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class EditDealScreen extends StatefulWidget {
  const EditDealScreen({super.key, required this.dealId});

  final String dealId;

  @override
  State<EditDealScreen> createState() => _EditDealScreenState();
}

class _EditDealScreenState extends State<EditDealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _original = TextEditingController();
  final _discount = TextEditingController();
  final _qty = TextEditingController();

  String? _categoryId;
  String? _locationId;
  DateTime? _expiry;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  List<Map<String, String>> _categories = [];
  List<Map<String, String>> _locations = [];

  XFile? _newImage;
  Uint8List? _newImageBytes;
  String? _existingImageUrl;

  static const _fbCat = [
    {'id': '1', 'name': 'Electronics'},
    {'id': '2', 'name': 'Fashion'},
  ];
  static const _fbLoc = [
    {'id': '1', 'name': 'Location 1'},
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final repo = VendorRepository();
      final deal = await repo.getDealById(widget.dealId);
      if (!Env.hasSupabase) {
        _categories = List.from(_fbCat);
        _locations = List.from(_fbLoc);
      } else {
        try {
          final c = await repo.getCategories();
          final l = await repo.getLocations();
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
            return {'id': e['id'].toString(), 'name': label};
          }).toList();
        } catch (_) {
          _categories = List.from(_fbCat);
          _locations = List.from(_fbLoc);
        }
      }

      _title.text = deal['title']?.toString() ?? '';
      _desc.text = deal['description']?.toString() ?? '';
      _original.text = '${deal['original_price'] ?? ''}';
      _discount.text = '${deal['discounted_price'] ?? ''}';
      _qty.text = '${deal['quantity_available'] ?? 0}';
      _categoryId = deal['category_id']?.toString();
      _locationId = deal['location_id']?.toString();
      final exp = deal['expiry_date'] ?? deal['expiry_time'];
      if (exp != null) {
        _expiry = DateTime.tryParse(exp.toString())?.toLocal();
      }
      final imgs = deal['images'];
      if (imgs is List && imgs.isNotEmpty && imgs.first is String) {
        _existingImageUrl = imgs.first as String;
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '$e';
        });
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _original.dispose();
    _discount.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final len = await picked.length();
    if (len > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image must be under 5MB')),
        );
      }
      return;
    }
    final bytes = await picked.readAsBytes();
    setState(() {
      _newImage = picked;
      _newImageBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an expiry date')),
      );
      return;
    }
    if (_categoryId == null || _locationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select category and location')),
      );
      return;
    }

    final orig = int.parse(_original.text);
    final disc = int.parse(_discount.text);
    if (disc >= orig) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discount price must be less than original price'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = VendorRepository();
      if (_newImageBytes != null && _newImage != null) {
        await repo.replaceDealImage(
          dealId: widget.dealId,
          imageBytes: _newImageBytes!,
          imageFileName: _newImage!.name.isNotEmpty
              ? _newImage!.name
              : 'deal.jpg',
        );
      }

      await repo.updateDeal(
        dealId: widget.dealId,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        originalPrice: orig,
        discountedPrice: disc,
        quantityRemaining: int.parse(_qty.text),
        categoryId: _categoryId,
        locationId: _locationId,
        expiryTime: _expiry,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deal updated')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPad = appShellBodyBottomPadding(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Edit deal')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Edit deal')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _loadError = null;
                      _loading = true;
                    });
                    _bootstrap();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit deal'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product image',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: _newImageBytes != null
                        ? Image.memory(_newImageBytes!, fit: BoxFit.cover)
                        : _existingImageUrl != null
                            ? Image.network(
                                _existingImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    ColoredBox(
                                  color: scheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: scheme.onSurfaceVariant,
                                    size: 40,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: scheme.onSurfaceVariant,
                                  size: 40,
                                ),
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to replace image (optional)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().length < 3 ? 'Min 3 characters' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Select'),
                  ),
                  ..._categories.map(
                    (e) => DropdownMenuItem<String>(
                      value: e['id'],
                      child: Text(e['name']!),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _locationId,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Select'),
                  ),
                  ..._locations.map(
                    (e) => DropdownMenuItem<String>(
                      value: e['id'],
                      child: Text(e['name']!),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _locationId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _original,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Original price',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (int.tryParse(v) == null || int.parse(v) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _discount,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Discount price',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final d = int.tryParse(v);
                        if (d == null || d < 0) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qty,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Quantity remaining',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final q = int.tryParse(v);
                  if (q == null || q < 0) return 'Must be ≥ 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expiry date'),
                subtitle: Text(
                  _expiry == null
                      ? 'Not set'
                      : DateFormat.yMMMd().format(_expiry!),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
