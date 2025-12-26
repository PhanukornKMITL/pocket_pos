import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
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
  DateFilter _selectedFilter = DateFilter.today;

  @override
  void initState() {
    super.initState();
    _loadSalesDetail();
  }

  Future<void> _loadSalesDetail() async {
    setState(() => _isLoading = true);
    try {
      final detail = await _db.getSalesDetailByProduct(
        startDate: _selectedFilter.startDate,
        endDate: _selectedFilter.endDate,
      );
      setState(() {
        _salesDetail = detail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    }
  }

  Widget _buildBarChart() {
    if (_salesDetail.isEmpty) return const SizedBox.shrink();

    // Show top 8 products by revenue using simple widgets (no external chart lib)
    final items = List<Map<String, dynamic>>.from(_salesDetail);
    items.sort((a, b) => ((b['total_revenue'] as num?)?.toDouble() ?? 0).compareTo((a['total_revenue'] as num?)?.toDouble() ?? 0));
    final top = items.take(8).toList();
    final maxRevenue = top.map((e) => (e['total_revenue'] as num?)?.toDouble() ?? 0.0).fold<double>(0.0, (p, e) => e > p ? e : p);

    return SizedBox(
      height: 260,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ยอดขายตามสินค้า (Top)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: top.map((e) {
                      final revenue = (e['total_revenue'] as num?)?.toDouble() ?? 0.0;
                      final name = e['product_name'] as String? ?? '';
                      final fraction = maxRevenue == 0 ? 0.0 : (revenue / maxRevenue).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Tooltip(
                              message: '${name}\n${_currencyFormat.format(revenue)} บาท',
                              child: Container(
                                width: 40,
                                height: 140,
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: fraction,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 72,
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดยอดขาย'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterBar(
              showStatusFilter: false,
              selectedDateFilter: _selectedFilter,
              onDateFilterChanged: (f) {
                setState(() => _selectedFilter = f);
                _loadSalesDetail();
              },
              onCustomRangeSelected: (range) {
                // treat custom by creating a temporary DateFilter? Not needed here — call db directly
                setState(() {
                  _selectedFilter = DateFilter.allTime; // keep label generic
                });
                _db.getSalesDetailByProduct(startDate: range.start, endDate: range.end).then((detail) {
                  if (mounted) setState(() => _salesDetail = detail);
                });
              },
              initialCustomRange: null,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _salesDetail.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bar_chart_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ยังไม่มีข้อมูลยอดขาย',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSalesDetail,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      const SizedBox(height: 8),
                      // Chart (top products) and header
                      _buildBarChart(),
                      const SizedBox(height: 8),
                      ..._salesDetail.map((item) {
                        final productName = item['product_name'] as String;
                        final totalQuantity = item['total_quantity'] as int? ?? 0;
                        final totalRevenue = (item['total_revenue'] as num?)?.toDouble() ?? 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: (() {
                                  final imagePath = item['image_path'] as String?;
                                  if (imagePath != null && imagePath.isNotEmpty) {
                                    if (kIsWeb) {
                                      if (imagePath.startsWith('http')) {
                                        return CircleAvatar(
                                          backgroundColor: Colors.transparent,
                                          backgroundImage: NetworkImage(imagePath),
                                        );
                                      }
                                      return CircleAvatar(
                                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                        child: Icon(Icons.shopping_bag, color: Theme.of(context).primaryColor),
                                      );
                                    }

                                    try {
                                      final file = File(imagePath);
                                      if (file.existsSync()) {
                                        return CircleAvatar(
                                          backgroundColor: Colors.transparent,
                                          backgroundImage: FileImage(file),
                                        );
                                      }
                                    } catch (_) {}
                                  }

                                  return CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                    child: Icon(Icons.shopping_bag, color: Theme.of(context).primaryColor),
                                  );
                                })(),
                            title: Text(
                              productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.shopping_cart, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'จำนวน: $totalQuantity',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_currencyFormat.format(totalRevenue)} บาท',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                Text(
                                  '${_currencyFormat.format(totalRevenue / (totalQuantity > 0 ? totalQuantity : 1))} ต่อชิ้น',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

