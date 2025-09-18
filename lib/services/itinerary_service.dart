
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ItineraryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<String> createTrip(Map<String, dynamic> tripData) async {
    final tripRef = await _db.collection('trips').add(tripData);
    return tripRef.id;
  }

  Future<void> generateItinerary({
    required String tripId,
    required List<String> interests,
    required String destination,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateItinerary');
      await callable.call(<String, dynamic>{
        'tripId': tripId,
        'destination': destination,
        'interests': interests,
      });
    } catch (e) {
      rethrow;
    }
  }

  Stream<DocumentSnapshot> getItineraryStream(String tripId, String day) {
    return _db.collection('trips').doc(tripId).collection('itinerary').doc(day).snapshots();
  }
}