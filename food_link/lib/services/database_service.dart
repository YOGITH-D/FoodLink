import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/food_donation.dart';

class DatabaseService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Static mock database
  static final List<FoodDonation> _mockDonations = [
    FoodDonation(
      id: 'mock_donation_1',
      providerId: 'mock_provider_1',
      providerName: 'Taj Mahal Hotel',
      providerPhone: '+919876543210',
      foodType: 'chicken_biryani',
      quantity: '20 kg (serves ~50 people)',
      prepTime: DateTime.now().subtract(const Duration(hours: 3)),
      storageCondition: 'fridge',
      packaging: 'closed',
      temperature: 4.0,
      imageUrl: '', // Will show default asset in UI if empty
      latitude: 18.9217,
      longitude: 72.8330,
      address: 'Taj Mahal Palace, Colaba, Mumbai, MH',
      predictedShelfLife: 24.5,
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    FoodDonation(
      id: 'mock_donation_2',
      providerId: 'mock_provider_1',
      providerName: 'Taj Mahal Hotel',
      providerPhone: '+919876543210',
      foodType: 'roti',
      quantity: '100 pieces',
      prepTime: DateTime.now().subtract(const Duration(hours: 1)),
      storageCondition: 'room',
      packaging: 'open',
      temperature: 28.5,
      imageUrl: '',
      latitude: 18.9217,
      longitude: 72.8330,
      address: 'Taj Mahal Palace, Colaba, Mumbai, MH',
      predictedShelfLife: 15.0,
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    FoodDonation(
      id: 'mock_donation_3',
      providerId: 'mock_provider_1',
      providerName: 'Taj Mahal Hotel',
      providerPhone: '+919876543210',
      foodType: 'milk',
      quantity: '10 Liters',
      prepTime: DateTime.now().subtract(const Duration(hours: 6)),
      storageCondition: 'room',
      packaging: 'open',
      temperature: 32.0,
      imageUrl: '',
      latitude: 18.9230,
      longitude: 72.8310,
      address: 'Gateway of India, Colaba, Mumbai, MH',
      predictedShelfLife: 8.0,
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  // StreamControllers to publish updates to mock stream subscribers
  static final StreamController<List<FoodDonation>> _activeDonationsController =
      StreamController<List<FoodDonation>>.broadcast();
  static final StreamController<List<FoodDonation>> _providerDonationsController =
      StreamController<List<FoodDonation>>.broadcast();
  static final StreamController<List<FoodDonation>> _receiverDonationsController =
      StreamController<List<FoodDonation>>.broadcast();

  // Helper to trigger updates on all mock streams
  static void _triggerMockUpdates() {
    _activeDonationsController.add(
      _mockDonations.where((d) => d.status == 'active' && d.currentRemainingHours > 0).toList(),
    );
    _providerDonationsController.add(List.from(_mockDonations));
    _receiverDonationsController.add(List.from(_mockDonations));
  }

  // Check if Firebase has been initialized
  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Create a new donation post
  Future<void> createDonation(FoodDonation donation) async {
    if (_isFirebaseAvailable) {
      await _firestore.collection('donations').add(donation.toMap());
    } else {
      final newDonation = FoodDonation(
        id: 'mock_donation_${DateTime.now().millisecondsSinceEpoch}',
        providerId: donation.providerId,
        providerName: donation.providerName,
        providerPhone: donation.providerPhone,
        foodType: donation.foodType,
        quantity: donation.quantity,
        prepTime: donation.prepTime,
        storageCondition: donation.storageCondition,
        packaging: donation.packaging,
        temperature: donation.temperature,
        imageUrl: donation.imageUrl,
        latitude: donation.latitude,
        longitude: donation.longitude,
        address: donation.address,
        predictedShelfLife: donation.predictedShelfLife,
        status: 'active',
        createdAt: DateTime.now(),
      );
      _mockDonations.insert(0, newDonation);
      _triggerMockUpdates();
    }
  }

  // Accept a donation or change its status
  Future<void> updateDonationStatus(
    String donationId,
    String status, {
    String? acceptedById,
    String? acceptedByName,
    String? acceptedByPhone,
  }) async {
    if (_isFirebaseAvailable) {
      final updateData = <String, dynamic>{'status': status};
      if (acceptedById != null) updateData['acceptedById'] = acceptedById;
      if (acceptedByName != null) updateData['acceptedByName'] = acceptedByName;
      if (acceptedByPhone != null) updateData['acceptedByPhone'] = acceptedByPhone;

      await _firestore.collection('donations').doc(donationId).update(updateData);
    } else {
      final index = _mockDonations.indexWhere((d) => d.id == donationId);
      if (index != -1) {
        _mockDonations[index] = _mockDonations[index].copyWith(
          status: status,
          acceptedById: acceptedById,
          acceptedByName: acceptedByName,
          acceptedByPhone: acceptedByPhone,
        );
        _triggerMockUpdates();
      } else {
        throw Exception('Donation not found');
      }
    }
  }

  // Stream active donations
  Stream<List<FoodDonation>> streamActiveDonations() {
    if (_isFirebaseAvailable) {
      return _firestore
          .collection('donations')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => FoodDonation.fromMap(doc.data(), doc.id))
            .where((d) => d.currentRemainingHours > 0) // Filter out naturally expired donations on-client
            .toList();
      });
    } else {
      // Return a stream that emits immediately, then feeds updates
      Timer.run(() => _triggerMockUpdates());
      return _activeDonationsController.stream;
    }
  }

  // Stream provider's postings
  Stream<List<FoodDonation>> streamDonationsForProvider(String providerId) {
    if (_isFirebaseAvailable) {
      return _firestore
          .collection('donations')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => FoodDonation.fromMap(doc.data(), doc.id)).toList());
    } else {
      Timer.run(() {
        _providerDonationsController.add(
          _mockDonations.where((d) => d.providerId == providerId).toList(),
        );
      });
      return _providerDonationsController.stream.map(
        (list) => list.where((d) => d.providerId == providerId).toList(),
      );
    }
  }

  // Stream receiver's accepted postings
  Stream<List<FoodDonation>> streamAcceptedDonationsForReceiver(String receiverId) {
    if (_isFirebaseAvailable) {
      return _firestore
          .collection('donations')
          .where('acceptedById', isEqualTo: receiverId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => FoodDonation.fromMap(doc.data(), doc.id)).toList());
    } else {
      Timer.run(() {
        _receiverDonationsController.add(
          _mockDonations.where((d) => d.acceptedById == receiverId).toList(),
        );
      });
      return _receiverDonationsController.stream.map(
        (list) => list.where((d) => d.acceptedById == receiverId).toList(),
      );
    }
  }
}
