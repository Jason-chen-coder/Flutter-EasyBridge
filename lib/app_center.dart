import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_bridge/utils/app_bridge.dart';
import 'h5_webview_debug_page.dart';
import 'h5_webview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';

class AppItem {
  final String name;
  final String description;
  final String version;
  final Widget icon;
  final WidgetBuilder builder;
  final String heroTag;

  const AppItem({
    required this.name,
    required this.icon,
    required this.builder,
    required this.heroTag,
    this.description = '',
    this.version = '1.0.0',
  });
}

class AppCenterPage extends StatefulWidget {
  const AppCenterPage({super.key});

  @override
  State<AppCenterPage> createState() => _AppCenterPageState();
}

class _AppCenterPageState extends State<AppCenterPage> {
  // 用于刷新应用列表
  Key _refreshKey = UniqueKey();

  Future<List<AppItem>> _buildApps() async {
    // 并行执行，互不影响
    final results = await Future.wait([
      _handleGetCacheApps().catchError((e) {
        print('[AppCenter] Failed to load cache apps: $e');
        return <AppItem>[];
      }),
      _handleGetLocalApps([
        'debugger-app',
        'vue-app',
      ]).catchError((e) {
        print('[AppCenter] Failed to load local apps: $e');
        return <AppItem>[];
      }),
      _handleGetOnlineApps().catchError((e) {
        print('[AppCenter] Failed to load online apps: $e');
        return <AppItem>[];
      }),
    ]);
    
    List<AppItem> cacheApps = results[0];
    List<AppItem> localApps = results[1];
    List<AppItem> onlineApps = results[2];
    
    return [...cacheApps, ...localApps, ...onlineApps];
  }

  Future<List<AppItem>> _handleGetLocalApps(List<String> appNames) async {
    List<AppItem> localApps = [];
    
    try {
      for (String appName in appNames) {
        try {
          // 1. 读取 manifest.json
          String manifestPath = 'assets/h5/$appName/manifest.json';
          String manifestContent = await rootBundle.loadString(manifestPath);
          Map<String, dynamic> manifest = json.decode(manifestContent);
          
          // 2. 从 manifest 解析配置信息
          String name = manifest['name'] ?? appName;
          String description = manifest['description'] ?? '';
          String version = manifest['version'] ?? '1.0.0';
          String heroTag = 'local-$appName-hero';
          
          // 3. 构建资源路径
          String iconPath = 'assets/h5/$appName/icon.png';
          
          // 4. 创建 AppItem
          localApps.add(
            AppItem(
              name: name,
              description: description,
              version: version,
              icon: Image.asset(iconPath),
              heroTag: heroTag,
              builder: (context) => appName == 'debugger-app'
                ? H5WebviewDebugPage(
                    key: UniqueKey(),
                    appName: appName,
                    heroTag: heroTag,
                    heroIcon: Image.asset(iconPath,fit:BoxFit.cover),
                  )
                : Scaffold(
                    backgroundColor: Colors.white,
                    appBar: AppBar(backgroundColor: Colors.white),
                    body: H5Webview(
                      key: UniqueKey(),
                      appName: appName,
                      bridge: AppBridge(),
                      heroTag: heroTag,
                      heroIcon: Image.asset(iconPath,fit:BoxFit.cover),
                    ),
                  ),
            ),
          );
          
          print('[AppCenter] Loaded local app: $name from assets/h5/$appName');
        } catch (e) {
          print('[AppCenter] Error loading local app $appName: $e');
        }
      }
    } catch (e) {
      print('[AppCenter] Error loading local apps: $e');
    }
    
    return localApps;
  }

  Future<List<AppItem>> _handleGetCacheApps() async {
    List<AppItem> cacheApps = [];
    
    try {
      // 1. 获取应用支持目录
      final Directory appSupportDir = await getApplicationSupportDirectory();
      final Directory h5Dir = Directory('${appSupportDir.path}/h5');
      
      // 如果h5目录不存在，直接返回空列表
      if (!await h5Dir.exists()) {
        print('[AppCenter] h5 directory does not exist: ${h5Dir.path}');
        return cacheApps;
      }
      
      // 2. 读取h5目录下的所有子目录
      final List<FileSystemEntity> entities = await h5Dir.list().toList();
      
      for (var entity in entities) {
        if (entity is Directory) {
          final String appName = entity.path.split('/').last;
          
          // 检查必需的文件是否都存在
          final File manifestFile = File('${entity.path}/manifest.json');
          final File iconFile = File('${entity.path}/icon.png');
          final File entryFile = File('${entity.path}/dist/index.html');
          
          bool manifestExists = await manifestFile.exists();
          bool iconExists = await iconFile.exists();
          bool entryExists = await entryFile.exists();
          
          if (manifestExists && iconExists && entryExists) {
            try {
              // 3. 读取并解析manifest.json
              String manifestContent = await manifestFile.readAsString();
              Map<String, dynamic> manifest = json.decode(manifestContent);
              
              // 从manifest读取应用信息
              String name = manifest['name'] ?? appName;
              String description = manifest['description'] ?? '';
              String version = manifest['version'] ?? '1.0.0';
              String heroTag = 'cache-$appName-hero';
              
              // 创建AppItem
              cacheApps.add(
                AppItem(
                  name: name,
                  description: description,
                  version: version,
                  icon: Image.file(iconFile,fit:BoxFit.cover,),
                  heroTag: heroTag,
                  builder: (context) => Scaffold(
                    backgroundColor: Colors.white,
                    appBar: AppBar(backgroundColor: Colors.white),
                    body: H5Webview(
                      key: UniqueKey(),
                      appName: appName,
                      bridge: AppBridge(),
                      localFilePath: entryFile.path,  // 使用本地文件路径
                      heroTag: heroTag,
                      heroIcon: Image.file(iconFile,fit:BoxFit.cover,),
                    ),
                  ),
                ),
              );
              
              print('[AppCenter] Loaded cache app: $name');
            } catch (e) {
              print('[AppCenter] Error parsing manifest for $appName: $e');
            }
          } else {
            print('[AppCenter] Skipping $appName - missing required files');
            print('  manifest.json: $manifestExists');
            print('  icon.png: $iconExists');
            print('  dist/index.html: $entryExists');
          }
        }
      }
    } catch (e) {
      print('[AppCenter] Error loading cache apps: $e');
    }
    
    return cacheApps;
  }

  /// 初始化默认在线应用配置
  Future<void> _initDefaultOnlineApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const String key = 'online_apps_config';
      
      // 如果已经有配置，则不覆盖
      if (prefs.containsKey(key)) {
        print('[AppCenter] Online apps config already exists');
        return;
      }
      
      // 默认在线应用配置
      List<Map<String, dynamic>> defaultApps = [
        {
          'id': 'flutter-official',
          'name': 'Flutter 官网',
          'description': '访问 Flutter 官方网站，了解最新的框架动态和资源。',
          'iconUrl': 'https://i-blog.csdnimg.cn/direct/445a8fb02750466dbde02cd700fcd51a.png',
          'url': 'https://flutter.dev',
        },
      ];
      
      // 保存到 SharedPreferences
      String jsonString = json.encode(defaultApps);
      await prefs.setString(key, jsonString);
      print('[AppCenter] Default online apps config initialized');
    } catch (e) {
      print('[AppCenter] Error initializing default online apps: $e');
    }
  }

  /// 从 SharedPreferences 读取在线应用配置
  Future<List<AppItem>> _handleGetOnlineApps() async {
    List<AppItem> onlineApps = [];
    
    try {
      // 1. 初始化默认配置（如果不存在）
      await _initDefaultOnlineApps();
      
      // 2. 读取配置
      final prefs = await SharedPreferences.getInstance();
      const String key = 'online_apps_config';
      String? jsonString = prefs.getString(key);
      
      if (jsonString == null || jsonString.isEmpty) {
        print('[AppCenter] No online apps config found');
        return onlineApps;
      }
      
      // 3. 解析配置
      List<dynamic> appsConfig = json.decode(jsonString);
      print("appsConfig===>${appsConfig}");
      // 4. 构建 AppItem 列表
      for (var config in appsConfig) {
        try {
          String id = config['id'] ?? '';
          String name = config['name'] ?? 'Unknown';
          String description = config['description'] ?? '';
          String version = config['version'] ?? '1.0.0';
          String iconUrl = config['iconUrl'] ?? '';
          String url = config['url'] ?? '';
          String heroTag = 'online-$id-hero';
          
          if (id.isEmpty || url.isEmpty) {
            print('[AppCenter] Skipping online app - missing id or url');
            continue;
          }
          
          onlineApps.add(
            AppItem(
              name: name,
              description: description,
              version: version,
              icon: Image.network(iconUrl,fit:BoxFit.cover),
              heroTag: heroTag,
              builder: (context) => Scaffold(
                backgroundColor: Colors.white,
                appBar: AppBar(backgroundColor: Colors.white),
                body: H5Webview(
                  key: UniqueKey(),
                  appName: id,
                  bridge: AppBridge(),
                  onlineUrl: url,
                  heroTag: heroTag,
                  heroIcon: Image.network(iconUrl,fit:BoxFit.cover),
                ),
              ),
            ),
          );
          
          print('[AppCenter] Loaded online app: $name');
        } catch (e) {
          print('[AppCenter] Error parsing online app config: $e');
        }
      }
    } catch (e) {
      print('[AppCenter] Error loading online apps: $e');
    }
    
    return onlineApps;
  }

  /// 显示添加应用选择对话框
  void _showAddAppTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加应用'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('添加离线应用'),
              subtitle: const Text('上传 zip 压缩包'),
              onTap: () {
                Navigator.of(context).pop();
                _showAddOfflineAppDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('添加在线应用'),
              subtitle: const Text('配置在线网址'),
              onTap: () {
                Navigator.of(context).pop();
                _showAddOnlineAppDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 显示添加在线应用对话框
  void _showAddOnlineAppDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final iconUrlController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加在线应用'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '应用名称 *',
                    hintText: '请输入应用名称',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入应用名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: '应用描述',
                    hintText: '请输入应用描述',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: iconUrlController,
                  decoration: const InputDecoration(
                    labelText: '图标URL *',
                    hintText: 'https://example.com/icon.png',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入图标URL';
                    }
                    if (!value.startsWith('http')) {
                      return '请输入有效的URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: '应用URL *',
                    hintText: 'https://example.com',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入应用URL';
                    }
                    if (!value.startsWith('http')) {
                      return '请输入有效的URL';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _saveOnlineApp(
                  nameController.text,
                  descriptionController.text,
                  iconUrlController.text,
                  urlController.text,
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 保存在线应用到 SharedPreferences
  Future<void> _saveOnlineApp(
    String name,
    String description,
    String iconUrl,
    String url,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const String key = 'online_apps_config';
      
      // 读取现有配置
      String? jsonString = prefs.getString(key);
      List<dynamic> appsConfig = [];
      
      if (jsonString != null && jsonString.isNotEmpty) {
        appsConfig = json.decode(jsonString);
      }
      
      // 生成唯一 ID
      String id = 'online-${DateTime.now().millisecondsSinceEpoch}';
      
      // 添加新应用
      appsConfig.add({
        'id': id,
        'name': name,
        'description': description,
        'iconUrl': iconUrl,
        'url': url,
        'version': '1.0.0',
      });
      
      // 保存配置
      await prefs.setString(key, json.encode(appsConfig));
      
      print('[AppCenter] Online app saved: $name');
      
      // 刷新应用列表
      _refreshAppList();
      
      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('在线应用 "$name" 添加成功')),
        );
      }
    } catch (e) {
      print('[AppCenter] Error saving online app: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  /// 显示添加离线应用对话框
  void _showAddOfflineAppDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加离线应用'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请上传包含以下内容的 zip 压缩包：'),
            const SizedBox(height: 12),
            const Text('📁 压缩包根目录应包含：'),
            const SizedBox(height: 8),
            _buildRequirementItem('manifest.json', '应用配置文件'),
            _buildRequirementItem('icon.png', '应用图标'),
            _buildRequirementItem('dist/index.html', 'H5 入口文件'),
            const SizedBox(height: 12),
            const Text(
              'manifest.json 示例：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '{\n'
                '  "name": "我的应用",\n'
                '  "description": "应用描述",\n'
                '  "version": "1.0.0"\n'
                '}',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _pickAndInstallOfflineApp();
            },
            child: const Text('选择文件'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String file, String description) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 13),
                children: [
                  TextSpan(
                    text: file,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' - $description'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 选择并安装离线应用
  Future<void> _pickAndInstallOfflineApp() async {
    try {
      // 选择 zip 文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) {
        print('[AppCenter] User cancelled file picker');
        return;
      }

      // 显示加载提示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在安装应用...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final file = File(result.files.single.path!);
      await _installOfflineApp(file);

      // 关闭加载提示
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('[AppCenter] Error picking file: $e');
      if (mounted) {
        Navigator.of(context).pop(); // 关闭加载提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文件选择失败: $e')),
        );
      }
    }
  }

  /// 安装离线应用
  Future<void> _installOfflineApp(File zipFile) async {
    try {
      // 1. 读取 zip 文件
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 2. 查找应用根目录（自动检测）
      String? appRootPrefix;
      String? manifestPath;
      String? iconPath;
      String? indexPath;

      // 遍历所有文件，找到 manifest.json 的位置
      for (final file in archive) {
        final name = file.name;
        
        // 忽略 macOS 系统文件
        if (name.startsWith('__MACOSX/') || name.contains('/.DS_Store')) {
          continue;
        }
        
        print('Found file in zip: $name');
        
        // 查找 manifest.json
        if (name.endsWith('manifest.json') && !name.contains('__MACOSX')) {
          manifestPath = name;
          // 提取根目录前缀
          if (name.contains('/')) {
            appRootPrefix = name.substring(0, name.lastIndexOf('/') + 1);
          } else {
            appRootPrefix = '';
          }
          print('Detected app root prefix: "$appRootPrefix"');
        }
      }

      if (manifestPath == null) {
        throw Exception('压缩包中未找到 manifest.json 文件');
      }

      // 3. 验证必需文件（使用检测到的根目录）
      iconPath = '${appRootPrefix}icon.png';
      indexPath = '${appRootPrefix}dist/index.html';

      bool hasManifest = false;
      bool hasIcon = false;
      bool hasIndex = false;

      for (final file in archive) {
        if (file.name == manifestPath) hasManifest = true;
        if (file.name == iconPath) hasIcon = true;
        if (file.name == indexPath) hasIndex = true;
      }

      print('Validation: hasManifest=$hasManifest, hasIcon=$hasIcon, hasIndex=$hasIndex');
      print('Looking for: manifest=$manifestPath, icon=$iconPath, index=$indexPath');

      if (!hasManifest || !hasIcon || !hasIndex) {
        throw Exception('压缩包缺少必需文件。\n需要: $manifestPath, $iconPath, $indexPath');
      }

      // 4. 读取 manifest 获取应用名称
      String? appName;
      for (final file in archive) {
        if (file.name == manifestPath) {
          final manifestContent = String.fromCharCodes(file.content as List<int>);
          final manifest = json.decode(manifestContent);
          appName = manifest['name'] ?? 'app-${DateTime.now().millisecondsSinceEpoch}';
          break;
        }
      }

      if (appName == null) {
        throw Exception('无法从 manifest.json 读取应用名称');
      }

      // 5. 获取应用支持目录
      final Directory appSupportDir = await getApplicationSupportDirectory();
      final Directory h5Dir = Directory('${appSupportDir.path}/h5');
      
      // 确保 h5 目录存在
      if (!await h5Dir.exists()) {
        await h5Dir.create(recursive: true);
      }

      // 6. 创建应用目录（使用时间戳避免重名）
      final String uniqueAppName = '${appName.replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}';
      final Directory appDir = Directory('${h5Dir.path}/$uniqueAppName');
      
      if (await appDir.exists()) {
        await appDir.delete(recursive: true);
      }
      await appDir.create(recursive: true);

      // 7. 解压文件（去除根目录前缀，忽略系统文件）
      for (final file in archive) {
        final name = file.name;
        
        // 忽略 macOS 系统文件和隐藏文件
        if (name.startsWith('__MACOSX/') || 
            name.contains('/.DS_Store') || 
            name.endsWith('.DS_Store')) {
          continue;
        }
        
        // 去除根目录前缀
        String relativePath = name;
        if (appRootPrefix != null && appRootPrefix.isNotEmpty && name.startsWith(appRootPrefix)) {
          relativePath = name.substring(appRootPrefix.length);
        }
        
        // 跳过空路径（根目录本身）
        if (relativePath.isEmpty) {
          continue;
        }
        
        if (file.isFile) {
          final data = file.content as List<int>;
          final outputFile = File('${appDir.path}/$relativePath');
          await outputFile.create(recursive: true);
          await outputFile.writeAsBytes(data);
          print('Extracted: $relativePath');
        } else {
          final dir = Directory('${appDir.path}/$relativePath');
          await dir.create(recursive: true);
        }
      }

      print('[AppCenter] Offline app installed: $appName at ${appDir.path}');

      // 8. 刷新应用列表
      _refreshAppList();

      // 9. 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('离线应用 "$appName" 安装成功')),
        );
      }
    } catch (e) {
      print('[AppCenter] Error installing offline app: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('安装失败: $e')),
        );
      }
    }
  }

  /// 刷新应用列表
  void _refreshAppList() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('应用中心')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAppTypeDialog,
        backgroundColor: const Color(0xff31DA9F),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<List<AppItem>>(
        key: _refreshKey,
        future: _buildApps(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('加载应用失败: ${snapshot.error}'),
            );
          }

          final apps = snapshot.data ?? [];

          if (apps.isEmpty) {
            return const Center(
              child: Text('暂无应用'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 110,
              ),
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return _AppTile(
                  name: app.name,
                  description: app.description,
                  version: app.version,
                  icon: app.icon,
                  heroTag: app.heroTag,
                  onTap: () async {
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => app.builder(context)));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final String name;
  final String description;
  final String version;
  final Widget icon;
  final VoidCallback onTap;
  final String heroTag;

  const _AppTile({
    required this.name,
    required this.description,
    required this.version,
    required this.icon,
    required this.onTap,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 左侧：应用图标
            Hero(
              tag: heroTag,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 64,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: icon,
                ),
              ),
            ),
            const SizedBox(width: 18),
            // 右侧：信息区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 第一行：标题 + 打开按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 26,
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor: Color(0xff31DA9F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            '打开',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 第二行：版本号
                  Text(
                    'v$version',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xff999999),
                    ),
                  ),
                  const SizedBox(height: 11),
                  // 第三行：描述 + 更多按钮
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          description.isEmpty ? '暂无描述' : description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff000000),
                          ),
                        ),
                      ),
                      if (description.length > 20)
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(name),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('版本: v$version'),
                                    const SizedBox(height: 8),
                                     Text('描述:$description', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('关闭'),
                                  ),
                                ],
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 20),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '更多',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xff31DA9F),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
