import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../models/food_donation.dart';
import '../../services/prediction_service.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';

class AddDonationScreen extends StatefulWidget {
  const AddDonationScreen({super.key});

  @override
  State<AddDonationScreen> createState() => _AddDonationScreenState();
}

class _AddDonationScreenState extends State<AddDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _addressController = TextEditingController();

  final PredictionService _predictionService = PredictionService();
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();

  List<String> _foodTypes = [];
  String? _selectedFoodType;
  String _storageCondition = 'room'; // 'room' or 'fridge'
  String _packaging = 'open'; // 'open' or 'closed'
  double _temperature = 28.0;
  DateTime _prepTime = DateTime.now();
  
  double _latitude = 0.0;
  double _longitude = 0.0;

  XFile? _imageFile;
  bool _isLoading = false;
  bool _fetchingLocation = false;
  
  double? _predictedShelfLife;
  bool _predictionPassed = false;
  String? _predictionError;

  final FocusNode _addressFocusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadFoodTypes();
    _autoDetectLocation();
    _addressFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _addressFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _addressController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  void _loadFoodTypes() async {
    try {
      final types = await _predictionService.fetchFoodTypes();
      setState(() {
        _foodTypes = types;
        if (types.isNotEmpty) {
          _selectedFoodType = types[0];
        }
      });
    } catch (_) {
      // Handled by fetchFoodTypes fallback list
    }
  }

  Future<void> _autoDetectLocation() async {
    setState(() {
      _fetchingLocation = true;
    });
    try {
      final position = await _locationService.determinePosition();
      final address = await _locationService.getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _addressController.text = address;
        _fetchingLocation = false;
      });
    } catch (_) {
      setState(() {
        _fetchingLocation = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  // Predict shelf life with API check
  void _checkShelfLifeSafety() async {
    if (_selectedFoodType == null) return;
    
    setState(() {
      _isLoading = true;
      _predictionError = null;
      _predictedShelfLife = null;
      _predictionPassed = false;
    });

    final elapsedHours = DateTime.now().difference(_prepTime).inMinutes / 60.0;

    try {
      final prediction = await _predictionService.predictShelfLife(
        foodType: _selectedFoodType!,
        temperature: _temperature,
        timeSincePrep: elapsedHours,
        storageCondition: _storageCondition,
        packaging: _packaging,
      );

      final remaining = prediction - elapsedHours;
      final remainingActual = remaining < 0 ? 0.0 : remaining;

      setState(() {
        _predictedShelfLife = prediction;
        // Strict safety rule: If remaining shelf life is less than 4 hours, block posting
        _predictionPassed = remainingActual >= 4.0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _predictionError = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _predictionPassed = false;
      });
      _showErrorDialog(_predictionError!);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.red, size: 48),
        title: const Text('API Connection Error'),
        content: Text(
          '$message\n\nIf this is the first request in a while, the server may just be waking up from idle — please wait ~30 seconds and tap Re-verify.\n\nFoodLink requires a verified ML shelf-life check to post donations. Approximate or fallback predictions are not allowed for food safety reasons.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture an image of the food for transparency.')),
      );
      return;
    }
    if (_latitude == 0.0 || _longitude == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a valid pickup location.')),
      );
      return;
    }
    if (!_predictionPassed || _predictedShelfLife == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must run and pass the ML shelf-life verification first.')),
      );
      return;
    }

    // Re-check against the current time: the cached _predictionPassed flag was computed
    // whenever "Verify Shelf-Life" was last tapped, but the user may have spent minutes
    // filling out the rest of the form since then. Recompute remaining shelf life now
    // (no new network call needed — the total predicted shelf life doesn't change).
    final freshElapsedHours = DateTime.now().difference(_prepTime).inMinutes / 60.0;
    if (_predictedShelfLife! - freshElapsedHours < 4.0) {
      setState(() {
        _predictionPassed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remaining shelf life has dropped below 4 hours since verification — please re-verify.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final donationProvider = Provider.of<DonationProvider>(context, listen: false);

      // Upload image
      final imageUrl = await _storageService.uploadDonationImage(_imageFile!);

      final donation = FoodDonation(
        id: '', // Generated by backend/db
        providerId: authProvider.currentUser!.uid,
        providerName: authProvider.currentUser!.name,
        providerPhone: authProvider.currentUser!.phone,
        foodType: _selectedFoodType!,
        quantity: _quantityController.text.trim(),
        prepTime: _prepTime,
        storageCondition: _storageCondition,
        packaging: _packaging,
        temperature: _temperature,
        imageUrl: imageUrl,
        latitude: _latitude,
        longitude: _longitude,
        address: _addressController.text.trim(),
        predictedShelfLife: _predictedShelfLife!,
        status: 'active',
        createdAt: DateTime.now(),
      );

      final success = await donationProvider.postDonation(donation);
      
      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donation posted successfully! NGOs will be notified.')),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(donationProvider.error ?? 'Failed to post donation.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSelectedImage() {
    if (kIsWeb) {
      return Image.network(
        _imageFile!.path,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    } else {
      return Image.file(
        File(_imageFile!.path),
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
  }

  Future<void> _selectPrepTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 2)),
      lastDate: DateTime.now(),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _prepTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      // Reset prediction since time changed
      _predictedShelfLife = null;
      _predictionPassed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsedMinutes = DateTime.now().difference(_prepTime).inMinutes;
    final elapsedHours = (elapsedMinutes / 60.0).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Surplus Food'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading food details and verifying shelf life...'),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Camera Capture Box
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildSelectedImage(),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 48, color: theme.colorScheme.primary),
                                const SizedBox(height: 8),
                                Text(
                                  'Capture Food Photo',
                                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text('Required for quality check', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Food Type Dropdown
                  if (_foodTypes.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedFoodType,
                      decoration: const InputDecoration(
                        labelText: 'Food Item Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.restaurant_outlined),
                      ),
                      items: _foodTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.replaceAll('_', ' ').toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedFoodType = val;
                          _predictedShelfLife = null;
                          _predictionPassed = false;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quantity
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity / Servings description',
                      helperText: 'E.g., "15 kg", "Approx 40 plates"',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Enter quantity';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Preparation Time Picker
                  ListTile(
                    title: const Text('Preparation Timestamp'),
                    subtitle: Text('Prepared $elapsedHours hours ago (${_prepTime.hour.toString().padLeft(2, '0')}:${_prepTime.minute.toString().padLeft(2, '0')})'),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    onTap: _selectPrepTime,
                  ),
                  const SizedBox(height: 16),

                  // Storage condition toggles
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Room Storage')),
                          selected: _storageCondition == 'room',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _storageCondition = 'room';
                                _temperature = 28.0; // Default room temp
                                _predictedShelfLife = null;
                                _predictionPassed = false;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Refrigerated')),
                          selected: _storageCondition == 'fridge',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _storageCondition = 'fridge';
                                _temperature = 4.0; // Default fridge temp
                                _predictedShelfLife = null;
                                _predictionPassed = false;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Packaging condition toggles
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Open Container')),
                          selected: _packaging == 'open',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _packaging = 'open';
                                _predictedShelfLife = null;
                                _predictionPassed = false;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Sealed/Closed')),
                          selected: _packaging == 'closed',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _packaging = 'closed';
                                _predictedShelfLife = null;
                                _predictionPassed = false;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Temperature Slider
                  Text(
                    'Storage Temperature: ${_temperature.toStringAsFixed(1)}°C',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: _temperature,
                    min: _storageCondition == 'fridge' ? 0.0 : 18.0,
                    max: _storageCondition == 'fridge' ? 10.0 : 40.0,
                    divisions: 20,
                    label: '${_temperature.toStringAsFixed(1)}°C',
                    onChanged: (val) {
                      setState(() {
                        _temperature = val;
                        _predictedShelfLife = null;
                        _predictionPassed = false;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Pickup Location with Auto-suggestions
                  TextFormField(
                    controller: _addressController,
                    focusNode: _addressFocusNode,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Pickup Address',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      suffixIcon: _fetchingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.my_location),
                              onPressed: _autoDetectLocation,
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Enter pickup address';
                      return null;
                    },
                    onChanged: (val) {
                      setState(() {
                        // Rebuild to update suggestion lists
                      });
                    },
                  ),

                  // Custom suggestion list dropdown
                  if (_showSuggestions && _addressController.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        color: theme.colorScheme.surface,
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: _kAddressSuggestions
                              .where((s) => s.address.toLowerCase().contains(_addressController.text.toLowerCase()))
                              .map((suggestion) {
                                return ListTile(
                                  leading: const Icon(Icons.location_on, size: 16),
                                  title: Text(suggestion.address, style: const TextStyle(fontSize: 13)),
                                  dense: true,
                                  onTap: () {
                                    setState(() {
                                      _addressController.text = suggestion.address;
                                      _latitude = suggestion.latitude;
                                      _longitude = suggestion.longitude;
                                      _showSuggestions = false;
                                      _addressFocusNode.unfocus();
                                    });
                                  },
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ML prediction check section
                  if (_predictedShelfLife == null) ...[
                    OutlinedButton.icon(
                      onPressed: _checkShelfLifeSafety,
                      icon: const Icon(Icons.security),
                      label: const Text('Verify Shelf-Life with ML Model'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _predictionPassed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _predictionPassed ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _predictionPassed ? Icons.check_circle : Icons.error,
                                color: _predictionPassed ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _predictionPassed ? 'Shelf-Life Check Passed' : 'Shelf-Life Warning!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _predictionPassed ? Colors.green[900] : Colors.red[900],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _predictionPassed
                                ? 'Model predicts food is consumable for another ${_predictedShelfLife!.toStringAsFixed(1)} hours (Remaining: ${(_predictedShelfLife! - elapsedMinutes / 60.0).toStringAsFixed(1)} hours). You are cleared to post.'
                                : 'Predicted remaining consumable life is less than 4 hours. Under FoodLink safety policies, you cannot donate this item. Please compost or dispose of safely.',
                            style: TextStyle(
                              color: _predictionPassed ? Colors.green[900] : Colors.red[900],
                            ),
                          ),
                          if (!_predictionPassed) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _checkShelfLifeSafety,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Re-verify'),
                              style: TextButton.styleFrom(foregroundColor: Colors.red[900]),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Post Donation Button
                  ElevatedButton(
                    onPressed: _predictionPassed ? _submitPost : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Post Food Donation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class AddressSuggestion {
  final String address;
  final double latitude;
  final double longitude;

  const AddressSuggestion({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

const List<AddressSuggestion> _kAddressSuggestions = [
  AddressSuggestion(
    address: 'Taj Mahal Palace, Colaba, Mumbai, MH',
    latitude: 18.9217,
    longitude: 72.8330,
  ),
  AddressSuggestion(
    address: 'Gateway of India, Colaba, Mumbai, MH',
    latitude: 18.9230,
    longitude: 72.8310,
  ),
  AddressSuggestion(
    address: 'Chhatrapati Shivaji Terminus, Fort, Mumbai, MH',
    latitude: 18.9400,
    longitude: 72.8353,
  ),
  AddressSuggestion(
    address: 'Vidhana Soudha, Ambedkar Veedhi, Bengaluru, KA',
    latitude: 12.9796,
    longitude: 77.5906,
  ),
  AddressSuggestion(
    address: 'Lalbagh Botanical Garden, Mavalli, Bengaluru, KA',
    latitude: 12.9507,
    longitude: 77.5844,
  ),
  AddressSuggestion(
    address: 'Indiranagar Club, 9th Main Road, Indiranagar, Bengaluru, KA',
    latitude: 12.9719,
    longitude: 77.6394,
  ),
  AddressSuggestion(
    address: 'Phoenix Marketcity, Whitefield Road, Mahadevapura, Bengaluru, KA',
    latitude: 12.9958,
    longitude: 77.6963,
  ),
  AddressSuggestion(
    address: 'Manyata Tech Park, Nagawara, Bengaluru, KA',
    latitude: 13.0451,
    longitude: 77.6266,
  ),
  AddressSuggestion(
    address: 'Mall of Mysore, Indira Nagar, Mysuru, KA',
    latitude: 12.3015,
    longitude: 76.6651,
  ),
  AddressSuggestion(
    address: 'Infosys Campus, Hebbal Industrial Area, Mysuru, KA',
    latitude: 12.3500,
    longitude: 76.5900,
  ),
];
