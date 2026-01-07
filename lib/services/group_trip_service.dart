import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_trip_model.dart';
import '../models/itinerary_model.dart';
import 'itinerary_service.dart';
import 'dart:math';

class GroupTripService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  // App download link - Firebase App Distribution
  // TODO: Replace with your actual Firebase App Distribution link after setup
  // Get link from: Firebase Console → App Distribution → Releases → Copy Installation Link
  // Format: https://appdistribution.firebase.dev/i/ABC123XYZ
  static const String appDownloadLink =
      'https://appdistribution.firebase.dev/i/YOUR_LINK_HERE'; // Replace after Firebase setup
  static const String appWebsiteLink = 'https://tripgenie.app';
  static const String appName = 'Trip Genie';

  // ==================== HELPER METHODS ====================

  /// Generate a 6-character unique code for trip sharing
  String generateTripCode(String tripId) {
    // Use first 6 characters of tripId and convert to uppercase
    return tripId.substring(0, min(6, tripId.length)).toUpperCase();
  }

  /// Join trip using code
  Future<void> joinTripWithCode(String code) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Query trips by tripCode field (efficient)
      final tripsSnapshot = await _db
          .collection('trips')
          .where('tripCode', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (tripsSnapshot.docs.isEmpty) {
        throw Exception('Trip not found. Please check the code and try again.');
      }

      final tripId = tripsSnapshot.docs.first.id;

      // Get trip and check if user is already a member
      final trip = await getTrip(tripId);
      if (trip == null) {
        throw Exception('Trip not found.');
      }

      if (trip.isMember(user.uid)) {
        throw Exception('You are already a member of this trip.');
      }

      // Check if trip has already started
      if (trip.startDate != null && trip.startDate!.isBefore(DateTime.now())) {
        throw Exception('Cannot join this trip as it has already started');
      }

      // Check if trip has already ended
      if (trip.endDate != null && trip.endDate!.isBefore(DateTime.now())) {
        throw Exception('Cannot join this trip as it has already ended');
      }

      // Get user details
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Add user as viewer member
      final newMember = TripMember(
        userId: user.uid,
        email: user.email!,
        displayName: userData['displayName'] ?? user.displayName ?? 'Unknown',
        role: TripRole.viewer,
        joinedAt: DateTime.now(),
        profileImageUrl: userData['profileImageUrl'],
      );

      // Update trip with new member
      await _db.collection('trips').doc(tripId).update({
        'members': FieldValue.arrayUnion([newMember.toFirestore()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log activity
      await _logActivity(
        tripId: tripId,
        userId: user.uid,
        userName: newMember.displayName,
        type: ActivityType.memberAdded,
        description: '${newMember.displayName} joined the trip with code',
      );
    } catch (e) {
      print('Error joining trip with code: $e');
      rethrow;
    }
  }

  /// Get shareable text with code and app link
  String getShareableText(GroupTrip trip) {
    final code = generateTripCode(trip.id);

    return '''
🌍 Join my trip to ${trip.destination}!

📍 Trip: ${trip.title}
${trip.description != null && trip.description!.isNotEmpty ? '✨ ${trip.description}\n' : ''}
${trip.startDate != null ? '📅 Dates: ${trip.startDate!.day}/${trip.startDate!.month}/${trip.startDate!.year}${trip.endDate != null ? ' - ${trip.endDate!.day}/${trip.endDate!.month}/${trip.endDate!.year}' : ''}' : ''}

🔑 Trip Code: $code

👉 To join:
1. Install $appName app: $appDownloadLink
2. Tap "Open" or install from downloads
3. Login/Signup with your email
4. Go to Group Trips → Tap "Join with Code" (🔑 icon)
5. Enter code: $code

Let's plan this trip together! 🎉
''';
  }

  // ==================== TRIP STATUS HELPERS ====================

  /// Check if trip has ended
  bool isTripEnded(GroupTrip trip) {
    if (trip.endDate == null) return false;
    return trip.endDate!.isBefore(DateTime.now());
  }

  /// Check if trip is active (not ended)
  bool isTripActive(GroupTrip trip) {
    return !isTripEnded(trip);
  }

  /// Check if trip has started
  bool isTripStarted(GroupTrip trip) {
    if (trip.startDate == null) return false;
    return trip.startDate!.isBefore(DateTime.now());
  }

  /// Migrate existing trips to add tripCode field
  /// Run this once to update old trips
  Future<void> migrateTripsWithCodes() async {
    try {
      final tripsSnapshot = await _db.collection('trips').get();

      for (var doc in tripsSnapshot.docs) {
        final tripData = doc.data();

        // Only update if tripCode doesn't exist
        if (tripData['tripCode'] == null) {
          final tripCode = generateTripCode(doc.id);
          await doc.reference.update({'tripCode': tripCode});
          print('Updated trip ${doc.id} with code: $tripCode');
        }
      }

      print('Migration completed! ${tripsSnapshot.docs.length} trips checked.');
    } catch (e) {
      print('Error during migration: $e');
      rethrow;
    }
  }

  // Itinerary helper methods moved up to class-level (see above)

  // ==================== TRIP OPERATIONS ====================

  /// Create a new group trip
  Future<String> createGroupTrip({
    required String title,
    required String destination,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? durationInDays,
    bool isPublic = false,
    Map<String, dynamic>? itinerarySummary,
    String? contactNumber,
    String? meetingPoint,
    String? transportationType,
    String? timeToReach,
    String? specialInstructions,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user details
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final docRef = _db.collection('trips').doc();

      final owner = TripMember(
        userId: user.uid,
        email: user.email ?? '',
        displayName: userData['displayName'] ?? user.displayName ?? 'Unknown',
        role: TripRole.owner,
        joinedAt: DateTime.now(),
        profileImageUrl: userData['profileImageUrl'],
      );

      final groupTrip = GroupTrip(
        id: docRef.id,
        ownerId: user.uid,
        title: title,
        destination: destination,
        description: description,
        startDate: startDate,
        endDate: endDate,
        durationInDays: durationInDays,
        members: [owner],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPublic: isPublic,
        itinerarySummary: itinerarySummary,
        contactNumber: contactNumber,
        meetingPoint: meetingPoint,
        transportationType: transportationType,
        timeToReach: timeToReach,
        specialInstructions: specialInstructions,
      );

      // Add trip to Firestore
      final tripData = groupTrip.toFirestore();
      tripData['tripCode'] = generateTripCode(docRef.id); // Add trip code field
      // Itinerary generation is temporarily disabled.
      // No `itineraryStatus` is set here while the feature is disabled.
      await docRef.set(tripData);

      // Log activity
      await _logActivity(
        tripId: docRef.id,
        userId: user.uid,
        userName: owner.displayName,
        type: ActivityType.created,
        description: '${owner.displayName} created the trip',
      );

      // Itinerary generation is temporarily disabled.
      // Previously we started `_generateAndStoreItinerary(...)` here; it has been disabled.

      return docRef.id;
    } catch (e) {
      print('Error creating group trip: $e');
      rethrow;
    }
  } // end createGroupTrip

  /// Background itinerary generation and persistence (disabled)
  Future<void> _generateAndStoreItinerary({
    required String tripId,
    required String destination,
    int? durationInDays,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Itinerary generation is currently disabled.
    // This method is a no-op while the feature is turned off.
    print('Itinerary generation is disabled. Skipping generation for $tripId');
    return;
  }

  /// Fetch stored itinerary for a trip (if any)
  Future<Itinerary?> getItinerary(String tripId) async {
    // Itinerary feature is currently disabled.
    print('Itinerary feature disabled: getItinerary called for $tripId');
    return null;
  }

  /// Public trigger to (re)generate the itinerary now (owner/editor only should use)
  Future<void> generateItineraryNow(String tripId) async {
    // Itinerary generation is currently disabled.
    print(
        'Itinerary generation disabled: generateItineraryNow called for $tripId');
    return;
  }

  /// Update group trip details
  Future<void> updateGroupTrip({
    required String tripId,
    String? title,
    String? destination,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? durationInDays,
    bool? isPublic,
    Map<String, dynamic>? itinerarySummary,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) throw Exception('Trip not found');

      final trip = GroupTrip.fromFirestore(tripDoc);
      if (!trip.canEdit(user.uid)) {
        throw Exception('You do not have permission to edit this trip');
      }

      final updates = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (title != null) updates['title'] = title;
      if (destination != null) updates['destination'] = destination;
      if (description != null) updates['description'] = description;
      if (startDate != null)
        updates['startDate'] = Timestamp.fromDate(startDate);
      if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
      if (durationInDays != null) updates['durationInDays'] = durationInDays;
      if (isPublic != null) updates['isPublic'] = isPublic;
      if (itinerarySummary != null) updates['summary'] = itinerarySummary;

      await _db.collection('trips').doc(tripId).update(updates);

      // Log activity
      final member = trip.getMember(user.uid);
      if (member != null) {
        await _logActivity(
          tripId: tripId,
          userId: user.uid,
          userName: member.displayName,
          type: ActivityType.edited,
          description: '${member.displayName} updated the trip details',
        );
      }
    } catch (e) {
      print('Error updating group trip: $e');
      rethrow;
    }
  }

  /// Delete a group trip
  Future<void> deleteGroupTrip(String tripId) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) throw Exception('Trip not found');

      final trip = GroupTrip.fromFirestore(tripDoc);
      if (!trip.isOwner(user.uid)) {
        throw Exception('Only the owner can delete this trip');
      }

      // Delete all sub-collections
      final batch = _db.batch();

      // Delete activities
      final activities = await _db
          .collection('trips')
          .doc(tripId)
          .collection('activities')
          .get();
      for (var doc in activities.docs) {
        batch.delete(doc.reference);
      }

      // Delete comments
      final comments = await _db
          .collection('trips')
          .doc(tripId)
          .collection('comments')
          .get();
      for (var doc in comments.docs) {
        batch.delete(doc.reference);
      }

      // Delete the trip itself
      batch.delete(_db.collection('trips').doc(tripId));

      await batch.commit();

      // Delete related invitations
      final invitations = await _db
          .collection('invitations')
          .where('tripId', isEqualTo: tripId)
          .get();
      for (var doc in invitations.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error deleting group trip: $e');
      rethrow;
    }
  }

  /// Get a single trip by ID
  Future<GroupTrip?> getTrip(String tripId) async {
    try {
      final doc = await _db.collection('trips').doc(tripId).get();
      if (!doc.exists) return null;
      return GroupTrip.fromFirestore(doc);
    } catch (e) {
      print('Error getting trip: $e');
      return null;
    }
  }

  /// Get all trips for the current user (owned and shared)
  Stream<List<GroupTrip>> getUserTrips() {
    final user = currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('trips')
        .where('members', arrayContains: {
          'userId': user.uid,
        })
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          // Fallback: Filter client-side if arrayContains doesn't work
          return snapshot.docs
              .map((doc) => GroupTrip.fromFirestore(doc))
              .where((trip) => trip.isMember(user.uid))
              .toList();
        });
  }

  /// Get trips owned by current user (only active trips)
  Stream<List<GroupTrip>> getOwnedTrips() {
    final user = currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('trips')
        .where('ownerId', isEqualTo: user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GroupTrip.fromFirestore(doc))
          .where((trip) => isTripActive(trip)) // Filter out ended trips
          .toList();
    });
  }

  /// Get trips shared with current user (not owned, only active)
  Stream<List<GroupTrip>> getSharedTrips() {
    final user = currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('trips')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GroupTrip.fromFirestore(doc))
          .where((trip) =>
              trip.isMember(user.uid) &&
              !trip.isOwner(user.uid) &&
              isTripActive(trip)) // Filter out ended trips
          .toList();
    });
  }

  /// Get past/ended trips (owned by or shared with current user)
  Stream<List<GroupTrip>> getPastTrips() {
    final user = currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('trips')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => GroupTrip.fromFirestore(doc))
          .where((trip) =>
              trip.isMember(user.uid) && // User is a member
              isTripEnded(trip)) // Trip has ended
          .toList();
    });
  }

  // ==================== INVITATION OPERATIONS ====================

  /// Send an invitation to join a trip
  Future<String> sendInvitation({
    required String tripId,
    required String invitedUserEmail,
    required TripRole role,
    String? message,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Validate email
      if (!_isValidEmail(invitedUserEmail)) {
        throw Exception('Invalid email address');
      }

      // Get trip details
      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) throw Exception('Trip not found');

      final trip = GroupTrip.fromFirestore(tripDoc);

      // Check if user has permission to invite
      if (!trip.canEdit(user.uid) && !trip.isOwner(user.uid)) {
        throw Exception('You do not have permission to invite members');
      }

      // Check if trip has already started
      if (trip.startDate != null && trip.startDate!.isBefore(DateTime.now())) {
        throw Exception('Cannot send invitations after the trip has started');
      }

      // Check if trip has already ended
      if (trip.endDate != null && trip.endDate!.isBefore(DateTime.now())) {
        throw Exception('Cannot send invitations for trips that have ended');
      }

      // Check if user is already a member
      final existingMember = trip.members.firstWhere(
        (m) => m.email.toLowerCase() == invitedUserEmail.toLowerCase(),
        orElse: () => TripMember(
          userId: '',
          email: '',
          displayName: '',
          role: TripRole.viewer,
          joinedAt: DateTime.now(),
        ),
      );

      if (existingMember.userId.isNotEmpty) {
        throw Exception('User is already a member of this trip');
      }

      // Check for existing pending invitation
      final existingInvites = await _db
          .collection('invitations')
          .where('tripId', isEqualTo: tripId)
          .where('invitedUserEmail', isEqualTo: invitedUserEmail.toLowerCase())
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingInvites.docs.isNotEmpty) {
        throw Exception('An invitation has already been sent to this email');
      }

      // Get inviting user details
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Look up invited user ID if they have an account
      String? invitedUserId;
      final usersQuery = await _db
          .collection('users')
          .where('email', isEqualTo: invitedUserEmail.toLowerCase())
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        invitedUserId = usersQuery.docs.first.id;
      }

      final docRef = _db.collection('invitations').doc();

      final invitation = TripInvitation(
        id: docRef.id,
        tripId: tripId,
        tripTitle: trip.title,
        tripDestination: trip.destination,
        invitedByUserId: user.uid,
        invitedByName: userData['displayName'] ?? user.displayName ?? 'Someone',
        invitedByEmail: user.email ?? '',
        invitedUserEmail: invitedUserEmail.toLowerCase(),
        invitedUserId: invitedUserId,
        role: role,
        status: InvitationStatus.pending,
        createdAt: DateTime.now(),
        message: message,
      );

      await docRef.set(invitation.toFirestore());

      // Log activity
      final member = trip.getMember(user.uid);
      if (member != null) {
        await _logActivity(
          tripId: tripId,
          userId: user.uid,
          userName: member.displayName,
          type: ActivityType.shared,
          description:
              '${member.displayName} invited $invitedUserEmail to the trip',
        );
      }

      return docRef.id;
    } catch (e) {
      print('Error sending invitation: $e');
      rethrow;
    }
  }

  /// Send invitations to multiple email addresses in one action.
  Future<List<String>> sendInvitations({
    required String tripId,
    required List<String> invitedUserEmails,
    required TripRole role,
    String? message,
  }) async {
    // Deduplicate and normalize input up front
    final uniqueEmails = invitedUserEmails
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toSet()
        .toList();

    if (uniqueEmails.isEmpty) {
      throw Exception('No email addresses provided');
    }

    final List<String> invitationIds = [];

    for (final email in uniqueEmails) {
      final id = await sendInvitation(
        tripId: tripId,
        invitedUserEmail: email,
        role: role,
        message: message,
      );
      invitationIds.add(id);
    }

    return invitationIds;
  }

  /// Accept an invitation
  Future<void> acceptInvitation(String invitationId) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      final inviteDoc =
          await _db.collection('invitations').doc(invitationId).get();
      if (!inviteDoc.exists) throw Exception('Invitation not found');

      final invitation = TripInvitation.fromFirestore(inviteDoc);

      // Verify invitation is for current user
      if (invitation.invitedUserEmail.toLowerCase() !=
          user.email?.toLowerCase()) {
        throw Exception('This invitation is not for you');
      }

      if (invitation.status != InvitationStatus.pending) {
        throw Exception(
            'This invitation has already been ${invitation.status.displayName.toLowerCase()}');
      }

      // Get user details
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Add user to trip members
      final newMember = TripMember(
        userId: user.uid,
        email: user.email ?? '',
        displayName: userData['displayName'] ?? user.displayName ?? 'Unknown',
        role: invitation.role,
        joinedAt: DateTime.now(),
        profileImageUrl: userData['profileImageUrl'],
      );

      await _db.collection('trips').doc(invitation.tripId).update({
        'members': FieldValue.arrayUnion([newMember.toFirestore()]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Update invitation status
      await _db.collection('invitations').doc(invitationId).update({
        'status': InvitationStatus.accepted.toFirestore(),
        'respondedAt': Timestamp.fromDate(DateTime.now()),
        'invitedUserId': user.uid,
      });

      // Log activity
      await _logActivity(
        tripId: invitation.tripId,
        userId: user.uid,
        userName: newMember.displayName,
        type: ActivityType.memberAdded,
        description: '${newMember.displayName} joined the trip',
      );
    } catch (e) {
      print('Error accepting invitation: $e');
      rethrow;
    }
  }

  /// Reject an invitation
  Future<void> rejectInvitation(String invitationId) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      final inviteDoc =
          await _db.collection('invitations').doc(invitationId).get();
      if (!inviteDoc.exists) throw Exception('Invitation not found');

      final invitation = TripInvitation.fromFirestore(inviteDoc);

      if (invitation.invitedUserEmail.toLowerCase() !=
          user.email?.toLowerCase()) {
        throw Exception('This invitation is not for you');
      }

      if (invitation.status != InvitationStatus.pending) {
        throw Exception(
            'This invitation has already been ${invitation.status.displayName.toLowerCase()}');
      }

      await _db.collection('invitations').doc(invitationId).update({
        'status': InvitationStatus.rejected.toFirestore(),
        'respondedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error rejecting invitation: $e');
      rethrow;
    }
  }

  /// Cancel an invitation (by the person who sent it)
  Future<void> cancelInvitation(String invitationId) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      final inviteDoc =
          await _db.collection('invitations').doc(invitationId).get();
      if (!inviteDoc.exists) throw Exception('Invitation not found');

      final invitation = TripInvitation.fromFirestore(inviteDoc);

      if (invitation.invitedByUserId != user.uid) {
        throw Exception('You can only cancel invitations you sent');
      }

      if (invitation.status != InvitationStatus.pending) {
        throw Exception(
            'Cannot cancel a ${invitation.status.displayName.toLowerCase()} invitation');
      }

      await _db.collection('invitations').doc(invitationId).update({
        'status': InvitationStatus.cancelled.toFirestore(),
        'respondedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error cancelling invitation: $e');
      rethrow;
    }
  }

  /// Get pending invitations for current user
  Stream<List<TripInvitation>> getPendingInvitations() {
    final user = currentUser;
    if (user == null || user.email == null) return Stream.value([]);

    return _db
        .collection('invitations')
        .where('invitedUserEmail', isEqualTo: user.email!.toLowerCase())
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripInvitation.fromFirestore(doc))
            .toList());
  }

  /// Get sent invitations for a trip
  Stream<List<TripInvitation>> getTripInvitations(String tripId) {
    return _db
        .collection('invitations')
        .where('tripId', isEqualTo: tripId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripInvitation.fromFirestore(doc))
            .toList());
  }

  // ==================== MEMBER MANAGEMENT ====================

  /// Remove a member from a trip
  Future<void> removeMember({
    required String tripId,
    required String memberUserId,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) throw Exception('Trip not found');

      final trip = GroupTrip.fromFirestore(tripDoc);

      // Only owner can remove members, or users can remove themselves
      if (!trip.isOwner(user.uid) && user.uid != memberUserId) {
        throw Exception('You do not have permission to remove members');
      }

      // Cannot remove the owner
      if (memberUserId == trip.ownerId) {
        throw Exception('Cannot remove the trip owner');
      }

      final memberToRemove = trip.getMember(memberUserId);
      if (memberToRemove == null) {
        throw Exception('Member not found');
      }

      // Remove member
      await _db.collection('trips').doc(tripId).update({
        'members': FieldValue.arrayRemove([memberToRemove.toFirestore()]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Log activity
      final currentMember = trip.getMember(user.uid);
      if (currentMember != null) {
        final description = user.uid == memberUserId
            ? '${memberToRemove.displayName} left the trip'
            : '${currentMember.displayName} removed ${memberToRemove.displayName} from the trip';

        await _logActivity(
          tripId: tripId,
          userId: user.uid,
          userName: currentMember.displayName,
          type: ActivityType.memberRemoved,
          description: description,
        );
      }
    } catch (e) {
      print('Error removing member: $e');
      rethrow;
    }
  }

  /// Update a member's role
  Future<void> updateMemberRole({
    required String tripId,
    required String memberUserId,
    required TripRole newRole,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) throw Exception('Trip not found');

      final trip = GroupTrip.fromFirestore(tripDoc);

      // Only owner can change roles
      if (!trip.isOwner(user.uid)) {
        throw Exception('Only the owner can change member roles');
      }

      // Cannot change owner's role
      if (memberUserId == trip.ownerId) {
        throw Exception('Cannot change the owner\'s role');
      }

      final member = trip.getMember(memberUserId);
      if (member == null) throw Exception('Member not found');

      // Update member role
      final updatedMember = member.copyWith(role: newRole);
      final members = trip.members
          .map((m) => m.userId == memberUserId ? updatedMember : m)
          .toList();

      await _db.collection('trips').doc(tripId).update({
        'members': members.map((m) => m.toFirestore()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Log activity
      final currentMember = trip.getMember(user.uid);
      if (currentMember != null) {
        await _logActivity(
          tripId: tripId,
          userId: user.uid,
          userName: currentMember.displayName,
          type: ActivityType.roleChanged,
          description:
              '${currentMember.displayName} changed ${member.displayName}\'s role to ${newRole.displayName}',
        );
      }
    } catch (e) {
      print('Error updating member role: $e');
      rethrow;
    }
  }

  // ==================== ACTIVITY LOG ====================

  /// Log an activity
  Future<void> _logActivity({
    required String tripId,
    required String userId,
    required String userName,
    required ActivityType type,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final docRef =
          _db.collection('trips').doc(tripId).collection('activities').doc();

      final activity = TripActivity(
        id: docRef.id,
        tripId: tripId,
        userId: userId,
        userName: userName,
        type: type,
        description: description,
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      await docRef.set(activity.toFirestore());
    } catch (e) {
      print('Error logging activity: $e');
      // Don't throw - activity logging should not break main operations
    }
  }

  /// Get activity log for a trip
  Stream<List<TripActivity>> getTripActivities(String tripId,
      {int limit = 50}) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripActivity.fromFirestore(doc))
            .toList());
  }

  // ==================== COMMENTS ====================

  /// Add a comment to a trip
  Future<String> addComment({
    required String tripId,
    required String comment,
    String? dayIndex,
    String? activityIndex,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Validate comment
      if (comment.trim().isEmpty) {
        throw Exception('Comment cannot be empty');
      }

      if (comment.length > 1000) {
        throw Exception('Comment is too long (max 1000 characters)');
      }

      // Check if user is a member
      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) throw Exception('Trip not found');

      final trip = GroupTrip.fromFirestore(tripDoc);
      if (!trip.isMember(user.uid)) {
        throw Exception('You must be a member to comment');
      }

      final member = trip.getMember(user.uid)!;

      final docRef =
          _db.collection('trips').doc(tripId).collection('comments').doc();

      final tripComment = TripComment(
        id: docRef.id,
        tripId: tripId,
        userId: user.uid,
        userName: member.displayName,
        comment: comment.trim(),
        createdAt: DateTime.now(),
        dayIndex: dayIndex,
        activityIndex: activityIndex,
      );

      await docRef.set(tripComment.toFirestore());

      // Log activity
      await _logActivity(
        tripId: tripId,
        userId: user.uid,
        userName: member.displayName,
        type: ActivityType.commentAdded,
        description: '${member.displayName} added a comment',
      );

      return docRef.id;
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  /// Update a comment
  Future<void> updateComment({
    required String tripId,
    required String commentId,
    required String newComment,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      if (newComment.trim().isEmpty) {
        throw Exception('Comment cannot be empty');
      }

      if (newComment.length > 1000) {
        throw Exception('Comment is too long (max 1000 characters)');
      }

      final commentDoc = await _db
          .collection('trips')
          .doc(tripId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) throw Exception('Comment not found');

      final comment = TripComment.fromFirestore(commentDoc);

      // Only comment author can update
      if (comment.userId != user.uid) {
        throw Exception('You can only edit your own comments');
      }

      await _db
          .collection('trips')
          .doc(tripId)
          .collection('comments')
          .doc(commentId)
          .update({
        'comment': newComment.trim(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      print('Error updating comment: $e');
      rethrow;
    }
  }

  /// Delete a comment
  Future<void> deleteComment({
    required String tripId,
    required String commentId,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      final commentDoc = await _db
          .collection('trips')
          .doc(tripId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) throw Exception('Comment not found');

      final comment = TripComment.fromFirestore(commentDoc);

      // Get trip to check if user is owner
      final tripDoc = await _db.collection('trips').doc(tripId).get();
      final trip = GroupTrip.fromFirestore(tripDoc);

      // Only comment author or trip owner can delete
      if (comment.userId != user.uid && !trip.isOwner(user.uid)) {
        throw Exception(
            'You can only delete your own comments or if you are the trip owner');
      }

      await _db
          .collection('trips')
          .doc(tripId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

  /// Get comments for a trip
  Stream<List<TripComment>> getTripComments(String tripId, {int limit = 100}) {
    return _db
        .collection('trips')
        .doc(tripId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripComment.fromFirestore(doc))
            .toList());
  }

  /// Get comments for a specific day/activity
  Stream<List<TripComment>> getFilteredComments({
    required String tripId,
    String? dayIndex,
    String? activityIndex,
  }) {
    Query query = _db.collection('trips').doc(tripId).collection('comments');

    if (dayIndex != null) {
      query = query.where('dayIndex', isEqualTo: dayIndex);
    }

    if (activityIndex != null) {
      query = query.where('activityIndex', isEqualTo: activityIndex);
    }

    return query.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => TripComment.fromFirestore(doc))
            .toList());
  }

  // ==================== HELPER METHODS ====================

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Search users by email (for inviting)
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String query) async {
    try {
      if (query.trim().isEmpty || query.length < 3) {
        return [];
      }

      final queryLower = query.toLowerCase();
      final results = await _db
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: queryLower)
          .where('email', isLessThanOrEqualTo: queryLower + '\uf8ff')
          .limit(10)
          .get();

      return results.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'email': data['email'] ?? '',
          'displayName': data['displayName'] ?? 'Unknown',
          'profileImageUrl': data['profileImageUrl'],
        };
      }).toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Get trip statistics
  Future<Map<String, dynamic>> getTripStats(String tripId) async {
    try {
      final tripDoc = await _db.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) throw Exception('Trip not found');

      final trip = GroupTrip.fromFirestore(tripDoc);

      final activitiesCount = await _db
          .collection('trips')
          .doc(tripId)
          .collection('activities')
          .count()
          .get();

      final commentsCount = await _db
          .collection('trips')
          .doc(tripId)
          .collection('comments')
          .count()
          .get();

      return {
        'memberCount': trip.members.length,
        'activitiesCount': activitiesCount.count,
        'commentsCount': commentsCount.count,
        'lastUpdated': trip.updatedAt,
        'createdAt': trip.createdAt,
      };
    } catch (e) {
      print('Error getting trip stats: $e');
      return {};
    }
  }
}
