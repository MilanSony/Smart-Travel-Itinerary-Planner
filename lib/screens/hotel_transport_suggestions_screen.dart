import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hotel_transport_model.dart';
import '../services/hotel_transport_service.dart';
import '../services/itinerary_service.dart';

class HotelTransportSuggestionsScreen extends StatefulWidget {
  final String destination;
  final double? destinationLat;
  final double? destinationLon;
  final DateTime? startDate;
  final DateTime? endDate;

  const HotelTransportSuggestionsScreen({
    super.key,
    required this.destination,
    this.destinationLat,
    this.destinationLon,
    this.startDate,
    this.endDate,
  });

  @override
  State<HotelTransportSuggestionsScreen> createState() => _HotelTransportSuggestionsScreenState();
}

class _HotelTransportSuggestionsScreenState extends State<HotelTransportSuggestionsScreen>
    with SingleTickerProviderStateMixin {
  final HotelTransportService _service = HotelTransportService();
  final ItineraryService _itineraryService = ItineraryService();

  late TabController _tabController;
  bool _isLoading = true;
  List<HotelSuggestion> _hotels = [];
  List<TransportSuggestion> _transportOptions = [];
  String _sortBy = 'distance'; // distance | rating | price

  // Filter state
  HotelTransportFilters _filters = HotelTransportFilters();
  bool _showFilters = false;

  // Filter controllers
  final TextEditingController _minBudgetController = TextEditingController();
  final TextEditingController _maxBudgetController = TextEditingController();
  final TextEditingController _minRatingController = TextEditingController();
  final TextEditingController _maxDistanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Set default budget values
    _minBudgetController.text = '500';
    _maxBudgetController.text = '10000';
    _loadSuggestions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    _minRatingController.dispose();
    _maxDistanceController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);

    try {
      // Validate destination name - only letters and spaces allowed (no numbers)
      final destination = widget.destination.trim();
      if (destination.isEmpty || RegExp(r'[0-9]').hasMatch(destination)) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid destination name. Only letters and spaces are allowed (no numbers).'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Get destination coordinates if not provided
      double centerLat = widget.destinationLat ?? 0.0;
      double centerLon = widget.destinationLon ?? 0.0;

      if (centerLat == 0.0 || centerLon == 0.0) {
        // Geocode destination to get coordinates
        final coords = await _itineraryService.getDestinationCoordinates(widget.destination);
        if (coords != null) {
          centerLat = coords['lat']!;
          centerLon = coords['lon']!;
        } else {
          // Fallback to default coordinates (Bangalore)
          centerLat = 12.9716;
          centerLon = 77.5946;
        }
      }

      // Fetch hotels and transport
      final hotels = await _service.fetchHotels(
        destination: widget.destination,
        centerLat: centerLat,
        centerLon: centerLon,
        filters: _filters,
        startDate: widget.startDate,
        endDate: widget.endDate,
      );

      final transport = await _service.fetchTransportOptions(
        destination: widget.destination,
        centerLat: centerLat,
        centerLon: centerLon,
        filters: _filters,
      );

      setState(() {
        _hotels = hotels;
        _transportOptions = transport;
        _applySorting();
        _isLoading = false;
      });

      // Inform user with a brief status snackbar
      if (mounted) {
        final hotelCount = hotels.length;
        final transportCount = transport.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found $hotelCount hotels and $transportCount transport options'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading suggestions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applySorting() {
    switch (_sortBy) {
      case 'rating':
        _hotels.sort((a, b) {
          final ar = a.rating ?? -1;
          final br = b.rating ?? -1;
          final cmp = br.compareTo(ar);
          if (cmp != 0) return cmp;
          final ad = a.distanceFromCenter ?? double.infinity;
          final bd = b.distanceFromCenter ?? double.infinity;
          return ad.compareTo(bd);
        });
        _transportOptions.sort((a, b) {
          final ad = a.distanceFromCenter ?? double.infinity;
          final bd = b.distanceFromCenter ?? double.infinity;
          return ad.compareTo(bd);
        });
        break;
      case 'price':
        _hotels.sort((a, b) {
          final ap = a.pricePerNight ?? double.infinity;
          final bp = b.pricePerNight ?? double.infinity;
          final cmp = ap.compareTo(bp);
          if (cmp != 0) return cmp;
          final ad = a.distanceFromCenter ?? double.infinity;
          final bd = b.distanceFromCenter ?? double.infinity;
          return ad.compareTo(bd);
        });
        _transportOptions.sort((a, b) {
          final ac = a.estimatedCost ?? double.infinity;
          final bc = b.estimatedCost ?? double.infinity;
          final cmp = ac.compareTo(bc);
          if (cmp != 0) return cmp;
          final ad = a.distanceFromCenter ?? double.infinity;
          final bd = b.distanceFromCenter ?? double.infinity;
          return ad.compareTo(bd);
        });
        break;
      case 'distance':
      default:
        _hotels.sort((a, b) {
          final ad = a.distanceFromCenter ?? double.infinity;
          final bd = b.distanceFromCenter ?? double.infinity;
          return ad.compareTo(bd);
        });
        _transportOptions.sort((a, b) {
          final ad = a.distanceFromCenter ?? double.infinity;
          final bd = b.distanceFromCenter ?? double.infinity;
          return ad.compareTo(bd);
        });
        break;
    }
  }

  void _applyFilters() {
    // Validate budget range
    final minBudget = _minBudgetController.text.isNotEmpty
        ? double.tryParse(_minBudgetController.text)
        : 500.0;
    final maxBudget = _maxBudgetController.text.isNotEmpty
        ? double.tryParse(_maxBudgetController.text)
        : 10000.0;
    
    if (minBudget != null && (minBudget < 500 || minBudget > 10000)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum budget must be between ₹500 and ₹10000'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (maxBudget != null && (maxBudget < 500 || maxBudget > 10000)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum budget must be between ₹500 and ₹10000'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (minBudget != null && maxBudget != null && minBudget > maxBudget) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum budget cannot be greater than maximum budget'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validate rating (0-5)
    double? minRating;
    if (_minRatingController.text.isNotEmpty) {
      minRating = double.tryParse(_minRatingController.text);
      if (minRating != null && (minRating < 0 || minRating > 5)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating must be between 0 and 5'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // Validate distance (0-25KM)
    double? maxDistance;
    if (_maxDistanceController.text.isNotEmpty) {
      maxDistance = double.tryParse(_maxDistanceController.text);
      if (maxDistance != null && (maxDistance < 0 || maxDistance > 25)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Distance must be between 0 and 25 km'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    setState(() {
      _filters = HotelTransportFilters(
        minBudget: minBudget,
        maxBudget: maxBudget,
        minRating: minRating,
        maxDistance: maxDistance,
      );
      _showFilters = false;
    });
    _loadSuggestions();
  }

  void _clearFilters() {
    setState(() {
      _minBudgetController.text = '500';
      _maxBudgetController.text = '10000';
      _minRatingController.clear();
      _maxDistanceController.clear();
      _filters = HotelTransportFilters(
        minBudget: 500.0,
        maxBudget: 10000.0,
      );
      _showFilters = false;
    });
    _loadSuggestions();
  }

  Widget _buildSortRow(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Sort by:', style: TextStyle(color: Colors.white)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                dropdownColor: Colors.white,
                iconEnabledColor: Colors.white,
                iconDisabledColor: Colors.white,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                selectedItemBuilder: (BuildContext context) {
                  return ['Distance', 'Rating', 'Price'].map<Widget>((String item) {
                    return Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    );
                  }).toList();
                },
                items: const [
                  DropdownMenuItem(
                    value: 'distance',
                    child: Text('Distance', style: TextStyle(color: Colors.black87)),
                  ),
                  DropdownMenuItem(
                    value: 'rating',
                    child: Text('Rating', style: TextStyle(color: Colors.black87)),
                  ),
                  DropdownMenuItem(
                    value: 'price',
                    child: Text('Price', style: TextStyle(color: Colors.black87)),
                  ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _sortBy = val;
                    _applySorting();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: const Color(0xFF6C5CE7),
        elevation: 0,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Stay & Transit', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined, color: Colors.white),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'Refine',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.hotel_rounded), text: 'Hotels'),
            Tab(icon: Icon(Icons.directions_transit_filled), text: 'Transport'),
          ],
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
              // Filter panel
              if (_showFilters) _buildFilterPanel(theme),
              _buildSortRow(theme),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildHotelsList(theme),
                          _buildTransportList(theme),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minBudgetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Min Budget (₹)',
                    hintText: '500',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                    helperText: 'Range: ₹500 - ₹10000',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxBudgetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Max Budget (₹)',
                    hintText: '10000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                    helperText: 'Range: ₹500 - ₹10000',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minRatingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Min Rating',
                    hintText: '0.0 - 5.0',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.star),
                    helperText: 'Range: 0.0 - 5.0',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxDistanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Max Distance (km)',
                    hintText: '0 - 25',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                    helperText: 'Range: 0 - 25 km',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotelsList(ThemeData theme) {
    if (_hotels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hotel, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hotels found',
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hotels.length,
      itemBuilder: (context, index) => _buildHotelCard(_hotels[index], theme),
    );
  }

  Widget _buildHotelCard(HotelSuggestion hotel, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(hotel.icon, color: theme.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hotel.name,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Availability badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hotel.isAvailable ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hotel.isAvailable ? Colors.green : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hotel.isAvailable ? Icons.check_circle : Icons.cancel,
                                  size: 14,
                                  color: hotel.isAvailable ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hotel.isAvailable ? 'Available' : 'Unavailable',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: hotel.isAvailable ? Colors.green[700] : Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (hotel.hotelType != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          hotel.hotelType!.replaceAll('_', ' ').toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (hotel.description != null) ...[
              const SizedBox(height: 12),
              Text(
                hotel.description!,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (hotel.rating != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        hotel.rating!.toStringAsFixed(1),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                if (hotel.pricePerNight != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.currency_rupee, color: Colors.green, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        hotel.displayPrice,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                if (hotel.distanceFromCenter != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: Colors.blue, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        hotel.displayDistance,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
              ],
            ),
            // Address - Always displayed prominently
            if (hotel.address != null && hotel.address!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, size: 20, color: Colors.red[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Address',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hotel.address!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Contact Number - Always displayed
            if (hotel.phone != null && hotel.phone!.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  // Clean phone number for dialing (remove +91 and keep only digits)
                  String phoneToDial = hotel.phone!.replaceAll(RegExp(r'[^\d]'), '');
                  if (phoneToDial.startsWith('91') && phoneToDial.length == 12) {
                    phoneToDial = phoneToDial.substring(2); // Remove country code
                  }
                  final phoneUri = Uri.parse('tel:$phoneToDial');
                  if (await canLaunchUrl(phoneUri)) {
                    await launchUrl(phoneUri);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not launch phone: ${hotel.phone}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone, size: 20, color: Colors.blue[700]),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hotel.phone!,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.call_made, size: 16, color: Colors.blue[700]),
                    ],
                  ),
                ),
              ),
            ],
            // Facilities
            if (hotel.facilities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Facilities:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hotel.facilities.map((facility) {
                  return Chip(
                    label: Text(
                      facility,
                      style: const TextStyle(fontSize: 12),
                    ),
                    avatar: Icon(
                      _getFacilityIcon(facility),
                      size: 16,
                      color: theme.primaryColor,
                    ),
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getFacilityIcon(String facility) {
    switch (facility.toLowerCase()) {
      case 'wifi':
        return Icons.wifi;
      case 'parking':
        return Icons.local_parking;
      case 'breakfast':
        return Icons.restaurant;
      case 'swimming pool':
        return Icons.pool;
      case 'gym':
        return Icons.fitness_center;
      case 'spa':
        return Icons.spa;
      case 'restaurant':
        return Icons.restaurant_menu;
      case 'bar':
        return Icons.local_bar;
      case 'air conditioning':
        return Icons.ac_unit;
      case 'elevator':
        return Icons.elevator;
      case 'wheelchair accessible':
        return Icons.accessible;
      case 'pet friendly':
        return Icons.pets;
      case 'room service':
        return Icons.room_service;
      case 'laundry':
        return Icons.local_laundry_service;
      case 'concierge':
        return Icons.support_agent;
      case 'business center':
        return Icons.business_center;
      case '24/7 reception':
        return Icons.access_time;
      case 'tour desk':
        return Icons.tour;
      case 'currency exchange':
        return Icons.currency_exchange;
      case 'gift shop':
        return Icons.card_giftcard;
      case 'conference room':
        return Icons.meeting_room;
      case 'banquet hall':
        return Icons.event;
      case 'kids play area':
        return Icons.child_care;
      case 'library':
        return Icons.library_books;
      case 'terrace':
        return Icons.deck;
      case 'garden':
        return Icons.local_florist;
      case 'bbq facilities':
        return Icons.outdoor_grill;
      case 'airport shuttle':
        return Icons.airport_shuttle;
      case 'kitchen':
        return Icons.kitchen;
      default:
        return Icons.check_circle;
    }
  }

  Widget _buildTransportList(ThemeData theme) {
    if (_transportOptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_transit, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No transport options found',
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _transportOptions.length,
      itemBuilder: (context, index) => _buildTransportCard(_transportOptions[index], theme),
    );
  }

  Widget _buildTransportCard(TransportSuggestion transport, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon, Name, Type
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(transport.icon, color: theme.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transport.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transport.displayType,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Basic Info Row: Cost and Distance
            Row(
              children: [
                if (transport.estimatedCost != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_rupee, color: Colors.green[700], size: 18),
                        const SizedBox(width: 6),
                        Text(
                          transport.displayCost,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (transport.distanceFromCenter != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: Colors.blue[700], size: 18),
                        const SizedBox(width: 6),
                        Text(
                          transport.distanceFromCenter! < 1
                              ? '${(transport.distanceFromCenter! * 1000).toStringAsFixed(0)}m'
                              : '${transport.distanceFromCenter!.toStringAsFixed(1)}km',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            // Address
            if (transport.address != null && transport.address!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      transport.address!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Contact
            if (transport.phone != null && transport.phone!.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  String phoneToDial = transport.phone!.replaceAll(RegExp(r'[^\d]'), '');
                  if (phoneToDial.startsWith('91') && phoneToDial.length == 12) {
                    phoneToDial = phoneToDial.substring(2);
                  }
                  final phoneUri = Uri.parse('tel:$phoneToDial');
                  if (await canLaunchUrl(phoneUri)) {
                    await launchUrl(phoneUri);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not launch phone: ${transport.phone}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      transport.phone!,
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.call_made, size: 14, color: Colors.blue[700]),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getTransportFacilityIcon(String facility) {
    switch (facility.toLowerCase()) {
      case 'wifi':
        return Icons.wifi;
      case 'air conditioning':
        return Icons.ac_unit;
      case 'ticket counter':
        return Icons.confirmation_number;
      case 'waiting room':
        return Icons.meeting_room;
      case 'food court':
        return Icons.restaurant;
      case 'atm':
        return Icons.atm;
      case 'parking':
        return Icons.local_parking;
      case '24/7 service':
        return Icons.access_time;
      case 'online booking':
        return Icons.online_prediction;
      case 'ac vehicles':
        return Icons.airline_seat_recline_normal;
      case 'lounge':
        return Icons.chair;
      case 'duty free':
        return Icons.shopping_bag;
      case 'multiple car options':
        return Icons.directions_car;
      case 'cash & card payment':
        return Icons.payment;
      default:
        return Icons.check_circle;
    }
  }
}

