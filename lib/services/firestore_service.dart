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
      if (docSnapshot.exists && docSnapshot.data()!.containsKey('preferences')) {
        return docSnapshot.data()!['preferences'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error getting user preferences: $e");
      return null;
    }
  }

  /// Saves or updates a user's travel preferences.
  Future<void> setUserPreferences(String uid, Map<String, dynamic> preferences) async {
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
    return _db.collection('trips').orderBy('createdAt', descending: true).snapshots();
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
}
