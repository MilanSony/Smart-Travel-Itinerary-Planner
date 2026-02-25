import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_genie/screens/hotel_transport_suggestions_screen.dart';

void main() {
  testWidgets(
    'HotelTransportSuggestionsScreen shows app bar title and tabs',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HotelTransportSuggestionsScreen(
            destination: 'Mumbai',
          ),
        ),
      );

      // App bar title
      expect(find.text('Stay & Transit'), findsOneWidget);

      // Tab labels
      expect(find.text('Hotels'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
    },
  );

  testWidgets(
    'HotelTransportSuggestionsScreen shows loading indicator initially',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HotelTransportSuggestionsScreen(
            destination: 'Mumbai',
          ),
        ),
      );

      // On first frame _isLoading is true, so a CircularProgressIndicator should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );
}
