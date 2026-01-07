# Group Trip Collaboration - Architecture & Flow Diagrams

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                          │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  Group Trips │  │ Trip Detail  │  │ Invitations  │         │
│  │    Screen    │  │    Screen    │  │    Screen    │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                  │                  │                  │
│  ┌──────▼───────┐  ┌──────▼───────┐  ┌──────▼───────┐         │
│  │Create/Edit   │  │Invite Member │  │   Comments   │         │
│  │Trip Screens  │  │    Screen    │  │   & Activity │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      SERVICE LAYER                              │
├─────────────────────────────────────────────────────────────────┤
│                   GroupTripService                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │   Trip      │ │ Invitation  │ │   Member    │             │
│  │ Operations  │ │  Operations │ │ Management  │             │
│  └─────────────┘ └─────────────┘ └─────────────┘             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │  Comments   │ │  Activity   │ │   Helper    │             │
│  │  Operations │ │   Logging   │ │  Functions  │             │
│  └─────────────┘ └─────────────┘ └─────────────┘             │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DATA LAYER                                 │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │  GroupTrip  │ │   Trip      │ │    Trip     │             │
│  │    Model    │ │  Member     │ │ Invitation  │             │
│  └─────────────┘ └─────────────┘ └─────────────┘             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐             │
│  │    Trip     │ │    Trip     │ │    Enums    │             │
│  │  Activity   │ │  Comment    │ │     &       │             │
│  │    Model    │ │    Model    │ │ Extensions  │             │
│  └─────────────┘ └─────────────┘ └─────────────┘             │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   FIREBASE FIRESTORE                            │
├─────────────────────────────────────────────────────────────────┤
│  trips/{tripId}                                                 │
│  ├── Trip Document                                              │
│  ├── activities/{activityId}                                    │
│  └── comments/{commentId}                                       │
│                                                                  │
│  invitations/{invitationId}                                     │
│  └── Invitation Documents                                       │
│                                                                  │
│  users/{userId}                                                 │
│  └── User Profile Documents                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagrams

### 1. Create Trip Flow

```
┌──────────┐
│   User   │
└────┬─────┘
     │ 1. Opens Create Screen
     ▼
┌─────────────────┐
│ Create Screen   │
│ - Fill form     │
│ - Validate      │
└────┬────────────┘
     │ 2. Submit
     ▼
┌─────────────────┐
│ GroupTripService│
│ - Validate data │
│ - Create owner  │
│   member        │
└────┬────────────┘
     │ 3. Create document
     ▼
┌─────────────────┐
│   Firestore     │
│ trips/{tripId}  │
└────┬────────────┘
     │ 4. Log activity
     ▼
┌─────────────────┐
│   Firestore     │
│ activities/     │
│   {activityId}  │
└────┬────────────┘
     │ 5. Return trip ID
     ▼
┌─────────────────┐
│ Success Screen  │
│ - Show trip     │
└─────────────────┘
```

### 2. Invitation Flow

```
┌─────────┐                              ┌─────────┐
│ Owner/  │                              │ Invitee │
│ Editor  │                              │         │
└────┬────┘                              └────┬────┘
     │                                        │
     │ 1. Send Invitation                    │
     ▼                                        │
┌──────────────────┐                         │
│ Invite Screen    │                         │
│ - Enter email    │                         │
│ - Select role    │                         │
│ - Add message    │                         │
└────┬─────────────┘                         │
     │ 2. Submit                              │
     ▼                                        │
┌──────────────────┐                         │
│ GroupTripService │                         │
│ - Validate email │                         │
│ - Check duplicate│                         │
│ - Create invite  │                         │
└────┬─────────────┘                         │
     │ 3. Save to Firestore                  │
     ▼                                        │
┌──────────────────┐                         │
│    Firestore     │                         │
│ invitations/     │────────────────────────►│
│   {inviteId}     │  4. Notification        │
└──────────────────┘                         │
                                              │ 5. Opens app
                                              ▼
                                         ┌──────────────┐
                                         │ Invitations  │
                                         │   Screen     │
                                         │ - View invite│
                                         │ - Accept/    │
                                         │   Reject     │
                                         └──────┬───────┘
                                                │ 6. Accept
                                                ▼
                                         ┌──────────────┐
                                         │GroupTrip     │
                                         │Service       │
                                         │- Add member  │
                                         │- Update      │
                                         │  invitation  │
                                         └──────┬───────┘
                                                │ 7. Update
                                                ▼
┌──────────────────┐                    ┌──────────────┐
│    Firestore     │◄───────────────────│  Firestore   │
│ trips/{tripId}   │  8. Real-time sync │ Update status│
│ - Add member     │                    └──────────────┘
└──────────────────┘
```

### 3. Real-time Collaboration Flow

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│ User A  │     │ User B  │     │ User C  │
└────┬────┘     └────┬────┘     └────┬────┘
     │               │               │
     │ 1. Edit trip  │               │
     ▼               │               │
┌──────────────┐     │               │
│GroupTrip     │     │               │
│Service       │     │               │
│- Update trip │     │               │
└──────┬───────┘     │               │
     │ 2. Save       │               │
     ▼               │               │
┌──────────────┐     │               │
│  Firestore   │     │               │
│ trips/       │─────┼───────────────┼──► Real-time
│   {tripId}   │     │               │    listeners
└──────────────┘     │               │
                     │               │
     3. Stream update│               │
     ◄───────────────┼───────────────┤
     │               │               │
     │               ▼               ▼
     │          ┌──────────┐   ┌──────────┐
     │          │StreamBdr │   │StreamBdr │
     │          │- Rebuild │   │- Rebuild │
     │          │- Show    │   │- Show    │
     │          │  changes │   │  changes │
     │          └──────────┘   └──────────┘
     │               │               │
     │ All users see changes instantly
     └───────────────┴───────────────┘
```

### 4. Permission Check Flow

```
┌──────────┐
│   User   │
└────┬─────┘
     │ 1. Attempts action
     ▼
┌─────────────────┐
│   UI Layer      │
│ - Check role    │
│ - Show/Hide     │
│   controls      │
└────┬────────────┘
     │ 2. Request action
     ▼
┌─────────────────┐
│ Service Layer   │
│ - Verify user   │
│ - Load trip     │
└────┬────────────┘
     │ 3. Check permission
     ▼
┌─────────────────┐
│ GroupTrip Model │
│ - canEdit()?    │
│ - isOwner()?    │
└────┬────────────┘
     │
     ├─► Permission granted
     │   ├─► Execute action
     │   └─► Return success
     │
     └─► Permission denied
         ├─► Throw exception
         └─► Show error message
```

---

## Component Relationships

```
┌──────────────────────────────────────────────────────────┐
│                    GroupTripsScreen                      │
│  ┌────────────────────┐  ┌─────────────────────┐       │
│  │  Owned Trips Tab   │  │ Shared Trips Tab    │       │
│  │  ┌──────────────┐  │  │  ┌──────────────┐   │       │
│  │  │ Trip Cards   │  │  │  │ Trip Cards   │   │       │
│  │  │ (Stream)     │  │  │  │ (Stream)     │   │       │
│  │  └──────┬───────┘  │  │  └──────┬───────┘   │       │
│  └─────────┼──────────┘  └─────────┼───────────┘       │
└────────────┼──────────────────────┼─────────────────────┘
             │                       │
             │ Tap on card           │
             └───────────┬───────────┘
                         ▼
┌──────────────────────────────────────────────────────────┐
│              GroupTripDetailScreen                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ Overview │ │ Members  │ │ Activity │ │ Comments │  │
│  │   Tab    │ │   Tab    │ │   Tab    │ │   Tab    │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │
│       │            │             │             │         │
│       ├─ Stats     ├─ List       ├─ History   ├─ List  │
│       ├─ Details   ├─ Invite     └─ Real-time └─ Add   │
│       └─ Info      └─ Manage                            │
└──────────────────────────────────────────────────────────┘
             │
             ├─► Edit Trip ──► EditGroupTripScreen
             │
             ├─► Invite ──────► InviteMemberScreen
             │
             └─► Delete Trip ─► Confirmation Dialog
```

---

## State Management Flow

```
┌─────────────────────────────────────────────────┐
│              StreamBuilder Pattern              │
└─────────────────────────────────────────────────┘

┌──────────────┐
│  UI Widget   │
└──────┬───────┘
       │ StreamBuilder<List<GroupTrip>>
       ▼
┌──────────────────────────┐
│   GroupTripService       │
│   ├─ getUserTrips()      │
│   └─ Returns Stream      │
└──────┬───────────────────┘
       │ Stream
       ▼
┌──────────────────────────┐
│   Firestore Query        │
│   ├─ .snapshots()        │
│   └─ Real-time listener  │
└──────┬───────────────────┘
       │ QuerySnapshot
       ▼
┌──────────────────────────┐
│   Data Transformation    │
│   ├─ Map to models       │
│   └─ Filter/Sort         │
└──────┬───────────────────┘
       │ List<GroupTrip>
       ▼
┌──────────────────────────┐
│   UI Rebuild             │
│   ├─ Display data        │
│   └─ Update widgets      │
└──────────────────────────┘
       │
       │ User changes data
       ▼
┌──────────────────────────┐
│   Service Method         │
│   ├─ updateGroupTrip()   │
│   └─ Save to Firestore   │
└──────┬───────────────────┘
       │
       │ Firestore triggers
       │ snapshot update
       │
       └─────────► Loop back to Stream
```

---

## User Journey Map

### Journey 1: Trip Creator (Owner)

```
Start
  │
  ├─► 1. Open Group Trips Screen
  │      └─► Empty state with Create button
  │
  ├─► 2. Tap Create Trip
  │      └─► Fill form (title, destination, dates)
  │
  ├─► 3. Submit Trip
  │      ├─► Validation
  │      ├─► Create in Firestore
  │      └─► Become owner automatically
  │
  ├─► 4. View Trip Details
  │      ├─► See overview
  │      ├─► View as Owner
  │      └─► All permissions available
  │
  ├─► 5. Invite Friends
  │      ├─► Enter emails
  │      ├─► Assign roles
  │      └─► Send invitations
  │
  ├─► 6. Collaborate
  │      ├─► See members join
  │      ├─► View activities
  │      ├─► Read/write comments
  │      └─► Edit trip details
  │
  └─► 7. Manage Trip
         ├─► Change member roles
         ├─► Remove members if needed
         └─► Track all activities
End
```

### Journey 2: Invited Member (Editor/Viewer)

```
Start
  │
  ├─► 1. Receive Invitation
  │      ├─► Email notification (future)
  │      └─► In-app badge
  │
  ├─► 2. Open Invitations Screen
  │      └─► See pending invitation
  │
  ├─► 3. Review Invitation
  │      ├─► See trip details
  │      ├─► See inviter info
  │      └─► See assigned role
  │
  ├─► 4. Accept Invitation
  │      ├─► Join trip as member
  │      └─► Navigate to trip details
  │
  ├─► 5. View Trip
  │      ├─► See overview
  │      ├─► View members
  │      └─► Check activity log
  │
  ├─► 6. Participate
  │      ├─► Edit trip (if Editor)
  │      ├─► Add comments
  │      ├─► View updates
  │      └─► Collaborate with team
  │
  └─► 7. Optional: Leave Trip
         └─► Remove self from members
End
```

---

## Role Permission Matrix

```
┌────────────────────────┬────────┬────────┬────────┐
│      Action            │ Owner  │ Editor │ Viewer │
├────────────────────────┼────────┼────────┼────────┤
│ View Trip Details      │   ✓    │   ✓    │   ✓    │
├────────────────────────┼────────┼────────┼────────┤
│ View Members           │   ✓    │   ✓    │   ✓    │
├────────────────────────┼────────┼────────┼────────┤
│ View Activity Log      │   ✓    │   ✓    │   ✓    │
├────────────────────────┼────────┼────────┼────────┤
│ Add Comments           │   ✓    │   ✓    │   ✓    │
├────────────────────────┼────────┼────────┼────────┤
│ Edit Own Comments      │   ✓    │   ✓    │   ✓    │
├────────────────────────┼────────┼────────┼────────┤
│ Delete Own Comments    │   ✓    │   ✓    │   ✓    │
├────────────────────────┼────────┼────────┼────────┤
│ Edit Trip Details      │   ✓    │   ✓    │   ✗    │
├────────────────────────┼────────┼────────┼────────┤
│ Invite Members         │   ✓    │   ✓    │   ✗    │
├────────────────────────┼────────┼────────┼────────┤
│ Remove Members         │   ✓    │   ✗    │   ✗    │
├────────────────────────┼────────┼────────┼────────┤
│ Change Roles           │   ✓    │   ✗    │   ✗    │
├────────────────────────┼────────┼────────┼────────┤
│ Delete Others' Comments│   ✓    │   ✗    │   ✗    │
├────────────────────────┼────────┼────────┼────────┤
│ Delete Trip            │   ✓    │   ✗    │   ✗    │
├────────────────────────┼────────┼────────┼────────┤
│ Leave Trip             │   ✗    │   ✓    │   ✓    │
└────────────────────────┴────────┴────────┴────────┘
```

---

## Activity Logging Flow

```
Any User Action
      │
      ├─► Create Trip
      ├─► Edit Trip
      ├─► Invite Member
      ├─► Accept Invitation
      ├─► Remove Member
      ├─► Change Role
      ├─► Add Comment
      └─► Delete Trip
            │
            ▼
┌────────────────────────┐
│  Service Layer         │
│  - Execute action      │
│  - Call _logActivity() │
└────────┬───────────────┘
         │
         ▼
┌────────────────────────┐
│  Create Activity Entry │
│  - User ID & name      │
│  - Activity type       │
│  - Description         │
│  - Timestamp           │
│  - Metadata (optional) │
└────────┬───────────────┘
         │
         ▼
┌────────────────────────┐
│  Save to Firestore     │
│  trips/{tripId}/       │
│    activities/         │
│      {activityId}      │
└────────┬───────────────┘
         │
         ▼
┌────────────────────────┐
│  Real-time Update      │
│  - StreamBuilder       │
│  - Activity tab        │
│  - Show new activity   │
└────────────────────────┘
```

---

## Error Handling Flow

```
User Action
    │
    ▼
Try {
    ├─► Service Method
    │       │
    │       ├─► Validation
    │       │   ├─► Pass → Continue
    │       │   └─► Fail → throw Exception
    │       │
    │       ├─► Permission Check
    │       │   ├─► Pass → Continue
    │       │   └─► Fail → throw Exception
    │       │
    │       ├─► Firestore Operation
    │       │   ├─► Success → Return result
    │       │   └─► Fail → throw FirebaseException
    │       │
    │       └─► Return Success
    │
} Catch (e) {
    │
    ├─► Log Error
    │   └─► Print to console
    │
    ├─► Parse Error Message
    │   ├─► Remove "Exception: " prefix
    │   └─► Make user-friendly
    │
    └─► Show to User
        ├─► SnackBar (non-critical)
        ├─► Dialog (critical)
        └─► Error state (persistent)
}
```

---

## Database Query Patterns

### Pattern 1: Get User's Trips

```
Query: trips collection
Filter: ownerId == currentUser.uid
Sort: updatedAt DESC
Listen: Real-time snapshots()

Firestore:
trips
  └─ where('ownerId', '==', userId)
     └─ orderBy('updatedAt', 'descending')
        └─ snapshots()

Result: Stream<List<GroupTrip>>
```

### Pattern 2: Get Shared Trips

```
Query: trips collection
Filter: Client-side filter for members array
Sort: updatedAt DESC
Listen: Real-time snapshots()

Firestore:
trips
  └─ orderBy('updatedAt', 'descending')
     └─ snapshots()
     
Client:
  .where((trip) => 
    trip.isMember(userId) && 
    !trip.isOwner(userId))

Result: Stream<List<GroupTrip>>
```

### Pattern 3: Get Pending Invitations

```
Query: invitations collection
Filter: invitedUserEmail == user.email
       AND status == 'pending'
Sort: createdAt DESC
Listen: Real-time snapshots()

Firestore:
invitations
  └─ where('invitedUserEmail', '==', email)
     └─ where('status', '==', 'pending')
        └─ orderBy('createdAt', 'descending')
           └─ snapshots()

Result: Stream<List<TripInvitation>>
```

---

## Security Rules Decision Tree

```
User makes request to Firestore
        │
        ▼
Is user authenticated?
        │
        ├─ NO → DENY ✗
        │
        ▼ YES
        
What operation?
        │
        ├─► READ
        │   │
        │   Is trip public?
        │   ├─ YES → ALLOW ✓
        │   │
        │   ▼ NO
        │   Is user a member?
        │   ├─ YES → ALLOW ✓
        │   └─ NO → DENY ✗
        │
        ├─► CREATE
        │   │
        │   Is user the owner in data?
        │   ├─ YES → ALLOW ✓
        │   └─ NO → DENY ✗
        │
        ├─► UPDATE
        │   │
        │   Can user edit trip?
        │   ├─ YES → ALLOW ✓
        │   └─ NO → DENY ✗
        │
        └─► DELETE
            │
            Is user the owner?
            ├─ YES → ALLOW ✓
            └─ NO → DENY ✗
```

---

## Screen Navigation Flow

```
                    App Home
                        │
                        ├─► Group Trips Screen
                        │        │
                        │        ├─► My Trips Tab
                        │        │     └─► Trip Card
                        │        │           └─► Trip Detail Screen
                        │        │                 ├─► Overview Tab
                        │        │                 ├─► Members Tab
                        │        │                 │     └─► Invite Screen
                        │        │                 ├─► Activity Tab
                        │        │                 └─► Comments Tab
                        │        │
                        │        └─► Shared Trips Tab
                        │              └─► (same as above)
                        │
                        ├─► Create Trip Screen
                        │     └─► Submit → Trip Detail Screen
                        │
                        ├─► Invitations Screen
                        │     ├─► Accept → Trip Detail Screen
                        │     └─► Reject → Back to Invitations
                        │
                        └─► Edit Trip Screen
                              └─► Save → Trip Detail Screen
```

---

## Complete Feature Map

```
Group Trip Collaboration Module
│
├─ Trip Management
│  ├─ Create Trip
│  ├─ Edit Trip
│  ├─ Delete Trip
│  ├─ View Trip
│  └─ Public/Private Setting
│
├─ Member Management
│  ├─ Invite Members
│  │  ├─ Email input
│  │  ├─ Role selection
│  │  └─ Custom message
│  │
│  ├─ Accept/Reject Invitations
│  ├─ Remove Members
│  ├─ Change Roles
│  └─ Leave Trip
│
├─ Collaboration Features
│  ├─ Real-time Updates
│  ├─ Activity Tracking
│  ├─ Comment System
│  │  ├─ Add comments
│  │  ├─ Edit comments
│  │  └─ Delete comments
│  │
│  └─ Permission System
│     ├─ Owner
│     ├─ Editor
│     └─ Viewer
│
└─ Data & Security
   ├─ Firestore Integration
   ├─ Security Rules
   ├─ Data Validation
   └─ Error Handling
```

---

This architecture document provides visual representations of how the Group Trip Planning & Collaboration module is structured and how data flows through the system. Use these diagrams as reference when developing, debugging, or explaining the system to others.