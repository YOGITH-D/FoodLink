import 'package:cloud_firestore/cloud_firestore.dart';

class FoodDonation {
  final String id;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final String foodType;
  final String quantity;
  final DateTime prepTime;
  final String storageCondition;
  final String packaging;
  final double temperature;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String address;
  final double predictedShelfLife;
  final String status; // 'active', 'accepted', 'expired'
  final String? acceptedById;
  final String? acceptedByName;
  final String? acceptedByPhone;
  final DateTime createdAt;

  FoodDonation({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.foodType,
    required this.quantity,
    required this.prepTime,
    required this.storageCondition,
    required this.packaging,
    required this.temperature,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.predictedShelfLife,
    required this.status,
    this.acceptedById,
    this.acceptedByName,
    this.acceptedByPhone,
    required this.createdAt,
  });

  factory FoodDonation.fromMap(Map<String, dynamic> map, String documentId) {
    return FoodDonation(
      id: documentId,
      providerId: map['providerId'] ?? '',
      providerName: map['providerName'] ?? '',
      providerPhone: map['providerPhone'] ?? '',
      foodType: map['foodType'] ?? '',
      quantity: map['quantity'] ?? '',
      prepTime: (map['prepTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      storageCondition: map['storageCondition'] ?? 'room',
      packaging: map['packaging'] ?? 'open',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 25.0,
      imageUrl: map['imageUrl'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      predictedShelfLife: (map['predictedShelfLife'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'active',
      acceptedById: map['acceptedById'],
      acceptedByName: map['acceptedByName'],
      acceptedByPhone: map['acceptedByPhone'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'providerPhone': providerPhone,
      'foodType': foodType,
      'quantity': quantity,
      'prepTime': Timestamp.fromDate(prepTime),
      'storageCondition': storageCondition,
      'packaging': packaging,
      'temperature': temperature,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'predictedShelfLife': predictedShelfLife,
      'status': status,
      'acceptedById': acceptedById,
      'acceptedByName': acceptedByName,
      'acceptedByPhone': acceptedByPhone,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FoodDonation copyWith({
    String? status,
    String? acceptedById,
    String? acceptedByName,
    String? acceptedByPhone,
  }) {
    return FoodDonation(
      id: id,
      providerId: providerId,
      providerName: providerName,
      providerPhone: providerPhone,
      foodType: foodType,
      quantity: quantity,
      prepTime: prepTime,
      storageCondition: storageCondition,
      packaging: packaging,
      temperature: temperature,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      address: address,
      predictedShelfLife: predictedShelfLife,
      status: status ?? this.status,
      acceptedById: acceptedById ?? this.acceptedById,
      acceptedByName: acceptedByName ?? this.acceptedByName,
      acceptedByPhone: acceptedByPhone ?? this.acceptedByPhone,
      createdAt: createdAt,
    );
  }

  // Calculate current remaining shelf life based on prep time and predicted total shelf life
  double get currentRemainingHours {
    final elapsed = DateTime.now().difference(prepTime).inMinutes / 60.0;
    final remaining = predictedShelfLife - elapsed;
    return remaining < 0 ? 0.0 : remaining;
  }

  String get freshnessStatus {
    final remaining = currentRemainingHours;
    if (remaining >= 12.0) {
      return 'fresh';
    } else if (remaining > 0.0) {
      return 'consume_soon';
    } else {
      return 'spoiled';
    }
  }
}
