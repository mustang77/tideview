import 'package:flutter/material.dart';

import '../jmap/jmap_client.dart';
import '../util/format.dart';

Color senderColor(String seed) =>
    Colors.primaries[seed.hashCode.abs() % Colors.primaries.length];

class EmailTile extends StatelessWidget {
  final EmailHeader email;
  final bool selected;
  final VoidCallback onTap;

  const EmailTile({
    super.key,
    required this.email,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final fromText =
        email.from.isNotEmpty ? email.from.first.display : '(tanpa pengirim)';
    final bold = email.seen ? FontWeight.normal : FontWeight.w700;
    final initial =
        fromText.isNotEmpty ? fromText.characters.first.toUpperCase() : '?';
    return ListTile(
      selected: selected,
      leading: CircleAvatar(
        backgroundColor: senderColor(fromText).withValues(alpha: 0.85),
        foregroundColor: Colors.white,
        child: Text(initial),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(fromText,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: bold)),
          ),
          const SizedBox(width: 8),
          Text(formatDateShort(email.receivedAt),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(email.subject,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: bold)),
              ),
              if (email.hasAttachment) const Icon(Icons.attach_file, size: 14),
            ],
          ),
          Text(email.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      onTap: onTap,
    );
  }
}
