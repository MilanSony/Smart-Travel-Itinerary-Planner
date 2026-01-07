@echo off
REM Firebase App Distribution Quick Setup Script
REM For Trip Genie App - Windows Version

echo.
echo ====================================
echo Firebase App Distribution Setup
echo ====================================
echo.

REM Check if Firebase CLI is installed
echo Checking Firebase CLI...
firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Firebase CLI not found
    echo.
    echo Installing Firebase CLI...
    npm install -g firebase-tools
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to install Firebase CLI
        echo Please install Node.js first from: https://nodejs.org
        pause
        exit /b 1
    )
    echo [SUCCESS] Firebase CLI installed
) else (
    echo [SUCCESS] Firebase CLI found
)

echo.

REM Login to Firebase
echo Logging into Firebase...
firebase login
if %errorlevel% neq 0 (
    echo [ERROR] Login failed
    pause
    exit /b 1
)
echo [SUCCESS] Logged in
echo.

REM Build APK
echo Building release APK...
flutter build apk --release
if %errorlevel% neq 0 (
    echo [ERROR] APK build failed
    pause
    exit /b 1
)
echo [SUCCESS] APK built successfully
echo.

REM Get App ID
echo ================================================
echo Finding your Firebase App ID...
echo ================================================
echo.
echo Go to Firebase Console and get your Android App ID:
echo 1. Visit: https://console.firebase.google.com/project/trip-genie-8af8f/settings/general
echo 2. Scroll to 'Your apps' section
echo 3. Click on Android app
echo 4. Copy the App ID (format: 1:123456789:android:abc123)
echo.
set /p APP_ID="Enter your Firebase Android App ID: "

echo.

REM Get release notes
echo ================================================
echo Release Notes
echo ================================================
set /p RELEASE_NOTES="Enter release notes (or press Enter for default): "

if "%RELEASE_NOTES%"=="" (
    set RELEASE_NOTES=Trip Genie - Group Trip Collaboration Feature
)

echo.

REM Get tester emails
echo ================================================
echo Add Testers
echo ================================================
echo Enter tester email addresses (comma-separated), or press Enter to skip:
set /p TESTERS="Emails: "

echo.

REM Distribute APK
echo Uploading APK to Firebase App Distribution...
echo.

if "%TESTERS%"=="" (
    REM No testers specified
    firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --app "%APP_ID%" --release-notes "%RELEASE_NOTES%"
) else (
    REM With testers
    firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --app "%APP_ID%" --release-notes "%RELEASE_NOTES%" --testers "%TESTERS%"
)

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Upload failed
    echo.
    echo Troubleshooting:
    echo - Verify your App ID is correct
    echo - Check you're logged into the correct Firebase account
    echo - Ensure App Distribution is enabled in Firebase Console
    echo.
    pause
    exit /b 1
)

echo.
echo [SUCCESS] APK uploaded successfully!
echo.
echo ================================================
echo Next Steps:
echo ================================================
echo.
echo 1. Go to Firebase Console:
echo    https://console.firebase.google.com/project/trip-genie-8af8f/appdistribution
echo.
echo 2. Click on your release
echo.
echo 3. Copy the 'Installation link'
echo    Format: https://appdistribution.firebase.dev/i/ABC123
echo.
echo 4. Update the link in your code:
echo    File: lib\services\group_trip_service.dart
echo    Line 17: appDownloadLink = 'YOUR_COPIED_LINK'
echo.
echo 5. Test by sharing a trip!
echo.
echo ================================================
echo Setup complete!
echo ================================================
echo.
pause
