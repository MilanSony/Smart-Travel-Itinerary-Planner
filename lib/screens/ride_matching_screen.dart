import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';
import '../services/ride_matching_service.dart';
import '../widgets/travel_theme_background.dart';
import 'offer_ride_screen.dart';
import 'find_rides_screen.dart';
import 'my_matches_screen.dart';

class RideMatchingScreen extends StatefulWidget {
  const RideMatchingScreen({super.key});

  @override
  State<RideMatchingScreen> createState() => _RideMatchingScreenState();
}

class _RideMatchingScreenState extends State<RideMatchingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find or Offer Rides'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car), text: 'Offer Ride'),
            Tab(icon: Icon(Icons.search), text: 'Find Rides'),
            Tab(icon: Icon(Icons.handshake), text: 'My Matches'),
          ],
        ),
      ),
      body: TravelThemeBackground(
        theme: TravelTheme.rideMatching,
        child: TabBarView(
          controller: _tabController,
          children: const [
            OfferRideScreen(),
            FindRidesScreen(),
            MyMatchesScreen(),
          ],
        ),
      ),
    );
  }
}

