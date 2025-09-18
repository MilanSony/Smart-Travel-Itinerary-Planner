import 'package:flutter/material.dart';
import '../models/itinerary_model.dart';

class ItineraryScreen extends StatelessWidget {
  final Itinerary itinerary;

  const ItineraryScreen({super.key, required this.itinerary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(itinerary.destination),
        backgroundColor: const Color(0xFF6A1B9A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Text(
              itinerary.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A ${itinerary.dayPlans.length}-day trip to ${itinerary.destination}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const Divider(height: 32),

            // --- DAY PLANS LIST ---
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(), // Important for nested lists
              shrinkWrap: true,
              itemCount: itinerary.dayPlans.length,
              itemBuilder: (context, index) {
                final dayPlan = itinerary.dayPlans[index];
                return _buildDayPlanCard(dayPlan);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET FOR A SINGLE DAY PLAN ---
  Widget _buildDayPlanCard(DayPlan dayPlan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dayPlan.dayTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A1B9A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dayPlan.description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const Divider(height: 24),

            // --- ACTIVITIES FOR THE DAY ---
            ...dayPlan.activities.map((activity) => _buildActivityTile(activity)).toList(),
          ],
        ),
      ),
    );
  }

  // --- WIDGET FOR A SINGLE ACTIVITY ---
  Widget _buildActivityTile(Activity activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(activity.icon, color: Colors.purple.shade300, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${activity.time} - ${activity.title}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}