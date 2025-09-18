import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// IMPORTANT: Make sure these import paths are correct for your project structure
import '../models/itinerary_model.dart';
import '../services/static_itinerary_service.dart';
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

  // --- State Variables ---
  DateTime? _startDate;
  DateTime? _endDate;
  int _travelers = 1; // Default traveler count is 1
  String? _selectedTransportation;
  final Set<String> _selectedInterests = {};

  final double _minBudget = 2000.0;
  final List<String> _interestOptions = ['Food', 'Nature', 'Culture', 'Shopping', 'Adventure'];
  final List<String> _transportOptions = ['Bike Sharing', 'Rental Car', 'Public Transit', 'Ride Hailing'];

  @override
  void dispose() {
    _destinationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  // --- LOGIC METHODS ---

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: const Color(0xFF6A1B9A), onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _submitForm() {
    final isFormValid = _formKey.currentState!.validate();
    final areDatesValid = _startDate != null && _endDate != null;
    final areInterestsValid = _selectedInterests.isNotEmpty;

    if (isFormValid && areDatesValid && areInterestsValid) {
      // --- Integration with Static Itinerary Service ---
      final destination = _destinationController.text;
      // Calculate duration in days. +1 to make it inclusive.
      final duration = _endDate!.difference(_startDate!).inDays + 1;

      final Itinerary? itinerary = StaticItineraryService.getItinerary(destination, duration);

      if (itinerary != null) {
        // Navigate to the results screen if an itinerary is found
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItineraryScreen(itinerary: itinerary),
          ),
        );
      } else {
        // Show an error message if no pre-written itinerary exists
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sorry, no pre-written itinerary found for "$destination".'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Handle validation failures for non-form fields
      if (!areDatesValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select your travel dates.'), backgroundColor: Colors.redAccent),
        );
      } else if (!areInterestsValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one interest.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // --- UI BUILDER WIDGETS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bikesNeeded = _selectedTransportation == 'Bike Sharing' ? (_travelers / 2).ceil() : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5).withOpacity(0.5),
      appBar: AppBar(
        title: const Text('Plan a New Trip'),
        backgroundColor: const Color(0xFF6A1B9A),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -- Destination --
              TextFormField(
                controller: _destinationController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Please enter a destination';
                  if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) return 'Please enter a valid name (letters only)';
                  return null;
                },
                decoration: _inputDecoration('Enter Destination', Icons.location_on_outlined),
              ),

              // -- Dates --
              _buildSectionHeader('Select your travel dates'),
              InkWell(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        _startDate == null ? 'Select Dates' : '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM, yyyy').format(_endDate!)}',
                        style: TextStyle(color: _startDate == null ? Colors.grey.shade600 : Colors.black, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              // -- Travelers & Budget Row --
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Travelers Counter --
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Travelers'),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(icon: const Icon(Icons.remove), onPressed: () => {if (_travelers > 1) setState(() => _travelers--)}),
                              Text('$_travelers', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _travelers++)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // -- Budget Field --
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
                            final budget = double.tryParse(value);
                            if (budget == null) return 'Invalid number';
                            if (budget < _minBudget) return 'Min budget is ₹${_minBudget.toInt()}';
                            return null;
                          },
                          decoration: _inputDecoration('Amount', null).copyWith(
                            prefixIcon: const Padding(
                              padding: EdgeInsets.fromLTRB(12, 12, 8, 12),
                              child: Text('₹', style: TextStyle(fontSize: 18, color: Colors.grey)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // -- Dynamic Bike Sharing Info --
              if (bikesNeeded > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                          children: [
                            const TextSpan(text: 'This will require '),
                            TextSpan(text: '$bikesNeeded bike${bikesNeeded > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
                            const TextSpan(text: ' for your group.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // -- Transportation --
              _buildSectionHeader('How do you like to get around?'),
              DropdownButtonFormField<String>(
                value: _selectedTransportation,
                items: _transportOptions.map((method) => DropdownMenuItem(value: method, child: Text(method))).toList(),
                onChanged: (value) => setState(() => _selectedTransportation = value),
                validator: (value) => value == null ? 'Please select an option' : null,
                decoration: _inputDecoration('Select transportation', Icons.directions_car_outlined),
              ),

              // -- Interests --
              _buildSectionHeader('What are your interests?'),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _interestOptions.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) _selectedInterests.add(interest);
                        else _selectedInterests.remove(interest);
                      });
                    },
                    selectedColor: const Color(0xFF6A1B9A).withOpacity(0.3),
                    checkmarkColor: const Color(0xFF6A1B9A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF6A1B9A) : Colors.grey.shade400)),
                  );
                }).toList(),
              ),

              // -- Submit Button --
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Generate Itinerary', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText, IconData? icon) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
    );
  }
}