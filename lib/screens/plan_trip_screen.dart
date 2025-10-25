import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/itinerary_model.dart';
import '../services/itinerary_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'itinerary_screen.dart';

class PlanTripScreen extends StatefulWidget {
  const PlanTripScreen({super.key});

  @override
  State<PlanTripScreen> createState() => _PlanTripScreenState();
}

class _PlanTripScreenState extends State<PlanTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  int _travelers = 1;
  String? _selectedTransportation;
  final Set<String> _selectedInterests = {};
  bool _isLoading = false;

  final ItineraryService _itineraryService = ItineraryService();
  final List<String> _interestOptions = ['Food', 'Nature', 'Culture', 'Shopping', 'Adventure'];
  final List<String> _transportOptions = ['Bike Sharing', 'Rental Car', 'Public Transport'];

  @override
  void dispose() {
    _destinationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;

    final result = await showDialog<DateTimeRange?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select range'),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    // Show selected dates if any
                    if (tempStartDate != null || tempEndDate != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.deepPurple, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              tempStartDate != null && tempEndDate != null
                                  ? '${DateFormat('MMM d').format(tempStartDate!)} - ${DateFormat('MMM d').format(tempEndDate!)}'
                                  : tempStartDate != null
                                      ? 'Start: ${DateFormat('MMM d').format(tempStartDate!)}'
                                      : 'Select dates',
                              style: TextStyle(
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Calendar
                    Expanded(
                      child: CalendarDatePicker(
                        initialDate: tempStartDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(DateTime.now().year + 5),
                        onDateChanged: (date) {
                          if (tempStartDate == null) {
                            tempStartDate = date;
                          } else if (tempEndDate == null) {
                            if (date.isAfter(tempStartDate!) || date.isAtSameMomentAs(tempStartDate!)) {
                              tempEndDate = date;
                            } else {
                              tempStartDate = date;
                              tempEndDate = null;
                            }
                          } else {
                            tempStartDate = date;
                            tempEndDate = null;
                          }
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (tempStartDate != null && tempEndDate != null)
                      ? () {
                          Navigator.of(context).pop(
                            DateTimeRange(start: tempStartDate!, end: tempEndDate!),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
      _saveDates();
    }
  }

  void _saveDates() {
    if (_startDate != null && _endDate != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dates saved: ${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }


  Future<void> _handleGenerateItinerary() async {
    final isFormValid = _formKey.currentState!.validate();
    if (!isFormValid) return;

    if (_startDate == null || _endDate == null) {
      _showErrorSnackBar('Please select your travel dates.');
      return;
    }
    if (_selectedInterests.isEmpty) {
      _showErrorSnackBar('Please select at least one interest.');
      return;
    }
    if (_selectedTransportation == 'Bike Sharing' && _travelers > 2 && _travelers % 2 != 0) {
      _showErrorSnackBar('For an odd number of travelers, please select another transport option.');
      return;
    }

    setState(() => _isLoading = true);
    
    // Show loading message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating your personalized itinerary... This may take a moment.'),
        backgroundColor: Colors.deepPurple,
        duration: Duration(seconds: 3),
      ),
    );
    
    try {
      final destination = _destinationController.text.trim();
      final duration = _endDate!.difference(_startDate!).inDays + 1;

      final itinerary = await _itineraryService.generateItinerary(
        destination: destination,
        durationInDays: duration,
        interests: _selectedInterests.toList(),
        travelers: _travelers,
        budget: _budgetController.text.isNotEmpty ? _budgetController.text : null,
        transportation: _selectedTransportation,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - please try again');
        },
      );

      if (mounted) {
        if (itinerary != null) {
          // Save basic trip info to Firestore for My Trips
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            print('Saving trip for user: ${user.uid}');
            print('Destination: ${itinerary.destination}');
            print('Title: ${itinerary.title}');
            
            try {
              final firestore = FirestoreService();
              final tripId = await firestore.createTrip(
                userId: user.uid,
                destination: itinerary.destination,
                title: itinerary.title,
                durationInDays: duration,
                interests: _selectedInterests.toList(),
                budget: _budgetController.text.isNotEmpty ? _budgetController.text : null,
                itinerarySummary: {
                  'days': itinerary.dayPlans.length,
                  'totalEstimatedCost': itinerary.totalEstimatedCost,
                  'previewActivities': itinerary.dayPlans.isNotEmpty
                      ? itinerary.dayPlans.first.activities.take(3).map((a) => a.title).toList()
                      : [],
                },
              );
              print('Trip saved successfully with ID: $tripId');
            } catch (e) {
              print('Error saving trip: $e');
            }
          } else {
            print('No user found, cannot save trip');
          }

          Navigator.push(context, MaterialPageRoute(builder: (context) => ItineraryScreen(itinerary: itinerary)));
        } else {
          _showErrorSnackBar('Sorry, no itinerary could be generated for "$destination". It might be an unsupported location.');
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'An error occurred. Please try again.';
        
        if (e.toString().contains('timeout')) {
          errorMessage = 'Request timed out. Please check your internet connection and try again.';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = 'No internet connection. Please check your network and try again.';
        } else if (e.toString().contains('HandshakeException')) {
          errorMessage = 'Connection error. Please try again.';
        }
        
        _showErrorSnackBar(errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Plan a New Trip'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.deepPurple,
        elevation: 2,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Where do you want to go?'),
              TextFormField(
                controller: _destinationController,
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a destination' : null,
                decoration: _buildInputDecoration('Enter Destination', Icons.location_on_outlined),
              ),
              _buildSectionHeader('Select your travel dates'),
              InkWell(
                onTap: _selectDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        _startDate == null ? 'Select Dates' : '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                        style: TextStyle(color: _startDate == null ? Colors.grey.shade600 : Colors.black, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildSectionHeader('Travelers'), _buildTravelerCounter()])),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Budget'),
                        TextFormField(
                          controller: _budgetController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            final parsed = double.tryParse(value);
                            if (parsed == null) return 'Enter a valid number';
                            if (parsed < 2000) return 'Min ₹2000';
                            if (parsed > 100000) return 'Max ₹100000';
                            return null;
                          },
                          decoration: _buildInputDecoration('Amount', Icons.currency_rupee),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _buildSectionHeader('How do you like to get around?'),
              DropdownButtonFormField<String>(
                value: _selectedTransportation,
                items: _transportOptions.map((method) => DropdownMenuItem(value: method, child: Text(method))).toList(),
                onChanged: (value) => setState(() => _selectedTransportation = value),
                validator: (value) => value == null ? 'Please select an option' : null,
                decoration: _buildInputDecoration('Select Transportation', Icons.directions_car_outlined),
              ),
              _buildSectionHeader('What are your interests?'),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _interestOptions.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    onSelected: (selected) => setState(() => selected ? _selectedInterests.add(interest) : _selectedInterests.remove(interest)),
                    selectedColor: Colors.deepPurple.withOpacity(0.1),
                    checkmarkColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.deepPurple : Colors.grey.shade300)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleGenerateItinerary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Generating...', style: TextStyle(fontSize: 18)),
                        ],
                      )
                    : const Text('Generate Itinerary', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 20.0, bottom: 12.0),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
  );

  InputDecoration _buildInputDecoration(String hintText, IconData icon) => InputDecoration(
    hintText: hintText,
    prefixIcon: Icon(icon, color: Colors.grey),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
  );

  Widget _buildTravelerCounter() => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.remove, color: Colors.deepPurple), onPressed: () => {if (_travelers > 1) setState(() => _travelers--)}),
        Text('$_travelers', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.add, color: Colors.deepPurple), onPressed: () => setState(() => _travelers++)),
      ],
    ),
  );
}