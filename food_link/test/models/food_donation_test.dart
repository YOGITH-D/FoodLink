import 'package:flutter_test/flutter_test.dart';
import 'package:food_link/models/food_donation.dart';

FoodDonation _donation({required DateTime prepTime, required double predictedShelfLife}) {
  return FoodDonation(
    id: 'test',
    providerId: 'p1',
    providerName: 'Test Provider',
    providerPhone: '+910000000000',
    foodType: 'roti',
    quantity: '1',
    prepTime: prepTime,
    storageCondition: 'room',
    packaging: 'open',
    temperature: 28.0,
    imageUrl: '',
    latitude: 0.0,
    longitude: 0.0,
    address: '',
    predictedShelfLife: predictedShelfLife,
    status: 'active',
    createdAt: DateTime.now(),
  );
}

void main() {
  test('currentRemainingHours decreases as time elapses since prepTime', () {
    final donation = _donation(
      prepTime: DateTime.now().subtract(const Duration(hours: 5)),
      predictedShelfLife: 8.0,
    );
    expect(donation.currentRemainingHours, closeTo(3.0, 0.1));
  });

  test('currentRemainingHours floors at zero and never goes negative', () {
    final donation = _donation(
      prepTime: DateTime.now().subtract(const Duration(hours: 20)),
      predictedShelfLife: 8.0,
    );
    expect(donation.currentRemainingHours, 0.0);
  });

  test('freshnessStatus reflects remaining hours thresholds', () {
    final fresh = _donation(
      prepTime: DateTime.now().subtract(const Duration(hours: 1)),
      predictedShelfLife: 20.0,
    );
    expect(fresh.freshnessStatus, 'fresh');

    final consumeSoon = _donation(
      prepTime: DateTime.now().subtract(const Duration(hours: 5)),
      predictedShelfLife: 8.0,
    );
    expect(consumeSoon.freshnessStatus, 'consume_soon');

    final spoiled = _donation(
      prepTime: DateTime.now().subtract(const Duration(hours: 20)),
      predictedShelfLife: 8.0,
    );
    expect(spoiled.freshnessStatus, 'spoiled');
  });
}
