import 'package:cloud_firestore/cloud_firestore.dart';

class RideOffer {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? userPhotoUrl;
  final String destination;
  final String pickupLocation;
  final DateTime pickupDate;
  final String pickupTime;
  final int availableSeats;
  final double costPerSeat;
  final String vehicleNumber;
  final String vehicleModel;
  final String? additionalInfo;
  final String status; // 'active', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  RideOffer({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userPhotoUrl,
    required this.destination,
    required this.pickupLocation,
    required this.pickupDate,
    required this.pickupTime,
    required this.availableSeats,
    required this.costPerSeat,
    required this.vehicleNumber,
    required this.vehicleModel,
    this.additionalInfo,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory RideOffer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RideOffer(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      destination: data['destination'] ?? '',
      pickupLocation: data['pickupLocation'] ?? '',
      pickupDate: (data['pickupDate'] as Timestamp).toDate(),
      pickupTime: data['pickupTime'] ?? '',
      availableSeats: data['availableSeats'] ?? 1,
      costPerSeat: data['costPerSeat']?.toDouble() ?? 0.0,
      vehicleNumber: data['vehicleNumber'] ?? '',
      vehicleModel: data['vehicleModel'] ?? '',
      additionalInfo: data['additionalInfo'],
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhotoUrl': userPhotoUrl,
      'destination': destination,
      'pickupLocation': pickupLocation,
      'pickupDate': Timestamp.fromDate(pickupDate),
      'pickupTime': pickupTime,
      'availableSeats': availableSeats,
      'costPerSeat': costPerSeat,
      'vehicleNumber': vehicleNumber,
      'vehicleModel': vehicleModel,
      'additionalInfo': additionalInfo,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class RideRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? userPhotoUrl;
  final String rideOfferId;
  final String status; // 'pending', 'accepted', 'rejected', 'completed'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? passengerContact;
  final String? passengerName;

  RideRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userPhotoUrl,
    required this.rideOfferId,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.passengerContact,
    this.passengerName,
  });

  factory RideRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RideRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      rideOfferId: data['rideOfferId'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      passengerContact: data['passengerContact'],
      passengerName: data['passengerName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhotoUrl': userPhotoUrl,
      'rideOfferId': rideOfferId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'passengerContact': passengerContact,
      'passengerName': passengerName,
    };
  }
}

class RideMatch {
  final String id;
  final String rideOfferId;
  final String rideRequestId;
  final String driverUserId;
  final String driverName;
  final String driverEmail;
  final String? driverContact;
  final String passengerUserId;
  final String passengerName;
  final String passengerEmail;
  final String? passengerContact;
  final String status; // 'pending', 'accepted', 'rejected', 'completed'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? driverPickupLocation;
  final String? driverPickupTime;

  RideMatch({
    required this.id,
    required this.rideOfferId,
    required this.rideRequestId,
    required this.driverUserId,
    required this.driverName,
    required this.driverEmail,
    this.driverContact,
    required this.passengerUserId,
    required this.passengerName,
    required this.passengerEmail,
    this.passengerContact,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.driverPickupLocation,
    this.driverPickupTime,
  });

  factory RideMatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RideMatch(
      id: doc.id,
      rideOfferId: data['rideOfferId'] ?? '',
      rideRequestId: data['rideRequestId'] ?? '',
      driverUserId: data['driverUserId'] ?? '',
      driverName: data['driverName'] ?? '',
      driverEmail: data['driverEmail'] ?? '',
      driverContact: data['driverContact'],
      passengerUserId: data['passengerUserId'] ?? '',
      passengerName: data['passengerName'] ?? '',
      passengerEmail: data['passengerEmail'] ?? '',
      passengerContact: data['passengerContact'],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      driverPickupLocation: data['driverPickupLocation'],
      driverPickupTime: data['driverPickupTime'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'rideOfferId': rideOfferId,
      'rideRequestId': rideRequestId,
      'driverUserId': driverUserId,
      'driverName': driverName,
      'driverEmail': driverEmail,
      'driverContact': driverContact,
      'passengerUserId': passengerUserId,
      'passengerName': passengerName,
      'passengerEmail': passengerEmail,
      'passengerContact': passengerContact,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'driverPickupLocation': driverPickupLocation,
      'driverPickupTime': driverPickupTime,
    };
  }
}

