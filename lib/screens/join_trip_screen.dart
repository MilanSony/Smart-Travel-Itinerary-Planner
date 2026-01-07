import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_trip_model.dart';
import '../services/group_trip_service.dart';
import '../config/group_trip_theme.dart';
import 'group_trip_detail_screen.dart';
import 'package:intl/intl.dart';

class JoinTripScreen extends StatefulWidget {
  final String tripId;

  const JoinTripScreen({Key? key, required this.tripId}) : super(key: key);

  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
  final GroupTripService _groupTripService = GroupTripService();
  bool _isLoading = true;
  bool _isJoining = false;
  GroupTrip? _trip;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final trip = await _groupTripService.getTrip(widget.tripId);
      if (mounted) {
        setState(() {
          _trip = trip;
          _isLoading = false;

          // Check if user is already a member
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && trip != null) {
            if (trip.isMember(user.uid)) {
              // Already a member, go directly to trip detail
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GroupTripDetailScreen(tripId: widget.tripId),
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to load trip. It may not exist or you may not have access.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinTrip() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to join this trip'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_trip == null) return;

    setState(() {
      _isJoining = true;
    });

    try {
      // Create a pseudo-invitation and accept it
      // This uses the existing invitation flow
      final tripDoc = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .get();

      if (!tripDoc.exists) {
        throw Exception('Trip not found');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      // Add user directly as a member
      final newMember = TripMember(
        userId: user.uid,
        email: user.email ?? '',
        displayName: userData['displayName'] ?? user.displayName ?? 'Unknown',
        role: TripRole.viewer,
        joinedAt: DateTime.now(),
        profileImageUrl: userData['profileImageUrl'],
      );

      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .update({
        'members': FieldValue.arrayUnion([newMember.toFirestore()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log activity
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .collection('activities')
          .add({
        'tripId': widget.tripId,
        'userId': user.uid,
        'userName': newMember.displayName,
        'type': 'memberAdded',
        'description': '${newMember.displayName} joined the trip via link',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the trip!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to trip detail
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GroupTripDetailScreen(tripId: widget.tripId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining trip: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: GroupTripTheme.backgroundLightPeach,
        appBar: AppBar(
          title: const Text('Join Trip'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: GroupTripTheme.sunsetGradient,
            ),
          ),
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: GroupTripTheme.backgroundLightPeach,
        appBar: AppBar(
          title: const Text('Join Trip'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: GroupTripTheme.sunsetGradient,
            ),
          ),
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_trip == null) {
      return Scaffold(
        backgroundColor: GroupTripTheme.backgroundLightPeach,
        appBar: AppBar(
          title: const Text('Join Trip'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: GroupTripTheme.sunsetGradient,
            ),
          ),
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text('Trip not found'),
        ),
      );
    }

    final trip = _trip!;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      backgroundColor: GroupTripTheme.backgroundLightPeach,
      appBar: AppBar(
        title: const Text('Join Trip'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: GroupTripTheme.sunsetGradient,
          ),
        ),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.group_add,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You\'ve been invited!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Trip details
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip title
                  Text(
                    trip.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Destination
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.destination,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (trip.description != null &&
                      trip.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      trip.description!,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Trip info cards
                  if (trip.startDate != null)
                    _buildInfoCard(
                      Icons.calendar_today,
                      'Dates',
                      trip.endDate != null
                          ? '${dateFormat.format(trip.startDate!)} - ${dateFormat.format(trip.endDate!)}'
                          : dateFormat.format(trip.startDate!),
                      Colors.green,
                    ),

                  if (trip.durationInDays != null)
                    _buildInfoCard(
                      Icons.event,
                      'Duration',
                      '${trip.durationInDays} ${trip.durationInDays == 1 ? 'day' : 'days'}',
                      Colors.orange,
                    ),

                  _buildInfoCard(
                    Icons.people,
                    'Members',
                    '${trip.members.length} ${trip.members.length == 1 ? 'member' : 'members'}',
                    Colors.blue,
                  ),

                  const SizedBox(height: 32),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You\'ll join as a Viewer. You can view trip details and add comments.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Join button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isJoining ? null : _joinTrip,
                      icon: _isJoining
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        _isJoining ? 'Joining...' : 'Join Trip',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                          _isJoining ? null : () => Navigator.pop(context),
                      child: const Text('Not Now'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Widget _buildInfoCard(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
