import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../jmap/jmap_client.dart';
import '../util/format.dart';
import '../widgets/html_view.dart';

class MessageView extends StatelessWidget {
  final EmailDetail detail;
  final JmapClient client;
  final VoidCallback onDelete;
  final VoidCallback onMarkUnread;
  final VoidCallback onReply;

  const MessageView({
    super.key,
    required this.detail,
    required this.client,
    required this.onDelete,
    required this.onMarkUnread,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final h = detail.header;
    final fromText = h.from.isNotEmpty ? h.from.first.full : '(tanpa pengirim)';
    final toText = detail.to.map((a) => a.display).join(', ');
    final ccText = detail.cc.map((a) => a.display).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h.subject,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    child: Text(fromText.isNotEmpty
                        ? fromText.characters.first.toUpperCase()
                        : '?'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fromText,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        if (toText.isNotEmpty)
                          Text('kepada $toText',
                              style: Theme.of(context).textTheme.bodySmall),
                        if (ccText.isNotEmpty)
                          Text('cc $ccText',
                              style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text(formatDateFull(h.receivedAt),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onReply,
                    icon: const Icon(Icons.reply, size: 18),
                    label: const Text('Balas'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onMarkUnread,
                    icon: const Icon(Icons.mark_email_unread_outlined,
                        size: 18),
                    label: const Text('Tandai belum dibaca'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus'),
                  ),
                ],
              ),
              if (detail.attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final a in detail.attachments)
                      ActionChip(
                        avatar: const Icon(Icons.attach_file, size: 16),
                        label: Text('${a.name} (${formatSize(a.size)})'),
                        onPressed: () => web.window
                            .open(client.downloadUrl(a), '_blank'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: detail.html != null
              ? HtmlContentView(html: detail.html!)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(detail.text ?? '(email kosong)'),
                ),
        ),
      ],
    );
  }
}
