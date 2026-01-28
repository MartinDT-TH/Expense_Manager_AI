import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../auth/token_storage.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  /// Save file from Base64 content and return the file path
  Future<String> saveFileFromBase64({
    required String base64Content,
    required String fileName,
    String? defaultExtension,
  }) async {
    try {
      final bytes = _decodeBase64Flexible(base64Content);
      final resolvedFileName =
          _withDefaultExtension(fileName, defaultExtension);

      final directory = await _pickWritableDirectory();
      final filePath = '${directory.path}/$resolvedFileName';

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      return filePath;
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  /// Save file from URL and return the file path
  Future<String> saveFileFromUrl({
    required String url,
    required String fileName,
    String? defaultExtension,
  }) async {
    try {
      final resolvedFileName =
          _withDefaultExtension(fileName, defaultExtension);
      final directory = await _pickWritableDirectory();
      final filePath = '${directory.path}/$resolvedFileName';

      final token = await const TokenStorage().getAccessToken();
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: token == null || token.isEmpty
              ? null
              : {'Authorization': 'Bearer $token'},
        ),
      );

      final data = response.data;
      if (data == null || data.isEmpty) {
        throw Exception('Empty response');
      }

      final file = File(filePath);
      await file.writeAsBytes(data, flush: true);
      return filePath;
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }

  /// Open file with default app
  Future<void> openFile(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('Failed to open file: ${result.message}');
      }
    } catch (e) {
      throw Exception('Failed to open file: $e');
    }
  }

  /// Share file
  Future<void> shareFile({
    required String filePath,
    String? subject,
  }) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: subject ?? 'MoneyManager Report',
      );
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }

  /// Save and open file
  Future<String> saveAndOpenFile({
    required String base64Content,
    required String fileName,
    String? defaultExtension,
  }) async {
    final filePath = await saveFileFromBase64(
      base64Content: base64Content,
      fileName: fileName,
      defaultExtension: defaultExtension,
    );
    await openFile(filePath);
    return filePath;
  }

  /// Save and share file
  Future<String> saveAndShareFile({
    required String base64Content,
    required String fileName,
    String? subject,
    String? defaultExtension,
  }) async {
    final filePath = await saveFileFromBase64(
      base64Content: base64Content,
      fileName: fileName,
      defaultExtension: defaultExtension,
    );
    await shareFile(filePath: filePath, subject: subject);
    return filePath;
  }

  Uint8List _decodeBase64Flexible(String input) {
    var cleaned = input.trim();

    if (cleaned.startsWith('data:')) {
      final commaIndex = cleaned.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < cleaned.length) {
        cleaned = cleaned.substring(commaIndex + 1);
      }
    }

    cleaned = cleaned.replaceAll(RegExp(r'\s'), '');

    try {
      return base64Decode(cleaned);
    } catch (_) {
      final normalized = cleaned.replaceAll('-', '+').replaceAll('_', '/');
      final padded =
          normalized.padRight(((normalized.length + 3) ~/ 4) * 4, '=');
      return base64Decode(padded);
    }
  }

  String _withDefaultExtension(String fileName, String? defaultExtension) {
    final trimmed = fileName.trim();
    if (defaultExtension == null || defaultExtension.trim().isEmpty) {
      return trimmed;
    }
    if (trimmed.contains('.')) return trimmed;
    final ext = defaultExtension.trim().replaceFirst(RegExp(r'^\.+'), '');
    return ext.isEmpty ? trimmed : '$trimmed.$ext';
  }

  Future<Directory> _pickWritableDirectory() async {
    final candidates = <Directory>[];

    if (Platform.isAndroid) {
      candidates.add(Directory('/storage/emulated/0/Download'));
      final external = await getExternalStorageDirectory();
      if (external != null) candidates.add(external);
      candidates.add(await getApplicationDocumentsDirectory());
    } else if (Platform.isIOS) {
      candidates.add(await getApplicationDocumentsDirectory());
    } else {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) candidates.add(downloads);
      candidates.add(await getApplicationDocumentsDirectory());
    }

    Object? lastError;
    for (final dir in candidates) {
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final probe = File('${dir.path}/.mm_write_probe');
        await probe.writeAsString('ok', flush: true);
        await probe.delete();
        return dir;
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('No writable directory found: $lastError');
  }
}
