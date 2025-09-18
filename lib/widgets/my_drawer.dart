import 'package:flutter/material.dart';
import 'package:trip_genie/screens/auth_gate.dart'; // <-- Import the AuthGate for navigation
import 'package:trip_genie/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trip_genie/screens/profile_page.dart'; // Import your other screens
import 'package:trip_genie/screens/home_screen.dart';   // Import your other screens

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Column(
        children: [
          // --- Drawer Header with User Info ---
          UserAccountsDrawerHeader(
            accountName: Text(
              currentUser?.displayName ?? 'Welcome, Traveller!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(currentUser?.email ?? 'No email provided'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepPurple,
              child: Text(
                currentUser?.displayName?.substring(0, 1).toUpperCase() ?? 'T',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
            ),
          ),

          // --- Navigation Links ---
          ListTile(
            leading: const Icon(Icons.dashboard_outlined),
            title: const Text('Dashboard'),
            onTap: () {
              // Close the drawer and navigate to the home screen
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            onTap: () {
              // Close the drawer and navigate to the profile page
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.card_travel_outlined),
            title: const Text('My Trips'),
            onTap: () {
              // TODO: Navigate to your "My Trips" screen
            },
          ),

          const Spacer(), // Pushes the logout button to the bottom

          const Divider(),

          // --- LOGOUT TILE (WITH THE CORRECT NAVIGATION FIX) ---
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              // 1. First, call the signOut method to log the user out.
              await authService.signOut();

              // 2. ✅ THEN, navigate the user back to the AuthGate.
              // This is the critical step. It removes all screens behind it,
              // so the user can't press the "back" button to get into the app again.
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthGate()),
                      (Route<dynamic> route) => false, // This condition removes all previous routes.
                );
              }
            },
          ),
          const SizedBox(height: 10), // Some padding at the bottom
        ],
      ),
    );
  }
}