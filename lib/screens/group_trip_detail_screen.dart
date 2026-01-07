import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/group_trip_model.dart';
import '../services/group_trip_service.dart';
import '../config/group_trip_theme.dart';
import 'invite_member_screen.dart';
import 'edit_group_trip_screen.dart';
// Itinerary screen import removed (feature temporarily disabled)

class GroupTripDetailScreen extends StatefulWidget {
  final String tripId;

  const GroupTripDetailScreen({Key? key, required this.tripId})
      : super(key: key);

  @override
  State<GroupTripDetailScreen> createState() => _GroupTripDetailScreenState();
}

class _GroupTripDetailScreenState extends State<GroupTripDetailScreen>
    with SingleTickerProviderStateMixin {
  final GroupTripService _groupTripService = GroupTripService();
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _showDeleteConfirmation(GroupTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text(
            'Are you sure you want to delete "${trip.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _groupTripService.deleteGroupTrip(widget.tripId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting trip: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _leaveTrip(GroupTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Trip'),
        content: Text(
            'Are you sure you want to leave "${trip.title}"? You will need to be re-invited to rejoin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _groupTripService.removeMember(
            tripId: widget.tripId,
            memberUserId: user.uid,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Left trip successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error leaving trip: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showTripCode(GroupTrip trip) {
    final tripCode = _groupTripService.generateTripCode(trip.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.vpn_key, color: GroupTripTheme.primaryOrange),
            const SizedBox(width: 8),
            const Text('Trip Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: GroupTripTheme.sunsetGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    tripCode,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share this code with friends',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Anyone with this code can join your trip',
              style: TextStyle(
                fontSize: 12,
                color: GroupTripTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Schedule share after a short delay to avoid UI race conditions.
              print('Scheduling share for trip ${trip.id} in 600ms');
              Future.delayed(const Duration(milliseconds: 600), () {
                if (!mounted) {
                  print(
                      'Share cancelled: widget no longer mounted for trip ${trip.id}');
                  return;
                }
                print('Proceeding to share trip ${trip.id}');
                _shareTrip(trip);
              });
            },
            icon: const Icon(Icons.share),
            label: const Text('Share Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GroupTripTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareTrip(GroupTrip trip) async {
    try {
      // Check if trip has already started
      final tripHasStarted =
          trip.startDate != null && trip.startDate!.isBefore(DateTime.now());

      if (tripHasStarted && mounted) {
        // Show warning dialog
        final confirmShare = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Trip Has Started'),
              ],
            ),
            content: const Text(
              'This trip has already started. New members may not be able to join. Do you still want to share?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Share Anyway'),
              ),
            ],
          ),
        );

        if (confirmShare != true) return;

        // Small delay to allow the dialog to fully dismiss before opening platform share sheet.
        print(
            'Confirmed share. Waiting 600ms before opening share sheet for trip ${trip.id}');
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) {
          print(
              'Share aborted: widget no longer mounted after confirmation for trip ${trip.id}');
          return;
        }
      }

      final shareText = _groupTripService.getShareableText(trip);
      final tripCode = _groupTripService.generateTripCode(trip.id);

      try {
        print(
            'Attempting to share trip ${trip.id} (${trip.title}) by user ${FirebaseAuth.instance.currentUser?.uid ?? 'unknown'}');
        if (!mounted) {
          print(
              'Share aborted: widget not mounted before opening share sheet for trip ${trip.id}');
          return;
        }
        await Share.share(
          shareText,
          subject: '🌍 Join my trip: ${trip.title} (Code: $tripCode)',
        );
        print('Share successful for trip ${trip.id}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trip code: $tripCode - Shared successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (shareError) {
        print('Share.share failed for trip ${trip.id}: $shareError');
        // Fallback: copy to clipboard if share sheet fails
        try {
          await Clipboard.setData(ClipboardData(text: shareText));
          print('Copied share text to clipboard for trip ${trip.id}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Could not open share dialog. Link copied to clipboard.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } catch (clipboardError) {
          print('Clipboard copy failed for trip ${trip.id}: $clipboardError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error sharing trip: ${shareError.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing trip: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Itinerary feature is temporarily disabled. This handler will show a short
  // message if invoked (keeps callers safe while the feature is removed).
  Future<void> _handleViewItinerary(
      GroupTrip trip, bool isOwner, TripMember? userMember) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Itinerary feature is temporarily disabled')),
      );
    }
    return;
  }

  /// Directly launch the phone dialer (no confirmation).
  /// If the dialer cannot be opened, show an error SnackBar.
  Future<void> _callOrCopyPhone(String phoneNumber) async {
    // Try to launch the dialer first
    final launched = await _callPhone(phoneNumber);
    if (launched) return;

    // Dialer couldn't be launched — show an error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open phone dialer'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Open the phone dialer with the provided [phoneNumber].
  /// Returns true if the dialer was launched, false otherwise.
  Future<bool> _callPhone(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final telUrl = 'tel:$cleaned';

    try {
      // First try the normal url_launcher approach
      if (await canLaunch(telUrl)) {
        await launch(telUrl);
        return true;
      }

      // Fallback: on Android, try an explicit DIAL intent via AndroidIntent
      try {
        if (Platform.isAndroid) {
          final intent = AndroidIntent(
            action: 'android.intent.action.DIAL',
            data: telUrl,
          );
          await intent.launch();
          return true;
        }
      } catch (intentErr) {
        print('AndroidIntent launch failed: $intentErr');
      }

      return false;
    } catch (e) {
      print('Error launching dialer: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GroupTrip?>(
      future: _groupTripService.getTrip(widget.tripId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: GroupTripTheme.backgroundLightPeach,
            appBar: AppBar(title: const Text('Loading...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            backgroundColor: GroupTripTheme.backgroundLightPeach,
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Trip not found or error loading'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final trip = snapshot.data!;
        final user = FirebaseAuth.instance.currentUser;
        final isOwner = trip.isOwner(user?.uid ?? '');
        final canEdit = trip.canEdit(user?.uid ?? '');
        final userMember = trip.getMember(user?.uid ?? '');
        // Members (or owner) can view sensitive fields like contact/pickup/instructions.
        final canViewSensitive = userMember != null || isOwner;
        final tripHasStarted =
            trip.startDate != null && trip.startDate!.isBefore(DateTime.now());
        final tripHasEnded =
            trip.endDate != null && trip.endDate!.isBefore(DateTime.now());

        return Scaffold(
          backgroundColor: GroupTripTheme.backgroundLightPeach,
          appBar: AppBar(
            title: Text(trip.title),
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: GroupTripTheme.sunsetGradient,
              ),
            ),
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (canEdit && !tripHasEnded)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditGroupTripScreen(tripId: widget.tripId),
                      ),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  print(
                      'AppBar share tapped; scheduling in 600ms for trip ${trip.id}');
                  Future.delayed(const Duration(milliseconds: 600), () {
                    if (!mounted) {
                      print(
                          'AppBar share aborted: widget not mounted for trip ${trip.id}');
                      return;
                    }
                    print(
                        'AppBar share: invoking _shareTrip for trip ${trip.id}');
                    _shareTrip(trip);
                  });
                },
                tooltip: 'Share Trip',
              ),
              // Itinerary viewing disabled — button removed
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'viewcode':
                      _showTripCode(trip);
                      break;
                    case 'invite':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              InviteMemberScreen(tripId: widget.tripId),
                        ),
                      );
                      break;
                    case 'share':
                      // Delay to avoid immediate share call from menu closing
                      print(
                          'Menu share selected; scheduling share in 600ms for trip ${trip.id}');
                      Future.delayed(const Duration(milliseconds: 600), () {
                        if (!mounted) {
                          print(
                              'Menu share aborted: widget not mounted for trip ${trip.id}');
                          return;
                        }
                        print(
                            'Menu share: invoking _shareTrip for trip ${trip.id}');
                        _shareTrip(trip);
                      });
                      break;
                    case 'leave':
                      _leaveTrip(trip);
                      break;
                    case 'delete':
                      _showDeleteConfirmation(trip);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (!tripHasEnded)
                    const PopupMenuItem(
                      value: 'viewcode',
                      child: Row(
                        children: [
                          Icon(Icons.vpn_key),
                          SizedBox(width: 8),
                          Text('View Trip Code'),
                        ],
                      ),
                    ),
                  if (tripHasEnded)
                    PopupMenuItem(
                      enabled: false,
                      value: 'viewcode_disabled',
                      child: Row(
                        children: [
                          Icon(Icons.vpn_key, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'View Trip Code (Trip Ended)',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  if (canEdit && !tripHasStarted)
                    const PopupMenuItem(
                      value: 'invite',
                      child: Row(
                        children: [
                          Icon(Icons.person_add),
                          SizedBox(width: 8),
                          Text('Invite Members'),
                        ],
                      ),
                    ),
                  if (canEdit && tripHasStarted)
                    PopupMenuItem(
                      enabled: false,
                      value: 'invite_disabled',
                      child: Row(
                        children: [
                          Icon(Icons.person_add, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'Invite Members (Trip Started)',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  if (!tripHasEnded)
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Share Trip Link'),
                        ],
                      ),
                    ),
                  if (tripHasEnded)
                    PopupMenuItem(
                      enabled: false,
                      value: 'share_disabled',
                      child: Row(
                        children: [
                          Icon(Icons.share, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'Share Trip (Trip Ended)',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  if (!isOwner)
                    const PopupMenuItem(
                      value: 'leave',
                      child: Row(
                        children: [
                          Icon(Icons.exit_to_app, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Leave Trip'),
                        ],
                      ),
                    ),
                  if (isOwner)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Trip'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview', icon: Icon(Icons.info_outline, size: 20)),
                Tab(text: 'Members', icon: Icon(Icons.people, size: 20)),
                Tab(text: 'Activity', icon: Icon(Icons.history, size: 20)),
                Tab(text: 'Comments', icon: Icon(Icons.comment, size: 20)),
              ],
              isScrollable: false,
              labelStyle: const TextStyle(fontSize: 12),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(trip, userMember),
              _buildMembersTab(trip, isOwner, canEdit),
              _buildActivityTab(),
              _buildCommentsTab(trip),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab(GroupTrip trip, TripMember? userMember) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final tripHasEnded =
        trip.endDate != null && trip.endDate!.isBefore(DateTime.now());
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = trip.isOwner(user?.uid ?? '');
    final canViewSensitive = userMember != null || isOwner;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Trip Ended Warning Banner
        if (tripHasEnded)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red[300]!, width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.event_busy, color: Colors.red[700], size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip Has Ended',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This trip is now in read-only mode. No new members can join or be invited.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Trip Header Card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trip.destination,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (trip.description != null &&
                    trip.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    trip.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Your role: ${userMember?.role.displayName ?? "N/A"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Trip Details
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.event,
                  'Duration',
                  trip.durationInDays != null
                      ? '${trip.durationInDays} ${trip.durationInDays == 1 ? 'day' : 'days'}'
                      : 'Not specified',
                ),
                const Divider(),
                if (trip.startDate != null)
                  _buildDetailRow(
                    Icons.calendar_today,
                    'Start Date',
                    dateFormat.format(trip.startDate!),
                  ),
                if (trip.startDate != null) const Divider(),
                if (trip.endDate != null)
                  _buildDetailRow(
                    Icons.event_available,
                    'End Date',
                    dateFormat.format(trip.endDate!),
                  ),
                if (trip.endDate != null) const Divider(),
                _buildDetailRow(
                  Icons.people,
                  'Members',
                  '${trip.members.length} ${trip.members.length == 1 ? 'member' : 'members'}',
                ),
                const Divider(),
                _buildDetailRow(
                  trip.isPublic ? Icons.public : Icons.lock,
                  'Visibility',
                  trip.isPublic ? 'Public' : 'Private',
                ),
                const Divider(),

                // If there are sensitive details (contact/pickup/instructions) and
                // the current viewer is NOT a trip member/owner, show a small hint.
                if (!canViewSensitive &&
                    ((trip.contactNumber != null &&
                            trip.contactNumber!.isNotEmpty) ||
                        (trip.meetingPoint != null &&
                            trip.meetingPoint!.isNotEmpty) ||
                        (trip.specialInstructions != null &&
                            trip.specialInstructions!.isNotEmpty))) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Some trip details (contact, pickup spot or instructions) are visible to members only.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                ],

                // Sensitive fields: Contact Number and Pickup Spot (members/owner only)
                if (canViewSensitive &&
                    trip.contactNumber != null &&
                    trip.contactNumber!.isNotEmpty) ...[
                  _buildDetailRow(
                    Icons.phone,
                    'Contact Number',
                    trip.contactNumber!,
                    onTap: () => _callOrCopyPhone(trip.contactNumber!),
                  ),
                  const Divider(),
                ],
                if (canViewSensitive &&
                    trip.meetingPoint != null &&
                    trip.meetingPoint!.isNotEmpty) ...[
                  _buildDetailRow(
                    Icons.place,
                    'Pickup Spot',
                    trip.meetingPoint!,
                  ),
                  const Divider(),
                ],

                // General info (transportation & time) — shown when present
                if (trip.transportationType != null &&
                    trip.transportationType!.isNotEmpty) ...[
                  _buildDetailRow(
                    Icons.directions_car,
                    'Transportation',
                    trip.transportationType!,
                  ),
                  const Divider(),
                ],
                if (trip.timeToReach != null &&
                    trip.timeToReach!.isNotEmpty) ...[
                  _buildDetailRow(
                    Icons.access_time,
                    'Time to Reach',
                    trip.timeToReach!,
                  ),
                  const Divider(),
                ],

                // Special instructions (treated as sensitive — members/owner only)
                if (canViewSensitive &&
                    trip.specialInstructions != null &&
                    trip.specialInstructions!.isNotEmpty) ...[
                  _buildDetailRow(
                    Icons.info,
                    'Special Instructions',
                    trip.specialInstructions!,
                  ),
                  const Divider(),
                ],

                _buildDetailRow(
                  Icons.person,
                  'Created By',
                  trip.members
                      .firstWhere((m) => m.userId == trip.ownerId)
                      .displayName,
                ),
                const Divider(),
                _buildDetailRow(
                  Icons.access_time,
                  'Created',
                  _formatDateTime(trip.createdAt),
                ),
                const Divider(),
                _buildDetailRow(
                  Icons.update,
                  'Last Updated',
                  _formatDateTime(trip.updatedAt),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Quick Stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                Icons.people_outline,
                '${trip.members.length}',
                'Members',
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<List<TripComment>>(
                stream: _groupTripService.getTripComments(widget.tripId),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return _buildStatCard(
                    Icons.comment_outlined,
                    '$count',
                    'Comments',
                    Colors.green,
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Permissions Info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Your Permissions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                userMember?.role.description ?? 'No permissions',
                style: TextStyle(fontSize: 13, color: Colors.blue[900]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab(GroupTrip trip, bool isOwner, bool canEdit) {
    return Column(
      children: [
        if (canEdit)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          InviteMemberScreen(tripId: widget.tripId),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Invite Member'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: trip.members.length,
            itemBuilder: (context, index) {
              final member = trip.members[index];
              final isSelf =
                  member.userId == FirebaseAuth.instance.currentUser?.uid;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: _getRoleColor(member.role),
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (isSelf)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        member.email,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRoleColor(member.role),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              member.role.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Joined ${_formatDate(member.joinedAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: isOwner && member.role != TripRole.owner
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) async {
                            if (value == 'remove') {
                              await _removeMember(member);
                            } else {
                              await _changeRole(member, value);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'editor',
                              child: Text('Make Editor'),
                            ),
                            const PopupMenuItem(
                              value: 'viewer',
                              child: Text('Make Viewer'),
                            ),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Text(
                                'Remove',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab() {
    return StreamBuilder<List<TripActivity>>(
      stream: _groupTripService.getTripActivities(widget.tripId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final activities = snapshot.data ?? [];

        if (activities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No activity yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return _buildActivityItem(activity);
          },
        );
      },
    );
  }

  Widget _buildActivityItem(TripActivity activity) {
    IconData icon;
    Color iconColor;

    switch (activity.type) {
      case ActivityType.created:
        icon = Icons.add_circle;
        iconColor = Colors.green;
        break;
      case ActivityType.edited:
        icon = Icons.edit;
        iconColor = Colors.blue;
        break;
      case ActivityType.memberAdded:
        icon = Icons.person_add;
        iconColor = Colors.purple;
        break;
      case ActivityType.memberRemoved:
        icon = Icons.person_remove;
        iconColor = Colors.orange;
        break;
      case ActivityType.roleChanged:
        icon = Icons.swap_horiz;
        iconColor = Colors.indigo;
        break;
      case ActivityType.commentAdded:
        icon = Icons.comment;
        iconColor = Colors.teal;
        break;
      case ActivityType.shared:
        icon = Icons.share;
        iconColor = Colors.pink;
        break;
      case ActivityType.deleted:
        icon = Icons.delete;
        iconColor = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          activity.description,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          _formatDateTime(activity.timestamp),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            activity.type.displayName,
            style: TextStyle(
              color: iconColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsTab(GroupTrip trip) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<TripComment>>(
            stream: _groupTripService.getTripComments(widget.tripId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.comment_outlined,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to comment!',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  return _buildCommentItem(comments[index], trip);
                },
              );
            },
          ),
        ),
        _buildCommentInput(trip),
      ],
    );
  }

  Widget _buildCommentItem(TripComment comment, GroupTrip trip) {
    final user = FirebaseAuth.instance.currentUser;
    final isOwnComment = comment.userId == user?.uid;
    final isOwner = trip.isOwner(user?.uid ?? '');
    final canDelete = isOwnComment || isOwner;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue,
                  child: Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDateTime(comment.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red,
                    onPressed: () => _deleteComment(comment.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comment.comment,
              style: const TextStyle(fontSize: 14),
            ),
            if (comment.updatedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Edited',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput(GroupTrip trip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: IconButton(
              icon: _isSubmittingComment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _isSubmittingComment ? null : _submitComment,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isSubmittingComment = true;
    });

    try {
      await _groupTripService.addComment(
        tripId: widget.tripId,
        comment: _commentController.text.trim(),
      );
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _groupTripService.deleteComment(
        tripId: widget.tripId,
        commentId: commentId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(TripMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove ${member.displayName} from this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _groupTripService.removeMember(
          tripId: widget.tripId,
          memberUserId: member.userId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Member removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing member: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _changeRole(TripMember member, String newRoleString) async {
    TripRole newRole;
    switch (newRoleString) {
      case 'editor':
        newRole = TripRole.editor;
        break;
      case 'viewer':
        newRole = TripRole.viewer;
        break;
      default:
        return;
    }

    if (member.role == newRole) {
      return;
    }

    try {
      await _groupTripService.updateMemberRole(
        tripId: widget.tripId,
        memberUserId: member.userId,
        newRole: newRole,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${member.displayName}\'s role changed to ${newRole.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing role: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                const SizedBox(height: 2),
                InkWell(
                  onTap: onTap,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color:
                          onTap != null ? Theme.of(context).primaryColor : null,
                      decoration:
                          onTap != null ? TextDecoration.underline : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, String value, String label, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(TripRole role) {
    switch (role) {
      case TripRole.owner:
        return Colors.purple;
      case TripRole.editor:
        return Colors.blue;
      case TripRole.viewer:
        return Colors.green;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'yr' : 'yrs'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'mo' : 'mos'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else {
      return 'Today';
    }
  }
}
