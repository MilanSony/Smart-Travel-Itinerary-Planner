import 'package:flutter/material.dart';
import 'package:trip_genie/screens/manage_users_screen.dart';
import 'package:trip_genie/services/auth_service.dart';
import 'auth_gate.dart';

// --- UPDATED: Import the new screens ---
import 'manage_trips_screen.dart';
import 'view_analytics_screen.dart';
import 'system_settings_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  // Helper method to create each styled dashboard item (no changes needed here)
  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthGate()),
                      (route) => false,
                );
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF5F3FF), // Light violet top
              const Color(0xFFE8F0FE), // Light blue bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: GridView.count(
          padding: const EdgeInsets.all(24),
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: <Widget>[
            _buildDashboardCard(
              context: context,
              icon: Icons.people_alt_outlined,
              title: 'Manage Users',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageUsersScreen()),
                );
              },
            ),
            // --- UPDATED: Navigates to ManageTripsScreen ---
            _buildDashboardCard(
              context: context,
              icon: Icons.card_travel_outlined,
              title: 'Manage Trips',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageTripsScreen()),
                );
              },
            ),
            // --- UPDATED: Navigates to ViewAnalyticsScreen ---
            _buildDashboardCard(
              context: context,
              icon: Icons.analytics_outlined,
              title: 'View Analytics',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ViewAnalyticsScreen()),
                );
              },
            ),
            // --- UPDATED: Navigates to SystemSettingsScreen ---
            _buildDashboardCard(
              context: context,
              icon: Icons.settings_outlined,
              title: 'System Settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SystemSettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}