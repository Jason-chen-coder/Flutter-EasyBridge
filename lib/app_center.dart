import 'package:flutter/material.dart';
import 'package:flutter_h5/utils/localhost_server_manager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'local_h5_webview.dart';

class AppItem {
  final String title;
  final String path;
  final IconData icon;
  final String? remoteUrl;

  const AppItem({
    required this.title,
    required this.path,
    required this.icon,
    this.remoteUrl,
  });
}

class AppCenterPage extends StatelessWidget {
  const AppCenterPage({super.key});

  List<AppItem> _buildApps() {
    return const [
      AppItem(title: '示例应用 A', path: 'app1', icon: Icons.web),
      AppItem(title: '示例应用 B', path: 'app2', icon: Icons.language),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final apps = _buildApps();

    return Scaffold(
      appBar: AppBar(title: const Text('应用中心')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return _AppTile(
              title: app.title,
              icon: app.icon,
              onTap: () async {
                final LocalhostServerManager _serverManager =
                    LocalhostServerManager();
                final baseUrl = await _serverManager.start(
                  documentRoot: 'assets/h5',
                );

                // Try to find index.html in the dist subdirectory first, then fallback to app directory
                String path = '/app1/dist/index.html';
                final url = '$baseUrl$path';
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LocalH5WebView(key:UniqueKey(),appName: app.path)
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _AppTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 24, child: Icon(icon, size: 28)),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
