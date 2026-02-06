import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Service for uploading images to Cloudinary
/// 
/// Configured with signed upload for security
class CloudinaryService {
  // Cloudinary credentials
  static const String cloudName = 'dpr6zwanv';
  static const String apiKey = '638459429143781';
  static const String apiSecret = 'EibeA0ej4VbNG2LzDrlIYU20vVk';
  
  // Folders for organizing uploads
  static const String billsFolder = 'money_manager/bills';
  static const String avatarsFolder = 'money_manager/avatars';
  static const String groupsFolder = 'money_manager/groups';
  
  final Dio _dio;
  
  CloudinaryService({Dio? dio}) : _dio = dio ?? Dio();
  
  /// Generate signature for signed upload
  String _generateSignature(Map<String, dynamic> params) {
    // Sort parameters alphabetically
    final sortedKeys = params.keys.toList()..sort();
    final stringToSign = sortedKeys
        .map((key) => '$key=${params[key]}')
        .join('&');
    
    // Add API secret and generate SHA1
    final bytes = utf8.encode('$stringToSign$apiSecret');
    final digest = sha1.convert(bytes);
    return digest.toString();
  }
  
  /// Upload image file to Cloudinary with signed upload
  /// 
  /// [file] - The image file to upload
  /// [folder] - Optional folder path (default: bills)
  /// 
  /// Returns the secure URL of uploaded image
  Future<CloudinaryUploadResult> uploadImage(
    File file, {
    String folder = billsFolder,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Parameters to sign (alphabetically sorted for signature)
      final params = {
        'folder': folder,
        'timestamp': timestamp,
      };
      
      // Generate signature
      final signature = _generateSignature(params);
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: '${timestamp}_$fileName',
        ),
        'api_key': apiKey,
        'timestamp': timestamp,
        'signature': signature,
        'folder': folder,
      });
      
      final response = await _dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        data: formData,
        onSendProgress: onProgress,
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        return CloudinaryUploadResult(
          success: true,
          secureUrl: data['secure_url'],
          publicId: data['public_id'],
          width: data['width'],
          height: data['height'],
          format: data['format'],
          bytes: data['bytes'],
        );
      } else {
        return CloudinaryUploadResult(
          success: false,
          error: 'Tải lên thất bại (mã lỗi: ${response.statusCode})',
        );
      }
    } on DioException catch (e) {
      return CloudinaryUploadResult(
        success: false,
        error: e.response?.data?.toString() ?? e.message ?? 'Lỗi mạng khi tải lên',
      );
    } catch (e) {
      return CloudinaryUploadResult(
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// Upload multiple images
  Future<List<CloudinaryUploadResult>> uploadMultipleImages(
    List<File> files, {
    String folder = billsFolder,
  }) async {
    final results = <CloudinaryUploadResult>[];
    
    for (final file in files) {
      final result = await uploadImage(file, folder: folder);
      results.add(result);
    }
    
    return results;
  }
  
  /// Delete image from Cloudinary (requires signed request)
  /// Note: For production, this should be done through your backend
  Future<bool> deleteImage(String publicId) async {
    // TODO: Implement via backend API for security
    // Direct deletion requires API secret which shouldn't be in client
    throw UnimplementedError(
      'Việc xóa ảnh nên được xử lý ở backend để đảm bảo an toàn',
    );
  }
  
  /// Generate optimized URL with transformations
  /// 
  /// [originalUrl] - Original Cloudinary URL
  /// [width] - Desired width
  /// [height] - Desired height
  /// [quality] - Quality (auto, 80, etc.)
  static String getOptimizedUrl(
    String originalUrl, {
    int? width,
    int? height,
    String quality = 'auto',
  }) {
    if (!originalUrl.contains('cloudinary.com')) {
      return originalUrl;
    }
    
    // Build transformation string
    final transforms = <String>[];
    if (width != null) transforms.add('w_$width');
    if (height != null) transforms.add('h_$height');
    transforms.add('q_$quality');
    transforms.add('f_auto'); // Auto format (webp if supported)
    
    final transformString = transforms.join(',');
    
    // Insert transformation into URL
    // URL format: https://res.cloudinary.com/{cloud}/image/upload/{transforms}/...
    return originalUrl.replaceFirst(
      '/image/upload/',
      '/image/upload/$transformString/',
    );
  }
  
  /// Get thumbnail URL
  static String getThumbnailUrl(String originalUrl, {int size = 150}) {
    return getOptimizedUrl(
      originalUrl,
      width: size,
      height: size,
      quality: '80',
    );
  }
}

/// Result of Cloudinary upload
class CloudinaryUploadResult {
  final bool success;
  final String? secureUrl;
  final String? publicId;
  final int? width;
  final int? height;
  final String? format;
  final int? bytes;
  final String? error;
  
  CloudinaryUploadResult({
    required this.success,
    this.secureUrl,
    this.publicId,
    this.width,
    this.height,
    this.format,
    this.bytes,
    this.error,
  });
  
  /// File size in KB
  double? get sizeKB => bytes != null ? bytes! / 1024 : null;
  
  /// File size in MB
  double? get sizeMB => bytes != null ? bytes! / (1024 * 1024) : null;
}
