import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  /// Save file from Base64 content and return the file path
  Future<String> saveFileFromBase64({
    required String base64Content,
    required String fileName,
  }) async {
    try {
      // Decode Base64
      final bytes = base64Decode(base64Content);
      
      // Get downloads directory
      Directory directory;
      if (Platform.isAndroid) {
        directory = await getApplicationDocumentsDirectory();
        // Try to use Downloads folder if available
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          directory = downloadDir;
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      // Create file path
      final filePath = '${directory.path}/$fileName';
      
      // Write file
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      
      return filePath;
    } catch (e) {
      throw Exception('Failed to save file: $e');
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
  }) async {
    final filePath = await saveFileFromBase64(
      base64Content: base64Content,
      fileName: fileName,
    );
    await openFile(filePath);
    return filePath;
  }

  /// Save and share file
  Future<String> saveAndShareFile({
    required String base64Content,
    required String fileName,
    String? subject,
  }) async {
    final filePath = await saveFileFromBase64(
      base64Content: base64Content,
      fileName: fileName,
    );
    await shareFile(filePath: filePath, subject: subject);
    return filePath;
  }
}
