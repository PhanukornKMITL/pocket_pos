import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_item.dart';
import 'payment_confirmation_screen.dart';
import 'qr_code_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<OrderItem> cartItems;
  final double total;
  final int? pendingOrderId;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.total,
    this.pendingOrderId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final NumberFormat _currencyFormat = NumberFormat('#,##0.00');
  String? _selectedPaymentMethod;

  void _proceedToPayment() {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวิธีชำระเงิน')),
      );
      return;
    }

    if (_selectedPaymentMethod == 'QR Code') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRCodeScreen(
            cartItems: widget.cartItems,
            total: widget.total,
            pendingOrderId: widget.pendingOrderId,
          ),
        ),
      );
    } else if (_selectedPaymentMethod == 'เงินสด') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentConfirmationScreen(
            cartItems: widget.cartItems,
            total: widget.total,
            paymentMethod: 'เงินสด',
            pendingOrderId: widget.pendingOrderId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สรุปออเดอร์'),
      ),
      body: Column(
        children: [
          // Order Summary
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'รายการสินค้า',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                                    fontSize: 16,
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
                  const SizedBox(height: 24),
                  const Text(
                    'วิธีชำระเงิน',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PaymentMethodOption(
                    title: 'เงินสด',
                    icon: Icons.money,
                    isSelected: _selectedPaymentMethod == 'เงินสด',
                    onTap: () {
                      setState(() => _selectedPaymentMethod = 'เงินสด');
                    },
                  ),
                  const SizedBox(height: 12),
                  _PaymentMethodOption(
                    title: 'QR Code',
                    icon: Icons.qr_code,
                    isSelected: _selectedPaymentMethod == 'QR Code',
                    onTap: () {
                      setState(() => _selectedPaymentMethod = 'QR Code');
                    },
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
                    onPressed: _selectedPaymentMethod == null ? null : _proceedToPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPaymentMethod == null
                          ? Colors.grey[300]
                          : Theme.of(context).primaryColor,
                      foregroundColor: _selectedPaymentMethod == null
                          ? Colors.grey[600]
                          : Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                    ),
                    child: const Text(
                      'ดำเนินการต่อ',
                      style: TextStyle(
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

class _PaymentMethodOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected
          ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
          : null,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected ? Theme.of(context).primaryColor : null,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).primaryColor : null,
            ),
          ),
          trailing: isSelected
              ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                )
              : null,
        ),
      ),
    );
  }
}

