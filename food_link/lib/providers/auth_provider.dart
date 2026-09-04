import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  AppUser? _currentUser;
  bool _isLoading = true;
  String? _error;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _initAuthListener();
  }

  // Initialize and listen to active auth changes
  void _initAuthListener() {
    _authService.authStateChanges.listen((uid) async {
      _isLoading = true;
      notifyListeners();

      if (uid != null) {
        try {
          _currentUser = await _authService.getUserDetails(uid);
          _error = null;
        } catch (e) {
          _error = e.toString();
          _currentUser = null;
        }
      } else {
        _currentUser = null;
        _error = null;
      }
      
      _isLoading = false;
      notifyListeners();
    });
  }

  // Clear current error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Login action
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.login(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register action
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String address,
    required double latitude,
    required double longitude,
    required String phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentUser = await _authService.register(
        email: email,
        password: password,
        name: name,
        role: role,
        address: address,
        latitude: latitude,
        longitude: longitude,
        phone: phone,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Send a password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    _error = null;
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Logout action
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    await _authService.logout();
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }
}
