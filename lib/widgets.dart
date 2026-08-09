import 'package:flutter/material.dart';

import 'format.dart';
import 'models.dart';

const serviceIcons = <String, IconData>{
  'cuci_setrika': Icons.local_laundry_service,
  'cuci_kering': Icons.wash,
  'setrika': Icons.iron,
  'express': Icons.bolt,
  'baju_atasan': Icons.checkroom,
  'baju_bawahan': Icons.dry_cleaning,
  'selimut': Icons.airline_seat_individual_suite,
  'bedcover': Icons.bed,
  'sepatu': Icons.ice_skating,
};

IconData serviceIcon(String id) =>
    serviceIcons[id] ?? Icons.local_laundry_service;

/// Kop merek "H2O LAUNDRY / PARAKAN" dengan logo, dipakai di
/// beranda pelanggan, dashboard pemilik, dan layar pembuka.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoSize = compact ? 44.0 : 88.0;
    return Row(
      mainAxisAlignment:
          compact ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(compact ? 12 : 24),
          ),
          child: Icon(Icons.local_laundry_service,
              size: compact ? 26 : 48, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'H2O LAUNDRY',
              style: TextStyle(
                fontSize: compact ? 17 : 24,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            Text(
              'PARAKAN',
              style: TextStyle(
                fontSize: compact ? 11 : 14,
                fontWeight: FontWeight.w700,
                letterSpacing: compact ? 4 : 6,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Color statusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.menunggu:
      return const Color(0xFFD97706); // amber
    case OrderStatus.diterima:
      return const Color(0xFF2563EB); // blue
    case OrderStatus.diproses:
      return const Color(0xFF7C3AED); // violet
    case OrderStatus.siap:
      return const Color(0xFF0D9488); // teal
    case OrderStatus.selesai:
      return const Color(0xFF16A34A); // green
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(order.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        order.statusText,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showCustomer = false,
  });

  final Order order;
  final VoidCallback onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      serviceIcon(order.items.isEmpty
                          ? ''
                          : order.items.first.serviceId),
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showCustomer ? order.customerName : order.itemsBrief,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          showCustomer
                              ? '${order.id} • ${order.itemsBrief}'
                              : order.id,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusChip(order: order),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateTimeText(order.createdAt),
                      style: theme.textTheme.bodySmall),
                  Text(
                    rupiah(order.total),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linimasa 5 langkah status pesanan dengan waktu tercapainya.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (final status in OrderStatus.values) {
      final reached = status.index <= order.status.index;
      final isCurrent = status == order.status;
      StatusEntry? entry;
      for (final e in order.history) {
        if (e.status == status) entry = e;
      }
      final color =
          reached ? statusColor(order.status) : theme.disabledColor;
      children.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                reached
                    ? (isCurrent && !order.selesai
                        ? Icons.radio_button_checked
                        : Icons.check_circle)
                    : Icons.circle_outlined,
                size: 22,
                color: color,
              ),
              if (status != OrderStatus.selesai)
                Container(
                  width: 2,
                  height: 26,
                  color: status.index < order.status.index
                      ? color
                      : theme.dividerColor,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel(status),
                    style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: reached
                          ? theme.colorScheme.onSurface
                          : theme.disabledColor,
                    ),
                  ),
                  if (entry != null)
                    Text(dateTimeText(entry.at),
                        style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ));
    }
    return Column(children: children);
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.disabledColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.disabledColor),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Baris rincian "label ... nilai" untuk kartu ringkasan.
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold ? style : theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          Flexible(
            child: Text(value, style: style, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
