import 'product.dart';

class OrderItem {
  final int? id;
  final int orderId;
  final int productId;
  final String productName;
  final double productPrice;
  final int quantity;
  final double subtotal;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    double? subtotal,
  }) : subtotal = subtotal ?? (productPrice * quantity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'product_price': productPrice,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      productPrice: (map['product_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }

  OrderItem copyWith({
    int? id,
    int? orderId,
    int? productId,
    String? productName,
    double? productPrice,
    int? quantity,
    double? subtotal,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productPrice: productPrice ?? this.productPrice,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
    );
  }

  static OrderItem fromProduct(Product product, {int quantity = 1}) {
    return OrderItem(
      productId: product.id!,
      productName: product.name,
      productPrice: product.price,
      quantity: quantity,
      orderId: 0, // Will be set when order is created
    );
  }
}

