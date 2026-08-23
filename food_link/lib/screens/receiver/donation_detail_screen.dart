import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donation_provider.dart';
import '../../models/food_donation.dart';
import '../../services/location_service.dart';

class DonationDetailScreen extends StatefulWidget {
  final FoodDonation donation;
  
  const DonationDetailScreen({super.key, required this.donation});

  @override
  State<DonationDetailScreen> createState() => _DonationDetailScreenState();
}

class _DonationDetailScreenState extends State<DonationDetailScreen> {
  final LocationService _locationService = LocationService();
  bool _isLoading = false;

  void _claimDonation() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final donationProvider = Provider.of<DonationProvider>(context, listen: false);

    final success = await donationProvider.acceptDonation(
      donationId: widget.donation.id,
      receiverId: authProvider.currentUser!.uid,
      receiverName: authProvider.currentUser!.name,
      receiverPhone: authProvider.currentUser!.phone,
    );

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation Claimed! Coordinate pick-up with provider.')),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(donationProvider.error ?? 'Claim failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _releaseClaim() async {
    setState(() {
      _isLoading = true;
    });

    final donationProvider = Provider.of<DonationProvider>(context, listen: false);
    final success = await donationProvider.cancelAcceptedDonation(widget.donation.id);

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim released. Food is active on feed again.')),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(donationProvider.error ?? 'Release failed.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    final remaining = widget.donation.currentRemainingHours;
    final isExpired = remaining <= 0;
    
    Color freshnessColor;
    String freshnessText;
    
    if (isExpired) {
      freshnessColor = theme.colorScheme.error;
      freshnessText = 'Expired (Spoiled)';
    } else if (remaining >= 12.0) {
      freshnessColor = Colors.green;
      freshnessText = 'Fresh (Consume within ${remaining.toStringAsFixed(1)} hours)';
    } else {
      freshnessColor = Colors.amber[800]!;
      freshnessText = 'Nearing Spoilage (Consume within ${remaining.toStringAsFixed(1)} hours)';
    }

    final formattedPrepTime = DateFormat('dd MMMM yyyy, hh:mm a').format(widget.donation.prepTime);
    final isClaimedByMe = widget.donation.acceptedById == authProvider.currentUser?.uid;

    double? distance;
    if (authProvider.currentUser != null) {
      distance = _locationService.calculateDistance(
        authProvider.currentUser!.latitude,
        authProvider.currentUser!.longitude,
        widget.donation.latitude,
        widget.donation.longitude,
      );
    }

    final oneWayMinutes = distance != null ? (distance / 30.0 * 60).round() : 0;
    final roundTripMinutes = 2 * oneWayMinutes;
    final remainingMinutes = (remaining * 60).round();
    final isTransitSafe = distance == null || roundTripMinutes < remainingMinutes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donation Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Food Image banner
                Container(
                  height: 220,
                  width: double.infinity,
                  color: theme.colorScheme.primaryContainer,
                  child: widget.donation.imageUrl.isNotEmpty
                      ? Image.network(widget.donation.imageUrl, fit: BoxFit.cover)
                      : Icon(Icons.restaurant, size: 80, color: theme.colorScheme.primary),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food Name
                      Text(
                        widget.donation.foodType.replaceAll('_', ' ').toUpperCase(),
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      
                      // Proximity and fresh timer
                      Row(
                        children: [
                          if (distance != null) ...[
                            Chip(
                              label: Text('${distance.toStringAsFixed(1)} km away'),
                              avatar: const Icon(Icons.location_on, size: 16),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Chip(
                            label: Text(freshnessText),
                            avatar: Icon(Icons.circle, size: 12, color: freshnessColor),
                            backgroundColor: freshnessColor.withOpacity(0.1),
                            labelStyle: TextStyle(color: freshnessColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      
                      if (distance != null && !isExpired) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isTransitSafe
                                ? theme.colorScheme.secondaryContainer.withOpacity(0.2)
                                : theme.colorScheme.errorContainer.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isTransitSafe
                                  ? theme.colorScheme.secondary.withOpacity(0.3)
                                  : theme.colorScheme.error.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.commute_outlined,
                                    color: isTransitSafe
                                        ? theme.colorScheme.secondary
                                        : theme.colorScheme.error,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Transit Feasibility Analysis',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isTransitSafe
                                          ? theme.colorScheme.onSecondaryContainer
                                          : theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Estimated One-way transit:'),
                                  Text(
                                    '~$oneWayMinutes mins',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Estimated Round-trip transit:'),
                                  Text(
                                    '~$roundTripMinutes mins',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Remaining Shelf Life:'),
                                  Text(
                                    '~$remainingMinutes mins (${remaining.toStringAsFixed(1)}h)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: freshnessColor,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                children: [
                                  Icon(
                                    isTransitSafe
                                        ? Icons.check_circle_outline
                                        : Icons.warning_amber_outlined,
                                    color: isTransitSafe
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isTransitSafe
                                          ? 'Safe to claim: Round-trip travel time ($roundTripMinutes mins) is safely within the food\'s shelf life ($remainingMinutes mins).'
                                          : 'Transit Risk Warning: Round-trip travel time ($roundTripMinutes mins) exceeds remaining shelf life ($remainingMinutes mins). Spoilage will occur in transit!',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const Divider(height: 32),
                      
                      // Details section
                      Text(
                        'Details',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      
                      _buildDetailRow(Icons.shopping_bag_outlined, 'Quantity', widget.donation.quantity),
                      _buildDetailRow(Icons.timer_outlined, 'Preparation Time', formattedPrepTime),
                      _buildDetailRow(
                        Icons.thermostat_outlined,
                        'Storage Condition',
                        '${widget.donation.storageCondition.toUpperCase()} storage at ${widget.donation.temperature}°C (${widget.donation.packaging} container)',
                      ),
                      _buildDetailRow(Icons.storefront_outlined, 'Donor', widget.donation.providerName),
                      _buildDetailRow(Icons.pin_drop_outlined, 'Pickup Address', widget.donation.address),
                      
                      const Divider(height: 32),

                      // Spoilage Warning Alert box
                      if (isExpired) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.error),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: theme.colorScheme.error, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Food Spoilage Alert: The model predicts that this food is no longer fresh enough for safe consumption. Pickup is locked.',
                                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Claimed info or pickup instructions
                      if (widget.donation.status == 'accepted') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isClaimedByMe ? Colors.green.withOpacity(0.08) : Colors.amber.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isClaimedByMe ? Colors.green : Colors.amber),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isClaimedByMe ? Icons.check_circle : Icons.lock,
                                    color: isClaimedByMe ? Colors.green : Colors.amber,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isClaimedByMe ? 'You Claimed This Donation' : 'Claimed by Another NGO',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isClaimedByMe ? Colors.green[900] : Colors.amber[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isClaimedByMe
                                    ? 'Contact the provider immediately to arrange safe transport. Please use insulated carriers for temperature-controlled food.'
                                    : 'This donation has already been secured by another charity organization to reduce local food waste.',
                                style: TextStyle(
                                  color: isClaimedByMe ? Colors.green[900] : Colors.amber[900],
                                ),
                              ),
                              if (isClaimedByMe && widget.donation.providerPhone.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _launchTel(widget.donation.providerPhone),
                                        icon: const Icon(Icons.call, size: 18),
                                        label: const Text('Call Provider'),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.green[900]),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _launchSms(widget.donation.providerPhone),
                                        icon: const Icon(Icons.sms_outlined, size: 18),
                                        label: const Text('Message'),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.green[900]),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // CTA Actions
                      if (widget.donation.status == 'active' && !isExpired) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isTransitSafe
                                ? _claimDonation
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Cannot claim: Transit duration exceeds remaining shelf life. Food safety hazard!'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.assignment_turned_in),
                            label: const Text('Claim Surplus Food'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: isTransitSafe ? theme.colorScheme.primary : Colors.grey[400],
                              foregroundColor: isTransitSafe ? theme.colorScheme.onPrimary : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                      
                      if (isClaimedByMe) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _releaseClaim,
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel Claim & Release Food'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: theme.colorScheme.error,
                              side: BorderSide(color: theme.colorScheme.error),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              ],
            ),
    );
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
