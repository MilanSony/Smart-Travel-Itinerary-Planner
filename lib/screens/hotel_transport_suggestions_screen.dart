import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/hotel_transport_model.dart';
import '../services/hotel_transport_service.dart';
import '../services/itinerary_service.dart';

class HotelTransportSuggestionsScreen extends StatefulWidget {
  final String destination;
  final double? destinationLat;
  final double? destinationLon;

  const HotelTransportSuggestionsScreen({
    super.key,
    required this.destination,
    this.destinationLat,
    this.destinationLon,
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
    setState(() {
      _filters = HotelTransportFilters(
        minBudget: _minBudgetController.text.isNotEmpty
            ? double.tryParse(_minBudgetController.text)
            : null,
        maxBudget: _maxBudgetController.text.isNotEmpty
            ? double.tryParse(_maxBudgetController.text)
            : null,
        minRating: _minRatingController.text.isNotEmpty
            ? double.tryParse(_minRatingController.text)
            : null,
        maxDistance: _maxDistanceController.text.isNotEmpty
            ? double.tryParse(_maxDistanceController.text)
            : null,
      );
      _showFilters = false;
    });
    _loadSuggestions();
  }

  void _clearFilters() {
    setState(() {
      _minBudgetController.clear();
      _maxBudgetController.clear();
      _minRatingController.clear();
      _maxDistanceController.clear();
      _filters = HotelTransportFilters();
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
                dropdownColor: const Color(0xFF6C5CE7),
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'distance', child: Text('Distance')),
                  DropdownMenuItem(value: 'rating', child: Text('Rating')),
                  DropdownMenuItem(value: 'price', child: Text('Price')),
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
                  decoration: const InputDecoration(
                    labelText: 'Min Budget (₹)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxBudgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Budget (₹)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
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
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Min Rating (0-5)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.star),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxDistanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Distance (km)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
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
                      Text(
                        hotel.name,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
            if (hotel.address != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.place, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hotel.address!,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transport.type.replaceAll('_', ' ').toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (transport.description != null) ...[
              const SizedBox(height: 12),
              Text(
                transport.description!,
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
                if (transport.estimatedCost != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.currency_rupee, color: Colors.green, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        transport.displayCost,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                if (transport.distanceFromCenter != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: Colors.blue, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        transport.distanceFromCenter! < 1
                            ? '${(transport.distanceFromCenter! * 1000).toStringAsFixed(0)}m from center'
                            : '${transport.distanceFromCenter!.toStringAsFixed(1)}km from center',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
              ],
            ),
            if (transport.address != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.place, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      transport.address!,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

