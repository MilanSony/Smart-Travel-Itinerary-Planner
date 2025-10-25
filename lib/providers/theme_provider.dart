import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../config/theme.dart'; // Import your theme definitions

class ThemeProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isDarkMode = false; // Default to light mode

  bool get isDarkMode => _isDarkMode;

  // ✅ NEW: A public getter that returns the correct ThemeData object based on the flag.
  // This is the crucial missing link.
  ThemeData get themeData => _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  ThemeProvider() {
    // When the provider starts, load the theme from the device's local storage first for a fast startup.
    _loadThemeFromLocal();
    // Then, listen for login/logout to sync with Firestore.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        // If a user logs in, load their preference from the cloud.
        _loadThemeFromFirestore(user.uid);
      } else {
        // If a user logs out, reset to the default light theme.
        resetToDefault();
      }
    });
  }

  /// Toggles the theme and saves the preference to both local and cloud storage.
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemeToLocal();    // Save to device
    _saveThemeToFirestore(); // Sync to cloud
    notifyListeners();
  }

  /// Resets the theme to light mode and saves the choice. Used on logout.
  Future<void> resetToDefault() async {
    _isDarkMode = false; // Default to light mode
    await _saveThemeToLocal();
    notifyListeners();
  }

  // --- Private Helper Methods ---

  Future<void> _loadThemeFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> _saveThemeToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> _loadThemeFromFirestore(String uid) async {
    final prefs = await _firestoreService.getUserPreferences(uid);
    if (prefs != null && prefs.containsKey('isDarkMode')) {
      _isDarkMode = prefs['isDarkMode'];
      await _saveThemeToLocal(); // Sync the cloud setting to the local device
      notifyListeners();
    }
  }

  Future<void> _saveThemeToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestoreService.setUserPreferences(user.uid, {'isDarkMode': _isDarkMode});
    }
  }
}