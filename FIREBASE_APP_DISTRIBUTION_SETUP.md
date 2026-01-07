# Firebase App Distribution Setup Guide

## 🚀 **Complete Setup for Trip Genie**

This guide will help you set up Firebase App Distribution to easily share your app with testers.

---

## 📋 **Prerequisites**

- ✅ Firebase project already created
- ✅ Android app registered in Firebase
- ✅ Flutter project configured with Firebase

---

## 🔧 **Step 1: Install Firebase CLI (If Not Already)**

### **Windows:**
```bash
npm install -g firebase-tools
```

### **Mac/Linux:**
```bash
curl -sL https://firebase.tools | bash
```

### **Verify Installation:**
```bash
firebase --version
```

---

## 🔐 **Step 2: Login to Firebase**

```bash
firebase login
```

This will open a browser for authentication. Sign in with your Google account.

---

## 📱 **Step 3: Enable App Distribution in Firebase Console**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **trip-genie-8af8f**
3. Click **App Distribution** in left sidebar
4. Click **Get Started** if you see it
5. Your app should appear automatically

---

## 🏗️ **Step 4: Build Release APK**

```bash
cd trip_genie
flutter build apk --release
```

📁 APK Location: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📤 **Step 5: Upload APK to Firebase App Distribution**

### **Method 1: Using Firebase Console (Easiest)**

1. Go to Firebase Console → App Distribution
2. Click **Releases** tab
3. Click **Distribute app** button
4. Upload `app-release.apk`
5. Add release notes: "Initial release with group trip collaboration"
6. Select testers:
   - Click **Add testers**
   - Enter email addresses (one per line)
   - Or create a group
7. Click **Distribute**

### **Method 2: Using Firebase CLI**

```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app 1:YOUR_ANDROID_APP_ID \
  --release-notes "Initial release with group trip collaboration" \
  --testers "friend1@gmail.com,friend2@gmail.com"
```

**To find your Android App ID:**
1. Go to Firebase Console → Project Settings
2. Scroll to "Your apps" section
3. Click Android app
4. Copy the **App ID** (looks like: `1:123456789:android:abc123def456`)

---

## 🔗 **Step 6: Get Distribution Link**

After uploading, Firebase generates a unique link for your app:

### **Format:**
```
https://appdistribution.firebase.dev/i/ABC123XYZ
```

### **To Get Link:**

**Option A - From Console:**
1. Firebase Console → App Distribution → Releases
2. Click on your release
3. Copy the **Installation link**

**Option B - From Email:**
Testers receive an email with the installation link automatically.

---

## 🔧 **Step 7: Update Share Message in Code**

Now update the app download link in your service:

### **File:** `lib/services/group_trip_service.dart`

**Line 16-17, replace:**
```dart
static const String appDownloadLink =
    'https://drive.google.com/uc?export=download&id=YOUR_ID';
```

**With your Firebase App Distribution link:**
```dart
static const String appDownloadLink =
    'https://appdistribution.firebase.dev/i/YOUR_ACTUAL_LINK';
```

**Example:**
```dart
static const String appDownloadLink =
    'https://appdistribution.firebase.dev/i/e8f3a9b1c2d4';
```

---

## 📨 **Step 8: Share Message Format**

After updating the link, when users share a trip, the message will be:

```
🌍 Join my trip to Goa!

📍 Trip: Goa Trip
📅 Dates: 15/12/2024 - 20/12/2024

🔑 Trip Code: ABC123

👉 To join:
1. Download Trip Genie app (APK): 
   https://appdistribution.firebase.dev/i/YOUR_LINK
2. Install the APK on your Android device
3. Login/Signup with your email
4. Go to Group Trips → Tap "Join with Code" button (🔑 icon)
5. Enter code: ABC123

Let's plan this trip together! 🎉
```

---

## 👥 **Step 9: Add Testers**

### **Option A - Via Console:**
1. Firebase Console → App Distribution
2. Click **Testers & Groups** tab
3. Click **Add Testers**
4. Enter email addresses
5. Save

### **Option B - Via CLI:**
```bash
firebase appdistribution:testers:add \
  friend1@gmail.com friend2@gmail.com \
  --project trip-genie-8af8f
```

### **Create Tester Groups:**
```bash
# Create group
firebase appdistribution:group:create "Beta Testers" \
  --project trip-genie-8af8f

# Add testers to group
firebase appdistribution:group:add-testers "Beta Testers" \
  friend1@gmail.com friend2@gmail.com \
  --project trip-genie-8af8f
```

---

## 🔄 **Step 10: Update App (Future Releases)**

When you release a new version:

### **1. Update Version Number**

**File:** `pubspec.yaml`
```yaml
version: 1.0.1+2  # Increment this
```

### **2. Build New APK**
```bash
flutter build apk --release
```

### **3. Upload to Firebase**
```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_ANDROID_APP_ID \
  --release-notes "Bug fixes and improvements" \
  --groups "Beta Testers"
```

### **4. Testers Get Notification**
Existing testers automatically receive:
- 📧 Email notification
- 📱 In-app update prompt (if they have Firebase SDK installed)

---

## 📱 **User Installation Flow**

### **First Time:**
1. User receives share message with Firebase link
2. Clicks link → Opens browser
3. Downloads APK
4. Installs APK (needs "Unknown Sources" permission)
5. Opens app → Logs in
6. Joins trip with code

### **Updates:**
1. Firebase sends email notification
2. User clicks "Download" in email
3. Downloads new APK
4. Installs over existing app (data preserved)

---

## 🎯 **Quick Commands Reference**

```bash
# Build APK
flutter build apk --release

# Distribute APK
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_APP_ID \
  --release-notes "Your notes here" \
  --testers "email1@gmail.com,email2@gmail.com"

# Add testers
firebase appdistribution:testers:add email@gmail.com

# List testers
firebase appdistribution:testers:list

# Remove tester
firebase appdistribution:testers:remove email@gmail.com
```

---

## 🔍 **Find Your App ID**

### **Method 1: Firebase Console**
1. Firebase Console → Project Settings
2. Scroll to "Your apps"
3. Click Android app
4. Copy "App ID"

### **Method 2: google-services.json**
```bash
cd trip_genie/android/app
cat google-services.json | grep mobilesdk_app_id
```

**Format:** `1:123456789012:android:abc123def456ghi789`

---

## 🆘 **Troubleshooting**

### **Issue: "App not found" error**
**Solution:** Make sure you're using the correct App ID
```bash
firebase apps:list android
```

### **Issue: Testers not receiving email**
**Solution:** 
- Check spam folder
- Verify email address is correct
- Tester must accept invite (check Firebase Console → Testers)

### **Issue: "Invalid APK" error**
**Solution:** 
- Use release APK (not debug)
- Ensure APK is signed properly
- Check minimum SDK version

### **Issue: Can't install APK**
**Solution:** Users need to:
1. Enable "Install from Unknown Sources"
2. Settings → Security → Unknown Sources → Enable
3. Or: Settings → Apps → Browser → Install Unknown Apps → Allow

---

## 🎨 **Custom Branding (Optional)**

### **Add App Icon:**
Make sure your app has a proper icon set in:
```
android/app/src/main/res/mipmap-*/ic_launcher.png
```

### **Add Release Notes Template:**
Create file: `release_notes.txt`
```
## What's New in v1.0.1

✨ New Features:
- Group trip collaboration
- Real-time updates
- Trip code sharing

🐛 Bug Fixes:
- Fixed invitation issues
- Improved performance

📱 Download and enjoy!
```

Then distribute with:
```bash
firebase appdistribution:distribute app-release.apk \
  --app YOUR_APP_ID \
  --release-notes-file release_notes.txt
```

---

## 📊 **Analytics & Monitoring**

### **View Distribution Stats:**
1. Firebase Console → App Distribution
2. Click **Releases** tab
3. See:
   - Number of downloads
   - Number of testers
   - Crash reports (if enabled)

### **Enable Crash Reporting:**
Add to `pubspec.yaml`:
```yaml
dependencies:
  firebase_crashlytics: ^3.4.0
```

---

## 🔐 **Security Best Practices**

1. **Don't commit App ID to public repos**
2. **Use environment variables:**
   ```bash
   export FIREBASE_APP_ID="1:123:android:abc"
   ```
3. **Limit tester access** - Only add trusted users
4. **Rotate links** - Generate new links if shared publicly

---

## 🎉 **Success Checklist**

- [ ] Firebase CLI installed and logged in
- [ ] App Distribution enabled in Firebase Console
- [ ] Release APK built successfully
- [ ] APK uploaded to Firebase App Distribution
- [ ] Distribution link copied
- [ ] `appDownloadLink` updated in code
- [ ] Testers added to Firebase
- [ ] Test share message sent
- [ ] Tester successfully installed app
- [ ] Tester joined trip with code

---

## 📞 **Support Links**

- [Firebase App Distribution Docs](https://firebase.google.com/docs/app-distribution)
- [Flutter Build & Release Guide](https://docs.flutter.dev/deployment/android)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)

---

## 🎯 **Quick Start Summary**

```bash
# 1. Build APK
flutter build apk --release

# 2. Upload to Firebase (first time - use console)
# Go to: console.firebase.google.com → App Distribution → Upload

# 3. Get link from Firebase Console
# Example: https://appdistribution.firebase.dev/i/ABC123

# 4. Update code
# Edit: lib/services/group_trip_service.dart
# Line 16: appDownloadLink = 'YOUR_FIREBASE_LINK'

# 5. Test!
# Share trip → Send to friend → Friend downloads & joins
```

---

**That's it! Your app is now ready for easy distribution! 🚀**

**Next time you update:**
1. Build APK
2. Upload to Firebase
3. Testers get notified automatically