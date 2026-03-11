import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Debug prints to verify that main() runs on web and to surface Firebase issues.
  // These will appear in the browser console.
  print('TripGenie main() starting');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase.initializeApp completed');
  } catch (e, st) {
    // If Firebase fails to initialize on web, log the error but still start the app
    // so we avoid a completely blank screen.
    print('Error during Firebase.initializeApp: $e');
    print(st);
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const TripGenieApp(),
    ),
  );
}

class TripGenieApp extends StatelessWidget {
  const TripGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    // This Consumer widget will listen for changes in your ThemeProvider
    print('TripGenieApp.build called'); // debug print for web
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Trip Genie',
          // Use the new 'themeData' getter to apply the theme globally
          theme: themeProvider.themeData,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        );
      },
    );
  }
}