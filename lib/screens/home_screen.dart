import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_bar_logo.dart';
import '../widgets/gradient_background.dart';
import 'auth_gate.dart'; // <-- Import the AuthGate for navigation
import 'notifications_screen.dart';
import 'plan_trip_screen.dart';
import 'profile_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentPageIndex = 0;
  final AuthService _authService = AuthService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Your list of pages for the body is correct
  static const List<Widget> _pages = <Widget>[
    DashboardPage(),
    MyTripsPage(),
    ProfilePage(),
  ];

  void _onDrawerItemTapped(int index) {
    setState(() {
      _currentPageIndex = index;
    });
    Navigator.of(context).pop(); // Close the drawer
  }

  // Your "About" dialog is correct and doesn't need changes
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About Trip Genie'),
          content: const Text(
              'Trip Genie is your personal travel assistant...'), // Abridged for clarity
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const AppBarLogo(),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const NotificationsScreen())),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
            tooltip: 'About',
          ),
        ],
      ),
      drawer: Drawer(
        child: GradientBackground(
          child: Theme(
            data: theme.copyWith(
              // Your custom drawer theme is correct
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.cardColor,
                        backgroundImage: _currentUser?.photoURL != null ? NetworkImage(_currentUser!.photoURL!) : null,
                        child: _currentUser?.photoURL == null
                            ? Icon(Icons.person, size: 30, color: theme.primaryColor)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentUser?.displayName ?? 'Welcome, Traveller!',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentUser?.email ?? '',
                        style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined),
                  title: const Text('Dashboard'),
                  onTap: () => _onDrawerItemTapped(0),
                ),
                ListTile(
                  leading: const Icon(Icons.card_travel_outlined),
                  title: const Text('My Trips'),
                  onTap: () => _onDrawerItemTapped(1),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profile'),
                  onTap: () => _onDrawerItemTapped(2),
                ),
                const Divider(),

                // --- UPDATED LOGOUT TILE ---
                ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('Logout'),
                  onTap: () async {
                    // 1. First, call the signOut method to log the user out.
                    await _authService.signOut();

                    // 2. ✅ THEN, navigate the user back to the AuthGate.
                    // This is the critical step that fixes the problem. It removes
                    // all screens behind it, so the user can't press "back" to get in.
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const AuthGate()),
                            (Route<dynamic> route) => false, // This condition removes all previous routes.
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: GradientBackground(
        child: Center(
          child: _pages.elementAt(_currentPageIndex),
        ),
      ),
    );
  }
}

// --- Simple Dashboard (Original Design) ---
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, ${user?.displayName ?? 'Traveller'}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const PlanTripScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Plan a New Trip'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyTripsPage extends StatelessWidget {
  const MyTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SafeArea(
        child: Center(child: Text('Please sign in to view your trips.')),
      );
    }

    final tripsStream = FirebaseFirestore.instance
        .collection('trips')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: tripsStream,
        builder: (context, snapshot) {
          print('My Trips - User ID: ${user.uid}');
          print('My Trips - Connection state: ${snapshot.connectionState}');
          print('My Trips - Has error: ${snapshot.hasError}');
          print('My Trips - Error: ${snapshot.error}');
          print('My Trips - Data: ${snapshot.data}');
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('My Trips - Error details: ${snapshot.error}');
            return Center(child: Text('Failed to load trips: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          print('My Trips - Number of docs: ${docs.length}');
          
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No trips yet'),
                  const SizedBox(height: 12),
                  Text('User ID: ${user.uid}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const PlanTripScreen()),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Plan a New Trip'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final destination = data['destination'] as String? ?? 'Unknown';
              final title = data['title'] as String? ?? 'Trip';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final duration = data['durationInDays'];
              final interests = (data['interests'] as List?)?.cast<String>() ?? const [];
              final summary = data['summary'] as Map<String, dynamic>?;
              final previewActivities = (summary?['previewActivities'] as List?)?.cast<String>() ?? const [];
              final totalEstimatedCost = summary?['totalEstimatedCost'];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.card_travel_outlined),
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(destination),
                      if (duration != null) Text('Duration: $duration days'),
                      if (interests.isNotEmpty) Text('Interests: ${interests.join(', ')}'),
                      if (previewActivities.isNotEmpty) Text('Highlights: ${previewActivities.join(' · ')}'),
                      if (totalEstimatedCost != null) Text('Est. cost: ₹$totalEstimatedCost'),
                      if (createdAt != null) Text('Created: ${createdAt.toLocal()}'),
                    ],
                  ),
                  onTap: () {
                    // For now, simply show details; later we can rehydrate full itinerary
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(title),
                        content: Text('Destination: $destination'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          )
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}