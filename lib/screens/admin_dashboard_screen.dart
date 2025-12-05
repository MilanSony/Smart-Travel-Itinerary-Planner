import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/travel_theme_background.dart';
import 'manage_users_screen.dart';
import 'manage_trips_screen.dart'; // Import new screens
import 'view_analytics_screen.dart';
import 'system_settings_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: TravelThemeBackground(
        theme: TravelTheme.adminDashboard,
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(24.0),
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: [
            _buildDashboardCard(
              context,
              icon: Icons.people_outline,
              title: 'Manage Users',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ManageUsersScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context,
              icon: Icons.card_travel,
              title: 'Manage Trips',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ManageTripsScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context,
              icon: Icons.analytics_outlined,
              title: 'View Analytics',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ViewAnalyticsScreen()),
                );
              },
            ),
            _buildDashboardCard(
              context,
              icon: Icons.settings_outlined,
              title: 'System Settings',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SystemSettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.primaryColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}