import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_bar_logo.dart';
import '../widgets/gradient_background.dart';
import '../widgets/image_background.dart';
import '../services/trip_knn_service.dart';
import 'auth_gate.dart'; // <-- Import the AuthGate for navigation
import 'notifications_screen.dart';
import 'plan_trip_screen.dart';
import 'profile_page.dart';
import 'ride_matching_screen.dart';
import 'group_trips_screen.dart';

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
  List<Widget> get _pages => <Widget>[
        DashboardPage(onNavigateToTrips: () => _onDrawerItemTapped(1)),
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
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const NotificationsScreen())),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
            tooltip: 'About',
          ),
        ],
      ),
      extendBodyBehindAppBar: false,
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
                        backgroundImage: _currentUser?.photoURL != null
                            ? NetworkImage(_currentUser!.photoURL!)
                            : null,
                        child: _currentUser?.photoURL == null
                            ? Icon(Icons.person,
                                size: 30, color: theme.primaryColor)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentUser?.displayName ?? 'Welcome, Traveller!',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentUser?.email ?? '',
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                isDarkMode ? Colors.white70 : Colors.black54),
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
                  leading: const Icon(Icons.directions_car_outlined),
                  title: const Text('Find or Offer Rides'),
                  onTap: () {
                    Navigator.of(context).pop(); // Close drawer
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const RideMatchingScreen()),
                    );
                  },
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
                        MaterialPageRoute(
                            builder: (context) => const AuthGate()),
                        (Route<dynamic> route) =>
                            false, // This condition removes all previous routes.
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: _pages.elementAt(_currentPageIndex),
      ),
    );
  }
}

// --- Modern Professional Dashboard Design ---
class DashboardPage extends StatelessWidget {
  final VoidCallback? onNavigateToTrips;

  const DashboardPage({super.key, this.onNavigateToTrips});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final userName = () {
      final displayName = user?.displayName?.trim();
      if (displayName == null || displayName.isEmpty) return 'Traveler';
      final parts =
          displayName.split(' ').where((part) => part.isNotEmpty).toList();
      return parts.isNotEmpty ? parts.first : displayName;
    }();

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/backgrounds/home_hero.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFC5CAE9),
                    Color(0xFFB3E5FC),
                  ],
                ),
              ),
            );
          },
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.15),
                Colors.black.withOpacity(0.4),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  'Welcome, $userName!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ) ??
                      const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 320,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) => const PlanTripScreen()),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              size: 24, color: Colors.white),
                          label: const Text(
                            'Plan a New Trip',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(320, 60),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 18),
                            backgroundColor: const Color(0xFF4C74E0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 320,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const RideMatchingScreen()),
                            );
                          },
                          icon: const Icon(Icons.directions_car_rounded,
                              size: 24, color: Colors.white),
                          label: const Text(
                            'Find or Offer Rides',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(320, 60),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 18),
                            backgroundColor: const Color(0xFF26A69A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 320,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const GroupTripsScreen()),
                            );
                          },
                          icon: const Icon(Icons.group_rounded,
                              size: 24, color: Colors.white),
                          label: const Text(
                            'Group Trips',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(320, 60),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 18),
                            backgroundColor: const Color(0xFF9C27B0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Recent Trips Section at bottom with medium size
                if (user != null)
                  _RecentTripsSection(
                    userId: user.uid,
                    onNavigateToTrips: onNavigateToTrips,
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Recent Trips Section Widget
class _RecentTripsSection extends StatelessWidget {
  final String userId;
  final VoidCallback? onNavigateToTrips;

  const _RecentTripsSection({
    required this.userId,
    this.onNavigateToTrips,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tripsStream = FirebaseFirestore.instance
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: tripsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final tripDoc = docs.first;
        final data = tripDoc.data() as Map<String, dynamic>;

        // Extract trip data with validation
        final destination =
            data['destination'] as String? ?? 'Unknown Destination';
        final title = data['title'] as String? ?? 'My Trip';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final duration = data['durationInDays'] as int?;
        final interests = (data['interests'] as List?)?.cast<String>() ?? [];
        final summary = data['summary'] as Map<String, dynamic>?;
        final previewActivities =
            (summary?['previewActivities'] as List?)?.cast<String>() ?? [];
        final totalEstimatedCost = summary?['totalEstimatedCost'];
        final days = summary?['days'] as int?;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Trip',
                  style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ) ??
                      const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                // Show trip details dialog
                _RecentTripsSection._showTripDetailsDialog(
                    context, data, theme, onNavigateToTrips);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 280),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with destination and date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E3A5F),
                                    ) ??
                                    const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A5F),
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 14,
                                    color: const Color(0xFF26A69A),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      destination,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ) ??
                                              TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4C74E0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            createdAt != null
                                ? _RecentTripsSection._formatDate(createdAt)
                                : 'Recent',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4C74E0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Trip details
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (duration != null || days != null)
                          _InfoChip(
                            icon: Icons.calendar_today_rounded,
                            label: '${duration ?? days ?? 0} Days',
                            color: const Color(0xFF4C74E0),
                          ),
                        if (interests.isNotEmpty)
                          _InfoChip(
                            icon: Icons.favorite_rounded,
                            label: interests.take(1).join(', '),
                            color: const Color(0xFF26A69A),
                          ),
                        if (totalEstimatedCost != null)
                          _InfoChip(
                            icon: Icons.currency_rupee_rounded,
                            label: '₹${totalEstimatedCost.toStringAsFixed(0)}',
                            color: Colors.orange[700]!,
                          ),
                      ],
                    ),
                    if (previewActivities.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Highlights',
                        style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ) ??
                            TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                      ),
                      const SizedBox(height: 6),
                      ...previewActivities.take(2).map((activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 14,
                                  color: const Color(0xFF26A69A),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    activity,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ) ??
                                        TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    const SizedBox(height: 12),
                    // View details button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4C74E0),
                            Color(0xFF26A69A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View Full Details',
                            style: theme.textTheme.titleSmall?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ) ??
                                const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  static void _showTripDetailsDialog(
      BuildContext context,
      Map<String, dynamic> data,
      ThemeData theme,
      VoidCallback? onNavigateToTrips) {
    final destination = data['destination'] as String? ?? 'Unknown Destination';
    final title = data['title'] as String? ?? 'My Trip';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final duration = data['durationInDays'] as int?;
    final interests = (data['interests'] as List?)?.cast<String>() ?? [];
    final budget = data['budget'] as String?;
    final summary = data['summary'] as Map<String, dynamic>?;
    final previewActivities =
        (summary?['previewActivities'] as List?)?.cast<String>() ?? [];
    final totalEstimatedCost = summary?['totalEstimatedCost'];
    final days = summary?['days'] as int?;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E3A5F),
                                  ) ??
                                  const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A5F),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 20,
                                  color: Color(0xFF26A69A),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    destination,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                              fontSize: 18,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ) ??
                                            TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 20),
                  // Trip Details
                  _RecentTripsSection._buildDetailRow(
                    context,
                    Icons.calendar_today_rounded,
                    'Duration',
                    duration != null || days != null
                        ? '${duration ?? days ?? 0} Days'
                        : 'Not specified',
                    const Color(0xFF4C74E0),
                  ),
                  const SizedBox(height: 12),
                  if (interests.isNotEmpty)
                    _RecentTripsSection._buildDetailRow(
                      context,
                      Icons.favorite_rounded,
                      'Interests',
                      interests.join(', '),
                      const Color(0xFF26A69A),
                    ),
                  if (interests.isNotEmpty) const SizedBox(height: 12),
                  if (budget != null && budget.isNotEmpty)
                    _RecentTripsSection._buildDetailRow(
                      context,
                      Icons.account_balance_wallet_rounded,
                      'Budget',
                      '₹$budget',
                      Colors.orange[700]!,
                    ),
                  if (budget != null && budget.isNotEmpty)
                    const SizedBox(height: 12),
                  if (totalEstimatedCost != null)
                    _RecentTripsSection._buildDetailRow(
                      context,
                      Icons.currency_rupee_rounded,
                      'Estimated Cost',
                      '₹${totalEstimatedCost.toStringAsFixed(0)}',
                      Colors.green[700]!,
                    ),
                  if (totalEstimatedCost != null) const SizedBox(height: 12),
                  if (createdAt != null)
                    _RecentTripsSection._buildDetailRow(
                      context,
                      Icons.access_time_rounded,
                      'Created',
                      _RecentTripsSection._formatDate(createdAt),
                      Colors.purple[700]!,
                    ),
                  if (createdAt != null) const SizedBox(height: 20),
                  if (previewActivities.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 20),
                    Text(
                      'Trip Highlights',
                      style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A5F),
                          ) ??
                          const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...previewActivities.map((activity) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: const Color(0xFF26A69A),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  activity,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 15,
                                        color: Colors.grey[700],
                                      ) ??
                                      TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[700],
                                      ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 24),
                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF4C74E0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ) ??
                    TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: Colors.grey[900],
                      fontWeight: FontWeight.w600,
                    ) ??
                    const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Info Chip Widget
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Modern Action Card Widget
class _ModernActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ModernActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modern Impressive Destination Card Widget
class _ModernDestinationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String price;
  final String days;
  final Gradient gradient;

  const _ModernDestinationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.price,
    required this.days,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 25,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Animated background pattern
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                      Colors.white.withOpacity(0.05),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Large decorative icon in background
            Positioned(
              top: -30,
              right: -30,
              child: Opacity(
                opacity: 0.15,
                child: Icon(icon, size: 150, color: Colors.white),
              ),
            ),

            // Small decorative dots pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _DotsPatternPainter(),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row with favorite and icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Destination info
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.8,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Price and days row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              price,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            days,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for dots pattern
class _DotsPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MyTripsPage extends StatelessWidget {
  const MyTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return GradientBackground(
        child: const SafeArea(
          child: Center(child: Text('Please sign in to view your trips.')),
        ),
      );
    }

    final tripsStream = FirebaseFirestore.instance
        .collection('trips')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return ImageBackground(
      imagePath: 'assets/backgrounds/my_trips_bg.jpg',
      overlayOpacity: 0.3,
      child: SafeArea(
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
              return Center(
                  child: Text('Failed to load trips: ${snapshot.error}'));
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
                    Text('User ID: ${user.uid}',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const PlanTripScreen()),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Plan a New Trip'),
                    ),
                  ],
                ),
              );
            }

            // Build TripLite list and compute KNN recommendations
            List<TripSimilarityResult> tripRecommendations = [];
            try {
              final tripsLite = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return TripLite(
                  id: data['id'] as String? ?? doc.id,
                  destination:
                      (data['destination'] as String?)?.trim() ?? 'Unknown',
                  durationInDays: data['durationInDays'] as int?,
                  interests: ((data['interests'] as List?)?.cast<String>()) ??
                      const [],
                  budget: data['budget'] as String?,
                  createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                );
              }).toList();

              if (tripsLite.isNotEmpty) {
                tripsLite.sort((a, b) => (b.createdAt ?? DateTime(0))
                    .compareTo(a.createdAt ?? DateTime(0)));
                final queryTrip = tripsLite.first;
                tripRecommendations =
                    TripKnnService(k: 3).findSimilarTrips(queryTrip, tripsLite);
              }
            } catch (_) {
              tripRecommendations = [];
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length + (tripRecommendations.isNotEmpty ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (tripRecommendations.isNotEmpty && index == 0) {
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.auto_awesome, color: Colors.amber),
                              SizedBox(width: 8),
                              Text(
                                'Similar to your last trip (KNN)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...tripRecommendations.map(
                            (result) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.map_outlined),
                              title: Text(result.trip.destination),
                              subtitle: Text(
                                'Match: ${result.similarityPercent} • '
                                'Interests: ${result.trip.interests.isEmpty ? 'N/A' : result.trip.interests.join(', ')}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final adjustedIndex =
                    tripRecommendations.isNotEmpty ? index - 1 : index;
                final data = docs[adjustedIndex].data() as Map<String, dynamic>;
                final destination = data['destination'] as String? ?? 'Unknown';
                final title = data['title'] as String? ?? 'Trip';
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                final duration = data['durationInDays'];
                final interests =
                    (data['interests'] as List?)?.cast<String>() ?? const [];
                final summary = data['summary'] as Map<String, dynamic>?;
                final previewActivities =
                    (summary?['previewActivities'] as List?)?.cast<String>() ??
                        const [];
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
                        if (interests.isNotEmpty)
                          Text('Interests: ${interests.join(', ')}'),
                        if (previewActivities.isNotEmpty)
                          Text('Highlights: ${previewActivities.join(' · ')}'),
                        if (totalEstimatedCost != null)
                          Text('Est. cost: ₹$totalEstimatedCost'),
                        if (createdAt != null)
                          Text('Created: ${createdAt.toLocal()}'),
                      ],
                    ),
                    onTap: () {
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
      ),
    );
  }
}
