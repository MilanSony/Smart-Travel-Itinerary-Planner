# Group Trip Collaboration - Quick Start Guide

## 🚀 Quick Implementation Guide

This guide will help you integrate the Group Trip Planning & Collaboration module into your Trip Genie app in **under 30 minutes**.

---

## Prerequisites

✅ Flutter 3.0+  
✅ Firebase project configured  
✅ Cloud Firestore enabled  
✅ Firebase Authentication active  
✅ User authentication working  

---

## Step 1: Verify Files (2 minutes)

Ensure all module files are present:

### Models
```
lib/models/group_trip_model.dart
```

### Services
```
lib/services/group_trip_service.dart
```

### Screens
```
lib/screens/group_trips_screen.dart
lib/screens/create_group_trip_screen.dart
lib/screens/group_trip_detail_screen.dart
lib/screens/edit_group_trip_screen.dart
lib/screens/invite_member_screen.dart
lib/screens/trip_invitations_screen.dart
```

---

## Step 2: Add Navigation (5 minutes)

### Option A: From Home Screen

Add to your `home_screen.dart`:

```dart
ListTile(
  leading: const Icon(Icons.group, color: Colors.blue),
  title: const Text('Group Trips'),
  subtitle: const Text('Plan with friends'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GroupTripsScreen(),
      ),
    );
  },
),
```

### Option B: From Bottom Navigation

```dart
BottomNavigationBarItem(
  icon: Icon(Icons.group),
  label: 'Group Trips',
),

// In onTap:
case 2:
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const GroupTripsScreen(),
    ),
  );
  break;
```

---

## Step 3: Configure Firestore Security Rules (10 minutes)

Update your `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isTripMember(tripId) {
      let trip = get(/databases/$(database)/documents/trips/$(tripId));
      return request.auth.uid in trip.data.members.map(m => m.userId);
    }
    
    function isTripOwner(tripId) {
      let trip = get(/databases/$(database)/documents/trips/$(tripId));
      return request.auth.uid == trip.data.ownerId;
    }
    
    function canEditTrip(tripId) {
      let trip = get(/databases/$(database)/documents/trips/$(tripId));
      let member = trip.data.members.filter(m => m.userId == request.auth.uid)[0];
      return member.role == 'owner' || member.role == 'editor';
    }
    
    // Trips collection
    match /trips/{tripId} {
      allow read: if isAuthenticated() && 
        (isTripMember(tripId) || resource.data.isPublic == true);
      
      allow create: if isAuthenticated() && 
        request.auth.uid == request.resource.data.ownerId;
      
      allow update: if isAuthenticated() && canEditTrip(tripId);
      
      allow delete: if isAuthenticated() && isTripOwner(tripId);
      
      // Activities subcollection
      match /activities/{activityId} {
        allow read: if isAuthenticated() && isTripMember(tripId);
        allow write: if isAuthenticated() && isTripMember(tripId);
      }
      
      // Comments subcollection
      match /comments/{commentId} {
        allow read: if isAuthenticated() && isTripMember(tripId);
        allow create: if isAuthenticated() && isTripMember(tripId);
        allow update: if isAuthenticated() && 
          request.auth.uid == resource.data.userId;
        allow delete: if isAuthenticated() && 
          (request.auth.uid == resource.data.userId || isTripOwner(tripId));
      }
    }
    
    // Invitations collection
    match /invitations/{invitationId} {
      allow read: if isAuthenticated() && 
        (request.auth.uid == resource.data.invitedByUserId || 
         request.auth.email == resource.data.invitedUserEmail);
      
      allow create: if isAuthenticated();
      
      allow update: if isAuthenticated() && 
        (request.auth.uid == resource.data.invitedByUserId || 
         request.auth.email == resource.data.invitedUserEmail);
      
      allow delete: if isAuthenticated() && 
        request.auth.uid == resource.data.invitedByUserId;
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

---

## Step 4: Create Firestore Indexes (5 minutes)

Update `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "trips",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "ownerId", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "trips",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "members.userId", "order": "ASCENDING" },
        { "fieldPath": "updatedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "invitations",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "invitedUserEmail", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "invitations",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "tripId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "activities",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "tripId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "comments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "tripId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

Deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

---

## Step 5: Test the Module (5 minutes)

### Basic Test Flow:

1. **Launch app and navigate to Group Trips**
   ```
   ✓ Should see empty state
   ✓ Should see "Create Trip" button
   ```

2. **Create a test trip**
   ```
   Title: "Test Trip"
   Destination: "Test City"
   Tap "Create Trip"
   ✓ Should succeed
   ✓ Should navigate to trip list
   ```

3. **Open trip details**
   ```
   Tap on created trip
   ✓ Should show 4 tabs
   ✓ Should show you as Owner
   ```

4. **Test invitation**
   ```
   Tap ⋮ menu → "Invite Members"
   Enter a test email
   Select role
   Tap "Send Invitation"
   ✓ Should succeed
   ```

5. **Check activity log**
   ```
   Go to Activity tab
   ✓ Should show "created the trip"
   ✓ Should show invitation sent
   ```

---

## Step 6: Add Notification Badge (Optional, 3 minutes)

Show pending invitations count:

```dart
// In your app bar or navigation
StreamBuilder<List<TripInvitation>>(
  stream: GroupTripService().getPendingInvitations(),
  builder: (context, snapshot) {
    final count = snapshot.data?.length ?? 0;
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.mail_outline),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TripInvitationsScreen(),
              ),
            );
          },
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  },
)
```

---

## Common Issues & Solutions

### Issue 1: "Permission Denied" Error
**Cause:** Firestore rules not deployed  
**Solution:** Run `firebase deploy --only firestore:rules`

### Issue 2: "Index Required" Error
**Cause:** Composite indexes not created  
**Solution:** 
1. Click the error link in console
2. Or run `firebase deploy --only firestore:indexes`

### Issue 3: Invitations Not Showing
**Cause:** Email mismatch or not logged in  
**Solution:** 
- Verify user is authenticated
- Check email matches exactly
- Check invitations collection in Firestore

### Issue 4: Real-time Updates Not Working
**Cause:** StreamBuilder not properly set up  
**Solution:** 
- Verify using StreamBuilder, not FutureBuilder
- Check Firestore connection in console

### Issue 5: Cannot Edit Trip
**Cause:** Insufficient permissions  
**Solution:** 
- Check user role (must be Owner or Editor)
- Verify user is in members array

---

## Quick Reference: Service Methods

### Trip Operations
```dart
// Create trip
final tripId = await groupTripService.createGroupTrip(
  title: 'Trip Name',
  destination: 'Location',
);

// Update trip
await groupTripService.updateGroupTrip(
  tripId: tripId,
  title: 'New Title',
);

// Delete trip
await groupTripService.deleteGroupTrip(tripId);

// Get trip
final trip = await groupTripService.getTrip(tripId);

// Stream user trips
Stream<List<GroupTrip>> trips = groupTripService.getUserTrips();
```

### Invitation Operations
```dart
// Send invitation
await groupTripService.sendInvitation(
  tripId: tripId,
  invitedUserEmail: 'user@email.com',
  role: TripRole.editor,
  message: 'Join us!',
);

// Accept invitation
await groupTripService.acceptInvitation(invitationId);

// Reject invitation
await groupTripService.rejectInvitation(invitationId);

// Get pending invitations
Stream<List<TripInvitation>> invites = 
  groupTripService.getPendingInvitations();
```

### Member Operations
```dart
// Remove member
await groupTripService.removeMember(
  tripId: tripId,
  memberUserId: userId,
);

// Update role
await groupTripService.updateMemberRole(
  tripId: tripId,
  memberUserId: userId,
  newRole: TripRole.editor,
);
```

### Comment Operations
```dart
// Add comment
await groupTripService.addComment(
  tripId: tripId,
  comment: 'Your comment',
);

// Update comment
await groupTripService.updateComment(
  tripId: tripId,
  commentId: commentId,
  newComment: 'Updated text',
);

// Delete comment
await groupTripService.deleteComment(
  tripId: tripId,
  commentId: commentId,
);

// Get comments stream
Stream<List<TripComment>> comments = 
  groupTripService.getTripComments(tripId);
```

### Activity Operations
```dart
// Get activities stream
Stream<List<TripActivity>> activities = 
  groupTripService.getTripActivities(tripId, limit: 50);
```

---

## Testing Checklist

Use this checklist to verify everything works:

- [ ] Can access Group Trips screen
- [ ] Can create a new trip
- [ ] Can view trip details
- [ ] Can edit trip (as owner/editor)
- [ ] Can send invitation
- [ ] Can view pending invitations
- [ ] Can accept invitation
- [ ] Can reject invitation
- [ ] Can add comment
- [ ] Can view activity log
- [ ] Can see real-time updates
- [ ] Can view members list
- [ ] Can change member role (as owner)
- [ ] Can remove member (as owner)
- [ ] Can leave trip (as non-owner)
- [ ] Can delete trip (as owner)
- [ ] Permission errors show correctly
- [ ] Validation works on all forms

---

## Performance Tips

1. **Limit activity log items:**
   ```dart
   groupTripService.getTripActivities(tripId, limit: 50)
   ```

2. **Limit comments:**
   ```dart
   groupTripService.getTripComments(tripId, limit: 100)
   ```

3. **Use pagination for large lists** (future enhancement)

4. **Close streams when not needed:**
   ```dart
   @override
   void dispose() {
     _streamSubscription?.cancel();
     super.dispose();
   }
   ```

---

## Next Steps

### Immediate (Week 1)
1. ✅ Complete basic integration
2. ✅ Test all features
3. ✅ Deploy to staging

### Short-term (Week 2-4)
1. 🔔 Add push notifications
2. 📧 Set up email notifications
3. 📊 Add analytics tracking
4. 🎨 Customize UI to match app theme

### Long-term (Month 2+)
1. 💬 Add real-time chat
2. 💰 Add expense splitting
3. 📅 Add calendar integration
4. 🗺️ Add collaborative itinerary editing
5. 📸 Add photo sharing

---

## Resources

- **Full Documentation:** `GROUP_TRIP_COLLABORATION_MODULE.md`
- **Walkthrough Example:** `GROUP_TRIP_EXAMPLE_WALKTHROUGH.md`
- **Model Reference:** `lib/models/group_trip_model.dart`
- **Service Reference:** `lib/services/group_trip_service.dart`

---

## Support

If you encounter issues:

1. Check error messages in console
2. Verify Firestore rules are deployed
3. Check indexes are created
4. Review validation rules
5. Test with different user roles
6. Check network connectivity

---

## Success! 🎉

You've successfully integrated the Group Trip Planning & Collaboration module!

Your users can now:
- ✅ Create and manage group trips
- ✅ Invite friends to collaborate
- ✅ Edit trips together in real-time
- ✅ Track all activities
- ✅ Communicate via comments
- ✅ Manage permissions with roles

**Total implementation time: ~30 minutes**

Happy coding! 🚀