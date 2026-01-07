# Firebase Cloud Functions - Email OTP Setup Guide

## Overview
This guide explains how to set up Firebase Cloud Functions to send OTP emails to passengers when drivers initiate vehicle entry verification.

## Architecture

```
Driver clicks "Verify Passenger Entry"
           ↓
Flutter App calls generateAndSendVehicleEntryOTP()
           ↓
Store OTP in Firestore
           ↓
Trigger Cloud Function (via HTTP call or Firestore trigger)
           ↓
Cloud Function sends email via SendGrid/Mailgun
           ↓
Passenger receives email with OTP
```

---

## Prerequisites

1. **Firebase Project** with Blaze Plan (Pay-as-you-go)
   - Cloud Functions require billing to be enabled
   - Free tier includes: 2M invocations/month, 400K GB-seconds/month

2. **Email Service Provider** (choose one):
   - **SendGrid** (Recommended - 100 emails/day free)
   - **Mailgun** (100 emails/day free)
   - **AWS SES** (62,000 emails/month free)

3. **Node.js** installed locally (v16 or higher)

4. **Firebase CLI** installed:
   ```bash
   npm install -g firebase-tools
   ```

---

## Step 1: Initialize Firebase Functions

### 1.1 Login to Firebase
```bash
firebase login
```

### 1.2 Initialize Functions in Your Project
Navigate to your project directory:
```bash
cd trip_genie
firebase init functions
```

Select:
- **Language**: JavaScript or TypeScript
- **ESLint**: Yes (recommended)
- **Install dependencies**: Yes

This creates a `functions` folder with:
```
trip_genie/
├── functions/
│   ├── index.js          # Your cloud functions
│   ├── package.json      # Dependencies
│   └── .env              # Environment variables (create this)
```

---

## Step 2: Setup SendGrid (Recommended)

### 2.1 Create SendGrid Account
1. Go to https://sendgrid.com/
2. Sign up for free account
3. Verify your email address
4. Complete sender verification

### 2.2 Create API Key
1. Go to Settings → API Keys
2. Click "Create API Key"
3. Name: `Trip_Genie_OTP_Emails`
4. Permission: **Full Access** or **Mail Send** only
5. Copy the API key (you'll only see it once!)

### 2.3 Verify Sender Identity
1. Go to Settings → Sender Authentication
2. Choose "Single Sender Verification" (easier for testing)
3. Enter your email address (e.g., `noreply@tripgenie.com` or your domain)
4. Verify the email address

### 2.4 Store API Key in Firebase
```bash
firebase functions:config:set sendgrid.key="YOUR_SENDGRID_API_KEY"
firebase functions:config:set sendgrid.sender="noreply@tripgenie.com"
```

---

## Step 3: Install Dependencies

In the `functions` folder:
```bash
cd functions
npm install @sendgrid/mail
npm install firebase-admin
npm install firebase-functions
```

---

## Step 4: Write Cloud Function

### Option A: HTTP Callable Function (Recommended)

**File**: `functions/index.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');

admin.initializeApp();

// Initialize SendGrid
const SENDGRID_API_KEY = functions.config().sendgrid.key;
const SENDER_EMAIL = functions.config().sendgrid.sender || 'noreply@tripgenie.com';
sgMail.setApiKey(SENDGRID_API_KEY);

/**
 * HTTP Callable Function to send OTP email
 * Called directly from Flutter app
 */
exports.sendOTPEmail = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to send OTP emails.'
    );
  }

  // Extract parameters
  const { passengerEmail, passengerName, otp, driverName } = data;

  // Validate inputs
  if (!passengerEmail || !otp) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: passengerEmail, otp'
    );
  }

  // Email content
  const msg = {
    to: passengerEmail,
    from: SENDER_EMAIL,
    subject: '🚗 Your Vehicle Entry OTP - Trip Genie',
    text: `Hello ${passengerName || 'Passenger'},

Your vehicle entry OTP is: ${otp}

Driver ${driverName || 'N/A'} has requested verification. Please share this 6-digit code with the driver when boarding the vehicle.

This OTP is valid for the current ride only.

Safe travels!
Trip Genie Team`,
    html: `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #1a237e, #0d47a1, #1976d2); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .header h1 { margin: 0; font-size: 24px; }
    .content { padding: 30px; }
    .otp-box { background-color: #e3f2fd; border: 3px solid #1976d2; border-radius: 10px; padding: 20px; text-align: center; margin: 20px 0; }
    .otp-code { font-size: 42px; font-weight: bold; letter-spacing: 10px; color: #1976d2; margin: 10px 0; }
    .info-box { background-color: #fff3e0; border-left: 4px solid #ff9800; padding: 15px; margin: 20px 0; border-radius: 5px; }
    .footer { background-color: #f5f5f5; padding: 20px; text-align: center; color: #666; font-size: 12px; border-radius: 0 0 10px 10px; }
    .icon { font-size: 48px; margin-bottom: 10px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="icon">🚗</div>
      <h1>Vehicle Entry Verification</h1>
    </div>
    
    <div class="content">
      <p>Hello <strong>${passengerName || 'Passenger'}</strong>,</p>
      
      <p>Your driver <strong>${driverName || 'has'}</strong> requested vehicle entry verification.</p>
      
      <div class="otp-box">
        <p style="margin: 0; font-size: 14px; color: #666;">Your OTP Code:</p>
        <div class="otp-code">${otp}</div>
        <p style="margin: 0; font-size: 12px; color: #666;">Share this code with your driver</p>
      </div>
      
      <div class="info-box">
        <strong>⚠️ Important:</strong>
        <ul style="margin: 10px 0; padding-left: 20px;">
          <li>Share this OTP with the driver when boarding</li>
          <li>This OTP is valid for this ride only</li>
          <li>You can also view this OTP in the Trip Genie app</li>
          <li>Never share this OTP with anyone else</li>
        </ul>
      </div>
      
      <p>If you did not request this OTP or have any concerns, please contact us immediately.</p>
      
      <p>Safe travels! 🛣️</p>
      
      <p style="color: #666; font-size: 14px;">
        <strong>Trip Genie Team</strong><br>
        Your trusted travel companion
      </p>
    </div>
    
    <div class="footer">
      <p>This is an automated message. Please do not reply to this email.</p>
      <p>&copy; 2024 Trip Genie. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
    `,
  };

  try {
    // Send email via SendGrid
    await sgMail.send(msg);
    
    console.log(`OTP email sent successfully to ${passengerEmail}`);
    
    return {
      success: true,
      message: 'OTP email sent successfully',
    };
  } catch (error) {
    console.error('Error sending OTP email:', error);
    
    if (error.response) {
      console.error('SendGrid error response:', error.response.body);
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send OTP email',
      error.message
    );
  }
});


/**
 * Optional: Firestore Trigger Function
 * Automatically sends email when OTP is added to a match
 */
exports.onOTPCreated = functions.firestore
  .document('ride_matches/{matchId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    
    // Check if vehicleEntryOTP was just added
    if (newData.vehicleEntryOTP && !oldData.vehicleEntryOTP) {
      const { passengerEmail, passengerName, vehicleEntryOTP, driverName } = newData;
      
      if (!passengerEmail || !vehicleEntryOTP) {
        console.log('Missing email or OTP, skipping email send');
        return null;
      }
      
      const msg = {
        to: passengerEmail,
        from: SENDER_EMAIL,
        subject: '🚗 Your Vehicle Entry OTP - Trip Genie',
        text: `Your OTP is: ${vehicleEntryOTP}. Share this with driver ${driverName || ''} when boarding.`,
        html: `<!-- Same HTML template as above -->`,
      };
      
      try {
        await sgMail.send(msg);
        console.log(`Auto-sent OTP email to ${passengerEmail}`);
        return null;
      } catch (error) {
        console.error('Error auto-sending OTP email:', error);
        return null;
      }
    }
    
    return null;
  });
```

---

## Step 5: Update Flutter App

### 5.1 Add Cloud Functions Package

**File**: `pubspec.yaml`
```yaml
dependencies:
  cloud_functions: ^4.5.0  # Add this
```

Run:
```bash
flutter pub get
```

### 5.2 Update RideMatchingService

**File**: `trip_genie/lib/services/ride_matching_service.dart`

```dart
import 'package:cloud_functions/cloud_functions.dart';

class RideMatchingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Random _random = Random();

  /// Generates and sends vehicle entry OTP to passenger's email
  Future<String> generateAndSendVehicleEntryOTP(String matchId, String passengerEmail) async {
    final otp = _generateVehicleEntryOTP();
    
    // Store OTP in Firestore
    await _db.collection('ride_matches').doc(matchId).update({
      'vehicleEntryOTP': otp,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Get match details for email
    final matchDoc = await _db.collection('ride_matches').doc(matchId).get();
    final matchData = matchDoc.data()!;
    
    try {
      // Call Cloud Function to send email
      final callable = _functions.httpsCallable('sendOTPEmail');
      final result = await callable.call({
        'passengerEmail': passengerEmail,
        'passengerName': matchData['passengerName'],
        'driverName': matchData['driverName'],
        'otp': otp,
      });
      
      print('Email sent successfully: ${result.data}');
    } catch (e) {
      print('Error calling cloud function: $e');
      // Don't throw error - OTP is still stored and visible in app
    }
    
    return otp;
  }
}
```

---

## Step 6: Deploy Cloud Functions

### 6.1 Deploy
```bash
firebase deploy --only functions
```

### 6.2 View Logs
```bash
firebase functions:log
```

### 6.3 Test Locally (Optional)
```bash
cd functions
npm run serve
```

---

## Step 7: Testing

### Test Email Sending

1. **In your app**: Click "Verify Passenger Entry"
2. **Check console logs**: Should see "Email sent successfully"
3. **Check passenger email**: Should receive OTP email within seconds
4. **Check Firebase Console**: 
   - Go to Functions tab
   - View execution logs
   - Check for any errors

### Test Scenarios

1. ✅ **Valid email**: Should receive email
2. ❌ **Invalid email**: Should log error but not crash
3. 🔄 **Retry logic**: If email fails, app still works (OTP in app)
4. 📧 **Email content**: Check formatting, OTP display, instructions

---

## Cost Estimation

### Free Tier Limits
- **SendGrid**: 100 emails/day (forever free)
- **Firebase Functions**: 2M invocations/month
- **Firestore**: 50K reads/day, 20K writes/day

### Estimated Costs (after free tier)
- **SendGrid Pro**: $19.95/month (100K emails)
- **Firebase Functions**: ~$0.40 per million invocations
- **Typical usage**: 1000 rides/month = **FREE**

---

## Security Best Practices

### 1. Environment Variables
Never commit API keys to Git:
```bash
# .gitignore
functions/.env
functions/serviceAccountKey.json
```

### 2. Function Authentication
Always verify the user is authenticated:
```javascript
if (!context.auth) {
  throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
}
```

### 3. Rate Limiting
Prevent abuse:
```javascript
// Limit OTP emails to 5 per hour per user
const recentEmails = await admin.firestore()
  .collection('otp_logs')
  .where('userId', '==', context.auth.uid)
  .where('timestamp', '>', Date.now() - 3600000)
  .get();

if (recentEmails.size >= 5) {
  throw new functions.https.HttpsError('resource-exhausted', 'Too many requests');
}
```

### 4. Email Validation
```javascript
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
if (!emailRegex.test(passengerEmail)) {
  throw new functions.https.HttpsError('invalid-argument', 'Invalid email');
}
```

---

## Alternative: Mailgun Setup

If you prefer Mailgun over SendGrid:

### Install Mailgun
```bash
npm install mailgun-js
```

### Configure Mailgun
```javascript
const mailgun = require('mailgun-js');
const mg = mailgun({
  apiKey: functions.config().mailgun.key,
  domain: functions.config().mailgun.domain,
});

const data = {
  from: 'Trip Genie <noreply@tripgenie.com>',
  to: passengerEmail,
  subject: 'Your Vehicle Entry OTP',
  text: `Your OTP is: ${otp}`,
  html: '<!-- HTML content -->',
};

await mg.messages().send(data);
```

---

## Troubleshooting

### Issue: "Billing account not configured"
**Solution**: Enable Blaze plan in Firebase Console

### Issue: "SendGrid API key invalid"
**Solution**: 
1. Regenerate API key in SendGrid
2. Update Firebase config: `firebase functions:config:set sendgrid.key="NEW_KEY"`
3. Redeploy: `firebase deploy --only functions`

### Issue: Emails going to spam
**Solution**:
1. Verify sender domain in SendGrid
2. Set up SPF/DKIM records
3. Use authenticated domain instead of @gmail.com

### Issue: Function timeout
**Solution**: Increase timeout in `index.js`:
```javascript
exports.sendOTPEmail = functions
  .runWith({ timeoutSeconds: 60 })
  .https.onCall(async (data, context) => { /* ... */ });
```

---

## Monitoring & Analytics

### View Function Logs
```bash
firebase functions:log --only sendOTPEmail
```

### Track Email Delivery
Add logging to Firestore:
```javascript
await admin.firestore().collection('email_logs').add({
  to: passengerEmail,
  otp: otp,
  matchId: matchId,
  sentAt: admin.firestore.FieldValue.serverTimestamp(),
  status: 'sent',
});
```

### SendGrid Analytics
1. Go to SendGrid Dashboard
2. View Activity → All Activity
3. Filter by recipient email
4. See delivery status, opens, clicks

---

## Next Steps

1. ✅ Setup SendGrid account
2. ✅ Initialize Firebase Functions
3. ✅ Deploy cloud function
4. ✅ Update Flutter app
5. ✅ Test email sending
6. 📈 Monitor usage
7. 🔒 Add rate limiting
8. 🌐 Setup custom domain (optional)

---

## Summary

After setup, the flow will be:
1. Driver clicks "Verify Passenger Entry" → OTP generated
2. Cloud Function automatically sends email to passenger
3. Passenger receives email with OTP
4. Passenger can view OTP in app OR email
5. Passenger shares OTP with driver
6. Driver verifies and passenger boards vehicle ✅

**Total setup time**: ~30 minutes  
**Cost**: FREE for most use cases  
**Reliability**: 99.9% uptime