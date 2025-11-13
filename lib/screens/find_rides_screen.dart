import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';
import '../services/ride_matching_service.dart';
import '../widgets/gradient_background.dart';
import '../config/theme.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryNavy,
                    AppTheme.primaryNavyLight,
                    AppTheme.accentBlue.withOpacity(0.6),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find Rides',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your journey with fellow travelers',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<RideOffer>>(
                stream: _rideService.getActiveRideOffers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: AppTheme.lightTextSecondary),
                          ),
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
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryNavy.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.directions_car_rounded,
                              size: 64,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No ride offers available',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later for new offers',
                            style: TextStyle(
                              color: AppTheme.lightTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _createSampleOffers,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create Sample Offers'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: offers.length,
                    itemBuilder: (context, index) {
                      final offer = offers[index];
                      return _RideOfferCard(offer: offer);
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with driver info
            Row(
              children: [
                Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryNavy.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: widget.offer.userPhotoUrl != null
                          ? NetworkImage(widget.offer.userPhotoUrl!)
                          : null,
                      backgroundColor: AppTheme.primaryNavy.withOpacity(0.1),
                      child: widget.offer.userPhotoUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: AppTheme.primaryNavy,
                              size: 28,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.offer.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.offer.userEmail,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.offer.availableSeats > 0 
                          ? Colors.green.withOpacity(0.1) 
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.offer.availableSeats > 0 
                            ? Colors.green 
                            : Colors.red,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      widget.offer.availableSeats > 0 
                          ? '${widget.offer.availableSeats} seats' 
                          : 'No seats',
                      style: TextStyle(
                        color: widget.offer.availableSeats > 0 
                            ? Colors.green[700] 
                            : Colors.red[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            
            // Route info with modern design
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryNavy.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on, color: Colors.red, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.offer.pickupLocation,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.flag, color: Colors.green, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'To',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.offer.destination,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Date, time and vehicle info in a row
            Row(
              children: [
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.calendar_today,
                      label: '${widget.offer.pickupDate.day}/${widget.offer.pickupDate.month}/${widget.offer.pickupDate.year}',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.access_time,
                      label: widget.offer.pickupTime,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            _InfoChip(
              icon: Icons.directions_car_rounded,
              label: '${widget.offer.vehicleModel} (${widget.offer.vehicleNumber})',
              color: AppTheme.primaryNavy,
            ),
            const SizedBox(height: 20),

            // Cost with modern design
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentOrange.withOpacity(0.15),
                    AppTheme.accentOrange.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentOrange.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.currency_rupee_rounded,
                          color: AppTheme.accentOrange,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cost per seat',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightTextSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${widget.offer.costPerSeat.toInt()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),

            // Additional info
            if (widget.offer.additionalInfo != null && widget.offer.additionalInfo!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Additional Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.offer.additionalInfo!,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_isRequesting || widget.offer.availableSeats <= 0) ? null : _requestRide,
                      icon: _isRequesting 
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.handshake, size: 20),
                      label: Text(
                        _isRequesting 
                            ? 'Requesting...' 
                            : widget.offer.availableSeats <= 0 
                                ? 'No Seats' 
                                : 'Request Ride',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.offer.availableSeats <= 0 
                            ? Colors.grey[400] 
                            : Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
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
                        
                        return OutlinedButton.icon(
                          onPressed: () => _showContactInfo(),
                          icon: Icon(
                            hasAcceptedMatch ? Icons.contact_phone_rounded : Icons.info_outline_rounded,
                            size: 20,
                          ),
                          label: const Text(
                            'Contact Info',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: hasAcceptedMatch 
                                ? Colors.green[600] 
                                : AppTheme.primaryNavy,
                            side: BorderSide(
                              color: hasAcceptedMatch 
                                  ? Colors.green[600]! 
                                  : AppTheme.primaryNavy,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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

  // Removed old OTP verification methods - now using vehicle entry OTP only
  
  Future<void> _sharePassengerContact(RideMatch match) async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final contactInfo = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Your Contact Details'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter your full name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
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
                    return 'Phone number is required';
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
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

// Info Chip Widget
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color.withOpacity(0.9),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
