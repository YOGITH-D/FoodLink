import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/app_user.dart';

class AuthService {
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Static in-memory database for mock fallback if Firebase is not configured
  static final List<AppUser> _mockUsers = [
    AppUser(
      uid: 'mock_provider_1',
      email: 'provider@foodlink.com',
      name: 'Taj Mahal Hotel',
      role: 'provider',
      address: 'Taj Mahal Palace, Mumbai, India',
      latitude: 18.9217,
      longitude: 72.8330,
      phone: '+919876543210',
    ),
    AppUser(
      uid: 'mock_receiver_1',
      email: 'receiver@foodlink.com',
      name: 'Helping Hands NGO',
      role: 'receiver',
      address: 'Colaba Causeway, Mumbai, India',
      latitude: 18.9200,
      longitude: 72.8300,
      phone: '+919876500000',
    ),
  ];
  static AppUser? _mockCurrentUser;

  // Check if Firebase has been initialized
  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Get current user UID
  String? get currentUserUid {
    if (_isFirebaseAvailable) {
      return _firebaseAuth.currentUser?.uid;
    } else {
      return _mockCurrentUser?.uid;
    }
  }

  // Monitor auth state changes
  Stream<String?> get authStateChanges {
    if (_isFirebaseAvailable) {
      return _firebaseAuth.authStateChanges().map((user) => user?.uid);
    } else {
      // Return a stream containing the mock current user uid
      return Stream.value(_mockCurrentUser?.uid);
    }
  }

  // Register a new user
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String address,
    required double latitude,
    required double longitude,
    required String phone,
  }) async {
    if (_isFirebaseAvailable) {
      try {
        final credential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = credential.user!.uid;

        final newUser = AppUser(
          uid: uid,
          email: email,
          name: name,
          role: role,
          address: address,
          latitude: latitude,
          longitude: longitude,
          phone: phone,
        );

        // Store user details in Firestore
        await _firestore.collection('users').doc(uid).set(newUser.toMap());
        return newUser;
      } on FirebaseAuthException catch (e) {
        throw Exception(e.message ?? 'Registration failed.');
      }
    } else {
      // Local Mock registration
      if (_mockUsers.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
        throw Exception('An account with this email already exists.');
      }
      final uid = 'mock_user_${DateTime.now().millisecondsSinceEpoch}';
      final newUser = AppUser(
        uid: uid,
        email: email,
        name: name,
        role: role,
        address: address,
        latitude: latitude,
        longitude: longitude,
        phone: phone,
      );
      _mockUsers.add(newUser);
      _mockCurrentUser = newUser;
      return newUser;
    }
  }

  // Login existing user
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    if (_isFirebaseAvailable) {
      try {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = credential.user!.uid;

        // Fetch user details from Firestore
        final doc = await _firestore.collection('users').doc(uid).get();
        if (!doc.exists) {
          throw Exception('User profile not found in database.');
        }
        return AppUser.fromMap(doc.data()!, doc.id);
      } on FirebaseAuthException catch (e) {
        throw Exception(e.message ?? 'Login failed.');
      }
    } else {
      // Local Mock login
      // Simulating a simple match (for testing, password matches email prefix or is ignored)
      try {
        final matched = _mockUsers.firstWhere(
          (u) => u.email.toLowerCase() == email.toLowerCase(),
        );
        _mockCurrentUser = matched;
        return matched;
      } catch (_) {
        throw Exception('Invalid email or password.');
      }
    }
  }

  // Get current user details
  Future<AppUser?> getUserDetails(String uid) async {
    if (_isFirebaseAvailable) {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!, doc.id);
      }
      return null;
    } else {
      try {
        return _mockUsers.firstWhere((u) => u.uid == uid);
      } catch (_) {
        return null;
      }
    }
  }

  // Logout
  Future<void> logout() async {
    if (_isFirebaseAvailable) {
      await _firebaseAuth.signOut();
    } else {
      _mockCurrentUser = null;
    }
  }
}
