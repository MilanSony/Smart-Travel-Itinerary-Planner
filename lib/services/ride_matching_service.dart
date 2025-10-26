import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';

class RideMatchingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- RIDE OFFERS ---

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

  /// Gets all active ride offers
  Stream<List<RideOffer>> getActiveRideOffers() {
    return _db
        .collection('ride_offers')
        .where('status', isEqualTo: 'active')
        .orderBy('pickupDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideOffer.fromFirestore(doc))
            .toList());
  }

  /// Gets ride offers for a specific user
  Stream<List<RideOffer>> getUserRideOffers(String userId) {
    return _db
        .collection('ride_offers')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideOffer.fromFirestore(doc))
            .toList());
  }

  /// Updates a ride offer
  Future<void> updateRideOffer(String offerId, Map<String, dynamic> updates) async {
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

  /// Gets ride matches for a specific user
  Stream<List<RideMatch>> getUserRideMatches(String userId) {
    return _db
        .collection('ride_matches')
        .where('driverUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideMatch.fromFirestore(doc))
            .toList());
  }

  /// Gets passenger ride matches
  Stream<List<RideMatch>> getPassengerRideMatches(String userId) {
    return _db
        .collection('ride_matches')
        .where('passengerUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideMatch.fromFirestore(doc))
            .toList());
  }

  /// Updates a ride match status
  Future<void> updateRideMatchStatus(String matchId, String status) async {
    await _db.collection('ride_matches').doc(matchId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accepts a ride match with driver contact info
  Future<void> acceptRideMatch(String matchId, {
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
  Future<void> updatePassengerContact(String matchId, {
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
  Future<void> updateAvailableSeats(String rideOfferId, int seatsRequested) async {
    try {
      final offerDoc = await _db.collection('ride_offers').doc(rideOfferId).get();
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
          print('Warning: Not enough seats available. Requested: $seatsRequested, Available: $currentSeats');
        }
      }
    } catch (e) {
      print('Error updating available seats: $e');
      rethrow; // Re-throw to handle in calling method
    }
  }

  /// Restores available seats when a request is rejected or cancelled
  Future<void> restoreAvailableSeats(String rideOfferId, int seatsToRestore) async {
    try {
      final offerDoc = await _db.collection('ride_offers').doc(rideOfferId).get();
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
}
