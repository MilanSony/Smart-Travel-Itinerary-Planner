# Group Trip Planning & Collaboration Module

## Overview

The Group Trip Planning & Collaboration module enables users to create, share, and collaboratively plan trips with friends and family. This feature-rich module includes real-time collaboration, role-based permissions, activity tracking, commenting system, and invitation management.

## Features

### 1. **Trip Management**
- Create group trips with detailed information
- Edit trip details (title, destination, description, dates, duration)
- Delete trips (owner only)
- Public/Private trip visibility settings
- Real-time synchronization across all members

### 2. **Collaboration & Sharing**
- Invite members via email
- Role-based access control (Owner, Editor, Viewer)
- Real-time updates for all members
- Activity tracking for all changes
- Member management (add/remove members, change roles)

### 3. **Communication**
- Trip-specific commenting system
- Real-time comment updates
- Edit and delete comments
- Comment notifications

### 4. **Invitation System**
- Send invitations with custom messages
- Accept/Reject invitations
- View pending invitations
- Cancel sent invitations
- Invitation notifications with badges

### 5. **Activity Log**
- Track all trip activities
- View who made what changes
- Timestamped activity history
- Activity types: Created, Edited, Member Added/Removed, Role Changed, Comments, etc.

## Architecture

### Models

#### `GroupTrip`
- Core trip information
- Member list with roles
- Timestamps and metadata
- Permission checking methods

#### `TripMember`
- User information
- Role assignment
- Join date
- Profile data

#### `TripInvitation`
- Invitation details
- Status tracking (Pending, Accepted, Rejected, Cancelled)
- Inviter and invitee information
- Custom message support

#### `TripActivity`
- Activity logging
- User attribution
- Activity types
- Timestamps and metadata

#### `TripComment`
- Comment content
- Author information
- Edit tracking
- Optional day/activity linking

### Services

#### `GroupTripService`
Comprehensive service handling all group trip operations:
- CRUD operations for trips
- Invitation management
- Member management
- Activity logging
- Comment operations
- Search and statistics

### Screens

1. **GroupTripsScreen** - Main screen with tabs for owned and shared trips
2. **CreateGroupTripScreen** - Create new group trips
3. **GroupTripDetailScreen** - View trip details with tabs (Overview, Members, Activity, Comments)
4. **EditGroupTripScreen** - Edit trip information
5. **InviteMemberScreen** - Invite new members with role selection
6. **TripInvitationsScreen** - View and manage pending invitations

## User Roles & Permissions

### Owner
- Full control over the trip
- Can edit all trip details
- Can invite/remove members
- Can change member roles
- Can delete the trip
- Cannot be removed from trip
- Only one owner per trip

### Editor
- Can view trip details
- Can edit trip information
- Can invite new members
- Can add comments
- Cannot remove members
- Cannot change roles
- Cannot delete trip

### Viewer
- Can view trip details
- Can view members
- Can add comments
- Cannot edit trip
- Cannot invite members
- Cannot manage members

## Data Structure

### Firestore Collections

```
trips/
  {tripId}/
    - id: string
    - ownerId: string
    - userId: string (for backward compatibility)
    - title: string
    - destination: string
    - description: string?
    - startDate: Timestamp?
    - endDate: Timestamp?
    - durationInDays: number?
    - members: Array<TripMember>
    - createdAt: Timestamp
    - updatedAt: Timestamp
    - isPublic: boolean
    - summary: Map?
    
    activities/
      {activityId}/
        - id: string
        - tripId: string
        - userId: string
        - userName: string
        - type: string
        - description: string
        - timestamp: Timestamp
        - metadata: Map?
    
    comments/
      {commentId}/
        - id: string
        - tripId: string
        - userId: string
        - userName: string
        - comment: string
        - createdAt: Timestamp
        - updatedAt: Timestamp?
        - dayIndex: string?
        - activityIndex: string?

invitations/
  {invitationId}/
    - id: string
    - tripId: string
    - tripTitle: string
    - tripDestination: string
    - invitedByUserId: string
    - invitedByName: string
    - invitedByEmail: string
    - invitedUserEmail: string
    - invitedUserId: string?
    - role: string
    - status: string (pending/accepted/rejected/cancelled)
    - createdAt: Timestamp
    - respondedAt: Timestamp?
    - message: string?
```

## Usage Examples

### Example 1: Creating a Group Trip

```dart
// Navigate to create screen from home
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const CreateGroupTripScreen(),
  ),
);

// Or programmatically create a trip
final tripId = await groupTripService.createGroupTrip(
  title: 'Summer Beach Vacation',
  destination: 'Goa, India',
  description: 'Fun beach trip with college friends',
  startDate: DateTime(2024, 6, 15),
  endDate: DateTime(2024, 6, 22),
  durationInDays: 7,
  isPublic: false,
);
```

### Example 2: Inviting Members

```dart
// Send invitation
await groupTripService.sendInvitation(
  tripId: tripId,
  invitedUserEmail: 'friend@example.com',
  role: TripRole.editor,
  message: 'Join me for an amazing beach vacation!',
);

// The invited user receives notification and can accept/reject
```

### Example 3: Accepting an Invitation

```dart
// User receives invitation
// In TripInvitationsScreen, user taps "Accept"
await groupTripService.acceptInvitation(invitationId);

// User is automatically added to trip members
// Activity log records the new member
// All trip members see the update in real-time
```

### Example 4: Managing Member Roles

```dart
// Owner can change member roles
await groupTripService.updateMemberRole(
  tripId: tripId,
  memberUserId: memberId,
  newRole: TripRole.editor, // Promote viewer to editor
);

// Activity is logged
// Member receives updated permissions
```

### Example 5: Adding Comments

```dart
// Any member can add comments
await groupTripService.addComment(
  tripId: tripId,
  comment: 'Should we book flights early?',
);

// Comments appear in real-time for all members
// Activity log records the comment
```

### Example 6: Tracking Activities

```dart
// Get activity stream for a trip
StreamBuilder<List<TripActivity>>(
  stream: groupTripService.getTripActivities(tripId),
  builder: (context, snapshot) {
    final activities = snapshot.data ?? [];
    // Display activity feed
    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ListTile(
          title: Text(activity.description),
          subtitle: Text(formatTime(activity.timestamp)),
        );
      },
    );
  },
);
```

### Example 7: Removing a Member

```dart
// Owner removes a member
await groupTripService.removeMember(
  tripId: tripId,
  memberUserId: memberIdToRemove,
);

// Member can also leave voluntarily
await groupTripService.removeMember(
  tripId: tripId,
  memberUserId: currentUser.uid, // Self-removal
);
```

### Example 8: Real-time Trip Updates

```dart
// Listen to trip changes
StreamBuilder<List<GroupTrip>>(
  stream: groupTripService.getUserTrips(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final trips = snapshot.data!;
      // UI automatically updates when any trip changes
      return ListView.builder(
        itemCount: trips.length,
        itemBuilder: (context, index) => TripCard(trips[index]),
      );
    }
    return CircularProgressIndicator();
  },
);
```

## Validation Rules

### Trip Creation/Update
- **Title**: 3-100 characters, required
- **Destination**: 2-100 characters, required
- **Description**: 0-500 characters, optional
- **Duration**: 1-365 days
- **Dates**: End date must be after start date
- **Visibility**: Public or Private

### Invitations
- **Email**: Valid email format, required
- **Email**: Must not already be a member
- **Email**: Cannot have pending invitation
- **Role**: Must be Editor or Viewer (Owner cannot be assigned)
- **Message**: 0-200 characters, optional

### Comments
- **Content**: 1-1000 characters, required
- **Content**: Cannot be empty or only whitespace
- **Editing**: Only author can edit own comments
- **Deletion**: Author or trip owner can delete

### Member Management
- **Remove**: Only owner can remove others
- **Remove**: Owner cannot be removed
- **Remove**: Members can remove themselves (leave trip)
- **Role Change**: Only owner can change roles
- **Role Change**: Cannot change owner's role

## Error Handling

The service includes comprehensive error handling for:
- Authentication errors
- Permission denied errors
- Not found errors
- Validation errors
- Network errors
- Firestore errors

All errors are caught and returned with user-friendly messages.

## Security Rules (Firestore)

Recommended Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is trip member
    function isTripMember(tripId) {
      let trip = get(/databases/$(database)/documents/trips/$(tripId));
      return request.auth.uid in trip.data.members.map(m => m.userId);
    }
    
    // Helper function to check if user is trip owner
    function isTripOwner(tripId) {
      let trip = get(/databases/$(database)/documents/trips/$(tripId));
      return request.auth.uid == trip.data.ownerId;
    }
    
    // Helper function to check if user can edit
    function canEditTrip(tripId) {
      let trip = get(/databases/$(database)/documents/trips/$(tripId));
      let member = trip.data.members.filter(m => m.userId == request.auth.uid)[0];
      return member.role == 'owner' || member.role == 'editor';
    }
    
    // Trips collection
    match /trips/{tripId} {
      // Allow read if user is member or trip is public
      allow read: if request.auth != null && 
        (isTripMember(tripId) || resource.data.isPublic == true);
      
      // Allow create if authenticated
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.ownerId;
      
      // Allow update if user can edit
      allow update: if request.auth != null && canEditTrip(tripId);
      
      // Allow delete if user is owner
      allow delete: if request.auth != null && isTripOwner(tripId);
      
      // Activities subcollection
      match /activities/{activityId} {
        allow read: if request.auth != null && isTripMember(tripId);
        allow write: if request.auth != null && isTripMember(tripId);
      }
      
      // Comments subcollection
      match /comments/{commentId} {
        allow read: if request.auth != null && isTripMember(tripId);
        allow create: if request.auth != null && isTripMember(tripId);
        allow update: if request.auth != null && 
          request.auth.uid == resource.data.userId;
        allow delete: if request.auth != null && 
          (request.auth.uid == resource.data.userId || isTripOwner(tripId));
      }
    }
    
    // Invitations collection
    match /invitations/{invitationId} {
      allow read: if request.auth != null && 
        (request.auth.uid == resource.data.invitedByUserId || 
         request.auth.email == resource.data.invitedUserEmail);
      
      allow create: if request.auth != null;
      
      allow update: if request.auth != null && 
        (request.auth.uid == resource.data.invitedByUserId || 
         request.auth.email == resource.data.invitedUserEmail);
      
      allow delete: if request.auth != null && 
        request.auth.uid == resource.data.invitedByUserId;
    }
  }
}
```

## Integration with Existing App

### Step 1: Add Navigation

In your home screen or main menu, add navigation to GroupTripsScreen:

```dart
ListTile(
  leading: Icon(Icons.group),
  title: Text('Group Trips'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GroupTripsScreen(),
      ),
    );
  },
)
```

### Step 2: Link from Existing Trips

When users create regular trips, offer option to convert to group trip or share:

```dart
ElevatedButton(
  onPressed: () async {
    // Create group trip from existing itinerary
    await groupTripService.createGroupTrip(
      title: existingTrip.title,
      destination: existingTrip.destination,
      itinerarySummary: existingTrip.summary,
      // ... other details
    );
  },
  child: Text('Share with Friends'),
)
```

### Step 3: Add Notification Badge

Show pending invitation count in app bar or bottom navigation:

```dart
StreamBuilder<List<TripInvitation>>(
  stream: groupTripService.getPendingInvitations(),
  builder: (context, snapshot) {
    final count = snapshot.data?.length ?? 0;
    return Badge(
      count: count,
      child: Icon(Icons.notifications),
    );
  },
)
```

## Testing Checklist

### Trip Management
- [ ] Create trip with all fields
- [ ] Create trip with minimal fields
- [ ] Edit trip details
- [ ] Delete trip as owner
- [ ] Try to delete trip as non-owner (should fail)
- [ ] Public/Private visibility toggle

### Invitations
- [ ] Send invitation to registered user
- [ ] Send invitation to unregistered email
- [ ] Accept invitation
- [ ] Reject invitation
- [ ] Cancel sent invitation
- [ ] Try to invite existing member (should fail)
- [ ] Try to invite with pending invitation (should fail)

### Member Management
- [ ] View member list
- [ ] Change member role (owner only)
- [ ] Remove member (owner only)
- [ ] Leave trip (non-owner)
- [ ] Try to remove owner (should fail)

### Comments
- [ ] Add comment as member
- [ ] Edit own comment
- [ ] Delete own comment
- [ ] Delete comment as owner
- [ ] Try to edit other's comment (should fail)
- [ ] Real-time comment updates

### Activity Log
- [ ] View activity history
- [ ] Verify all activity types are logged
- [ ] Check activity timestamps
- [ ] Activity real-time updates

### Permissions
- [ ] Verify owner can do everything
- [ ] Verify editor can edit but not manage members
- [ ] Verify viewer can only view and comment
- [ ] Check permission errors display properly

## Future Enhancements

1. **Push Notifications**
   - Invitation received
   - Trip updated
   - New comment
   - Member added/removed

2. **Chat System**
   - Real-time chat for each trip
   - Direct messaging between members

3. **Collaborative Itinerary Editing**
   - Real-time itinerary collaboration
   - Suggestions and voting system
   - Conflict resolution

4. **File Sharing**
   - Upload and share trip documents
   - Photo galleries
   - Booking confirmations

5. **Expense Splitting**
   - Track shared expenses
   - Split bills among members
   - Settlement suggestions

6. **Calendar Integration**
   - Export to device calendar
   - Sync with Google Calendar
   - Reminders and notifications

7. **Advanced Search**
   - Search trips by destination
   - Filter by date range
   - Search by members

8. **Trip Templates**
   - Save trips as templates
   - Reuse popular itineraries
   - Community shared templates

## Troubleshooting

### Issue: Invitations not appearing
- Check email is correct
- Verify user is logged in
- Check Firestore security rules
- Verify internet connection

### Issue: Cannot edit trip
- Check user role (must be owner or editor)
- Verify trip exists
- Check Firestore permissions

### Issue: Real-time updates not working
- Verify StreamBuilder is used correctly
- Check Firestore connection
- Verify listener is not disposed

### Issue: Members not syncing
- Check members array in Firestore
- Verify arrayContains query works
- Check for client-side filtering

## Support

For issues or questions about the Group Trip Collaboration module:
1. Check this documentation
2. Review error messages in console
3. Verify Firestore security rules
4. Check network connectivity
5. Review validation rules

## License

This module is part of the Trip Genie application.

---

**Version**: 1.0.0  
**Last Updated**: December 2024  
**Compatibility**: Flutter 3.0+, Firebase Firestore 4.15+