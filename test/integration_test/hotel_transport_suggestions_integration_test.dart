import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_genie/screens/hotel_transport_suggestions_screen.dart';

/// A small test app that navigates to HotelTransportSuggestionsScreen.
class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HotelTransportSuggestionsScreen(
                    destination: 'Mumbai',
                  ),
                ),
              );
            },
            child: const Text('Open Hotel Suggestions'),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'User can navigate to HotelTransportSuggestionsScreen and see basic UI',
    (WidgetTester tester) async {
      // Start a mini app that can navigate to the screen.
      await tester.pumpWidget(const _TestApp());

      // Tap the button to open the hotel/transport suggestions screen.
      await tester.tap(find.text('Open Hotel Suggestions'));
      await tester.pumpAndSettle();

      // Now we should be on the HotelTransportSuggestionsScreen.
      expect(find.text('Stay & Transit'), findsOneWidget); // App bar title
      expect(find.text('Hotels'), findsOneWidget); // Tab label
      expect(find.text('Transport'), findsOneWidget); // Tab label

      // Because data loading is async and may hit network, we only assert
      // that a loading indicator appears, not the final list contents.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );
}

