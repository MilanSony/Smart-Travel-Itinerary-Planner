import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/group_trip_service.dart';
import '../models/group_trip_model.dart';
import '../config/group_trip_theme.dart';

class CreateGroupTripScreen extends StatefulWidget {
  const CreateGroupTripScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupTripScreen> createState() => _CreateGroupTripScreenState();
}

class _CreateGroupTripScreenState extends State<CreateGroupTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final GroupTripService _groupTripService = GroupTripService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _meetingPointController = TextEditingController();
  final TextEditingController _timeToReachController = TextEditingController();
  TimeOfDay? _timeToReachTime;
  final TextEditingController _specialInstructionsController =
      TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  String _selectedTransportation = 'Car';

  @override
  void dispose() {
    _titleController.dispose();
    _destinationController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _contactNumberController.dispose();
    _meetingPointController.dispose();
    _timeToReachController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Select start date',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Auto-adjust end date if it's before start date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime firstDate = _startDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? firstDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Select end date',
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        // Calculate duration
        if (_startDate != null) {
          final duration = _endDate!.difference(_startDate!).inDays + 1;
          _durationController.text = duration.toString();
        }
      });
    }
  }

  Future<void> _selectTimeToReach() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _timeToReachTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _timeToReachTime = picked;
        final formatted = picked.format(context);
        final tz = _formatTimezoneLabel();
        _timeToReachController.text = '$formatted ($tz)';
      });
    }
  }

  String _formatTimezoneLabel() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final tzName = now.timeZoneName;
    return '$tzName (UTC$sign$hours:$minutes)';
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation
    if (_startDate != null && _endDate != null) {
      if (_endDate!.isBefore(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End date must be after start date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int? durationInDays;
      if (_durationController.text.isNotEmpty) {
        durationInDays = int.tryParse(_durationController.text);
      } else if (_startDate != null && _endDate != null) {
        durationInDays = _endDate!.difference(_startDate!).inDays + 1;
      }

      final tripId = await _groupTripService.createGroupTrip(
        title: _titleController.text.trim(),
        destination: _destinationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        durationInDays: durationInDays,
        contactNumber: _contactNumberController.text.trim().isEmpty
            ? null
            : _contactNumberController.text.trim(),
        meetingPoint: _meetingPointController.text.trim().isEmpty
            ? null
            : _meetingPointController.text.trim(),
        transportationType: _selectedTransportation,
        timeToReach: _timeToReachController.text.trim().isEmpty
            ? null
            : _timeToReachController.text.trim(),
        specialInstructions: _specialInstructionsController.text.trim().isEmpty
            ? null
            : _specialInstructionsController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, tripId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating trip: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      backgroundColor: GroupTripTheme.backgroundLightPeach,
      appBar: AppBar(
        title: const Text('Create Group Trip'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: GroupTripTheme.sunsetGradient,
          ),
        ),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: GroupTripTheme.travelGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: GroupTripTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.group_add,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Plan Together',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a trip and invite friends to collaborate',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Trip Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Trip Title *',
                hintText: 'e.g., Summer Beach Vacation',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a trip title';
                }
                if (value.trim().length < 3) {
                  return 'Title must be at least 3 characters';
                }
                if (value.trim().length > 100) {
                  return 'Title must be less than 100 characters';
                }
                // Allow letters, numbers, spaces, and common punctuation
                if (!RegExp(r"^[a-zA-Z0-9\s,\-'\.!]+$")
                    .hasMatch(value.trim())) {
                  return 'Title contains invalid characters';
                }
                return null;
              },
              maxLength: 100,
            ),

            const SizedBox(height: 16),

            // Destination
            TextFormField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: 'Destination *',
                hintText: 'e.g., Paris',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a destination';
                }
                if (value.trim().length < 2) {
                  return 'Destination must be at least 2 characters';
                }
                if (value.trim().length > 100) {
                  return 'Destination must be less than 100 characters';
                }
                // Allow letters and spaces only (no numbers or punctuation)
                if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                  return 'Destination should contain letters and spaces only';
                }
                return null;
              },
              maxLength: 100,
            ),

            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Add details about your trip...',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              maxLength: 500,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  if (value.trim().length < 10) {
                    return 'Description should be at least 10 characters';
                  }
                  if (value.trim().length > 500) {
                    return 'Description must be less than 500 characters';
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Duration
            TextFormField(
              controller: _durationController,
              decoration: InputDecoration(
                labelText: 'Duration (Days)',
                hintText: 'e.g., 5',
                prefixIcon: const Icon(Icons.event_available),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                suffixText: 'days',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final duration = int.tryParse(value.trim());
                  if (duration == null) {
                    return 'Please enter a valid number';
                  }
                  if (duration < 1) {
                    return 'Duration must be at least 1 day';
                  }
                  if (duration > 365) {
                    return 'Duration must be less than 365 days';
                  }
                }
                return null;
              },
              onChanged: (value) {
                // If duration is manually entered, calculate end date from start date
                if (_startDate != null && value.isNotEmpty) {
                  final duration = int.tryParse(value);
                  if (duration != null && duration > 0) {
                    setState(() {
                      _endDate = _startDate!.add(Duration(days: duration - 1));
                    });
                  }
                }
              },
            ),

            const SizedBox(height: 24),

            // Date Selection Section
            Text(
              'Trip Dates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 0,
                    color: Colors.blue[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.blue[200]!),
                    ),
                    child: InkWell(
                      onTap: _selectStartDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Start Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _startDate != null
                                  ? dateFormat.format(_startDate!)
                                  : 'Select date',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _startDate != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _startDate != null
                                    ? Colors.blue[900]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    elevation: 0,
                    color: Colors.green[50],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.green[200]!),
                    ),
                    child: InkWell(
                      onTap: _selectEndDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.event,
                                    size: 16, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'End Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _endDate != null
                                  ? dateFormat.format(_endDate!)
                                  : 'Select date',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _endDate != null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _endDate != null
                                    ? Colors.green[900]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Info Card
            const SizedBox(height: 24),

            // Section Header - Additional Details
            Text(
              'Additional Trip Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Contact Number
            TextFormField(
              controller: _contactNumberController,
              decoration: InputDecoration(
                labelText: 'Contact Number *',
                hintText: '10-digit number',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter contact number';
                }
                if (value.trim().length != 10) {
                  return 'Contact number must be exactly 10 digits';
                }
                if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
                  return 'Contact number must contain only digits';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Pickup Spot
            TextFormField(
              controller: _meetingPointController,
              decoration: InputDecoration(
                labelText: 'Pickup Spot (Optional)',
                hintText: 'e.g., City Center',
                prefixIcon: const Icon(Icons.place),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  if (value.trim().length < 3) {
                    return 'Pickup spot must be at least 3 characters';
                  }
                  // Allow letters and spaces only (no numbers or punctuation)
                  if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                    return 'Pickup spot should contain letters and spaces only';
                  }
                }
                return null;
              },
              maxLength: 200,
            ),

            const SizedBox(height: 16),

            // Transportation Type
            DropdownButtonFormField<String>(
              value: _selectedTransportation,
              decoration: InputDecoration(
                labelText: 'Transportation',
                prefixIcon: const Icon(Icons.directions_car),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: ['Car', 'Public Transport','Self Arranged', 'Other']
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please select a transportation type';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _selectedTransportation = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Time to Reach
            GestureDetector(
              onTap: _selectTimeToReach,
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _timeToReachController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Time to Reach (Optional)',
                    hintText: 'Select time',
                    prefixIcon: const Icon(Icons.access_time),
                    suffixIcon: _timeToReachTime != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _timeToReachTime = null;
                                _timeToReachController.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      // Accept both 24-hour (HH:MM like 14:30) and 12-hour (HH:MM AM/PM) formats
                      final pattern = RegExp(
                          r'^(?:[01]?\d|2[0-3]):[0-5]\d(?:\s?(?:AM|PM))?',
                          caseSensitive: false);
                      if (!pattern.hasMatch(value.trim())) {
                        return 'Invalid time format (expected HH:MM or HH:MM AM/PM)';
                      }
                    }
                    return null;
                  },
                  maxLength: 100,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Device timezone display
            Text(
              _formatTimezoneLabel(),
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),

            const SizedBox(height: 16),

            // Special Instructions
            TextFormField(
              controller: _specialInstructionsController,
              decoration: InputDecoration(
                labelText: 'Special Instructions (Optional)',
                hintText: 'e.g., Bring warm clothes, valid ID required...',
                prefixIcon: const Icon(Icons.info),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              maxLength: 500,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  if (value.trim().length < 5) {
                    return 'Instructions must be at least 5 characters';
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can invite friends to collaborate after creating the trip. Members can view and edit the itinerary together.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Create Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _createTrip,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _isLoading ? 'Creating...' : 'Create Trip',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
