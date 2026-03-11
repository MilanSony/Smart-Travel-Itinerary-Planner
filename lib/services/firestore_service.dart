import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USER-SPECIFIC FUNCTIONS ---

  /// Updates the user's profile display name in the 'users' collection.
  Future<void> updateUserProfile(String uid, String newDisplayName) async {
    try {
      await _db.collection('users').doc(uid).update({
        'displayName': newDisplayName,
      });
    } catch (e) {
      print("Error updating user profile in Firestore: $e");
      rethrow;
    }
  }

  /// Gets a user's saved travel preferences from their document.
  Future<Map<String, dynamic>?> getUserPreferences(String uid) async {
    try {
      final docSnapshot = await _db.collection('users').doc(uid).get();
      // This checks for a 'preferences' map inside the user document.
      if (docSnapshot.exists &&
          docSnapshot.data()!.containsKey('preferences')) {
        return docSnapshot.data()!['preferences'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error getting user preferences: $e");
      return null;
    }
  }

  /// Saves or updates a user's travel preferences.
  Future<void> setUserPreferences(
      String uid, Map<String, dynamic> preferences) async {
    try {
      // We use 'set' with 'merge: true' to create the field if it doesn't exist,
      // or update it without overwriting other user data.
      await _db.collection('users').doc(uid).set({
        'preferences': preferences,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error setting user preferences: $e");
      rethrow;
    }
  }

  /// Gets a real-time stream of trips created by a specific user.
  Stream<QuerySnapshot> getTripsForUser(String uid) {
    return _db.collection('trips').where('userId', isEqualTo: uid).snapshots();
  }

  /// Creates a new trip document for a user and stores summary details.
  Future<String> createTrip({
    required String userId,
    required String destination,
    required String title,
    required Map<String, dynamic> itinerarySummary,
    int? durationInDays,
    List<String>? interests,
    String? budget,
  }) async {
    final docRef = _db.collection('trips').doc();
    await docRef.set({
      'id': docRef.id,
      'userId': userId,
      'destination': destination,
      'title': title,
      'durationInDays': durationInDays,
      'interests': interests ?? [],
      'budget': budget,
      'summary': itinerarySummary,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // --- ADMIN-SPECIFIC FUNCTIONS ---

  /// Gets a real-time stream of ALL trips from all users for the admin dashboard.
  Stream<QuerySnapshot> getAllTrips() {
    return _db
        .collection('trips')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Allows an admin to delete a specific trip document.
  Future<void> deleteTrip(String tripId) async {
    try {
      await _db.collection('trips').doc(tripId).delete();
      // Note: A more robust implementation would also delete the itinerary sub-collection.
    } catch (e) {
      print("Error deleting trip: $e");
      rethrow;
    }
  }

  // --- PACKING LIST (SPLG) FUNCTIONS ---

  /// Saves a user's final packing list as a transaction document that can be
  /// used later by an Apriori mining job.
  Future<void> savePackingTransaction({
    required String userId,
    required String tripId,
    required String destination,
    required DateTime? startDate,
    required DateTime? endDate,
    required int durationDays,
    required String? tripType,
    required List<String> contextTags,
    required List<String> items,
    int? numAdults,
    int? numChildren,
    List<String>? childrenAgeGroups,
  }) async {
    try {
      // Upsert: keep a single document per (userId, destination)
      final existing = await _db
          .collection('packing_transactions')
          .where('userId', isEqualTo: userId)
          .where('destination', isEqualTo: destination)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await _db.collection('packing_transactions').add({
          'userId': userId,
          'tripId': tripId,
          'destination': destination,
          'startDate': startDate,
          'endDate': endDate,
          'durationDays': durationDays,
          'tripType': tripType,
          'contextTags': contextTags,
          'items': items,
          'numAdults': numAdults,
          'numChildren': numChildren,
          'childrenAgeGroups': childrenAgeGroups,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await existing.docs.first.reference.update({
          'tripId': tripId,
          'startDate': startDate,
          'endDate': endDate,
          'durationDays': durationDays,
          'tripType': tripType,
          'contextTags': contextTags,
          'items': items,
          'numAdults': numAdults,
          'numChildren': numChildren,
          'childrenAgeGroups': childrenAgeGroups,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving packing transaction: $e');
      rethrow;
    }
  }

  /// Fetches mined ARM rules stored in Firestore. These rules are expected
  /// to be generated offline using Apriori and stored in the 'packing_rules'
  /// collection with support & confidence values.
  Future<List<Map<String, dynamic>>> getPackingRules() async {
    try {
      final snapshot = await _db.collection('packing_rules').get();
      return snapshot.docs.map((d) => d.data()).toList();
    } catch (e) {
      print('Error fetching packing rules: $e');
      return [];
    }
  }

  /// Stream of saved packing transactions for a given user and destination.
  /// Used to show previously saved packing lists per destination.
  Stream<QuerySnapshot> getPackingTransactionsForUserDestination(
    String userId,
    String destination,
  ) {
    return _db
        .collection('packing_transactions')
        .where('userId', isEqualTo: userId)
        .where('destination', isEqualTo: destination)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Update only the items array for an existing packing transaction.
  Future<void> updatePackingTransactionItems(
    String docId,
    List<String> items,
  ) async {
    try {
      await _db.collection('packing_transactions').doc(docId).update({
        'items': items,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating packing transaction items: $e');
      rethrow;
    }
  }

  /// Returns the (single) evolving packing transaction for a given
  /// (userId, destination), if it exists.
  ///
  /// Note: We intentionally do not orderBy to avoid requiring a composite index.
  Future<DocumentSnapshot<Map<String, dynamic>>?> getPackingTransactionForUserDestination(
    String userId,
    String destination,
  ) async {
    try {
      final snapshot = await _db
          .collection('packing_transactions')
          .where('userId', isEqualTo: userId)
          .where('destination', isEqualTo: destination)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first;
    } catch (e) {
      print('Error fetching packing transaction: $e');
      return null;
    }
  }
}
