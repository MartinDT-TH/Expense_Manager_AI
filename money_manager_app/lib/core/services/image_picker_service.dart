import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart';

/// Service for picking and uploading images
class ImagePickerService {
  final ImagePicker _picker;
  final CloudinaryService _cloudinaryService;
  
  ImagePickerService({
    ImagePicker? picker,
    CloudinaryService? cloudinaryService,
  })  : _picker = picker ?? ImagePicker(),
        _cloudinaryService = cloudinaryService ?? CloudinaryService();
  
  /// Pick image from camera
  /// Quality optimized for OCR recognition while saving some memory
  Future<File?> pickFromCamera({
    int maxWidth = 1920,  // Keep high resolution for OCR accuracy
    int maxHeight = 1920, // Keep high resolution for OCR accuracy
    int quality = 85,     // Keep high quality for OCR accuracy
  }) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: quality,
      requestFullMetadata: false, // Disable metadata to reduce memory (doesn't affect image quality)
    );
    
    return image != null ? File(image.path) : null;
  }
  
  /// Pick image from gallery
  /// Quality optimized for OCR recognition
  Future<File?> pickFromGallery({
    int maxWidth = 1920,  // Keep high resolution for OCR accuracy
    int maxHeight = 1920, // Keep high resolution for OCR accuracy
    int quality = 85,     // Keep high quality for OCR accuracy
  }) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: quality,
      requestFullMetadata: false, // Disable metadata to reduce memory
    );
    
    return image != null ? File(image.path) : null;
  }
  
  /// Pick multiple images from gallery
  Future<List<File>> pickMultipleFromGallery({
    int maxWidth = 1920,
    int maxHeight = 1920,
    int quality = 85,
    int? limit,
  }) async {
    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight.toDouble(),
      imageQuality: quality,
      limit: limit,
      requestFullMetadata: false,
    );
    
    return images.map((xFile) => File(xFile.path)).toList();
  }
  
  /// Pick and upload image from camera
  Future<CloudinaryUploadResult?> pickAndUploadFromCamera({
    String folder = CloudinaryService.billsFolder,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = await pickFromCamera();
    if (file == null) return null;
    
    return _cloudinaryService.uploadImage(
      file,
      folder: folder,
      onProgress: onProgress,
    );
  }
  
  /// Pick and upload image from gallery
  Future<CloudinaryUploadResult?> pickAndUploadFromGallery({
    String folder = CloudinaryService.billsFolder,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = await pickFromGallery();
    if (file == null) return null;
    
    return _cloudinaryService.uploadImage(
      file,
      folder: folder,
      onProgress: onProgress,
    );
  }
}
