# APK Hosting Guide for Trip Genie

## 📦 How to Share Your APK File

Since Trip Genie is not on Play Store/App Store yet, you need to host the APK file online and share the download link.

---

## 🚀 **Quick Steps**

### Step 1: Build Release APK
```bash
cd trip_genie
flutter build apk --release
```
APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

### Step 2: Upload to a Hosting Service
Choose one of the options below.

### Step 3: Update the Link in Code
Replace the link in `lib/services/group_trip_service.dart`:
```dart
static const String appDownloadLink = 'YOUR_ACTUAL_LINK_HERE';
```

---

## 📤 **Option 1: Google Drive (Easiest - FREE)**

### Upload Steps:
1. Go to [Google Drive](https://drive.google.com)
2. Click **New** → **File upload**
3. Upload `app-release.apk`
4. Right-click file → **Share** → **Change to "Anyone with the link"**
5. Copy the sharing link

### Get Direct Download Link:
Original link looks like:
```
https://drive.google.com/file/d/1ABC123XYZ/view?usp=sharing
```

Convert to direct download:
```
https://drive.google.com/uc?export=download&id=1ABC123XYZ
```

### Update in Code:
```dart
static const String appDownloadLink =
    'https://drive.google.com/uc?export=download&id=1ABC123XYZ';
```

✅ **Pros:** Free, Easy, Reliable
❌ **Cons:** Google may show warning (users need to click "Download anyway")

---

## 📤 **Option 2: Dropbox (FREE)**

### Upload Steps:
1. Go to [Dropbox](https://www.dropbox.com)
2. Upload `app-release.apk`
3. Click **Share** → **Create link**
4. Copy the link

### Get Direct Download Link:
Original link:
```
https://www.dropbox.com/s/abc123xyz/app-release.apk?dl=0
```

Change `dl=0` to `dl=1`:
```
https://www.dropbox.com/s/abc123xyz/app-release.apk?dl=1
```

### Update in Code:
```dart
static const String appDownloadLink =
    'https://www.dropbox.com/s/abc123xyz/app-release.apk?dl=1';
```

✅ **Pros:** Free, Direct download
❌ **Cons:** 2GB free storage limit

---

## 📤 **Option 3: Firebase Storage (Recommended - FREE)**

### Setup Steps:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Storage** → **Upload file**
4. Upload `app-release.apk`
5. Click on file → **Get download URL**
6. Copy the URL

### Update in Code:
```dart
static const String appDownloadLink =
    'https://firebasestorage.googleapis.com/v0/b/your-project.appspot.com/o/app-release.apk?alt=media&token=abc123';
```

✅ **Pros:** Fast, Reliable, Already using Firebase
❌ **Cons:** Requires Firebase setup

---

## 📤 **Option 4: GitHub Releases (FREE - For Developers)**

### Setup Steps:
1. Create GitHub repository (if not already)
2. Go to repository → **Releases** → **Create a new release**
3. Upload `app-release.apk` as an asset
4. Publish release
5. Copy download link

### Link Format:
```
https://github.com/username/trip-genie/releases/download/v1.0.0/app-release.apk
```

### Update in Code:
```dart
static const String appDownloadLink =
    'https://github.com/yourusername/trip-genie/releases/download/v1.0.0/app-release.apk';
```

✅ **Pros:** Professional, Version control, Free
❌ **Cons:** Public (unless private repo)

---

## 📤 **Option 5: Free File Hosting Services**

### Services You Can Use:
- **MediaFire:** https://www.mediafire.com
- **File.io:** https://www.file.io
- **WeTransfer:** https://wetransfer.com
- **SendSpace:** https://www.sendspace.com

### Steps:
1. Upload APK to any service
2. Get shareable link
3. Update in code

⚠️ **Warning:** Some services have link expiry or ads

---

## 🔧 **Complete Implementation Example**

### 1. Build APK
```bash
flutter build apk --release
```

### 2. Upload to Google Drive and Get Link
```
https://drive.google.com/uc?export=download&id=1ABC123XYZ
```

### 3. Update in `lib/services/group_trip_service.dart`
```dart
static const String appDownloadLink =
    'https://drive.google.com/uc?export=download&id=1ABC123XYZ';
```

### 4. Test the Share Feature
- Create a trip
- Tap share button
- Verify message includes APK link

---

## 📱 **What Users Will See**

When you share a trip, users receive:

```
🌍 Join my trip to Goa!

📍 Trip: Goa Trip
✨ Beach vacation with friends

📅 Dates: 15/12/2024 - 20/12/2024

🔑 Trip Code: ABC123

👉 To join:
1. Download Trip Genie app (APK): [YOUR_LINK]
2. Install the APK on your Android device
3. Login/Signup with your email
4. Go to Group Trips → Tap "Join with Code" button (🔑 icon)
5. Enter code: ABC123

Let's plan this trip together! 🎉
```

---

## ⚠️ **Important Security Notes**

### Enable APK Installation:
Users need to enable "Install from Unknown Sources":
- **Android 8+:** Settings → Apps → Special Access → Install Unknown Apps → Select Browser → Allow
- **Older Android:** Settings → Security → Unknown Sources → Enable

### Add Warning in Share Message (Optional):
```dart
⚠️ Note: You may need to enable "Install from Unknown Sources" in Android settings
```

---

## 🎯 **Recommended Approach**

**For Quick Testing:** Use **Google Drive** (5 minutes setup)

**For Production:** Use **Firebase Storage** or **GitHub Releases** (Professional, reliable)

---

## 📝 **Quick Copy-Paste Instructions for Users**

Create a simple instruction file to share:

```
HOW TO INSTALL TRIP GENIE

1. Download APK: [YOUR_LINK]
2. Open downloaded file
3. Tap "Install" (allow unknown sources if asked)
4. Open Trip Genie app
5. Sign up/Login
6. Join trip with code: ABC123

Need help? Contact: your@email.com
```

---

## 🔄 **Updating APK**

When you release new version:
1. Build new APK
2. Upload to same location (or new version)
3. Update link in code if needed
4. Share new version with users

---

## ✅ **Checklist**

- [ ] Build release APK
- [ ] Upload to hosting service
- [ ] Get download link
- [ ] Update `appDownloadLink` in code
- [ ] Test sharing functionality
- [ ] Verify download works on another device
- [ ] Add version number for tracking

---

## 💡 **Pro Tips**

1. **Version Naming:** Name your APK like `trip-genie-v1.0.0.apk` for clarity
2. **File Size:** Release APK is usually 15-30MB (easy to download)
3. **QR Code:** Generate QR code for download link (easier to share)
4. **Backup:** Keep APK files backed up for each version

---

## 🆘 **Troubleshooting**

### Problem: Users can't download
- Check if link is public/accessible
- Try link in incognito browser
- Verify no login required

### Problem: APK won't install
- Check minimum Android version (update AndroidManifest.xml)
- Ensure APK is signed properly
- Verify no corruption during upload

### Problem: Link expired
- Use permanent hosting (Firebase/GitHub)
- Avoid temporary file services

---

## 📞 **Support**

If users face issues:
1. Verify Android version (minimum required)
2. Check storage space on device
3. Try different browser for download
4. Re-upload APK if corrupted

---

**Last Updated:** December 2024
**App Version:** 1.0.0