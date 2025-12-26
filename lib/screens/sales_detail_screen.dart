import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';

import '../services/database_service.dart';
import '../utils/date_filter.dart';
import '../widgets/filter_bar.dart';

class SalesDetailScreen extends StatefulWidget {
  const SalesDetailScreen({super.key});

  @override
  State<SalesDetailScreen> createState() => _SalesDetailScreenState();
}

class _SalesDetailScreenState extends State<SalesDetailScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');

  List<Map<String, dynamic>> _salesDetail = [];
  bool _isLoading = true;
  bool _showAllProducts = false;
  DateFilter _selectedFilter = DateFilter.today;

  @override
  void initState() {
    super.initState();
    _loadSalesDetail();
  }

  // ---------------------------
  // SUMMARY
  // ---------------------------
  double get _totalRevenue => _salesDetail.fold(
    0.0,
    (sum, e) => sum + ((e['total_revenue'] as num?)?.toDouble() ?? 0),
  );

  int get _totalQuantity => _salesDetail.fold(
    0,
    (sum, e) => sum + ((e['total_quantity'] as int?) ?? 0),
  );

  int get _totalProducts => _salesDetail.length;

  // ---------------------------
  // Smart Top N
  // ---------------------------
  int _calculateTopCount(int total) {
    if (total <= 5) return total;
    if (total <= 20) return 5;
    return 7;
  }

  Future<void> _loadSalesDetail() async {
    setState(() => _isLoading = true);
    try {
      final raw = await _db.getSalesDetailByProduct(
        startDate: _selectedFilter.startDate,
        endDate: _selectedFilter.endDate,
      );

      final List<Map<String, dynamic>> detail = raw
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      for (final item in detail) {
        final optionsJson = item['options'];
        if (optionsJson is String && optionsJson.isNotEmpty) {
          try {
            item['_parsedOptions'] = (jsonDecode(optionsJson) as List)
                .map((o) => o['name'] as String)
                .join(', ');
          } catch (_) {
            item['_parsedOptions'] = '';
          }
        } else {
          item['_parsedOptions'] = '';
        }
      }

      setState(() {
        _salesDetail = detail;
        _showAllProducts = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  // ---------------------------
  // DAILY SUMMARY UI
  // ---------------------------
  Widget _buildDailySummary() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _summaryItem(
              'ยอดขายรวม',
              '${_currencyFormat.format(_totalRevenue)} บาท',
            ),
            _summaryItem('จำนวนชิ้น', '$_totalQuantity'),
            _summaryItem('สินค้า', '$_totalProducts'),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ---------------------------
  // BAR CHART
  // ---------------------------
  Widget _buildBarChart() {
    if (_salesDetail.isEmpty) return const SizedBox.shrink();

    final items = List<Map<String, dynamic>>.from(_salesDetail);
    items.sort(
      (a, b) => ((b['total_revenue'] as num?)?.toDouble() ?? 0).compareTo(
        (a['total_revenue'] as num?)?.toDouble() ?? 0,
      ),
    );

    final topCount = _calculateTopCount(items.length);
    final displayItems = _showAllProducts
        ? items
        : items.take(topCount).toList();

    final maxRevenue = (items.first['total_revenue'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'อันดับสินค้าขายดี',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (items.length > topCount)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _showAllProducts = !_showAllProducts),
                    icon: AnimatedRotation(
                      turns: _showAllProducts ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more),
                    ),
                    label: Text(
                      _showAllProducts
                          ? 'ย่อ'
                          : 'ดูสินค้าอื่นๆ (${items.length - displayItems.length})',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // BARS
            ...displayItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              final name = item['product_name'] as String;
              final options = item['_parsedOptions'] as String;
              final displayName = options.isNotEmpty
                  ? '$name ($options)'
                  : name;

              final revenue = (item['total_revenue'] as num?)?.toDouble() ?? 0;
              final quantity = item['total_quantity'] as int? ?? 0;

              final fraction = maxRevenue == 0
                  ? 0.0
                  : (revenue / maxRevenue).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. $displayName',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${_currencyFormat.format(revenue)} บาท',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction,
                          child: Container(
                            height: 24,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$quantity ชิ้น',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // PRODUCT AVATAR
  // ---------------------------
  Widget _buildProductAvatar(BuildContext context, Map<String, dynamic> item) {
    final imagePath = item['image_path'] as String?;

    if (imagePath != null && imagePath.isNotEmpty) {
      if (kIsWeb && imagePath.startsWith('http')) {
        return CircleAvatar(backgroundImage: NetworkImage(imagePath));
      } else if (!kIsWeb) {
        try {
          final file = File(imagePath);
          if (file.existsSync()) {
            return CircleAvatar(backgroundImage: FileImage(file));
          }
        } catch (_) {}
      }
    }

    return CircleAvatar(
      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Icon(Icons.shopping_bag, color: Theme.of(context).primaryColor),
    );
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดยอดขาย'),
        actions: [
          FilterBar(
            showStatusFilter: false,
            selectedDateFilter: _selectedFilter,
            onDateFilterChanged: (f) {
              setState(() => _selectedFilter = f);
              _loadSalesDetail();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _salesDetail.isEmpty
            ? const Center(child: Text('ยังไม่มีข้อมูลยอดขาย'))
            : RefreshIndicator(
                onRefresh: _loadSalesDetail,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [_buildDailySummary(), _buildBarChart()],
                ),
              ),
      ),
    );
  }
}
