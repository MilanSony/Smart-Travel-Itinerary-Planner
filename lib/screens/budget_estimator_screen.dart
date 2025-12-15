import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/budget_model.dart';
import '../models/itinerary_model.dart';
import '../services/budget_estimator_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/gradient_background.dart';

class BudgetEstimatorScreen extends StatefulWidget {
  final String? tripId;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? travelers;
  final double? initialBudget;
  final Itinerary? itinerary;
  final String? budgetLevel;

  const BudgetEstimatorScreen({
    super.key,
    this.tripId,
    this.destination,
    this.startDate,
    this.endDate,
    this.travelers,
    this.initialBudget,
    this.itinerary,
    this.budgetLevel,
  });

  @override
  State<BudgetEstimatorScreen> createState() => _BudgetEstimatorScreenState();
}

class _BudgetEstimatorScreenState extends State<BudgetEstimatorScreen>
    with SingleTickerProviderStateMixin {
  // TODO: Replace with your Gemini API key from https://aistudio.google.com/app/apikey
  // Get your API key: https://aistudio.google.com/app/apikey
  static const String? _geminiApiKey = "AIzaSyAUj6xV4nS8TQnja-3AdAo0e2Ecma3FC1g"; // Paste your API key here: 'AIza...'
  
  final BudgetEstimatorService _budgetService = BudgetEstimatorService(
    apiKey: _geminiApiKey,
  );
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController();
  final _destinationController = TextEditingController();
  final _travelersController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  BudgetEstimation? _currentEstimation;
  bool _isLoading = false;
  String? _errorMessage;
  late TabController _tabController;
  List<String> _selectedPreferences = [];
  bool _showPerPerson = false;

  String? _validateInputs() {
    if (!_formKey.currentState!.validate()) {
      return 'Please correct the highlighted fields.';
    }
    if (_startDate == null) return 'Please select a start date.';
    if (_endDate == null) return 'Please select an end date.';
    if (_endDate!.isBefore(_startDate!)) {
      return 'End date must be after start date.';
    }
    final travelers = int.tryParse(_travelersController.text);
    if (travelers == null || travelers < 1) {
      return 'Number of travelers must be at least 1.';
    }
    final budget = double.tryParse(_budgetController.text);
    if (budget == null || budget <= 0) {
      return 'Budget must be greater than 0.';
    }
    return null;
  }

  Future<void> _regenerateFromCurrentEstimation() async {
    if (_currentEstimation == null) return;

    // Prefill controllers from the current estimation to ensure validation passes
    _destinationController.text = _currentEstimation!.destination;
    _travelersController.text = _currentEstimation!.travelers.toString();
    _budgetController.text = _currentEstimation!.totalBudget.toStringAsFixed(0);
    _startDate = _currentEstimation!.startDate;
    _endDate = _currentEstimation!.endDate;

    await _generateEstimation();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize with provided values
    if (widget.destination != null) {
      _destinationController.text = widget.destination!;
    }
    if (widget.startDate != null) {
      _startDate = widget.startDate;
    }
    if (widget.endDate != null) {
      _endDate = widget.endDate;
    }
    if (widget.travelers != null) {
      _travelersController.text = widget.travelers.toString();
    }
    if (widget.initialBudget != null) {
      _budgetController.text = widget.initialBudget.toString();
    }

    // Auto-generate if all required fields are present
    if (widget.destination != null &&
        widget.startDate != null &&
        widget.endDate != null &&
        widget.travelers != null &&
        widget.initialBudget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateEstimation();
      });
    }
  }

  Future<void> _generateEstimation() async {
    final validationError = _validateInputs();
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final destination = _destinationController.text.trim();
      final travelers = int.parse(_travelersController.text);
      final budget = double.parse(_budgetController.text);
      final tripId = widget.tripId ?? DateTime.now().millisecondsSinceEpoch.toString();

      if (_startDate == null || _endDate == null) {
        throw Exception('Please select start and end dates');
      }

      final estimation = await _budgetService.estimateBudget(
        tripId: tripId,
        destination: destination,
        startDate: _startDate!,
        endDate: _endDate!,
        travelers: travelers,
        totalBudget: budget,
        itinerary: widget.itinerary,
        preferences: _selectedPreferences.isNotEmpty ? _selectedPreferences : null,
        budgetLevel: widget.budgetLevel,
      );

      setState(() {
        _currentEstimation = estimation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _optimizeBudget(double? targetBudget) async {
    if (_currentEstimation == null) return;

    if (targetBudget != null && targetBudget <= 0) {
      setState(() {
        _errorMessage = 'Target budget must be greater than 0.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final optimized = await _budgetService.optimizeBudget(
        currentEstimation: _currentEstimation!,
        targetBudget: targetBudget,
        priorities: _selectedPreferences,
      );

      setState(() {
        _currentEstimation = optimized;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget optimized successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }
  @override
  void dispose() {
    _tabController.dispose();
    _budgetController.dispose();
    _destinationController.dispose();
    _travelersController.dispose();
    super.dispose();
  }


  Future<void> _selectDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now().add(const Duration(days: 7))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate!.add(const Duration(days: 1));
          }
        } else {
          if (_startDate == null || picked.isAfter(_startDate!)) {
            _endDate = picked;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('End date must be after start date'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Budget Estimator'),
        actions: [
          if (_currentEstimation != null)
            IconButton(
              icon: Icon(_showPerPerson ? Icons.group : Icons.person),
              tooltip: _showPerPerson ? 'Show totals' : 'Show per-person',
              onPressed: () {
                setState(() {
                  _showPerPerson = !_showPerPerson;
                });
              },
            ),
        ],
        bottom: _currentEstimation != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                  Tab(text: 'Breakdown', icon: Icon(Icons.pie_chart)),
                  Tab(text: 'Optimize', icon: Icon(Icons.tune)),
                ],
              )
            : null,
      ),
      body: GradientBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _currentEstimation == null
                ? _buildInputForm(theme)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(_currentEstimation!, theme),
                      _buildBreakdownTab(_currentEstimation!, theme),
                      _buildOptimizeTab(_currentEstimation!, theme),
                    ],
                  ),
      ),
    );
  }

  Widget _buildInputForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip Details',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        prefixIcon: Icon(Icons.place),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a destination';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                prefixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _startDate != null
                                    ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                    : 'Select start date',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date',
                                prefixIcon: Icon(Icons.event),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _endDate != null
                                    ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                    : 'Select end date',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _travelersController,
                      decoration: const InputDecoration(
                        labelText: 'Number of Travelers',
                        prefixIcon: Icon(Icons.people),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter number of travelers';
                        }
                        final num = int.tryParse(value);
                        if (num == null || num < 1) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _budgetController,
                      decoration: const InputDecoration(
                        labelText: 'Total Budget (₹)',
                        prefixIcon: Icon(Icons.account_balance_wallet),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your budget';
                        }
                        final num = double.tryParse(value);
                        if (num == null || num <= 0) {
                          return 'Please enter a valid budget amount';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preferences (Optional)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Accommodation',
                        'Food',
                        'Transportation',
                        'Activities',
                        'Shopping',
                      ].map((pref) {
                        final isSelected = _selectedPreferences.contains(pref);
                        return FilterChip(
                          label: Text(pref),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedPreferences.add(pref);
                              } else {
                                _selectedPreferences.remove(pref);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateEstimation,
              icon: const Icon(Icons.analytics),
              label: const Text('Generate Budget Estimate'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(BudgetEstimation estimation, ThemeData theme) {
    final statusColor = estimation.status == BudgetStatus.withinBudget
        ? Colors.green
        : estimation.status == BudgetStatus.slightlyOver
            ? Colors.orange
            : Colors.red;
    final travelers = max(1, estimation.travelers);
    double view(double amount) => _showPerPerson ? amount / travelers : amount;
    String perLabel = _showPerPerson ? ' (per person)' : '';
    String varianceText = view(estimation.budgetVariance) >= 0
        ? '₹${NumberFormat('#,##,###').format(view(estimation.budgetVariance).toInt())} under budget$perLabel'
        : '₹${NumberFormat('#,##,###').format(view(estimation.budgetVariance).abs().toInt())} over budget$perLabel';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Budget Status Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Budget$perLabel',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${NumberFormat('#,##,###').format(view(estimation.totalBudget).toInt())}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          estimation.status == BudgetStatus.withinBudget
                              ? 'Within Budget'
                              : estimation.status == BudgetStatus.slightlyOver
                                  ? 'Slightly Over'
                                  : 'Over Budget',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildStatItem(
                        'Estimated Cost$perLabel',
                        '₹${NumberFormat('#,##,###').format(view(estimation.estimatedTotalCost).toInt())}',
                        Icons.account_balance_wallet,
                        theme,
                      ),
                      _buildStatItem(
                        'Variance$perLabel',
                        varianceText,
                        Icons.trending_up,
                        theme,
                        color: statusColor,
                      ),
                      _buildStatItem(
                        'Utilization',
                        '${estimation.budgetUtilization.toStringAsFixed(1)}%',
                        Icons.pie_chart,
                        theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: estimation.budgetUtilization / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 8,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Cost Range Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cost Range',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _buildRangeItem(
                        'Minimum$perLabel',
                        view(estimation.minTotalCost),
                        Colors.blue,
                        theme,
                      ),
                      _buildRangeItem(
                        'Estimated$perLabel',
                        view(estimation.estimatedTotalCost),
                        Colors.purple,
                        theme,
                      ),
                      _buildRangeItem(
                        'Maximum$perLabel',
                        view(estimation.maxTotalCost),
                        Colors.orange,
                        theme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // AI Insights Card
          if (estimation.aiInsights != null)
            Card(
              elevation: 4,
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'AI Insights',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      estimation.aiInsights!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Quick Summary
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Destination', estimation.destination, theme),
                  _buildSummaryRow(
                    'Duration',
                    '${estimation.endDate.difference(estimation.startDate).inDays + 1} days',
                    theme,
                  ),
                  _buildSummaryRow(
                    'Travelers',
                    estimation.travelers.toString(),
                    theme,
                  ),
                  _buildSummaryRow(
                      'Daily Average$perLabel',
                      '₹${NumberFormat('#,##,###').format(view(estimation.estimatedTotalCost / (estimation.endDate.difference(estimation.startDate).inDays + 1)).toInt())}',
                    theme,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownTab(BudgetEstimation estimation, ThemeData theme) {
    final travelers = max(1, estimation.travelers);
    double view(double amount) => _showPerPerson ? amount / travelers : amount;
    String perLabel = _showPerPerson ? ' (per person)' : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Breakdown',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...estimation.categoryBreakdown.map((breakdown) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getCategoryColor(breakdown.category).withOpacity(0.2),
                  child: Icon(
                    breakdown.icon,
                    color: _getCategoryColor(breakdown.category),
                  ),
                ),
                title: Text(
                  breakdown.categoryName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '₹${NumberFormat('#,##,###').format(view(breakdown.estimatedCost).toInt())} (${breakdown.percentage.toStringAsFixed(1)}%)$perLabel',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      breakdown.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Range: ₹${NumberFormat('#,##,###').format(view(breakdown.minCost).toInt())} - ₹${NumberFormat('#,##,###').format(view(breakdown.maxCost).toInt())}$perLabel',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                trailing: SizedBox(
                  width: 60,
                  child: LinearProgressIndicator(
                    value: breakdown.percentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getCategoryColor(breakdown.category),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text(
            'Daily Budget Breakdown',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...estimation.dailyBudgets.map((daily) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ExpansionTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  DateFormat('MMM dd, yyyy').format(daily.date),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '₹${NumberFormat('#,##,###').format(view(daily.estimatedCost).toInt())}$perLabel',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
                children: [
                  if (daily.notes != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        daily.notes!,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ...daily.breakdown.map((cat) {
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        cat.icon,
                        size: 20,
                        color: _getCategoryColor(cat.category),
                      ),
                      title: Text(cat.categoryName),
                      trailing: Text(
                        '₹${NumberFormat('#,##,###').format(view(cat.estimatedCost).toInt())}$perLabel',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOptimizeTab(BudgetEstimation estimation, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (estimation.optimizations.isEmpty)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your budget looks optimal!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No major optimizations needed at this time.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'Optimization Suggestions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...estimation.optimizations.map((opt) {
              final impactColor = opt.impact == 'high'
                  ? Colors.red
                  : opt.impact == 'medium'
                      ? Colors.orange
                      : Colors.blue;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: impactColor.withOpacity(0.2),
                    child: Icon(
                      Icons.lightbulb,
                      color: impactColor,
                    ),
                  ),
                  title: Text(
                    opt.category,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(opt.suggestion),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Save ₹${NumberFormat('#,##,###').format(opt.potentialSavings.toInt())}',
                          style: TextStyle(
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      opt.impact.toUpperCase(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: impactColor.withOpacity(0.2),
                    labelStyle: TextStyle(color: impactColor),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showOptimizeDialog(),
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Optimize Budget'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _regenerateFromCurrentEstimation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Regenerate Estimate'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    ThemeData theme, {
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color ?? theme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: 2,
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRangeItem(
    String label,
    double value,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.circle, color: color, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        Text(
          '₹${NumberFormat('#,##,###').format(value.toInt())}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(BudgetCategory category) {
    switch (category) {
      case BudgetCategory.accommodation:
        return Colors.blue;
      case BudgetCategory.food:
        return Colors.orange;
      case BudgetCategory.transportation:
        return Colors.green;
      case BudgetCategory.activities:
        return Colors.purple;
      case BudgetCategory.shopping:
        return Colors.pink;
      case BudgetCategory.emergency:
        return Colors.red;
      case BudgetCategory.miscellaneous:
        return Colors.grey;
    }
  }

  void _showOptimizeDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Optimize Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a target budget to optimize, or leave empty to optimize current budget:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Target Budget (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
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
              final targetBudget = controller.text.trim().isEmpty
                  ? null
                  : double.tryParse(controller.text);
              Navigator.pop(context);
              _optimizeBudget(targetBudget);
            },
            child: const Text('Optimize'),
          ),
        ],
      ),
    );
  }

}



