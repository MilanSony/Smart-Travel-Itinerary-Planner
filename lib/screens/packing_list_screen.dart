import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/itinerary_model.dart';
import '../services/weather_service.dart';
import '../services/packing_list_service.dart';
import '../services/firestore_service.dart';
import 'saved_packing_lists_screen.dart';

/// Full-screen view for the ML-style smart packing list.
///
/// This screen is opened from the Weather Forecast screen once the
/// weather-based adjustments have been generated. It uses the same
/// forecasts and itinerary details to build a context-aware list of
/// essential items for the trip.
class PackingListScreen extends StatefulWidget {
  final Itinerary itinerary;
  final List<DailyForecast> forecasts;

  const PackingListScreen({
    super.key,
    required this.itinerary,
    required this.forecasts,
  });

  @override
  State<PackingListScreen> createState() => _PackingListScreenState();
}

class _PackingListScreenState extends State<PackingListScreen> {
  List<PackingItem> _items = const [];
  final Set<String> _checkedIds = {};
  bool _personalizing = true;
  String? _personalizationNote;

  // Local traveler configuration chosen on this screen.
  int _numAdults = 2;
  int _numChildren = 0;
  final Set<String> _childrenAgeGroups = {};

  @override
  void initState() {
    super.initState();
    // Initialize traveler values from itinerary if available.
    _numAdults = widget.itinerary.numAdults ?? _numAdults;
    _numChildren = widget.itinerary.numChildren ?? _numChildren;
    _childrenAgeGroups
        .addAll(widget.itinerary.childrenAgeGroups ?? const <String>[]);
    _regenerateBaseListAndPersonalization();
  }

  String _formatDateShort(DateTime d) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = (d.month >= 1 && d.month <= 12) ? months[d.month - 1] : '';
    return '$m ${d.day}, ${d.year}';
  }

  Itinerary _withTravelerInfo(Itinerary base) {
    // Create a lightweight copy of the itinerary with the chosen traveler data
    // so packing logic can use it without changing the original object.
    return Itinerary(
      destination: base.destination,
      title: base.title,
      dayPlans: base.dayPlans,
      summary: base.summary,
      totalEstimatedCost: base.totalEstimatedCost,
      startDate: base.startDate,
      endDate: base.endDate,
      numAdults: _numAdults,
      numChildren: _numChildren,
      childrenAgeGroups: _childrenAgeGroups.toList(),
    );
  }

  Future<void> _regenerateBaseListAndPersonalization() async {
    setState(() {
      _personalizing = true;
      _personalizationNote = null;
      _checkedIds.clear();
    });

    final itWithTravelers = _withTravelerInfo(widget.itinerary);
    final baseItems =
        PackingListService.generatePackingList(itWithTravelers, widget.forecasts);
    setState(() {
      _items = baseItems;
    });
    await _runArmPersonalization(itWithTravelers);
  }

  Future<void> _runArmPersonalization(Itinerary itineraryWithTravelers) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final firestore = FirestoreService();

      // 1) Pull the user's evolving saved list for this destination (if any)
      // so we can personalize + optionally pre-select.
      final existingDoc = uid == null
          ? null
          : await firestore.getPackingTransactionForUserDestination(
              uid,
              widget.itinerary.destination,
            );

      final savedItemNames = existingDoc?.data()?['items'] is List
          ? (existingDoc!.data()!['items'] as List).cast<String>()
          : const <String>[];

      // 2) Pull mined association rules (Apriori/FP-Growth outputs).
      final rules = await firestore.getPackingRules();
      final tags =
          PackingListService.buildContextTags(itineraryWithTravelers, widget.forecasts);

      // Expected rule schema (example):
      // { conditions: ['hot_weather','beach_or_water'], items: ['Sunscreen'], confidence: 0.72, support: 0.12 }
      // We keep this parsing defensive to tolerate partial docs.
      final List<PackingItem> armItems = [];
      for (final r in rules) {
        final rawConds = r['conditions'];
        final rawItems = r['items'];
        if (rawConds is! List || rawItems is! List) continue;

        final conds = rawConds.map((e) => e.toString()).toSet();
        if (conds.isEmpty) continue;
        if (!tags.containsAll(conds)) continue;

        final conf = (r['confidence'] is num) ? (r['confidence'] as num).toDouble() : null;
        // Basic threshold so we don't add noisy rules.
        if (conf != null && conf < 0.35) continue;

        for (final it in rawItems) {
          final name = it.toString().trim();
          if (name.isEmpty) continue;
          final id = 'arm_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
          armItems.add(
            PackingItem(
              id: id,
              name: name,
              reason: conf != null
                  ? 'Personalized from your saved packing history (ARM, confidence ${(conf * 100).toStringAsFixed(0)}%).'
                  : 'Personalized from your saved packing history (ARM).',
            ),
          );
        }
      }

      // 3) Merge: keep the base list, then add ARM items not already present by name.
      final existingNames =
          _items.map((e) => e.name.trim().toLowerCase()).toSet();
      final merged = <PackingItem>[..._items];
      int added = 0;
      for (final a in armItems) {
        final n = a.name.trim().toLowerCase();
        if (n.isEmpty) continue;
        if (existingNames.contains(n)) continue;
        merged.add(a);
        existingNames.add(n);
        added++;
      }

      // 4) Pre-select saved items (by matching item name).
      if (savedItemNames.isNotEmpty) {
        final savedLower = savedItemNames.map((e) => e.trim().toLowerCase()).toSet();
        for (final item in merged) {
          if (savedLower.contains(item.name.trim().toLowerCase())) {
            _checkedIds.add(item.id);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _items = merged;
        _personalizing = false;
        _personalizationNote = uid == null
            ? null
            : (added > 0
                ? 'Personalized with $added ARM-based suggestions from your saved history.'
                : (savedItemNames.isNotEmpty
                    ? 'Loaded your saved items for this destination.'
                    : null));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _personalizing = false;
        _personalizationNote = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Split items into general/adult vs children-specific for clear sections.
    final generalItems =
        _items.where((i) => !i.isForChildren).toList(growable: false);
    final childrenItems =
        _items.where((i) => i.isForChildren).toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Smart Packing List',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.itinerary.destination,
              style: const TextStyle(
                color: Color(0xFFCBD5F5),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Saved packing lists',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SavedPackingListsScreen(
                    destination: widget.itinerary.destination,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Packing suggestions are not available for this trip yet. Try again after generating the weather forecast.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Container(
              color: const Color(0xFFF3F4F6),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(theme),
                  const SizedBox(height: 12),
                  _buildTravelerSelector(theme),
                  if (_personalizing) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Personalizing suggestions from your saved history...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_personalizationNote != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0EA5E9).withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: Color(0xFF0EA5E9),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _personalizationNote!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF0C4A6E),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (generalItems.isNotEmpty) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.checklist_rounded,
                                    size: 18,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'General / Adult packing list',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Weather-aware essentials and clothing for your trip.',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...generalItems.map(
                              (item) => _buildItemRow(theme, item),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (childrenItems.isNotEmpty) ...[
                    _buildChildrenPackingListSection(theme, childrenItems),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _items.isEmpty
          ? null
          : _buildBottomSaveBar(theme),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    final start = widget.itinerary.startDate;
    final end = widget.itinerary.endDate;
    int? days;
    if (start != null) {
      final actualEnd = end ??
          start.add(Duration(days: widget.itinerary.dayPlans.length - 1));
      days = actualEnd.difference(start).inDays + 1;
    }

    final DateTime? computedEnd = start == null
        ? null
        : (end ?? start.add(Duration(days: (days ?? 1) - 1)));
    final String? dateRange = (start != null && computedEnd != null)
        ? '${_formatDateShort(start)}  →  ${_formatDateShort(computedEnd)}'
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.luggage_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.itinerary.title.isNotEmpty
                          ? widget.itinerary.title
                          : 'Upcoming trip',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_rounded,
                          size: 15,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.itinerary.destination,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (dateRange != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.date_range_rounded,
                            size: 15,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              dateRange,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (days != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 15,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$days-day itinerary',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'AI-generated packing, tuned for your weather, duration, travellers and activities.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelerSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Travellers',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStepper(
                  theme: theme,
                  label: 'Adults',
                  value: _numAdults,
                  min: 1,
                  onChanged: (v) {
                    setState(() => _numAdults = v);
                    _regenerateBaseListAndPersonalization();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStepper(
                  theme: theme,
                  label: 'Children',
                  value: _numChildren,
                  min: 0,
                  onChanged: (v) {
                    setState(() => _numChildren = v);
                    _regenerateBaseListAndPersonalization();
                  },
                ),
              ),
            ],
          ),
          if (_numChildren > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Children age groups',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildAgeChip('infant_0_2', 'Infant (0–2 yrs)'),
                _buildAgeChip('toddler_3_6', 'Toddler (3–6 yrs)'),
                _buildAgeChip('school_7_12', 'School age (7–12 yrs)'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepper({
    required ThemeData theme,
    required String label,
    required int value,
    required int min,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap + / - to adjust',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: value > min
                  ? () => onChanged(value - 1)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgeChip(String key, String label) {
    final selected = _childrenAgeGroups.contains(key);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          if (v) {
            _childrenAgeGroups.add(key);
          } else {
            _childrenAgeGroups.remove(key);
          }
        });
        _regenerateBaseListAndPersonalization();
      },
    );
  }

  /// Builds an impressive, categorized children's packing list section
  Widget _buildChildrenPackingListSection(ThemeData theme, List<PackingItem> items) {
    // Categorize children's items by age group first, then by type
    final infantItems = <PackingItem>[];
    final toddlerItems = <PackingItem>[];
    final schoolAgeItems = <PackingItem>[];

    for (final item in items) {
      final id = item.id.toLowerCase();
      if (id.startsWith('infant_') || id.contains('infant')) {
        infantItems.add(item);
      } else if (id.startsWith('toddler_') || id.contains('toddler')) {
        toddlerItems.add(item);
      } else if (id.startsWith('school_') || id.contains('school')) {
        schoolAgeItems.add(item);
      } else {
        // Legacy items or items without age prefix - categorize by content
        if (id.contains('baby_') || id.contains('diaper') || id.contains('feeding') || id.contains('blanket') || id.contains('carrier')) {
          infantItems.add(item);
        } else if (id.contains('potty') || id.contains('sippy') || id.contains('comfort')) {
          toddlerItems.add(item);
        } else if (id.contains('independence') || id.contains('journal') || id.contains('backpack')) {
          schoolAgeItems.add(item);
        } else {
          // Generic items that apply to all ages - add to all groups if they exist
          // But prioritize based on which age groups are selected
          final hasInfant = _childrenAgeGroups.any((g) => g.contains('infant') || g.contains('0_2'));
          final hasToddler = _childrenAgeGroups.any((g) => g.contains('toddler') || g.contains('3_6'));
          final hasSchool = _childrenAgeGroups.any((g) => g.contains('school') || g.contains('7_12'));
          
          if (hasInfant && !hasToddler && !hasSchool) {
            infantItems.add(item);
          } else if (hasToddler && !hasInfant && !hasSchool) {
            toddlerItems.add(item);
          } else if (hasSchool && !hasInfant && !hasToddler) {
            schoolAgeItems.add(item);
          } else {
            // Multiple age groups - add to all relevant ones
            if (hasInfant) infantItems.add(item);
            if (hasToddler) toddlerItems.add(item);
            if (hasSchool) schoolAgeItems.add(item);
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.child_care,
                  color: Color(0xFFEC4899),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Children\'s Packing List',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Carefully curated items for your little travelers',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Age Group: Infants (0-2 years)
        if (infantItems.isNotEmpty) ...[
          _buildAgeGroupSection(
            theme: theme,
            title: 'For Infants (0-2 years)',
            icon: Icons.child_care,
            iconColor: const Color(0xFFEC4899),
            backgroundColor: const Color(0xFFEC4899).withOpacity(0.08),
            items: infantItems,
          ),
          const SizedBox(height: 16),
        ],

        // Age Group: Toddlers (3-6 years)
        if (toddlerItems.isNotEmpty) ...[
          _buildAgeGroupSection(
            theme: theme,
            title: 'For Toddlers (3-6 years)',
            icon: Icons.face,
            iconColor: const Color(0xFF3B82F6),
            backgroundColor: const Color(0xFF3B82F6).withOpacity(0.08),
            items: toddlerItems,
          ),
          const SizedBox(height: 16),
        ],

        // Age Group: School Age (7-12 years)
        if (schoolAgeItems.isNotEmpty) ...[
          _buildAgeGroupSection(
            theme: theme,
            title: 'For School Age (7-12 years)',
            icon: Icons.school,
            iconColor: const Color(0xFF10B981),
            backgroundColor: const Color(0xFF10B981).withOpacity(0.08),
            items: schoolAgeItems,
          ),
        ],

        // Quick save button for children's items
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFEC4899).withOpacity(0.1),
                const Color(0xFF3B82F6).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFEC4899).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.save_alt_rounded,
                color: Color(0xFFEC4899),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Save Children\'s List',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select items above and tap save in the top bar to save this list',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds an age group section with categorized items
  Widget _buildAgeGroupSection({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required List<PackingItem> items,
  }) {
    // Categorize items within this age group
    final clothingItems = <PackingItem>[];
    final essentialsItems = <PackingItem>[];
    final healthItems = <PackingItem>[];
    final entertainmentItems = <PackingItem>[];

    for (final item in items) {
      final id = item.id.toLowerCase();
      if (id.contains('clothes') || id.contains('warm') || id.contains('rain') || id.contains('sun')) {
        clothingItems.add(item);
      } else if (id.contains('medicine') || id.contains('ors') || id.contains('bandage') || id.contains('health')) {
        healthItems.add(item);
      } else if (id.contains('snack') || id.contains('toy') || id.contains('entertainment') || id.contains('book') || id.contains('game')) {
        entertainmentItems.add(item);
      } else {
        essentialsItems.add(item);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Age group header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} items',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Categorized items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clothing & Weather Protection
                if (clothingItems.isNotEmpty) ...[
                  _buildSubCategory(
                    theme: theme,
                    title: 'Clothing & Weather Protection',
                    icon: Icons.checkroom,
                    iconColor: iconColor,
                    items: clothingItems,
                  ),
                  const SizedBox(height: 12),
                ],
                // Essentials
                if (essentialsItems.isNotEmpty) ...[
                  _buildSubCategory(
                    theme: theme,
                    title: 'Essentials',
                    icon: Icons.inventory_2_outlined,
                    iconColor: iconColor,
                    items: essentialsItems,
                  ),
                  const SizedBox(height: 12),
                ],
                // Health & Safety
                if (healthItems.isNotEmpty) ...[
                  _buildSubCategory(
                    theme: theme,
                    title: 'Health & Safety',
                    icon: Icons.medical_services_outlined,
                    iconColor: iconColor,
                    items: healthItems,
                  ),
                  const SizedBox(height: 12),
                ],
                // Entertainment & Snacks
                if (entertainmentItems.isNotEmpty) ...[
                  _buildSubCategory(
                    theme: theme,
                    title: 'Entertainment & Snacks',
                    icon: Icons.toys_outlined,
                    iconColor: iconColor,
                    items: entertainmentItems,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a sub-category within an age group
  Widget _buildSubCategory({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<PackingItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _buildChildrenItemCard(theme, item, iconColor)),
      ],
    );
  }

  /// Builds a category card for children's items
  Widget _buildChildrenCategoryCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required List<PackingItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Items list
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: items.map((item) => _buildChildrenItemCard(theme, item, iconColor)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an attractive item card for children's items
  Widget _buildChildrenItemCard(ThemeData theme, PackingItem item, Color categoryColor) {
    final checked = _checkedIds.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: checked ? categoryColor.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: checked ? categoryColor.withOpacity(0.3) : const Color(0xFFE5E7EB),
          width: checked ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (checked) {
              _checkedIds.remove(item.id);
            } else {
              _checkedIds.add(item.id);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox with custom styling
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: checked ? categoryColor : Colors.transparent,
                  border: Border.all(
                    color: checked ? categoryColor : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: checked
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
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
                            item.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (item.isEssential) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Essential',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC2410C),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.reason != null && item.reason!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: categoryColor.withOpacity(0.7),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.reason!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6B7280),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(ThemeData theme, PackingItem item) {
    final checked = _checkedIds.contains(item.id);

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: checked ? const Color(0xFFEEF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: checked ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
          width: checked ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (checked) {
              _checkedIds.remove(item.id);
            } else {
              _checkedIds.add(item.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: checked ? const Color(0xFF4F46E5) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: checked ? const Color(0xFF4F46E5) : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        if (item.isEssential) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withOpacity(0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Essential',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC2410C),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.reason != null && item.reason!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.reason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B7280),
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSaveBar(ThemeData theme) {
    final selectedCount = _checkedIds.length;
    final hasSelection = selectedCount > 0;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasSelection
                        ? '$selectedCount item${selectedCount > 1 ? 's' : ''} selected'
                        : 'Select items to save',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'We use your saved lists to personalize future trips.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: hasSelection ? _saveTransaction : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(
                  Icons.save_alt_rounded,
                  size: 18,
                ),
                label: Text(
                  hasSelection ? 'Save packing list' : 'Save',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to save your packing list.'),
          ),
        );
        return;
      }

      if (_checkedIds.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select items (tick the boxes) before saving.'),
          ),
        );
        return;
      }

      final start = widget.itinerary.startDate;
      DateTime? end = widget.itinerary.endDate;
      int durationDays =
          widget.itinerary.dayPlans.isNotEmpty ? widget.itinerary.dayPlans.length : 3;
      if (start != null) {
        end ??= start.add(Duration(days: durationDays - 1));
        durationDays = end.difference(start).inDays + 1;
      }

      final firestore = FirestoreService();

      final itWithTravelers = _withTravelerInfo(widget.itinerary);
      final contextTags = PackingListService
          .buildContextTags(itWithTravelers, widget.forecasts)
          .toList(growable: false);

      // Save ONLY items the user selected (ticked).
      final selectedItemNames = _items
          .where((i) => _checkedIds.contains(i.id))
          .map((i) => i.name)
          .toList(growable: false);

      if (selectedItemNames.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No selected items found to save.'),
          ),
        );
        return;
      }

      // Merge with any already-saved items for this destination so that
      // existing items remain unless explicitly removed from the Saved screen.
      final existingSnapshot = await FirebaseFirestore.instance
          .collection('packing_transactions')
          .where('userId', isEqualTo: uid)
          .where('destination', isEqualTo: widget.itinerary.destination)
          .limit(1)
          .get();

      final existingItems = existingSnapshot.docs.isNotEmpty
          ? ((existingSnapshot.docs.first.data()['items'] as List?)?.cast<String>() ??
              const <String>[])
          : const <String>[];

      final newOnly = selectedItemNames
          .where((name) => !existingItems.contains(name))
          .toList(growable: false);
      final duplicates = selectedItemNames
          .where((name) => existingItems.contains(name))
          .toList(growable: false);

      if (newOnly.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'These items are already in your saved list: ${duplicates.join(', ')}',
            ),
          ),
        );
        return;
      }

      final mergedItems = [...existingItems, ...newOnly];

      await firestore.savePackingTransaction(
        userId: uid,
        tripId: widget.itinerary.title,
        destination: widget.itinerary.destination,
        startDate: start,
        endDate: end,
        durationDays: durationDays,
        tripType: null,
        contextTags: contextTags,
        items: mergedItems,
        numAdults: _numAdults,
        numChildren: _numChildren,
        childrenAgeGroups: _childrenAgeGroups.toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Packing list saved for ML improvements.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save packing list right now.'),
        ),
      );
    }
  }
}