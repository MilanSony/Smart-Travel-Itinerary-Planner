import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';
import '../services/ride_matching_service.dart';
import '../widgets/travel_theme_background.dart';
import 'offer_ride_screen.dart' show validPlaces;

class MyMatchesScreen extends StatefulWidget {
  const MyMatchesScreen({super.key});

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> {
  final RideMatchingService _rideService = RideMatchingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please login to view matches'),
      );
    }

    return TravelThemeBackground(
      theme: TravelTheme.myMatches,
      child: StreamBuilder<List<RideMatch>>(
        stream: _rideService.getUserRideMatches(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final matches = snapshot.data ?? [];

          if (matches.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.handshake, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No ride matches yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Request rides to see matches here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              return _RideMatchCard(match: match);
            },
          );
        },
      ),
    );
  }
}

class _RideMatchCard extends StatefulWidget {
  final RideMatch match;

  const _RideMatchCard({required this.match});

  @override
  State<_RideMatchCard> createState() => _RideMatchCardState();
}

class _RideMatchCardState extends State<_RideMatchCard> {
  final RideMatchingService _rideService = RideMatchingService();
  bool _isProcessing = false;

  Future<void> _acceptMatch() async {
    final contactInfo = await _showContactInfoDialog();
    if (contactInfo == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _rideService.acceptRideMatch(
        widget.match.id,
        driverContact: contactInfo['contact']!,
        driverPickupLocation: contactInfo['pickupLocation']!,
        driverPickupTime: contactInfo['pickupTime']!,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride match accepted! Contact info shared.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting match: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Generates and sends vehicle entry OTP to passenger's email
  Future<void> _verifyPassengerEntry() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Generate and send OTP to passenger's email
      final otp = await _rideService.generateAndSendVehicleEntryOTP(
        widget.match.id,
        widget.match.passengerEmail,
      );

      if (mounted) {
        // Show OTP to driver (in production, OTP is sent via email)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to ${widget.match.passengerEmail}. OTP: $otp (Passenger will share this with you)'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 5),
          ),
        );

        // Show dialog for driver to enter OTP that passenger shares
        await _showVehicleEntryOTPDialog(widget.match.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating OTP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Shows dialog for driver to enter OTP that passenger shares
  Future<void> _showVehicleEntryOTPDialog(String matchId) async {
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isVerifying = false;
    bool? verificationResult;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.green),
              SizedBox(width: 8),
              Text('Verify Passenger Entry'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'An OTP has been sent to the passenger\'s email. Ask the passenger to share the 6-digit OTP they received:',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: otpController,
                  enabled: !isVerifying && verificationResult != true,
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP Shared by Passenger *',
                    hintText: '000000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => 
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('$currentLength / $maxLength digits'),
                    ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'OTP is required';
                    }
                    if (value.trim().length != 6) {
                      return 'OTP must be 6 digits';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                      return 'OTP must contain only digits';
                    }
                    return null;
                  },
                ),
                if (isVerifying) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (verificationResult == true) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Verified! Passenger can enter the vehicle.'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (verificationResult != true) ...[
              if (!isVerifying)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ElevatedButton(
                onPressed: isVerifying ? null : () async {
                  if (formKey.currentState!.validate()) {
                    setState(() => isVerifying = true);
                    // Verify the OTP
                    final isValid = await _rideService.verifyVehicleEntryOTP(matchId, otpController.text.trim());
                    setState(() {
                      isVerifying = false;
                      verificationResult = isValid;
                    });
                    
                    if (isValid && context.mounted) {
                      await Future.delayed(const Duration(milliseconds: 500));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Passenger verified! They can now enter the vehicle.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid OTP. Please ask passenger for the correct OTP.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Verify OTP'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Future<void> _rejectMatch() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _rideService.rejectRideMatch(widget.match.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride match rejected.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting match: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _completeMatch() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _rideService.completeRideMatch(widget.match.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Ride completed successfully! Thank you for using our service.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing match: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }


  Future<Map<String, String>?> _showContactInfoDialog() async {
    final contactController = TextEditingController();
    final pickupLocationController = TextEditingController();
    final pickupTimeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Share Your Contact Info',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Your Contact Number *',
                      hintText: '9876543210',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => 
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('$currentLength / $maxLength digits'),
                      ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      // Check for exactly 10 digits
                      if (value.trim().length != 10) {
                        return 'Phone number must be exactly 10 digits';
                      }
                      // Check if all characters are digits
                      if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                        return 'Phone number must contain only digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pickupLocationController,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Location *',
                      hintText: 'Where will you pick up?',
                      border: OutlineInputBorder(),
                      helperText: 'Enter a valid place in India',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      // Check if the entered value matches any valid place
                      final enteredValue = value.trim();
                      final isInvalid = !validPlaces.any(
                        (place) => place.toLowerCase() == enteredValue.toLowerCase() ||
                                   place.toLowerCase().contains(enteredValue.toLowerCase()) ||
                                   enteredValue.toLowerCase().contains(place.toLowerCase())
                      );
                      if (isInvalid) {
                        return 'Invalid place. Enter a valid place in India';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pickupTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Time *',
                      hintText: '09:00 AM',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context, {
                              'contact': contactController.text.trim(),
                              'pickupLocation': pickupLocationController.text.trim(),
                              'pickupTime': pickupTimeController.text.trim(),
                            });
                          }
                        },
                        child: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with passenger info
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.match.passengerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.match.passengerEmail,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.match.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status-specific content
            if (widget.match.status == 'pending') ...[
              const Text(
                'New ride request from passenger',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _acceptMatch,
                      icon: _isProcessing 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _rejectMatch,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (widget.match.status == 'accepted') ...[
              // Show driver contact info that was shared
              if (widget.match.driverContact != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Driver Contact Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Contact: ${widget.match.driverContact}'),
                      Text('Pickup Location: ${widget.match.driverPickupLocation}'),
                      Text('Pickup Time: ${widget.match.driverPickupTime}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Show passenger contact status
              if (widget.match.passengerContact == null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Waiting for Passenger Contact', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      SizedBox(height: 8),
                      Text('The passenger needs to share their contact details from the Find Rides section.'),
                    ],
                  ),
                ),
              ] else ...[
                // Show passenger contact info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Passenger Contact Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Name: ${widget.match.passengerName}'),
                      Text('Contact: ${widget.match.passengerContact}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Vehicle entry verification button
                if (!widget.match.vehicleEntryVerified) ...[
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _verifyPassengerEntry,
                    icon: _isProcessing 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user),
                    label: const Text('Verify Passenger Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Passenger Entry Verified', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Show completion button
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _completeMatch,
                  icon: _isProcessing 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle),
                  label: const Text('Mark as Completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ] else if (widget.match.status == 'rejected') ...[
              const Text(
                'Ride request was rejected',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
            ] else if (widget.match.status == 'completed') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Ride completed successfully!',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.match.status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
