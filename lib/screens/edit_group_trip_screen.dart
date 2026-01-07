import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/group_trip_service.dart';
import '../models/group_trip_model.dart';
import '../config/group_trip_theme.dart';

class EditGroupTripScreen extends StatefulWidget {
  final String tripId;

  const EditGroupTripScreen({Key? key, required this.tripId}) : super(key: key);

  @override
  State<EditGroupTripScreen> createState() => _EditGroupTripScreenState();
}

class _EditGroupTripScreenState extends State<EditGroupTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final GroupTripService _groupTripService = GroupTripService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPublic = false;
  bool _isLoading = true;
  bool _isSaving = false;
  GroupTrip? _trip;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final trip = await _groupTripService.getTrip(widget.tripId);
      if (trip != null && mounted) {
        setState(() {
          _trip = trip;
          _titleController.text = trip.title;
          _destinationController.text = trip.destination;
          _descriptionController.text = trip.description ?? '';
          _durationController.text = trip.durationInDays?.toString() ?? '';
          _startDate = trip.startDate;
          _endDate = trip.endDate;
          _isPublic = trip.isPublic;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trip: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _destinationController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
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

  Future<void> _saveChanges() async {
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
      _isSaving = true;
    });

    try {
      int? durationInDays;
      if (_durationController.text.isNotEmpty) {
        durationInDays = int.tryParse(_durationController.text);
      } else if (_startDate != null && _endDate != null) {
        durationInDays = _endDate!.difference(_startDate!).inDays + 1;
      }

      await _groupTripService.updateGroupTrip(
        tripId: widget.tripId,
        title: _titleController.text.trim(),
        destination: _destinationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        durationInDays: durationInDays,
        isPublic: _isPublic,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating trip: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    if (_isLoading) {
      return Scaffold(
        backgroundColor: GroupTripTheme.backgroundLightPeach,
        appBar: AppBar(
          title: const Text('Edit Trip'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: GroupTripTheme.sunsetGradient,
            ),
          ),
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: GroupTripTheme.backgroundLightPeach,
      appBar: AppBar(
        title: const Text('Edit Trip'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: GroupTripTheme.sunsetGradient,
          ),
        ),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: _isSaving ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Trip Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Trip Title *',
                hintText: 'e.g., Summer Vacation 2024',
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
                hintText: 'e.g., Paris, France',
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
              maxLines: 4,
              maxLength: 500,
              validator: (value) {
                if (value != null && value.trim().length > 500) {
                  return 'Description must be less than 500 characters';
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

            // Public/Private Toggle
            Card(
              elevation: 0,
              color: Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Public Trip',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _isPublic
                      ? 'Anyone with the link can view this trip'
                      : 'Only invited members can view this trip',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                value: _isPublic,
                onChanged: (value) {
                  setState(() {
                    _isPublic = value;
                  });
                },
                secondary: Icon(
                  _isPublic ? Icons.public : Icons.lock,
                  color: _isPublic ? Colors.green : Colors.orange,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Changes',
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
