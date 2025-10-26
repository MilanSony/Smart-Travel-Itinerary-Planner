import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';
import '../services/ride_matching_service.dart';
import '../widgets/gradient_background.dart';

class FindRidesScreen extends StatefulWidget {
  const FindRidesScreen({super.key});

  @override
  State<FindRidesScreen> createState() => _FindRidesScreenState();
}

class _FindRidesScreenState extends State<FindRidesScreen> {
  final RideMatchingService _rideService = RideMatchingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _createSampleOffers() async {
    try {
      // Create sample ride offers for testing
      await _rideService.createRideOffer(
        destination: 'Kochi',
        pickupLocation: 'Thiruvananthapuram Central',
        pickupDate: DateTime.now().add(const Duration(days: 2)),
        pickupTime: '08:00',
        availableSeats: 2,
        costPerSeat: 300.0,
        vehicleNumber: 'KL-01-AB-1234',
        vehicleModel: 'Maruti Swift',
        additionalInfo: 'Comfortable ride with AC',
      );
      
      await _rideService.createRideOffer(
        destination: 'Bangalore',
        pickupLocation: 'Kochi Airport',
        pickupDate: DateTime.now().add(const Duration(days: 3)),
        pickupTime: '14:30',
        availableSeats: 3,
        costPerSeat: 800.0,
        vehicleNumber: 'KL-02-CD-5678',
        vehicleModel: 'Toyota Innova',
        additionalInfo: 'Spacious vehicle for long journey',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample ride offers created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating sample offers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: StreamBuilder<List<RideOffer>>(
        stream: _rideService.getActiveRideOffers(),
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

          final offers = snapshot.data ?? [];

          if (offers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_car, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No ride offers available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check back later for new offers',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _createSampleOffers,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Sample Offers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              return _RideOfferCard(offer: offer);
            },
          );
        },
      ),
    );
  }
}

class _RideOfferCard extends StatefulWidget {
  final RideOffer offer;

  const _RideOfferCard({required this.offer});

  @override
  State<_RideOfferCard> createState() => _RideOfferCardState();
}

class _RideOfferCardState extends State<_RideOfferCard> {
  final RideMatchingService _rideService = RideMatchingService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isRequesting = false;

  Future<void> _requestRide() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to request rides'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (user.uid == widget.offer.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot request your own ride'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isRequesting = true;
    });

    try {
      // Create ride request
      final requestId = await _rideService.createRideRequest(widget.offer.id);
      
      // Create ride match
      await _rideService.createRideMatch(
        rideOfferId: widget.offer.id,
        rideRequestId: requestId,
        driverUserId: widget.offer.userId,
        driverName: widget.offer.userName,
        driverEmail: widget.offer.userEmail,
        passengerUserId: user.uid,
        passengerName: user.displayName ?? 'Unknown User',
        passengerEmail: user.email ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride request sent! Check My Matches for updates.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
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
            // Header with driver info
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.offer.userPhotoUrl != null
                      ? NetworkImage(widget.offer.userPhotoUrl!)
                      : null,
                  child: widget.offer.userPhotoUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.offer.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.offer.userEmail,
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
                    color: widget.offer.availableSeats > 0 ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.offer.availableSeats > 0 
                        ? '${widget.offer.availableSeats} seats' 
                        : 'No seats',
                    style: TextStyle(
                      color: widget.offer.availableSeats > 0 ? Colors.green[800] : Colors.red[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Route info
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.offer.pickupLocation,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.offer.destination,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date and time
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '${widget.offer.pickupDate.day}/${widget.offer.pickupDate.month}/${widget.offer.pickupDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  widget.offer.pickupTime,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vehicle info
            Row(
              children: [
                const Icon(Icons.directions_car, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '${widget.offer.vehicleModel} (${widget.offer.vehicleNumber})',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cost
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cost per seat:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '₹${widget.offer.costPerSeat.toInt()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),

            // Additional info
            if (widget.offer.additionalInfo != null && widget.offer.additionalInfo!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Additional Information:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.offer.additionalInfo!),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isRequesting || widget.offer.availableSeats <= 0) ? null : _requestRide,
                    icon: _isRequesting 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.handshake),
                    label: Text(_isRequesting ? 'Requesting...' : 
                               widget.offer.availableSeats <= 0 ? 'No Seats' : 'Request Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.offer.availableSeats <= 0 ? Colors.grey[400] : Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<List<RideMatch>>(
                    stream: _rideService.getPassengerRideMatches(_auth.currentUser!.uid),
                    builder: (context, snapshot) {
                      final hasAcceptedMatch = snapshot.data?.any(
                        (match) => match.rideOfferId == widget.offer.id && 
                                   match.status == 'accepted' && 
                                   match.driverContact != null
                      ) ?? false;
                      
                      // Check if passenger has shared their contact
                      final hasPassengerSharedContact = snapshot.data?.any(
                        (match) => match.rideOfferId == widget.offer.id && 
                                   match.status == 'accepted' && 
                                   match.passengerContact != null
                      ) ?? false;
                      
                      return OutlinedButton.icon(
                        onPressed: () => _showContactInfo(),
                        icon: Icon(hasAcceptedMatch ? Icons.contact_phone : Icons.info_outline),
                        label: Text(hasAcceptedMatch ? 'Contact Info' : 'Contact Info'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: hasAcceptedMatch ? Colors.green[600] : Colors.blue[600],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showContactInfo() async {
    // Check if there's an accepted match for this offer
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get ride matches for this user
      final matchesSnapshot = await _rideService.getPassengerRideMatches(user.uid).first;
      final acceptedMatch = matchesSnapshot.firstWhere(
        (match) => match.rideOfferId == widget.offer.id && match.status == 'accepted',
        orElse: () => RideMatch(
          id: '',
          rideOfferId: '',
          rideRequestId: '',
          driverUserId: '',
          driverName: '',
          driverEmail: '',
          passengerUserId: '',
          passengerName: '',
          passengerEmail: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (acceptedMatch.id.isNotEmpty && acceptedMatch.driverContact != null) {
        // Show actual contact info with passenger contact sharing option
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Driver Contact Information'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Driver: ${acceptedMatch.driverName}'),
                const SizedBox(height: 8),
                Text('Email: ${acceptedMatch.driverEmail}'),
                const SizedBox(height: 8),
                Text('Contact: ${acceptedMatch.driverContact}'),
                const SizedBox(height: 8),
                Text('Pickup Location: ${acceptedMatch.driverPickupLocation}'),
                const SizedBox(height: 8),
                Text('Pickup Time: ${acceptedMatch.driverPickupTime}'),
                const SizedBox(height: 16),
                
                // Show passenger contact sharing section
                if (acceptedMatch.passengerContact == null) ...[
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
                        Text('Share Your Contact Details', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Please share your contact information with the driver.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
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
                        const Text('Your Contact Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Name: ${acceptedMatch.passengerName}'),
                        Text('Contact: ${acceptedMatch.passengerContact}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: const Text(
                    'Contact details are now available! You can coordinate with the driver directly.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              if (acceptedMatch.passengerContact == null) ...[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _sharePassengerContact(acceptedMatch);
                  },
                  child: const Text('Share My Contact'),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ],
          ),
        );
      } else {
        // Show pending message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Contact Information'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Driver: ${widget.offer.userName}'),
                const SizedBox(height: 8),
                Text('Email: ${widget.offer.userEmail}'),
                const SizedBox(height: 8),
                const Text('Contact details will be shared after ride acceptance.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: const Text(
                    'Contact information will be available after the driver accepts your request.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Show error or default message
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contact Information'),
          content: const Text('Unable to load contact information. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _sharePassengerContact(RideMatch match) async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();

    final contactInfo = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Your Contact Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name *',
                border: OutlineInputBorder(),
                hintText: 'Enter your full name',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: contactController,
              decoration: const InputDecoration(
                labelText: 'Your Contact Number *',
                hintText: '+91 9876543210',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty &&
                  contactController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'name': nameController.text.trim(),
                  'contact': contactController.text.trim(),
                });
              }
            },
            child: const Text('Share Contact'),
          ),
        ],
      ),
    );

    if (contactInfo != null) {
      try {
        await _rideService.updatePassengerContact(
          match.id,
          passengerName: contactInfo['name']!,
          passengerContact: contactInfo['contact']!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact details shared successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error sharing contact: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
