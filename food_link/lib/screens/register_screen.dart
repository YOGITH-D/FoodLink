import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import 'provider/provider_dashboard.dart';
import 'receiver/receiver_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final LocationService _locationService = LocationService();
  final FocusNode _addressFocusNode = FocusNode();

  String _selectedRole = 'receiver'; // 'provider' or 'receiver'
  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _fetchingLocation = false;
  bool _obscurePassword = true;

  List<AddressSuggestion> _addressSuggestions = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _addressFocusNode.addListener(() {
      if (!_addressFocusNode.hasFocus) {
        setState(() => _addressSuggestions = []);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _addressFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onAddressChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await _locationService.searchAddress(query);
      if (mounted) {
        setState(() => _addressSuggestions = results);
      }
    });
  }

  void _selectSuggestion(AddressSuggestion suggestion) {
    setState(() {
      _addressController.text = suggestion.displayName;
      _latitude = suggestion.latitude;
      _longitude = suggestion.longitude;
      _addressSuggestions = [];
    });
    _addressFocusNode.unfocus();
  }

  // Detect and set address + coordinates using LocationService
  void _detectLocation() async {
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

      if (mounted) {
        // accuracy == 0.0 is the signature of LocationService's fallback
        // position (used when GPS is unavailable/denied) rather than a
        // real device fix — surface that distinction instead of claiming
        // success either way.
        final usedFallback = position.accuracy == 0.0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              usedFallback
                  ? 'Could not access device GPS — using an approximate location instead. You can type your real address above.'
                  : 'Location detected successfully!',
            ),
            backgroundColor: usedFallback ? Colors.amber[800] : null,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _fetchingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to detect location: ${e.toString()}')),
        );
      }
    }
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_latitude == 0.0 || _longitude == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please auto-detect location or fill coordinate info before registering.'),
            backgroundColor: Colors.amber,
          ),
        );
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        role: _selectedRole,
        address: _addressController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        phone: _phoneController.text.trim(),
      );

      if (success && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => _selectedRole == 'provider'
                ? const ProviderDashboard()
                : const ReceiverDashboard(),
          ),
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Registration failed.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Join FoodLink',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your role and register to start fighting food waste.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Role Selection Toggle
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('Surplus Provider'),
                            ),
                          ),
                          selected: _selectedRole == 'provider',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedRole = 'provider';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text('Food Receiver'),
                            ),
                          ),
                          selected: _selectedRole == 'receiver',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedRole = 'receiver';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Organization/Indiv Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _selectedRole == 'provider' ? 'Hotel / Restaurant Name' : 'NGO / Orphanage Name',
                      prefixIcon: const Icon(Icons.business_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone Number
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number',
                      helperText: 'Used by the other party to call/SMS you to arrange pickup',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a contact phone number';
                      }
                      final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digitsOnly.length < 10) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Location Address Field
                  TextFormField(
                    controller: _addressController,
                    focusNode: _addressFocusNode,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Physical Address',
                      helperText: 'Type to search, or tap the location icon to auto-detect',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      suffixIcon: _fetchingLocation
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.my_location),
                              tooltip: 'Detect Location',
                              onPressed: _detectLocation,
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: _onAddressChanged,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter or detect your address';
                      }
                      return null;
                    },
                  ),

                  if (_addressSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        color: theme.colorScheme.surface,
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: _addressSuggestions.map((suggestion) {
                            return ListTile(
                              leading: const Icon(Icons.location_on, size: 16),
                              title: Text(suggestion.displayName, style: const TextStyle(fontSize: 13)),
                              dense: true,
                              onTap: () => _selectSuggestion(suggestion),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],

                  if (_latitude != 0.0 && _longitude != 0.0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Coordinates: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Register Button
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Register Now',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
