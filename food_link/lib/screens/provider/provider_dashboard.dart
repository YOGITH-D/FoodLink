import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../models/food_donation.dart';
import '../login_screen.dart';
import 'add_donation_screen.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  @override
  void initState() {
    super.initState();
    // Start listening to provider donations in database
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        Provider.of<DonationProvider>(context, listen: false)
            .listenToProviderDonations(authProvider.currentUser!.uid);
      }
    });
  }

  Future<void> _launchTel(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No dialer app available on this device.')),
      );
    }
  }

  Future<void> _launchSms(String phone) async {
    final uri = Uri(scheme: 'sms', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messaging app available on this device.')),
      );
    }
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

    final providerName = authProvider.currentUser?.name ?? 'Provider';

    // Metrics Calculations
    final providerDonations = donationProvider.providerDonations;
    final activePostsCount = providerDonations.where((d) => d.status == 'active' && d.currentRemainingHours > 0).length;
    final acceptedPosts = providerDonations.where((d) => d.status == 'accepted').toList();
    final mealsRescuedCount = acceptedPosts.length * 25; // 25 average servings
    final impactPointsCount = acceptedPosts.length * 10; // 10 points per donation

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FoodLink Provider',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Log Out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddDonationScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Post Surplus Food', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: donationProvider.isLoading && providerDonations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (authProvider.currentUser != null) {
                  donationProvider.listenToProviderDonations(authProvider.currentUser!.uid);
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                children: [
                  // Greeting & Subtitle
                  Text(
                    "Welcome back,",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    providerName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Dashboard Metrics Banner
                  Row(
                    children: [
                      _buildStatCard(
                        'Active Posts',
                        '$activePostsCount',
                        Icons.campaign_outlined,
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withRed(100).withGreen(180),
                        theme,
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        'Meals Shared',
                        '$mealsRescuedCount',
                        Icons.restaurant_menu_outlined,
                        theme.colorScheme.secondary,
                        theme.colorScheme.secondary.withBlue(220).withRed(100),
                        theme,
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        'Impact Points',
                        '$impactPointsCount',
                        Icons.eco_outlined,
                        Colors.amber[800]!,
                        Colors.orange[400]!,
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // History Title
                  Text(
                    'Your Donation History',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (providerDonations.isEmpty) ...[
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
                              Icons.restaurant_outlined,
                              size: 64,
                              color: theme.colorScheme.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No surplus food listed yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your active and completed donations will appear here. Tap the button below to share surplus food and start saving meals.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // List of Cards
                    ...providerDonations.map((donation) => _buildDonationCard(donation, theme)),
                  ],
                ],
              ),
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
              color: color1.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationCard(FoodDonation donation, ThemeData theme) {
    final remaining = donation.currentRemainingHours;
    final isExpired = remaining <= 0;
    
    Color statusColor;
    String statusText;
    
    if (donation.status == 'accepted') {
      statusColor = theme.colorScheme.secondary;
      statusText = 'Claimed by ${donation.acceptedByName ?? 'Receiver'}';
    } else if (isExpired) {
      statusColor = theme.colorScheme.error;
      statusText = 'Expired / Spoilage Warning';
    } else {
      statusColor = theme.colorScheme.primary;
      statusText = 'Active - Fresh for ${remaining.toStringAsFixed(1)}h';
    }

    final formattedPrepTime = DateFormat('dd MMM, hh:mm a').format(donation.prepTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              color: statusColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          'Quantity: ${donation.quantity}',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          'Prepared: $formattedPrepTime',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.thermostat_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Stored: ${donation.storageCondition.toUpperCase()} (${donation.temperature}°C, ${donation.packaging} packaging)',
                            style: TextStyle(color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                    if (donation.status == 'accepted') ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: theme.colorScheme.secondary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Coordinate drop-off with the receiver. Food safety guidelines recommend collection before remaining shelf life decreases.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if ((donation.acceptedByPhone ?? '').isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _launchTel(donation.acceptedByPhone!),
                                      icon: const Icon(Icons.call, size: 18),
                                      label: const Text('Call Receiver'),
                                      style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.secondary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _launchSms(donation.acceptedByPhone!),
                                      icon: const Icon(Icons.sms_outlined, size: 18),
                                      label: const Text('Message'),
                                      style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.secondary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
