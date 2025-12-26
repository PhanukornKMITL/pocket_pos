import 'dart:typed_data';
import 'order_item.dart';

enum OrderStatus {
  pending,
  completed,
  cancelled,
}

class Order {
  final int? id;
  final OrderStatus status;
  final double total;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Uint8List? qrImage;
  final List<OrderItem> items;

  Order({
    this.id,
    this.status = OrderStatus.pending,
    required this.total,
    this.paymentMethod,
    this.notes,
    this.qrImage,
    DateTime? createdAt,
    this.completedAt,
    List<OrderItem>? items,
  })  : createdAt = createdAt ?? DateTime.now(),
        items = items ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status.name,
      'total': total,
      'payment_method': paymentMethod,
      'notes': notes,
      'qr_image': qrImage,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map, {List<OrderItem>? items}) {
    return Order(
      id: map['id'] as int?,
      status: OrderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      total: (map['total'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      qrImage: map['qr_image'] as Uint8List?,
      items: items ?? [],
    );
  }

  Order copyWith({
    int? id,
    OrderStatus? status,
    double? total,
    String? paymentMethod,
    String? notes,
    Uint8List? qrImage,
    DateTime? createdAt,
    DateTime? completedAt,
    List<OrderItem>? items,
  }) {
    return Order(
      id: id ?? this.id,
      status: status ?? this.status,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      qrImage: qrImage ?? this.qrImage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      items: items ?? this.items,
    );
  }

  bool get isPending => status == OrderStatus.pending;
  bool get isCompleted => status == OrderStatus.completed;
  bool get isCancelled => status == OrderStatus.cancelled;
}

