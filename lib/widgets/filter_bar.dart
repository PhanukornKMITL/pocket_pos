import 'package:flutter/material.dart';
import '../utils/date_filter.dart';
import '../models/order.dart';

/// Reusable filter bar used across screens.
/// - shows optional status filter (orders)
/// - shows date filter presets and a 'Custom' option which opens a date range picker
class FilterBar extends StatelessWidget {
  final bool showStatusFilter;
  final OrderStatus? status;
  final ValueChanged<OrderStatus?>? onStatusChanged;
  final DateFilter? selectedDateFilter; // null means custom range selected
  final ValueChanged<DateFilter>? onDateFilterChanged;
  final ValueChanged<DateTimeRange>? onCustomRangeSelected;
  final DateTimeRange? initialCustomRange;
  // refresh handled by parent with pull-to-refresh; removed onRefresh

  const FilterBar({
    super.key,
    this.showStatusFilter = false,
    this.status,
    this.onStatusChanged,
    this.selectedDateFilter = DateFilter.allTime,
    this.onDateFilterChanged,
    this.onCustomRangeSelected,
    this.initialCustomRange,
    // no onRefresh
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showStatusFilter) ...[
          PopupMenuButton<OrderStatus?>(
            icon: const Icon(Icons.filter_list),
            onSelected: onStatusChanged,
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('ทั้งหมด')),
              const PopupMenuItem(value: OrderStatus.pending, child: Text('รอดำเนินการ')),
              const PopupMenuItem(value: OrderStatus.completed, child: Text('เสร็จสิ้น')),
              const PopupMenuItem(value: OrderStatus.cancelled, child: Text('ยกเลิก')),
            ],
          ),
          const SizedBox(width: 8),
        ],

        DropdownButton<DateFilter?>(
          value: selectedDateFilter,
          items: [
            ...DateFilter.values.map((filter) => DropdownMenuItem<DateFilter?>(
                  value: filter,
                  child: Text(filter.label),
                )),
            const DropdownMenuItem<DateFilter?>(value: null, child: Text('กำหนดเอง')),
          ],
          onChanged: (f) async {
            if (f == null) {
              if (onCustomRangeSelected != null) {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 5),
                  lastDate: DateTime(now.year + 1),
                  initialDateRange: initialCustomRange,
                );
                if (picked != null) onCustomRangeSelected!(picked);
              }
            } else {
              if (onDateFilterChanged != null) onDateFilterChanged!(f);
            }
          },
        ),

        // No refresh button: use pull-to-refresh instead
      ],
    );
  }
}
