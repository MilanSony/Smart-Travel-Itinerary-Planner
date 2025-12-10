import 'package:flutter/material.dart';
import '../models/itinerary_model.dart';
import '../services/pdf_service.dart';
import '../services/itinerary_service.dart';
import '../widgets/image_background.dart';
import 'hotel_transport_suggestions_screen.dart';
import 'budget_estimator_screen.dart';
import 'budget_estimator_screen.dart';

class ItineraryScreen extends StatelessWidget {
  final Itinerary itinerary;

  const ItineraryScreen({super.key, required this.itinerary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: itinerary.dayPlans.length,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,

        appBar: AppBar(
          backgroundColor: const Color(0xFF6C5CE7),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(
            itinerary.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.hotel, color: Colors.white),
              onPressed: () => _showHotelTransportSuggestions(context),
              tooltip: 'Hotels & Transport',
            ),
            IconButton(
              icon: const Icon(Icons.savings, color: Colors.white),
              onPressed: () => _openBudgetEstimator(context),
              tooltip: 'AI Budget Estimator',
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: () => _exportToPdf(context),
              tooltip: 'Download PDF',
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: itinerary.dayPlans.map((plan) => Tab(text: plan.dayTitle)).toList(),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF6C5CE7), // Royal purple
                Color(0xFFA29BFE), // Lavender
                Color(0xFF74B9FF), // Sky blue
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
            children: [
              // Summary and cost information
              if (itinerary.summary != null || itinerary.totalEstimatedCost != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (itinerary.summary != null) ...[
                        Text(
                          'Trip Summary',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          itinerary.summary!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF374151),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (itinerary.totalEstimatedCost != null) ...[
                        Row(
                          children: [
                            Icon(Icons.currency_rupee, color: theme.primaryColor, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              'Estimated Total Cost: ₹${itinerary.totalEstimatedCost!.toStringAsFixed(0)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Day-wise Budget Breakdown',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...itinerary.dayPlans.asMap().entries.map((entry) {
                          final index = entry.key;
                          final dayPlan = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Day ${index + 1}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  '₹${dayPlan.totalEstimatedCost?.toStringAsFixed(0) ?? '0'}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              // Tab content
              Expanded(
                child: TabBarView(
                  children: itinerary.dayPlans.map((plan) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(20.0),
                      itemCount: plan.activities.length,
                      itemBuilder: (context, index) {
                        final activity = plan.activities[index];
                        return _buildTimelineTile(context, theme, activity, index, plan.activities.length);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // A new widget to build the professional timeline tile
  Widget _buildTimelineTile(BuildContext context, ThemeData theme, Activity activity, int index, int total) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- The Timeline Column (Icon and Line) ---
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(activity.icon, color: theme.primaryColor, size: 22),
              ),
              // The vertical line, but not for the last item
              if (index < total - 1)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.primaryColor.withOpacity(0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          // --- The Content Card ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Card(
                color: Colors.white,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time
                      Text(
                        activity.time,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Title
                      Text(
                        activity.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Detailed Description
                      Text(
                        activity.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF4B5563),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Additional Information
                      if (activity.placeDetails != null) ...[
                        _buildPlaceDetails(activity.placeDetails!, theme),
                        const SizedBox(height: 8),
                      ],
                      // Duration and Cost
                      Row(
                        children: [
                          if (activity.estimatedDuration != null) ...[
                            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                activity.estimatedDuration!,
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (activity.cost != null) ...[
                            Icon(Icons.currency_rupee, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                activity.cost!,
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceDetails(PlaceDetails place, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (place.address != null) ...[
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    place.address!,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (place.openingHours != null) ...[
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Hours: ${place.openingHours!}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (place.phone != null) ...[
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    place.phone!,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (place.website != null) ...[
            Row(
              children: [
                Icon(Icons.language, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Website available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.blue[600],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showHotelTransportSuggestions(BuildContext context) async {
    // Get destination coordinates
    final itineraryService = ItineraryService();
    final coords = await itineraryService.getDestinationCoordinates(itinerary.destination);
    
    // Use dates from itinerary if available, otherwise calculate from duration
    DateTime? startDate = itinerary.startDate;
    DateTime? endDate = itinerary.endDate;
    
    if (startDate == null || endDate == null) {
      // Calculate dates from itinerary duration (estimate start date as today, end date based on number of days)
      final numberOfDays = itinerary.dayPlans.length;
      startDate = DateTime.now();
      endDate = startDate.add(Duration(days: numberOfDays));
    }
    
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HotelTransportSuggestionsScreen(
            destination: itinerary.destination,
            destinationLat: coords?['lat'],
            destinationLon: coords?['lon'],
            startDate: startDate,
            endDate: endDate,
          ),
        ),
      );
    }
  }

  Future<void> _exportToPdf(BuildContext context) async {
    try {
      // Show loading dialog with more informative message
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Generating PDF...'),
              const SizedBox(height: 8),
              Text(
                'Creating your itinerary for ${itinerary.destination}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Generate and export PDF
      final success = await PdfService.exportItineraryToPdf(itinerary);

      // Hide loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        // Show success message with more details
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('PDF exported successfully!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      } else {
        // Show error message with more details
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Failed to export PDF. Please try again.'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message with more details
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _openBudgetEstimator(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BudgetEstimatorScreen(
          tripId: itinerary.title,
          destination: itinerary.destination,
          startDate: itinerary.startDate,
          endDate: itinerary.endDate,
          travelers: 2, // default fallback; planner can adjust
          initialBudget: itinerary.totalEstimatedCost,
          itinerary: itinerary,
          budgetLevel: null,
        ),
      ),
    );
  }
}
