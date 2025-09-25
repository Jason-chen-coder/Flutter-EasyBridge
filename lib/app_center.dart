import 'package:flutter/material.dart';
import 'package:flutter_h5/utils/app_bridge.dart';
import 'app1_h5_webview_debug_page.dart';
import 'h5_webview.dart';

class AppItem {
  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  const AppItem({
    required this.title,
    required this.icon,
    required this.builder,
  });
}

class AppCenterPage extends StatelessWidget {
  const AppCenterPage({super.key});

  List<AppItem> _buildApps() {
    return [
      AppItem(
        title: '示例应用 A (本地)',
        icon: Icons.web,
        builder:
            (context) =>
                App1H5WebviewDebugPage(key: UniqueKey(),appName: 'app1'),
      ),
      AppItem(
        title: '示例应用 B (本地)',
        icon: Icons.language,
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(backgroundColor: Colors.white),
              body: H5Webview(
                key: UniqueKey(),
                appName: 'app2',
                bridge: AppBridge(),
              ),
            ),
      ),
      AppItem(
        title: '在线应用示例',
        icon: Icons.cloud,
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(backgroundColor: Colors.white),
              body: H5Webview(
                key: UniqueKey(),
                appName: 'online_demo',
                bridge: AppBridge(),
                onlineUrl: 'https://flutter.dev',
              ),
            ),
      ),
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
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => app.builder(context)));
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
