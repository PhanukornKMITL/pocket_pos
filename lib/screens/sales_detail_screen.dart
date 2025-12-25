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
              onRefresh: _loadSalesDetail,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ยอดขายตามสินค้า',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          DropdownButton<DateFilter>(
                            value: _selectedFilter,
                            items: DateFilter.values.map((filter) {
                              return DropdownMenuItem(
                                value: filter,
                                child: Text(filter.label),
                              );
                            }).toList(),
                            onChanged: (filter) {
                              if (filter != null) {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                                _loadSalesDetail();
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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

