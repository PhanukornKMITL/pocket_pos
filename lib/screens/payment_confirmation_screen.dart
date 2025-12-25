import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../services/database_service.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final List<OrderItem> cartItems;
  final double total;
  final String paymentMethod;
  final int? pendingOrderId;

  const PaymentConfirmationScreen({
    super.key,
    required this.cartItems,
    required this.total,
    required this.paymentMethod,
    this.pendingOrderId,
  });

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  bool _isProcessing = false;

  Future<void> _confirmPayment() async {
    setState(() => _isProcessing = true);

    try {
      final order = Order(
        status: OrderStatus.completed,
        total: widget.total,
        paymentMethod: widget.paymentMethod,
        items: widget.cartItems,
        completedAt: DateTime.now(),
      );

      final db = DatabaseService.instance;
      if (widget.pendingOrderId != null) {
        // Finalize existing pending order (update + replace items)
        await db.finalizeOrder(widget.pendingOrderId!, order);
      } else {
        // Create a fresh completed order
        await db.createOrder(order);
      }

      if (mounted) {
        // Pop back to home screen
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกออเดอร์สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
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
        title: const Text('ยืนยันการชำระเงิน'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Payment Method Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.paymentMethod == 'เงินสด'
                          ? Icons.money
                          : Icons.qr_code,
                      size: 64,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.paymentMethod == 'เงินสด'
                        ? 'รอรับเงินสด'
                        : 'รอสแกน QR Code',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ยอดที่ต้องชำระ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_currencyFormat.format(widget.total)} บาท',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'รายการสินค้า',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ...widget.cartItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Column(
                            children: [
                              ListTile(
                                title: Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${_currencyFormat.format(item.productPrice)} บาท x ${item.quantity}',
                                ),
                                trailing: Text(
                                  '${_currencyFormat.format(item.subtotal)} บาท',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (index < widget.cartItems.length - 1)
                                const Divider(height: 1),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Total and Confirm Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'รวมทั้งหมด',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_currencyFormat.format(widget.total)} บาท',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                onPressed: _isProcessing ? null : _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.paymentMethod == 'เงินสด'
                            ? 'ยืนยันรับเงินแล้ว'
                            : 'ยืนยันการชำระเงิน',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

