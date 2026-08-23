import 'dart:async';
import 'package:flutter/material.dart';
import '../models/food_donation.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class DonationProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final LocationService _locationService = LocationService();

  List<FoodDonation> _activeDonations = [];
  List<FoodDonation> _providerDonations = [];
  List<FoodDonation> _acceptedDonations = [];
  
  bool _isLoading = false;
  String? _error;

  // Track subscription objects to clean up resources on dispose
  StreamSubscription? _activeSubscription;
  StreamSubscription? _providerSubscription;
  StreamSubscription? _receiverSubscription;

  List<FoodDonation> get activeDonations => _activeDonations;
  List<FoodDonation> get providerDonations => _providerDonations;
  List<FoodDonation> get acceptedDonations => _acceptedDonations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void dispose() {
    _activeSubscription?.cancel();
    _providerSubscription?.cancel();
    _receiverSubscription?.cancel();
    super.dispose();
  }

  // Subscribe to real-time feed of active postings
  void listenToActiveDonations(double? userLat, double? userLng) {
    _isLoading = true;
    _activeSubscription?.cancel();
    
    _activeSubscription = _dbService.streamActiveDonations().listen((donations) {
      if (userLat != null && userLng != null) {
        // Filter out donations where the round-trip travel time (assuming 30km/h average) is greater than or equal to the remaining shelf life
        _activeDonations = donations.where((d) {
          final distance = _locationService.calculateDistance(userLat, userLng, d.latitude, d.longitude);
          final roundTripTimeHours = 2 * (distance / 30.0);
          return roundTripTimeHours < d.currentRemainingHours;
        }).toList();

        // Sort active donations by distance (increasing/nearest first)
        _activeDonations.sort((a, b) {
          final distA = _locationService.calculateDistance(userLat, userLng, a.latitude, a.longitude);
          final distB = _locationService.calculateDistance(userLat, userLng, b.latitude, b.longitude);
          return distA.compareTo(distB);
        });
      } else {
        _activeDonations = donations;
      }
      
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (err) {
      _error = err.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  // Subscribe to real-time feed of provider's postings
  void listenToProviderDonations(String providerId) {
    _isLoading = true;
    _providerSubscription?.cancel();

    _providerSubscription = _dbService.streamDonationsForProvider(providerId).listen((donations) {
      _providerDonations = donations;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (err) {
      _error = err.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  // Subscribe to real-time feed of receiver's accepted postings
  void listenToReceiverAcceptedDonations(String receiverId) {
    _isLoading = true;
    _receiverSubscription?.cancel();

    _receiverSubscription = _dbService.streamAcceptedDonationsForReceiver(receiverId).listen((donations) {
      _acceptedDonations = donations;
      _isLoading = false;
      _error = null;
      notifyListeners();
    }, onError: (err) {
      _error = err.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  // Post a new donation
  Future<bool> postDonation(FoodDonation donation) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _dbService.createDonation(donation);
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

  // Accept a donation (Locks it under the receiver's ID)
  Future<bool> acceptDonation({
    required String donationId,
    required String receiverId,
    required String receiverName,
    required String receiverPhone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _dbService.updateDonationStatus(
        donationId,
        'accepted',
        acceptedById: receiverId,
        acceptedByName: receiverName,
        acceptedByPhone: receiverPhone,
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

  // Cancel/Release an accepted donation (Reverts status to 'active')
  Future<bool> cancelAcceptedDonation(String donationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _dbService.updateDonationStatus(
        donationId,
        'active',
        acceptedById: '', // Remove receiver link
        acceptedByName: '',
        acceptedByPhone: '',
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
}
