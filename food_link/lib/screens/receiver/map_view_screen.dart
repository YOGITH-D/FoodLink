import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../models/food_donation.dart';
import 'donation_detail_screen.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  void _openDonation(FoodDonation donation) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DonationDetailScreen(donation: donation)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final donationProvider = Provider.of<DonationProvider>(context);

    final userLat = authProvider.currentUser?.latitude ?? 18.9217;
    final userLng = authProvider.currentUser?.longitude ?? 72.8330;

    final markers = <Marker>[
      // User's current location marker
      Marker(
        point: ll.LatLng(userLat, userLng),
        width: 40,
        height: 40,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 32),
      ),
      // Donation markers, colored green (fresh) / orange (consume soon)
      for (final donation in donationProvider.activeDonations)
        if (donation.latitude != 0.0 && donation.longitude != 0.0)
          Marker(
            point: ll.LatLng(donation.latitude, donation.longitude),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => _openDonation(donation),
              child: Icon(
                Icons.location_on,
                size: 40,
                color: donation.currentRemainingHours >= 12.0 ? Colors.green : Colors.orange,
              ),
            ),
          ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surplus Food Map'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: ll.LatLng(userLat, userLng),
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.foodlink.food_link',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // Overlay info banner
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Showing ${donationProvider.activeDonations.length} surplus locations near you. Tap a marker to view details and claim.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
