import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../utils/date_filter.dart';
import '../widgets/filter_bar.dart';
import 'order_screen.dart';
import 'products_list_screen.dart';
import 'orders_history_screen.dart';
import 'sales_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  DateFilter _selectedFilter = DateFilter.today;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh statistics when screen becomes visible again
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadStatistics();
        }
      });
    }
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _db.getSalesStatistics(
        startDate: _selectedFilter.startDate,
        endDate: _selectedFilter.endDate,
      );
      setState(() {
        _statistics = stats;
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
        title: const Text('Pocket POS'),
        actions: [],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions
              const Text(
                'เมนูหลัก',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.add_shopping_cart,
                      title: 'สร้างออเดอร์',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OrderScreen(),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.inventory_2,
                      title: 'จัดการสินค้า',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProductsListScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.history,
                      title: 'ประวัติออเดอร์',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OrdersHistoryScreen(),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.analytics,
                      title: 'ยอดขาย',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SalesDetailScreen(),
                          ),
                        ).then((_) => _loadStatistics());
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Statistics
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'สรุปยอดขาย',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilterBar(
                        showStatusFilter: false,
                        selectedDateFilter: _selectedFilter,
                        onDateFilterChanged: (f) {
                          setState(() => _selectedFilter = f);
                          _loadStatistics();
                        },
                        onCustomRangeSelected: (range) {
                          // apply custom range directly to statistics
                          _db.getSalesStatistics(startDate: range.start, endDate: range.end).then((stats) {
                            if (mounted) setState(() => _statistics = stats);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _StatRow(
                              label: 'จำนวนออเดอร์ (ชำระเงินแล้ว)',
                              value: '${_statistics['total_orders'] ?? 0}',
                              icon: Icons.receipt_long,
                            ),
                            const Divider(),
                            _StatRow(
                              label: 'ยอดขายรวม',
                              value:
                                  '${_currencyFormat.format(_statistics['total_revenue'] ?? 0.0)} บาท',
                              icon: Icons.attach_money,
                              valueColor: Colors.green,
                            ),
                            if ((_statistics['total_orders'] ?? 0) > 0) ...[
                              const Divider(),
                              _StatRow(
                                label: 'ยอดขายเฉลี่ยต่อออเดอร์',
                                value:
                                    '${_currencyFormat.format((_statistics['total_revenue'] ?? 0.0) / (_statistics['total_orders'] ?? 1))} บาท',
                                icon: Icons.trending_up,
                                valueColor: Colors.blue,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}

