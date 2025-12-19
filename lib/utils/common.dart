import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Get FileType enum for FilePicker based on type string
FileType getFilePickerType(String type) {
  switch (type.toLowerCase()) {
    case 'image':
      return FileType.image;
    case 'video':
      return FileType.video;
    case 'audio':
      return FileType.audio;
    case 'document':
      return FileType.custom;
    case 'all':
    default:
      return FileType.any;
  }
}

/// Get file extensions for specific file type
/// Can handle both file type categories ('image', 'video', etc.) and actual file extensions ('jpg', 'png', etc.)
List<String>? getExtensionsForType(String type) {
  final lowerType = type.toLowerCase();

  // 如果type以点开头（如 '.jpg'），移除点后返回
  if (lowerType.startsWith('.')) {
    return [lowerType.substring(1)];
  }

  // 检查是否是直接的文件扩展名
  final allKnownExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg',
    'mp4', 'avi', 'mov', 'mkv', 'flv', 'webm',
    'mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg',
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'json'
  };

  if (allKnownExtensions.contains(lowerType)) {
    return [lowerType];
  }

  // 按文件类型分类处理
  switch (lowerType) {
    case 'image':
      return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
    case 'video':
      return ['mp4', 'avi', 'mov', 'mkv', 'flv', 'webm'];
    case 'audio':
      return ['mp3', 'wav', 'aac', 'flac', 'm4a', 'ogg'];
    case 'document':
      return ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv'];
    case 'all':
    default:
      return null;
  }
}

/// Get MIME type based on file extension
String getMimeType(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();

  // 常见图片格式
  if (['jpg', 'jpeg'].contains(ext)) return 'image/jpeg';
  if (ext == 'png') return 'image/png';
  if (ext == 'gif') return 'image/gif';
  if (ext == 'webp') return 'image/webp';
  if (ext == 'svg') return 'image/svg+xml';
  if (ext == 'bmp') return 'image/bmp';

  // 常见视频格式
  if (ext == 'mp4') return 'video/mp4';
  if (ext == 'avi') return 'video/x-msvideo';
  if (ext == 'mov') return 'video/quicktime';
  if (ext == 'mkv') return 'video/x-matroska';
  if (ext == 'webm') return 'video/webm';

  // 常见音频格式
  if (ext == 'mp3') return 'audio/mpeg';
  if (ext == 'wav') return 'audio/wav';
  if (ext == 'aac') return 'audio/aac';
  if (ext == 'flac') return 'audio/flac';
  if (ext == 'm4a') return 'audio/mp4';

  // 文档格式
  if (ext == 'pdf') return 'application/pdf';
  if (ext == 'txt') return 'text/plain';
  if (ext == 'csv') return 'text/csv';
  if (ext == 'json') return 'application/json';
  if (['doc', 'docx'].contains(ext)) return 'application/msword';
  if (['xls', 'xlsx'].contains(ext)) return 'application/vnd.ms-excel';
  if (['ppt', 'pptx'].contains(ext)) return 'application/vnd.ms-powerpoint';

  // 默认
  return 'application/octet-stream';
}

/// Check if MIME type is allowed
bool isMimeTypeAllowed(String mimeType, List<String> allowedMimes) {
  for (final allowed in allowedMimes) {
    if (allowed == '*/*') return true;
    if (allowed == mimeType) return true;

    // 支持通配符，如 image/*
    if (allowed.endsWith('/*')) {
      final prefix = allowed.substring(0, allowed.length - 2);
      if (mimeType.startsWith(prefix)) return true;
    }
  }
  return false;
}

/// Request necessary permissions for file access
Future<void> requestFileAccessPermissions() async {
  if (Platform.isAndroid) {
    var storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.storage.request();
    }

    if (!storageStatus.isGranted) {
      throw Exception('文件访问权限被拒绝');
    }

    // Android 11+ 需要 MANAGE_EXTERNAL_STORAGE 权限才能访问公共目录
    var manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      manageStatus = await Permission.manageExternalStorage.request();
    }

    if (!manageStatus.isGranted) {
      throw Exception('文件访问权限被拒绝');
    }
  } else if (Platform.isIOS) {
    // iOS 不需要特殊权限
  }
}

/// Read file in a separate isolate to avoid blocking the main thread
Future<Uint8List> readFileInIsolate(String path) async {
  return await Isolate.run<Uint8List>(() async {
    return await File(path).readAsBytes();
  });
}

/// Write file in a separate isolate to avoid blocking the main thread
Future<void> writeFileInIsolate(String path, Uint8List data) async {
  return await Isolate.run<void>(() async {
    final file = File(path);
    await file.writeAsBytes(data);
  });
}
