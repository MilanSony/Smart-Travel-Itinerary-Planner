import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';

class ThemeProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemeFromLocal();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _loadThemeFromFirestore(user.uid);
      }
    });
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemeToLocal();
    _saveThemeToFirestore();
    notifyListeners();
  }

  // --- THIS FUNCTION WAS MISSING ---
  // It resets the theme to light mode and saves the choice to the device
  Future<void> resetToDefault() async {
    _isDarkMode = false; // Default to light mode
    await _saveThemeToLocal();
    notifyListeners();
  }

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
    if (prefs != null) {
      _isDarkMode = prefs['isDarkMode'] ?? _isDarkMode;
      await _saveThemeToLocal();
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