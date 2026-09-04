import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/update_service.dart';
import 'login_screen.dart';
import 'provider/provider_dashboard.dart';
import 'receiver/receiver_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _checkForUpdate() async {
    final update = await _updateService.checkForUpdate();
    if (update == null || !mounted) return;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Update available (v${update.version})'),
        content: Text(
          update.releaseNotes.isNotEmpty
              ? update.releaseNotes
              : 'A newer version of FoodLink is available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (shouldUpdate != true || !mounted) return;
    await _downloadAndInstall(update);
  }

  Future<void> _downloadAndInstall(UpdateInfo update) async {
    final progressNotifier = ValueNotifier<double>(0);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Downloading update'),
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, value, child) => LinearProgressIndicator(value: value > 0 ? value : null),
        ),
      ),
    );

    try {
      final filePath = await _updateService.downloadApk(
        update.downloadUrl,
        onProgress: (p) => progressNotifier.value = p,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close progress dialog
      await _updateService.installApk(filePath);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _navigateToNext() async {
    // Artificial splash delay for visual branding
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    await _checkForUpdate();
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Auth provider takes care of auth status initialization in its constructor.
    // If it is still loading, wait.
    if (authProvider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    if (!mounted) return;

    if (authProvider.currentUser == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      final role = authProvider.currentUser!.role;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'provider'
              ? const ProviderDashboard()
              : const ReceiverDashboard(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Branding Icon
            Container(
              padding: const Size.square(80.0).shortestSide == 80.0
                  ? const EdgeInsets.all(24)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: const Icon(
                Icons.restaurant,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              'FoodLink',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'Predict, Share, Reduce Waste',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
