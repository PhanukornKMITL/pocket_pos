import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../services/database_service.dart';
import '../utils/date_filter.dart';
import '../widgets/filter_bar.dart';
import 'checkout_screen.dart';
import 'order_detail_screen.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  List<Order> _orders = [];
  bool _isLoading = true;
  OrderStatus? _filterStatus;
  DateFilter? _selectedDateFilter = DateFilter.allTime;
  // Custom range state
  bool _isCustomRange = false;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      DateTime? startDate;
      DateTime? endDate;
      if (_isCustomRange && _customStart != null && _customEnd != null) {
        startDate = _customStart;
        endDate = _customEnd;
      } else {
  startDate = _selectedDateFilter?.startDate;
  endDate = _selectedDateFilter?.endDate;
      }

      final orders = await _db.getAllOrders(
        status: _filterStatus,
        startDate: startDate,
        endDate: endDate,
      );
      setState(() {
        _orders = orders;
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
        title: const Text('ประวัติออเดอร์'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterBar(
              showStatusFilter: true,
              status: _filterStatus,
              onStatusChanged: (s) {
                setState(() => _filterStatus = s);
                _loadOrders();
              },
              selectedDateFilter: _isCustomRange ? null : _selectedDateFilter,
              onDateFilterChanged: (f) {
                setState(() {
                  _selectedDateFilter = f;
                  _isCustomRange = false;
                  _customStart = null;
                  _customEnd = null;
                });
                _loadOrders();
              },
              initialCustomRange: (_customStart != null && _customEnd != null)
                  ? DateTimeRange(start: _customStart!, end: _customEnd!)
                  : null,
              onCustomRangeSelected: (range) {
                setState(() {
                  _isCustomRange = true;
                  _customStart = range.start;
                  _customEnd = range.end;
                });
                _loadOrders();
              },
              onRefresh: _loadOrders,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ยังไม่มีออเดอร์',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ExpansionTile(
                          leading: _getStatusIcon(order.status),
                          title: Text(
                            'ออเดอร์ #${order.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_dateFormat.format(order.createdAt)),
                              Text(
                                '${_currencyFormat.format(order.total)} บาท',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...order.items.map((item) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${item.productName} x ${item.quantity}',
                                              ),
                                            ),
                                            Text(
                                              '${_currencyFormat.format(item.subtotal)} บาท',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'รวมทั้งหมด',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_currencyFormat.format(order.total)} บาท',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (order.paymentMethod != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'วิธีชำระ: ${order.paymentMethod}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  if (order.completedAt != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'ปิดออเดอร์: ${_dateFormat.format(order.completedAt!)}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          if (order.id != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => OrderDetailScreen(orderId: order.id!),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.visibility),
                                        label: const Text('รายละเอียด'),
                                      ),
                                    ],
                                  ),
                                  if (order.isPending) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _continueOrder(order),
                                            icon: const Icon(Icons.edit),
                                            label: const Text('ทำต่อ'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _cancelOrder(order),
                                            icon: const Icon(Icons.cancel),
                                            label: const Text('ยกเลิก'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
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
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _continueOrder(Order order) async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    
    // Navigate to checkout screen with order items and pending order ID
    await navigator.push(
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          cartItems: order.items,
          total: order.total,
          pendingOrderId: order.id,
        ),
      ),
    );

    // Reload orders when returning
    if (mounted) {
      _loadOrders();
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการยกเลิก'),
        content: const Text('ต้องการยกเลิกออเดอร์นี้หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ไม่'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteOrder(order.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ยกเลิกออเดอร์แล้ว'),
              backgroundColor: Colors.green,
            ),
          );
          _loadOrders();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
          );
        }
      }
    }
  }

  Widget _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Icon(Icons.pending, color: Colors.orange);
      case OrderStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case OrderStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.red);
    }
  }
}

