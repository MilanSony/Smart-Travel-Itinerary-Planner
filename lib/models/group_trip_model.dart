import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for user roles in a group trip
enum TripRole {
  owner,
  editor,
  viewer,
}

extension TripRoleExtension on TripRole {
  String get displayName {
    switch (this) {
      case TripRole.owner:
        return 'Owner';
      case TripRole.editor:
        return 'Editor';
      case TripRole.viewer:
        return 'Viewer';
    }
  }

  String get description {
    switch (this) {
      case TripRole.owner:
        return 'Can edit, share, and delete the trip';
      case TripRole.editor:
        return 'Can view and edit the itinerary';
      case TripRole.viewer:
        return 'Can only view the itinerary';
    }
  }

  static TripRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return TripRole.owner;
      case 'editor':
        return TripRole.editor;
      case 'viewer':
        return TripRole.viewer;
      default:
        return TripRole.viewer;
    }
  }

  String toFirestore() {
    return toString().split('.').last;
  }
}

/// Represents a member in a group trip
class TripMember {
  final String userId;
  final String email;
  final String displayName;
  final TripRole role;
  final DateTime joinedAt;
  final String? profileImageUrl;

  TripMember({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.profileImageUrl,
  });

  factory TripMember.fromFirestore(Map<String, dynamic> data) {
    return TripMember(
      userId: data['userId'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'Unknown User',
      role: TripRoleExtension.fromString(data['role'] ?? 'viewer'),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImageUrl: data['profileImageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'role': role.toFirestore(),
      'joinedAt': Timestamp.fromDate(joinedAt),
      'profileImageUrl': profileImageUrl,
    };
  }

  TripMember copyWith({
    String? userId,
    String? email,
    String? displayName,
    TripRole? role,
    DateTime? joinedAt,
    String? profileImageUrl,
  }) {
    return TripMember(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

/// Enum for invitation status
enum InvitationStatus {
  pending,
  accepted,
  rejected,
  cancelled,
}

extension InvitationStatusExtension on InvitationStatus {
  String get displayName {
    switch (this) {
      case InvitationStatus.pending:
        return 'Pending';
      case InvitationStatus.accepted:
        return 'Accepted';
      case InvitationStatus.rejected:
        return 'Rejected';
      case InvitationStatus.cancelled:
        return 'Cancelled';
    }
  }

  static InvitationStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return InvitationStatus.pending;
      case 'accepted':
        return InvitationStatus.accepted;
      case 'rejected':
        return InvitationStatus.rejected;
      case 'cancelled':
        return InvitationStatus.cancelled;
      default:
        return InvitationStatus.pending;
    }
  }

  String toFirestore() {
    return toString().split('.').last;
  }
}

/// Represents an invitation to join a trip
class TripInvitation {
  final String id;
  final String tripId;
  final String tripTitle;
  final String tripDestination;
  final String invitedByUserId;
  final String invitedByName;
  final String invitedByEmail;
  final String invitedUserEmail;
  final String? invitedUserId;
  final TripRole role;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? message;

  TripInvitation({
    required this.id,
    required this.tripId,
    required this.tripTitle,
    required this.tripDestination,
    required this.invitedByUserId,
    required this.invitedByName,
    required this.invitedByEmail,
    required this.invitedUserEmail,
    this.invitedUserId,
    required this.role,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.message,
  });

  factory TripInvitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripInvitation(
      id: doc.id,
      tripId: data['tripId'] ?? '',
      tripTitle: data['tripTitle'] ?? '',
      tripDestination: data['tripDestination'] ?? '',
      invitedByUserId: data['invitedByUserId'] ?? '',
      invitedByName: data['invitedByName'] ?? '',
      invitedByEmail: data['invitedByEmail'] ?? '',
      invitedUserEmail: data['invitedUserEmail'] ?? '',
      invitedUserId: data['invitedUserId'],
      role: TripRoleExtension.fromString(data['role'] ?? 'viewer'),
      status: InvitationStatusExtension.fromString(data['status'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      message: data['message'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tripId': tripId,
      'tripTitle': tripTitle,
      'tripDestination': tripDestination,
      'invitedByUserId': invitedByUserId,
      'invitedByName': invitedByName,
      'invitedByEmail': invitedByEmail,
      'invitedUserEmail': invitedUserEmail,
      'invitedUserId': invitedUserId,
      'role': role.toFirestore(),
      'status': status.toFirestore(),
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'message': message,
    };
  }

  TripInvitation copyWith({
    String? id,
    String? tripId,
    String? tripTitle,
    String? tripDestination,
    String? invitedByUserId,
    String? invitedByName,
    String? invitedByEmail,
    String? invitedUserEmail,
    String? invitedUserId,
    TripRole? role,
    InvitationStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? message,
  }) {
    return TripInvitation(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      tripTitle: tripTitle ?? this.tripTitle,
      tripDestination: tripDestination ?? this.tripDestination,
      invitedByUserId: invitedByUserId ?? this.invitedByUserId,
      invitedByName: invitedByName ?? this.invitedByName,
      invitedByEmail: invitedByEmail ?? this.invitedByEmail,
      invitedUserEmail: invitedUserEmail ?? this.invitedUserEmail,
      invitedUserId: invitedUserId ?? this.invitedUserId,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      message: message ?? this.message,
    );
  }
}

/// Enum for activity types in the trip
enum ActivityType {
  created,
  edited,
  memberAdded,
  memberRemoved,
  roleChanged,
  commentAdded,
  shared,
  deleted,
}

extension ActivityTypeExtension on ActivityType {
  String get displayName {
    switch (this) {
      case ActivityType.created:
        return 'Created';
      case ActivityType.edited:
        return 'Edited';
      case ActivityType.memberAdded:
        return 'Member Added';
      case ActivityType.memberRemoved:
        return 'Member Removed';
      case ActivityType.roleChanged:
        return 'Role Changed';
      case ActivityType.commentAdded:
        return 'Comment Added';
      case ActivityType.shared:
        return 'Shared';
      case ActivityType.deleted:
        return 'Deleted';
    }
  }

  static ActivityType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'created':
        return ActivityType.created;
      case 'edited':
        return ActivityType.edited;
      case 'memberadded':
        return ActivityType.memberAdded;
      case 'memberremoved':
        return ActivityType.memberRemoved;
      case 'rolechanged':
        return ActivityType.roleChanged;
      case 'commentadded':
        return ActivityType.commentAdded;
      case 'shared':
        return ActivityType.shared;
      case 'deleted':
        return ActivityType.deleted;
      default:
        return ActivityType.edited;
    }
  }

  String toFirestore() {
    return toString().split('.').last;
  }
}

/// Represents an activity log entry for a trip
class TripActivity {
  final String id;
  final String tripId;
  final String userId;
  final String userName;
  final ActivityType type;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  TripActivity({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.userName,
    required this.type,
    required this.description,
    required this.timestamp,
    this.metadata,
  });

  factory TripActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripActivity(
      id: doc.id,
      tripId: data['tripId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      type: ActivityTypeExtension.fromString(data['type'] ?? 'edited'),
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tripId': tripId,
      'userId': userId,
      'userName': userName,
      'type': type.toFirestore(),
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}

/// Represents a comment on a trip
class TripComment {
  final String id;
  final String tripId;
  final String userId;
  final String userName;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? dayIndex;
  final String? activityIndex;

  TripComment({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
    this.dayIndex,
    this.activityIndex,
  });

  factory TripComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripComment(
      id: doc.id,
      tripId: data['tripId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      dayIndex: data['dayIndex'],
      activityIndex: data['activityIndex'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tripId': tripId,
      'userId': userId,
      'userName': userName,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'dayIndex': dayIndex,
      'activityIndex': activityIndex,
    };
  }

  TripComment copyWith({
    String? id,
    String? tripId,
    String? userId,
    String? userName,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? dayIndex,
    String? activityIndex,
  }) {
    return TripComment(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dayIndex: dayIndex ?? this.dayIndex,
      activityIndex: activityIndex ?? this.activityIndex,
    );
  }
}

/// Represents a group trip with collaboration features
class GroupTrip {
  final String id;
  final String ownerId;
  final String title;
  final String destination;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? durationInDays;
  final List<TripMember> members;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;
  final Map<String, dynamic>? itinerarySummary;
  final String? itineraryStatus;

  // New detailed fields
  final String? contactNumber;
  final String? meetingPoint;
  final String? transportationType;
  final String? timeToReach;
  final String? specialInstructions;

  GroupTrip({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.destination,
    this.description,
    this.startDate,
    this.endDate,
    this.durationInDays,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = false,
    this.itinerarySummary,
    this.itineraryStatus,
    this.contactNumber,
    this.meetingPoint,
    this.transportationType,
    this.timeToReach,
    this.specialInstructions,
  });

  factory GroupTrip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final membersData = data['members'] as List<dynamic>? ?? [];

    return GroupTrip(
      id: doc.id,
      ownerId: data['ownerId'] ?? data['userId'] ?? '',
      title: data['title'] ?? '',
      destination: data['destination'] ?? '',
      description: data['description'],
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      durationInDays: data['durationInDays'],
      members: membersData
          .map((m) => TripMember.fromFirestore(m as Map<String, dynamic>))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPublic: data['isPublic'] ?? false,
      itinerarySummary: data['summary'] as Map<String, dynamic>?,
      itineraryStatus: data['itineraryStatus'],
      contactNumber: data['contactNumber'],
      meetingPoint: data['meetingPoint'],
      transportationType: data['transportationType'],
      timeToReach: data['timeToReach'],
      specialInstructions: data['specialInstructions'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'userId': ownerId, // For backward compatibility
      'title': title,
      'destination': destination,
      'description': description,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'durationInDays': durationInDays,
      'members': members.map((m) => m.toFirestore()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isPublic': isPublic,
      'summary': itinerarySummary,
      'itineraryStatus': itineraryStatus,
      'contactNumber': contactNumber,
      'meetingPoint': meetingPoint,
      'transportationType': transportationType,
      'timeToReach': timeToReach,
      'specialInstructions': specialInstructions,
    };
  }

  /// Get member by user ID
  TripMember? getMember(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (e) {
      return null;
    }
  }

  /// Check if user has permission to edit
  bool canEdit(String userId) {
    final member = getMember(userId);
    if (member == null) return false;
    return member.role == TripRole.owner || member.role == TripRole.editor;
  }

  /// Check if user is the owner
  bool isOwner(String userId) {
    return ownerId == userId;
  }

  /// Check if user is a member
  bool isMember(String userId) {
    return getMember(userId) != null;
  }

  GroupTrip copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? destination,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? durationInDays,
    List<TripMember>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    Map<String, dynamic>? itinerarySummary,
    String? itineraryStatus,
  }) {
    return GroupTrip(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      destination: destination ?? this.destination,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationInDays: durationInDays ?? this.durationInDays,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      itinerarySummary: itinerarySummary ?? this.itinerarySummary,
      itineraryStatus: itineraryStatus ?? this.itineraryStatus,
    );
  }
}
