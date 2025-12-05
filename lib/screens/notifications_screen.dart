import 'package:flutter/material.dart';
import '../widgets/travel_theme_background.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> notifications = [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: TravelThemeBackground(
        theme: TravelTheme.notifications,
        child: notifications.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 80,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              const SizedBox(height: 16),
              Text(
                'No New Notifications',
                style: TextStyle(
                  fontSize: 22,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re all caught up!',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        )
            : ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(notifications[index]),
            );
          },
        ),
        ),
    );
  }
}