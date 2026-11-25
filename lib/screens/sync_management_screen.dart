import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils/date_formatter.dart';
import '../providers/inventory_provider.dart';

class SyncManagementScreen extends StatelessWidget {
  const SyncManagementScreen({super.key});

  Future<void> _handleSync(
    BuildContext context,
    InventoryProvider provider,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final msg = await provider.syncToGoogleSheet();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Sync error: $e')));
    }
  }

  Future<void> _handleImportFromSheet(
    BuildContext context,
    InventoryProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fetch from Google Sheets?'),
        content: const Text(
          'This will import rows from Google Sheets into Firestore and update matching records (by ID, Property #, or Serial #). Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final msg = await provider.importFromGoogleSheet();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import error: $e')));
    }
  }

  Future<void> _handleWipeDatabase(
    BuildContext context,
    InventoryProvider provider,
  ) async {
    final confirmCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isMatch = confirmCtrl.text.trim().toUpperCase() == 'WIPE';
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('Wipe Firestore Database?'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will permanently delete ALL equipment records and change history from Firestore. Your Google Sheet will not be deleted.\n\nType WIPE below to confirm:',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Type WIPE',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: isMatch ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Delete Everything'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final msg = await provider.wipeDatabase();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Wipe failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final busy = provider.isSyncingSheet || provider.isWipingDatabase;

    return Scaffold(
      appBar: AppBar(title: const Text('Data & Google Sheets Sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sync,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Google Sheets Synchronization',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last Synced: ${DateFormatter.formatShort(provider.lastSyncedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Active Records in App: ${provider.totalCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => _handleImportFromSheet(context, provider),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Fetch from Google Sheets'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => _handleSync(context, provider),
                      icon: provider.isSyncingSheet
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        provider.isSyncingSheet
                            ? 'Syncing to Sheet...'
                            : 'Update Google Sheet',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Emergency Data Controls',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.red.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use this only when resetting Firestore before a fresh re-import from Google Sheets.',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: busy
                          ? null
                          : () => _handleWipeDatabase(context, provider),
                      icon: provider.isWipingDatabase
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever),
                      label: Text(
                        provider.isWipingDatabase
                            ? 'Clearing Database...'
                            : 'Wipe / Clear Firestore Database',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
