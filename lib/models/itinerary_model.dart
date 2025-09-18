import 'package:flutter/material.dart';

class Activity {
  final String time;
  final String title;
  final String description;
  final IconData icon;

  Activity({
    required this.time,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class DayPlan {
  final String dayTitle;
  final String description;
  final List<Activity> activities;

  DayPlan({
    required this.dayTitle,
    required this.description,
    required this.activities,
  });
}

class Itinerary {
  final String destination;
  final String title;
  final List<DayPlan> dayPlans;

  Itinerary({
    required this.destination,
    required this.title,
    required this.dayPlans,
  });
}