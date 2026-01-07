import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_functions/cloud_functions.dart'; // Uncomment when Cloud Functions are setup
import '../models/ride_model.dart';
import 'knn_service.dart';

class RideMatchingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // final FirebaseFunctions _functions = FirebaseFunctions.instance; // Uncomment when Cloud Functions are setup
  final KnnService _knnService = KnnService(k: 5);
  final Random _random = Random();

  // --- VEHICLE ENTRY OTP VERIFICATION ---

  /// Generates a 6-digit OTP for vehicle entry
  String _generateVehicleEntryOTP() {
    return (100000 + _random.nextInt(900000)).toString();
  }

  /// Generates and sends vehicle entry OTP to passenger's email
  /// Returns the OTP for display (passenger can also view it in the app)
  ///
  /// EMAIL SENDING SETUP:
  /// 1. For production: Setup Firebase Cloud Functions + SendGrid/Mailgun
  /// 2. See CLOUD_FUNCTION_EMAIL_SETUP.md for complete setup instructions
  /// 3. Uncomment the Cloud Functions code below after setup
  Future<String> generateAndSendVehicleEntryOTP(
      String matchId, String passengerEmail) async {
    final otp = _generateVehicleEntryOTP();

    // Store OTP in Firestore
    await _db.collection('ride_matches').doc(matchId).update({
      'vehicleEntryOTP': otp,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Get match details for email context
    final matchDoc = await _db.collection('ride_matches').doc(matchId).get();
    final matchData = matchDoc.data();

    // ============================================================================
    // EMAIL SENDING - OPTION 1: Cloud Functions (Recommended for Production)
    // ============================================================================
    // Uncomment this section after setting up Firebase Cloud Functions
    // See CLOUD_FUNCTION_EMAIL_SETUP.md for complete instructions

    /*
    try {
      final callable = _functions.httpsCallable('sendOTPEmail');
      final result = await callable.call({
        'passengerEmail': passengerEmail,
        'passengerName': matchData?['passengerName'] ?? 'Passenger',
        'driverName': matchData?['driverName'] ?? 'Driver',
        'otp': otp,
      });

      print('✅ OTP email sent successfully to $passengerEmail');
      print('Cloud Function response: ${result.data}');
    } catch (e) {
      print('⚠️ Error sending OTP email via Cloud Function: $e');
      // Don't throw - OTP is still stored and visible in the passenger's app
      // Email is a secondary notification channel
    }
    */

    // ============================================================================
    // CURRENT BEHAVIOR - Development/Testing
    // ============================================================================
    // OTP is stored in Firestore and displayed in the passenger's app
    // Passenger can view the OTP in Find Rides → Contact Info dialog
    // Email notification will be added when Cloud Functions are configured

    print('📱 Vehicle Entry OTP for $passengerEmail: $otp');
    print(
        'ℹ️  Passenger can view this OTP in their app (Find Rides → Contact Info)');
    print(
        '📧 To enable email sending, setup Cloud Functions (see CLOUD_FUNCTION_EMAIL_SETUP.md)');

    return otp;
  }

  /// Verifies vehicle entry OTP entered by driver
  Future<bool> verifyVehicleEntryOTP(String matchId, String otp) async {
    try {
      final matchDoc = await _db.collection('ride_matches').doc(matchId).get();
      if (!matchDoc.exists) return false;

      final matchData = matchDoc.data()!;
      final storedOTP = matchData['vehicleEntryOTP'] as String?;

      if (storedOTP == null || storedOTP != otp.trim()) {
        return false;
      }

      // Mark vehicle entry as verified
      await _db.collection('ride_matches').doc(matchId).update({
        'vehicleEntryVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error verifying vehicle entry OTP: $e');
      return false;
    }
  }

  /// Gets the vehicle entry OTP for a match (for driver to see what passenger should share)
  Future<String?> getVehicleEntryOTP(String matchId) async {
    try {
      final matchDoc = await _db.collection('ride_matches').doc(matchId).get();
      if (!matchDoc.exists) return null;
      return matchDoc.data()?['vehicleEntryOTP'] as String?;
    } catch (e) {
      return null;
    }
  }

  // --- RIDE OFFERS ---

  /// Helper method to check if a ride offer's pickup date/time has passed
  bool _isRideOfferExpired(RideOffer offer) {
    try {
      // Parse pickup time (format: "HH:mm")
      final timeParts = offer.pickupTime.split(':');
      if (timeParts.length != 2) return true;

      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);
      if (hour == null || minute == null) return true;

      // Combine pickup date and time
      final pickupDateTime = DateTime(
        offer.pickupDate.year,
        offer.pickupDate.month,
        offer.pickupDate.day,
        hour,
        minute,
      );

      // Check if pickup date/time has passed
      return pickupDateTime.isBefore(DateTime.now());
    } catch (e) {
      print('Error checking if ride offer is expired: $e');
      return true; // If error, consider it expired to be safe
    }
  }

  /// Creates a new ride offer
  Future<String> createRideOffer({
    required String destination,
    required String pickupLocation,
    required DateTime pickupDate,
    required String pickupTime,
    required int availableSeats,
    required double costPerSeat,
    required String vehicleNumber,
    required String vehicleModel,
    String? additionalInfo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final docRef = _db.collection('ride_offers').doc();
    final now = DateTime.now();

    final rideOffer = RideOffer(
      id: docRef.id,
      userId: user.uid,
      userName: user.displayName ?? 'Unknown User',
      userEmail: user.email ?? '',
      userPhotoUrl: user.photoURL,
      destination: destination,
      pickupLocation: pickupLocation,
      pickupDate: pickupDate,
      pickupTime: pickupTime,
      availableSeats: availableSeats,
      costPerSeat: costPerSeat,
      vehicleNumber: vehicleNumber,
      vehicleModel: vehicleModel,
      additionalInfo: additionalInfo,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(rideOffer.toFirestore());
    return docRef.id;
  }

  /// Gets all active ride offers (only upcoming rides)
  /// If [includeZeroSeats] is true, includes offers with 0 available seats
  /// If [userId] is provided, also includes inactive rides where user has accepted match
  Stream<List<RideOffer>> getActiveRideOffers({
    bool includeZeroSeats = false,
    String? userId,
  }) async* {
    if (userId == null) {
      // Original behavior - just return active rides
      yield* _db
          .collection('ride_offers')
          .where('status', isEqualTo: 'active')
          .orderBy('pickupDate')
          .snapshots()
          .map((snapshot) => snapshot.docs
                  .map((doc) => RideOffer.fromFirestore(doc))
                  .where((offer) {
                // Filter out expired rides
                if (_isRideOfferExpired(offer)) return false;

                // If includeZeroSeats is true, include all rides
                if (includeZeroSeats) return true;

                // Otherwise, only include rides with available seats
                return offer.availableSeats > 0;
              }).toList());
    } else {
      // New behavior - include user's accepted matches even if inactive
      await for (final activeSnapshot
          in _db.collection('ride_offers').orderBy('pickupDate').snapshots()) {
        // Get all active offers
        final allOffers = activeSnapshot.docs
            .map((doc) => RideOffer.fromFirestore(doc))
            .where((offer) => !_isRideOfferExpired(offer))
            .toList();

        // Get user's accepted matches
        final matchesSnapshot = await _db
            .collection('ride_matches')
            .where('passengerUserId', isEqualTo: userId)
            .where('status', isEqualTo: 'accepted')
            .get();

        final acceptedOfferIds = matchesSnapshot.docs
            .map((doc) => doc.data()['rideOfferId'] as String)
            .toSet();

        // Filter offers: show active with seats OR user's accepted matches
        final filteredOffers = allOffers.where((offer) {
          // If user has accepted match for this offer, always show it
          if (acceptedOfferIds.contains(offer.id)) {
            return true;
          }

          // Otherwise, only show if active and has seats
          return offer.status == 'active' && offer.availableSeats > 0;
        }).toList();

        yield filteredOffers;
      }
    }
  }

  /// Gets ride offers for a specific user
  Stream<List<RideOffer>> getUserRideOffers(String userId) {
    return _db
        .collection('ride_offers')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RideOffer.fromFirestore(doc)).toList());
  }

  /// Updates a ride offer
  Future<void> updateRideOffer(
      String offerId, Map<String, dynamic> updates) async {
    await _db.collection('ride_offers').doc(offerId).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- RIDE REQUESTS ---

  /// Creates a ride request
  Future<String> createRideRequest(String rideOfferId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final docRef = _db.collection('ride_requests').doc();
    final now = DateTime.now();

    final rideRequest = RideRequest(
      id: docRef.id,
      userId: user.uid,
      userName: user.displayName ?? 'Unknown User',
      userEmail: user.email ?? '',
      userPhotoUrl: user.photoURL,
      rideOfferId: rideOfferId,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(rideRequest.toFirestore());
    return docRef.id;
  }

  /// Gets ride requests for a specific user (as driver)
  Stream<List<RideRequest>> getRideRequestsForUser(String userId) async* {
    try {
      final offerIds = await _getUserRideOfferIds(userId);
      if (offerIds.isEmpty) {
        yield [];
        return;
      }

      yield* _db
          .collection('ride_requests')
          .where('rideOfferId', whereIn: offerIds)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => RideRequest.fromFirestore(doc))
              .toList());
    } catch (e) {
      yield [];
    }
  }

  /// Gets user's own ride requests (as passenger)
  Stream<List<RideRequest>> getUserRideRequests(String userId) {
    return _db
        .collection('ride_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideRequest.fromFirestore(doc))
            .toList());
  }

  /// Helper method to get user's ride offer IDs
  Future<List<String>> _getUserRideOfferIds(String userId) async {
    final snapshot = await _db
        .collection('ride_offers')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // --- RIDE MATCHES ---

  /// Creates a ride match
  Future<String> createRideMatch({
    required String rideOfferId,
    required String rideRequestId,
    required String driverUserId,
    required String driverName,
    required String driverEmail,
    required String passengerUserId,
    required String passengerName,
    required String passengerEmail,
  }) async {
    final docRef = _db.collection('ride_matches').doc();
    final now = DateTime.now();

    final rideMatch = RideMatch(
      id: docRef.id,
      rideOfferId: rideOfferId,
      rideRequestId: rideRequestId,
      driverUserId: driverUserId,
      driverName: driverName,
      driverEmail: driverEmail,
      passengerUserId: passengerUserId,
      passengerName: passengerName,
      passengerEmail: passengerEmail,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(rideMatch.toFirestore());
    return docRef.id;
  }

  /// Gets ride matches for a specific user (only upcoming rides)
  Stream<List<RideMatch>> getUserRideMatches(String userId) async* {
    yield* _db
        .collection('ride_matches')
        .where('driverUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final matches =
          snapshot.docs.map((doc) => RideMatch.fromFirestore(doc)).toList();

      // Filter out matches where the associated ride offer has expired
      final validMatches = <RideMatch>[];
      for (final match in matches) {
        try {
          final offerDoc =
              await _db.collection('ride_offers').doc(match.rideOfferId).get();
          if (offerDoc.exists) {
            final offer = RideOffer.fromFirestore(offerDoc);
            // Only include matches where the ride offer hasn't expired
            // OR matches that are already completed (keep completed matches for history)
            if (!_isRideOfferExpired(offer) || match.status == 'completed') {
              validMatches.add(match);
            }
          } else {
            // If ride offer doesn't exist, keep the match (might be deleted offer)
            validMatches.add(match);
          }
        } catch (e) {
          print('Error checking ride offer for match ${match.id}: $e');
          // On error, keep the match to be safe
          validMatches.add(match);
        }
      }

      return validMatches;
    });
  }

  /// Gets passenger ride matches (only upcoming rides)
  Stream<List<RideMatch>> getPassengerRideMatches(String userId) async* {
    yield* _db
        .collection('ride_matches')
        .where('passengerUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final matches =
          snapshot.docs.map((doc) => RideMatch.fromFirestore(doc)).toList();

      // Filter out matches where the associated ride offer has expired
      final validMatches = <RideMatch>[];
      for (final match in matches) {
        try {
          final offerDoc =
              await _db.collection('ride_offers').doc(match.rideOfferId).get();
          if (offerDoc.exists) {
            final offer = RideOffer.fromFirestore(offerDoc);
            // Only include matches where the ride offer hasn't expired
            // OR matches that are already completed (keep completed matches for history)
            if (!_isRideOfferExpired(offer) || match.status == 'completed') {
              validMatches.add(match);
            }
          } else {
            // If ride offer doesn't exist, keep the match (might be deleted offer)
            validMatches.add(match);
          }
        } catch (e) {
          print('Error checking ride offer for match ${match.id}: $e');
          // On error, keep the match to be safe
          validMatches.add(match);
        }
      }

      return validMatches;
    });
  }

  /// Updates a ride match status
  Future<void> updateRideMatchStatus(String matchId, String status) async {
    await _db.collection('ride_matches').doc(matchId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accepts a ride match with driver contact info
  Future<void> acceptRideMatch(
    String matchId, {
    required String driverContact,
    required String driverPickupLocation,
    required String driverPickupTime,
  }) async {
    // Get the match details first
    final matchDoc = await _db.collection('ride_matches').doc(matchId).get();
    if (!matchDoc.exists) return;

    final matchData = matchDoc.data()!;
    final rideOfferId = matchData['rideOfferId'] as String;

    // Update the match status
    await _db.collection('ride_matches').doc(matchId).update({
      'status': 'accepted',
      'driverContact': driverContact,
      'driverPickupLocation': driverPickupLocation,
      'driverPickupTime': driverPickupTime,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update available seats (assuming 1 seat is requested)
    await updateAvailableSeats(rideOfferId, 1);
  }

  /// Rejects a ride match
  Future<void> rejectRideMatch(String matchId) async {
    // Get the match details first to restore seats
    final matchDoc = await _db.collection('ride_matches').doc(matchId).get();
    if (matchDoc.exists) {
      final matchData = matchDoc.data()!;
      final rideOfferId = matchData['rideOfferId'] as String;

      // Restore 1 seat (assuming 1 seat was requested)
      await restoreAvailableSeats(rideOfferId, 1);
    }

    await updateRideMatchStatus(matchId, 'rejected');
  }

  /// Completes a ride match
  Future<void> completeRideMatch(String matchId) async {
    await updateRideMatchStatus(matchId, 'completed');
  }

  /// Updates passenger contact info
  Future<void> updatePassengerContact(
    String matchId, {
    required String passengerName,
    required String passengerContact,
  }) async {
    await _db.collection('ride_matches').doc(matchId).update({
      'passengerName': passengerName,
      'passengerContact': passengerContact,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates available seats when a request is accepted
  Future<void> updateAvailableSeats(
      String rideOfferId, int seatsRequested) async {
    try {
      final offerDoc =
          await _db.collection('ride_offers').doc(rideOfferId).get();
      if (offerDoc.exists) {
        final currentSeats = offerDoc.data()!['availableSeats'] as int;
        final newSeats = currentSeats - seatsRequested;

        if (newSeats >= 0) {
          await _db.collection('ride_offers').doc(rideOfferId).update({
            'availableSeats': newSeats,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // If no seats left, mark the offer as inactive
          if (newSeats == 0) {
            await _db.collection('ride_offers').doc(rideOfferId).update({
              'status': 'inactive',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          print(
              'Warning: Not enough seats available. Requested: $seatsRequested, Available: $currentSeats');
        }
      }
    } catch (e) {
      print('Error updating available seats: $e');
      rethrow; // Re-throw to handle in calling method
    }
  }

  /// Restores available seats when a request is rejected or cancelled
  Future<void> restoreAvailableSeats(
      String rideOfferId, int seatsToRestore) async {
    try {
      final offerDoc =
          await _db.collection('ride_offers').doc(rideOfferId).get();
      if (offerDoc.exists) {
        final currentSeats = offerDoc.data()!['availableSeats'] as int;
        final newSeats = currentSeats + seatsToRestore;

        await _db.collection('ride_offers').doc(rideOfferId).update({
          'availableSeats': newSeats,
          'status': 'active', // Reactivate the offer if it was inactive
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error restoring available seats: $e');
      rethrow;
    }
  }

  // --- KNN-BASED RECOMMENDATIONS ---

  /// Finds similar rides using KNN algorithm
  ///
  /// [queryRide] The ride to find similar rides for
  /// [allRides] List of all available rides to search from
  ///
  /// Returns a list of similar rides sorted by similarity score (highest first)
  List<RideSimilarityResult> findSimilarRides(
    RideOffer queryRide,
    List<RideOffer> allRides,
  ) {
    return _knnService.findSimilarRides(queryRide, allRides);
  }

  /// Gets recommended rides for a user using KNN
  ///
  /// Fetches all active rides and returns the most similar ones to rides
  /// the user has previously shown interest in
  Future<List<RideOffer>> getRecommendedRides(String userId) async {
    try {
      print('[KNN] getRecommendedRides for user: ' + userId);
      // Get ride offers (include docs without explicit status)
      // We filter in-memory to keep 'active' and missing-status offers
      final offersSnapshot = await _db.collection('ride_offers').get();

      final allRides = offersSnapshot.docs
          .map((doc) => RideOffer.fromFirestore(doc))
          .where((offer) => offer.status != 'inactive')
          .toList();
      print('[KNN] total eligible ride_offers: ' + allRides.length.toString());

      if (allRides.isEmpty) return [];

      // Get user's previous ride requests to understand their preferences
      final userRequestsSnapshot = await _db
          .collection('ride_requests')
          .where('userId', isEqualTo: userId)
          .limit(5)
          .get();
      print('[KNN] user ride_requests count: ' +
          userRequestsSnapshot.docs.length.toString());

      if (userRequestsSnapshot.docs.isEmpty) {
        // If user has no previous requests, return all rides
        return allRides.take(10).toList();
      }

      // Get the ride offers the user previously requested
      final List<RideOffer> userRides = [];
      for (final requestDoc in userRequestsSnapshot.docs) {
        final rideOfferId = requestDoc.data()['rideOfferId'] as String;
        try {
          final offerDoc =
              await _db.collection('ride_offers').doc(rideOfferId).get();
          if (offerDoc.exists) {
            userRides.add(RideOffer.fromFirestore(offerDoc));
          }
        } catch (e) {
          print('Error fetching ride offer: $e');
        }
      }
      print('[KNN] user referenced rides fetched: ' +
          userRides.length.toString());

      if (userRides.isEmpty) {
        return allRides.take(10).toList();
      }

      // Use the most recent user ride as the query
      final queryRide = userRides.first;
      print('[KNN] queryRide id: ' + queryRide.id);

      // Find similar rides using KNN
      final similarRides = _knnService.findSimilarRides(queryRide, allRides);
      print('[KNN] similarRides found: ' + similarRides.length.toString());

      // Return the ride offers from similarity results
      final results = similarRides.map((result) => result.ride).toList();

      // Fallback: if no neighbors (e.g., only 1 ride available which equals query),
      // return a few other rides so the section isn't empty.
      if (results.isEmpty) {
        final fallback =
            allRides.where((r) => r.id != queryRide.id).take(5).toList();
        print('[KNN] using fallback recommendations count: ' +
            fallback.length.toString());
        return fallback;
      }

      return results;
    } catch (e) {
      print('Error getting recommended rides: $e');
      return [];
    }
  }

  /// Updates KNN feature weights for personalized recommendations
  void updateKnnWeights(Map<String, double> weights) {
    weights.forEach((feature, weight) {
      _knnService.updateFeatureWeight(feature, weight);
    });
    _knnService.normalizeWeights();
  }

  /// Gets similarity breakdown between two rides
  Map<String, double> getSimilarityBreakdown(RideOffer ride1, RideOffer ride2) {
    return _knnService.getSimilarityBreakdown(ride1, ride2);
  }
}
