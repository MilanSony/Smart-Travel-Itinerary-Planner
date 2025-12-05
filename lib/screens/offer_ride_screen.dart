import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ride_matching_service.dart';
import '../widgets/travel_theme_background.dart';

// Comprehensive list of valid places in India
const List<String> validPlaces = [
  // Kerala
  'Thiruvananthapuram', 'Kochi', 'Ernakulam', 'Kollam', 'Thrissur', 'Kozhikode', 'Palakkad',
  'Malappuram', 'Kannur', 'Alappuzha', 'Kottayam', 'Idukki', 'Kasaragod', 'Pathanamthitta', 'Wayanad',
  'Aluva', 'Paravur', 'Arakunnam', 'Vaikom', 'Karunagappally', 'Kayamkulam', 'Chengannur', 'Changanassery',
  'Thiruvananthapuram Central', 'Kochi Central', 'Ernakulam Junction', 'Kollam Junction', 
  'Thrissur Railway Station', 'Kochi Airport', 'Thiruvananthapuram Airport',
  
  // Karnataka
  'Bangalore', 'Mysore', 'Mangalore', 'Hubli', 'Belgaum', 'Gulbarga', 'Davanagere', 'Bellary', 
  'Tumkur', 'Raichur', 'Shimoga', 'Udupi', 'Mysore Junction', 'Bangalore City Railway Station',
  'Mangalore Railway Station', 'Hubli Junction', 'Belgaum Railway Station', 'Bangalore Airport',
  
  // Tamil Nadu
  'Chennai', 'Coimbatore', 'Madurai', 'Salem', 'Tiruchirappalli', 'Tirunelveli', 'Erode', 
  'Dindigul', 'Tanjore', 'Vellore', 'Thanjavur', 'Tuticorin', 'Chennai Central', 'Chennai Airport',
  
  // Maharashtra
  'Mumbai', 'Pune', 'Nagpur', 'Aurangabad', 'Nashik', 'Amravati', 'Solapur', 'Sangli', 
  'Nanded', 'Kolhapur', 'Mumbai Central', 'Pune Railway Station', 'Mumbai Airport', 'Pune Airport',
  
  // Goa
  'Panaji', 'Margao', 'Vasco', 'Mapusa', 'Goa',
  
  // Delhi
  'Delhi', 'New Delhi', 'New Delhi Railway Station', 'Delhi Airport',
  
  // Andhra Pradesh
  'Hyderabad', 'Vijayawada', 'Visakhapatnam', 'Guntur', 'Tirupati', 'Hyderabad Railway Station',
  'Secunderabad Junction', 'Hyderabad Airport',
  
  // Gujarat
  'Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Jamnagar', 'Ahmedabad Railway Station',
  'Ahmedabad Airport',
  
  // West Bengal
  'Kolkata', 'Howrah', 'Howrah Junction', 'Sealdah', 'Kolkata Airport',
  
  // Rajasthan
  'Jaipur', 'Jodhpur', 'Udaipur', 'Ajmer', 'Jaipur Railway Station', 'Jaipur Airport',
  
  // Uttar Pradesh
  'Lucknow', 'Kanpur', 'Varanasi', 'Allahabad', 'Agra', 'Lucknow Railway Station',
  
  // Madhya Pradesh
  'Indore', 'Bhopal', 'Jabalpur', 'Gwalior',
  
  // Punjab
  'Amritsar', 'Ludhiana', 'Chandigarh', 'Jalandhar',
  
  // Haryana
  'Gurgaon', 'Faridabad', 'Panipat',
  
  // Bihar
  'Patna', 'Gaya', 'Bhagalpur',
  
  // Orissa
  'Bhubaneswar', 'Cuttack', 'Puri',
  
  // Assam
  'Guwahati', 'Jorhat', 'Tezpur',
  
  // Jammu and Kashmir
  'Srinagar', 'Jammu', 'Leh',
  
  // Himachal Pradesh
  'Shimla', 'Manali', 'Dharamshala',
  
  // Uttarakhand
  'Dehradun', 'Haridwar', 'Nainital',
  
  // Telangana
  'Warangal', 'Karimnagar', 'Nizamabad',
  
  // Kerala Cities and Towns
  'Adoor', 'Alappuzha', 'Attingal', 'Beypore', 'Chalakudy', 'Changanassery', 'Cherthala',
  'Guruvayur', 'Kannur', 'Kasargod', 'Kothamangalam', 'Manjeri', 'Muvattupuzha', 'Nedumangad',
  'Neyyattinkara', 'Ottapalam', 'Palakkad', 'Payyanur', 'Perinthalmanna', 'Ponnani', 'Punalur',
  'Shoranur', 'Taliparamba', 'Thalassery', 'Tirur', 'Varkala',
  
  // Karnataka Cities
  'Bangalore', 'Bellary', 'Bijapur', 'Davangere', 'Gadag', 'Gulbarga', 'Hassan', 'Karwar',
  'Koppal', 'Mandya', 'Mangalore', 'Raichur', 'Shimoga', 'Tumkur', 'Udupi', 'Yadgir',
  
  // Tamil Nadu Cities
  'Dindigul', 'Kanchipuram', 'Karaikudi', 'Kumbakonam', 'Mayiladuthurai', 'Namakkal',
  'Pudukkottai', 'Ramanathapuram', 'Sivakasi', 'Thanjavur', 'Thoothukudi', 'Tiruppur',
  'Tirunelveli', 'Tiruvannamalai', 'Vellore',
  
  // Maharashtra Cities
  'Ahmednagar', 'Akola', 'Amravati', 'Bhir', 'Buldhana', 'Jalgaon', 'Kolhapur',
  'Latur', 'Nagpur', 'Nashik', 'Osmanabad', 'Parbhani', 'Pune', 'Sangli', 'Satara',
  'Solapur', 'Thane', 'Wardha', 'Yavatmal',
  
  // Railway Stations (Major)
  'Bangalore City Railway Station', 'Mumbai Central', 'Chennai Central', 'Howrah Junction',
  'New Delhi Railway Station', 'Kolkata Howrah', 'Secunderabad Junction', 'Ahmedabad Railway Station',
  'Jaipur Railway Station', 'Lucknow Railway Station', 'Pune Railway Station',
  'Mangalore Railway Station', 'Hubli Junction', 'Thrissur Railway Station',
  'Ernakulam Junction', 'Kochi Central', 'Kollam Junction',
  
  // Airports
  'Delhi Airport', 'Mumbai Airport', 'Bangalore Airport', 'Chennai Airport', 'Kolkata Airport',
  'Hyderabad Airport', 'Pune Airport', 'Cochin Airport', 'Thiruvananthapuram Airport',
  'Goa Airport', 'Jaipur Airport', 'Ahmedabad Airport',
];

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final RideMatchingService _rideService = RideMatchingService();
  final _formKey = GlobalKey<FormState>();
  
  final _destinationController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _pickupTimeController = TextEditingController();
  final _availableSeatsController = TextEditingController();
  final _costPerSeatController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _additionalInfoController = TextEditingController();

  DateTime _pickupDate = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;

  @override
  void dispose() {
    _destinationController.dispose();
    _pickupLocationController.dispose();
    _pickupTimeController.dispose();
    _availableSeatsController.dispose();
    _costPerSeatController.dispose();
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _pickupDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() {
        _pickupDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    // If no time is selected, start with 9:00 AM, otherwise use current selection
    TimeOfDay initialTime = const TimeOfDay(hour: 9, minute: 0);
    if (_pickupTimeController.text.isNotEmpty) {
      final parts = _pickupTimeController.text.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          initialTime = TimeOfDay(hour: hour, minute: minute);
        }
      }
    }
    
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time != null) {
      setState(() {
        _pickupTimeController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Additional validation for pickup time
    if (_pickupTimeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pickup time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _rideService.createRideOffer(
        destination: _destinationController.text.trim(),
        pickupLocation: _pickupLocationController.text.trim(),
        pickupDate: _pickupDate,
        pickupTime: _pickupTimeController.text.trim(),
        availableSeats: int.parse(_availableSeatsController.text),
        costPerSeat: double.parse(_costPerSeatController.text),
        vehicleNumber: _vehicleNumberController.text.trim(),
        vehicleModel: _vehicleModelController.text.trim(),
        additionalInfo: _additionalInfoController.text.trim().isEmpty 
            ? null 
            : _additionalInfoController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride offer created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        setState(() {
          _pickupDate = DateTime.now().add(const Duration(days: 1));
          _pickupTimeController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating offer: $e'),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TravelThemeBackground(
        theme: TravelTheme.offerRide,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Share Your Ride',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Destination
              TextFormField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: 'Destination *',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                  hintText: 'Where are you going?',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter destination';
                  }
                  // Check if the entered value matches any valid place (case-insensitive)
                  final enteredValue = value.trim();
                  final isInvalid = !validPlaces.any(
                    (place) => place.toLowerCase() == enteredValue.toLowerCase() ||
                               place.toLowerCase().contains(enteredValue.toLowerCase()) ||
                               enteredValue.toLowerCase().contains(place.toLowerCase())
                  );
                  if (isInvalid) {
                    return 'Invalid place chosen. Please enter a valid place in India (e.g., Kochi, Goa, Chennai)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Pickup Location
              TextFormField(
                controller: _pickupLocationController,
                decoration: const InputDecoration(
                  labelText: 'Pickup Location *',
                  prefixIcon: Icon(Icons.my_location),
                  border: OutlineInputBorder(),
                  hintText: 'Where will you pick up passengers?',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter pickup location';
                  }
                  // Check if the entered value matches any valid place (case-insensitive)
                  final enteredValue = value.trim();
                  final isInvalid = !validPlaces.any(
                    (place) => place.toLowerCase() == enteredValue.toLowerCase() ||
                               place.toLowerCase().contains(enteredValue.toLowerCase()) ||
                               enteredValue.toLowerCase().contains(place.toLowerCase())
                  );
                  if (isInvalid) {
                    return 'Invalid place chosen. Please enter a valid place in India (e.g., Mangalore, Goa, Mumbai)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Pickup Date and Time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Pickup Date *',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          '${_pickupDate.day}/${_pickupDate.month}/${_pickupDate.year}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Pickup Time *',
                          prefixIcon: const Icon(Icons.access_time),
                          border: const OutlineInputBorder(),
                          errorText: _pickupTimeController.text.isEmpty ? 'Please select pickup time' : null,
                        ),
                        child: Text(_pickupTimeController.text.isEmpty 
                            ? 'Select Time' 
                            : _pickupTimeController.text),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Available Seats and Cost
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _availableSeatsController,
                      decoration: const InputDecoration(
                        labelText: 'Available Seats *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final seats = int.tryParse(value);
                        if (seats == null || seats < 1 || seats > 8) {
                          return '1-8 seats';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _costPerSeatController,
                      decoration: const InputDecoration(
                        labelText: 'Cost per Seat (₹) *',
                        prefixIcon: Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final cost = double.tryParse(value);
                        if (cost == null || cost < 0) {
                          return 'Invalid amount';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Vehicle Number
              TextFormField(
                controller: _vehicleNumberController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Number *',
                  prefixIcon: Icon(Icons.directions_car),
                  border: OutlineInputBorder(),
                  hintText: 'e.g., KL-05-A-3772',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter vehicle number';
                  }
                  // Check Indian vehicle registration format: XX-XX-X-XXXX
                  final regex = RegExp(r'^[A-Z]{2}-\d{2}-[A-Z]{1,2}-\d{4}$');
                  if (!regex.hasMatch(value.trim().toUpperCase())) {
                    return 'Format: XX-XX-X-XXXX (e.g., KL-05-A-3772)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Vehicle Model
              TextFormField(
                controller: _vehicleModelController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Model *',
                  prefixIcon: Icon(Icons.directions_car),
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Honda City, Maruti Swift',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter vehicle model';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Additional Info
              TextFormField(
                controller: _additionalInfoController,
                decoration: const InputDecoration(
                  labelText: 'Additional Information (Optional)',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                  hintText: 'Any special instructions or notes',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitOffer,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_isLoading ? 'Creating...' : 'Offer Ride'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
        ),
    );
  }
}
