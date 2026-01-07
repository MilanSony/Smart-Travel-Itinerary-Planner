#!/bin/bash

# Firebase App Distribution Quick Setup Script
# For Trip Genie App

echo "🚀 Firebase App Distribution Setup"
echo "===================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Firebase CLI is installed
echo -e "${BLUE}Checking Firebase CLI...${NC}"
if ! command -v firebase &> /dev/null
then
    echo -e "${RED}❌ Firebase CLI not found${NC}"
    echo ""
    echo "Installing Firebase CLI..."
    npm install -g firebase-tools
    echo -e "${GREEN}✅ Firebase CLI installed${NC}"
else
    echo -e "${GREEN}✅ Firebase CLI found${NC}"
fi

echo ""

# Login to Firebase
echo -e "${BLUE}Logging into Firebase...${NC}"
firebase login
echo -e "${GREEN}✅ Logged in${NC}"

echo ""

# Build APK
echo -e "${BLUE}Building release APK...${NC}"
flutter build apk --release

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ APK built successfully${NC}"
else
    echo -e "${RED}❌ APK build failed${NC}"
    exit 1
fi

echo ""

# Get App ID
echo -e "${YELLOW}📱 Finding your Firebase App ID...${NC}"
echo ""
echo "Go to Firebase Console and get your Android App ID:"
echo "1. Visit: https://console.firebase.google.com/project/trip-genie-8af8f/settings/general"
echo "2. Scroll to 'Your apps' section"
echo "3. Click on Android app"
echo "4. Copy the App ID (format: 1:123456789:android:abc123)"
echo ""
read -p "Enter your Firebase Android App ID: " APP_ID

echo ""

# Get release notes
echo -e "${YELLOW}📝 Release Notes${NC}"
read -p "Enter release notes (or press Enter for default): " RELEASE_NOTES

if [ -z "$RELEASE_NOTES" ]; then
    RELEASE_NOTES="Trip Genie - Group Trip Collaboration Feature"
fi

echo ""

# Get tester emails
echo -e "${YELLOW}👥 Add Testers${NC}"
echo "Enter tester email addresses (comma-separated), or press Enter to skip:"
read -p "Emails: " TESTERS

echo ""

# Distribute APK
echo -e "${BLUE}📤 Uploading APK to Firebase App Distribution...${NC}"

if [ -z "$TESTERS" ]; then
    # No testers specified
    firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
        --app "$APP_ID" \
        --release-notes "$RELEASE_NOTES"
else
    # With testers
    firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
        --app "$APP_ID" \
        --release-notes "$RELEASE_NOTES" \
        --testers "$TESTERS"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ APK uploaded successfully!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo "1. Go to Firebase Console:"
    echo "   https://console.firebase.google.com/project/trip-genie-8af8f/appdistribution"
    echo ""
    echo "2. Click on your release"
    echo ""
    echo "3. Copy the 'Installation link' (format: https://appdistribution.firebase.dev/i/ABC123)"
    echo ""
    echo "4. Update the link in your code:"
    echo "   File: lib/services/group_trip_service.dart"
    echo "   Line 17: appDownloadLink = 'YOUR_COPIED_LINK'"
    echo ""
    echo "5. Test by sharing a trip!"
    echo ""
    echo -e "${GREEN}🎉 Setup complete!${NC}"
else
    echo -e "${RED}❌ Upload failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "- Verify your App ID is correct"
    echo "- Check you're logged into the correct Firebase account"
    echo "- Ensure App Distribution is enabled in Firebase Console"
    exit 1
fi
