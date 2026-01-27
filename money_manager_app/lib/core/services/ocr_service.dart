import '../network/api_client.dart';

/// OCR scan result model
class OcrScanResult {
  final bool success;
  final String? errorMessage;
  final double? amount;
  final DateTime? date;
  final String? description;
  final String? merchantName;
  final String? rawData;
  final String? suggestedCategoryId;
  final String? suggestedCategoryName;

  OcrScanResult({
    required this.success,
    this.errorMessage,
    this.amount,
    this.date,
    this.description,
    this.merchantName,
    this.rawData,
    this.suggestedCategoryId,
    this.suggestedCategoryName,
  });

  factory OcrScanResult.fromJson(Map<String, dynamic> json) {
    return OcrScanResult(
      success: json['success'] ?? false,
      errorMessage: json['errorMessage'],
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      description: json['description'],
      merchantName: json['merchantName'],
      rawData: json['rawData'],
      suggestedCategoryId: json['suggestedCategoryId'],
      suggestedCategoryName: json['suggestedCategoryName'],
    );
  }

  /// Check if any useful data was extracted
  bool get hasData => amount != null || description != null || merchantName != null;
}

/// Service for handling OCR (receipt scanning) operations
class OcrService {
  final ApiClient _apiClient;

  OcrService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Scan receipt image and extract transaction data
  /// 
  /// [imageUrl] - URL of the uploaded receipt image (from Cloudinary)
  /// 
  /// Returns [OcrScanResult] with extracted data
  /// 
  /// Throws exception if user is not premium or API error occurs
  Future<OcrScanResult> scanReceipt(String imageUrl) async {
    try {
      final response = await _apiClient.post(
        '/Transaction/ocr',
        data: {'imageUrl': imageUrl},
      );

      if (response.statusCode == 200) {
        return OcrScanResult.fromJson(response.data);
      } else if (response.statusCode == 400) {
        // Check if it's premium required error
        final data = response.data;
        if (data is Map && data['code'] == 'PREMIUM_REQUIRED') {
          throw OcrPremiumRequiredException(data['message'] ?? 'Premium required');
        }
        throw OcrException(data['message'] ?? 'OCR scan failed');
      } else {
        throw OcrException('OCR scan failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (e is OcrException || e is OcrPremiumRequiredException) {
        rethrow;
      }
      throw OcrException('Network error during OCR scan: $e');
    }
  }
}

/// Exception thrown when OCR operation fails
class OcrException implements Exception {
  final String message;
  OcrException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when user doesn't have premium access for OCR
class OcrPremiumRequiredException implements Exception {
  final String message;
  OcrPremiumRequiredException(this.message);

  @override
  String toString() => message;
}
