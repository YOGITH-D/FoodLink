import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../models/food_donation.dart';
import '../../services/location_service.dart';
import '../login_screen.dart';
import 'donation_detail_screen.dart';
import 'map_view_screen.dart';

class ReceiverDashboard extends StatefulWidget {
  const ReceiverDashboard({super.key});

  @override
  State<ReceiverDashboard> createState() => _ReceiverDashboardState();
}

class _ReceiverDashboardState extends State<ReceiverDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LocationService _locationService = LocationService();
  bool _showAllPostings = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Start listening to databases
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final donationProvider = Provider.of<DonationProvider>(context, listen: false);

      if (authProvider.currentUser != null) {
        final user = authProvider.currentUser!;
        donationProvider.listenToActiveDonations(user.latitude, user.longitude);
        donationProvider.listenToReceiverAcceptedDonations(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final donationProvider = Provider.of<DonationProvider>(context);

    final ngoName = authProvider.currentUser?.name ?? 'Receiver NGO';
    final userLat = authProvider.currentUser?.latitude;
    final userLng = authProvider.currentUser?.longitude;

    final filteredActiveDonations = donationProvider.activeDonations.where((d) {
      if (_showAllPostings) return true;
      if (userLat != null && userLng != null) {
        final dist = _locationService.calculateDistance(userLat, userLng, d.latitude, d.longitude);
        return dist <= 30.0;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FoodLink Receiver',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'View Map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapViewScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Log Out',
            onPressed: _handleLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.explore), text: 'Surplus Feed'),
            Tab(icon: Icon(Icons.assignment_turned_in), text: 'Your Claims'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Surplus Feed
          donationProvider.isLoading && donationProvider.activeDonations.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    if (userLat != null && userLng != null) {
                      donationProvider.listenToActiveDonations(userLat, userLng);
                    }
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    children: [
                      // Greeting & Subtitle
                      Text(
                        "Welcome to FoodLink,",
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        ngoName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Metrics Banner
                      Row(
                        children: [
                          _buildStatCard(
                            'Active Options',
                            '${donationProvider.activeDonations.length}',
                            Icons.explore_outlined,
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withRed(100).withGreen(180),
                            theme,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            'Claims Secured',
                            '${donationProvider.acceptedDonations.length}',
                            Icons.assignment_turned_in_outlined,
                            theme.colorScheme.secondary,
                            theme.colorScheme.secondary.withBlue(220).withRed(100),
                            theme,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            'Impact Score',
                            '${donationProvider.acceptedDonations.length * 10}',
                            Icons.eco_outlined,
                            Colors.amber[800]!,
                            Colors.orange[400]!,
                            theme,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Section Title & Switch Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Surplus Food Nearby',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'Show all (>30km)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Switch(
                                value: _showAllPostings,
                                onChanged: (val) {
                                  setState(() {
                                    _showAllPostings = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (donationProvider.activeDonations.isEmpty) ...[
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.sentiment_satisfied_alt_outlined,
                                  size: 64,
                                  color: theme.colorScheme.primary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'All shared food is claimed!',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Please check back later or refresh. Fresh surplus listings will appear here when posted by nearby providers.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (filteredActiveDonations.isEmpty) ...[
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.explore_off_outlined,
                                  size: 64,
                                  color: theme.colorScheme.primary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No postings within 30 km',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Toggle "Show all" to view listings further away, or check back later.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Nearby items list
                        ...filteredActiveDonations.map((donation) {
                          double? distance;
                          if (userLat != null && userLng != null) {
                            distance = _locationService.calculateDistance(
                              userLat,
                              userLng,
                              donation.latitude,
                              donation.longitude,
                            );
                          }
                          return _buildDonationItem(donation, distance, theme);
                        }),
                      ],
                    ],
                  ),
                ),

          // Tab 2: Your Claims
          donationProvider.isLoading && donationProvider.acceptedDonations.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    if (authProvider.currentUser != null) {
                      donationProvider.listenToReceiverAcceptedDonations(authProvider.currentUser!.uid);
                    }
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    children: [
                      Text(
                        'Claimed Donations',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (donationProvider.acceptedDonations.isEmpty) ...[
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: theme.colorScheme.primary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No secured claims yet',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Browse the "Surplus Feed" tab to secure nearby active food donations and help reduce waste.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Claimed list
                        ...donationProvider.acceptedDonations.map((donation) {
                          double? distance;
                          if (userLat != null && userLng != null) {
                            distance = _locationService.calculateDistance(
                              userLat,
                              userLng,
                              donation.latitude,
                              donation.longitude,
                            );
                          }
                          return _buildDonationItem(donation, distance, theme);
                        }),
                      ],
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color1,
    Color color2,
    ThemeData theme,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color1.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationItem(FoodDonation donation, double? distance, ThemeData theme) {
    final remaining = donation.currentRemainingHours;
    final isExpired = remaining <= 0;
    
    Color freshnessColor;
    String freshnessText;
    
    if (isExpired) {
      freshnessColor = theme.colorScheme.error;
      freshnessText = 'Expired';
    } else if (remaining >= 12.0) {
      freshnessColor = Colors.green;
      freshnessText = 'Fresh for ${remaining.toStringAsFixed(1)}h';
    } else {
      freshnessColor = Colors.amber[800]!;
      freshnessText = 'Consume in ${remaining.toStringAsFixed(1)}h';
    }

    // Estimate one-way travel minutes (30 km/h = 2 mins per km)
    final oneWayMinutes = distance != null ? (distance / 30.0 * 60).round() : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DonationDetailScreen(donation: donation),
            ),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left freshness status accent bar
              Container(
                width: 6,
                color: freshnessColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food Image or Placeholder icon
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: donation.imageUrl.isNotEmpty
                            ? Image.network(
                                donation.imageUrl,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholderImage(theme),
                              )
                            : _buildPlaceholderImage(theme),
                      ),
                      const SizedBox(width: 14),
                      
                      // Text Metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    donation.foodType.replaceAll('_', ' ').toUpperCase(),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (distance != null) ...[
                                  Text(
                                    '${distance.toStringAsFixed(1)} km',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Provider: ${donation.providerName}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Qty: ${donation.quantity}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (oneWayMinutes != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.directions_car_outlined, size: 14, color: theme.colorScheme.secondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Travel: ~${oneWayMinutes}m (one-way)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            
                            // Freshness status chip
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: freshnessColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.circle, size: 6, color: freshnessColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        freshnessText,
                                        style: TextStyle(
                                          color: freshnessColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Container(
      width: 90,
      height: 90,
      color: theme.colorScheme.primaryContainer,
      child: Icon(Icons.restaurant, color: theme.colorScheme.primary),
    );
  }
}
