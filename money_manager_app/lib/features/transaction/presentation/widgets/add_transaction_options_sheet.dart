import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/services/image_picker_service.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../screens/add_transaction_screen.dart';
import '../bloc/transaction_bloc.dart';
import '../bloc/transaction_event.dart';
import '../../data/models/transaction_model.dart';
import '../../../budget/presentation/bloc/budget_bloc.dart';
import '../../../budget/presentation/bloc/budget_event.dart';
import '../../../wallet/domain/entities/wallet.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import 'ocr_result_bottom_sheet.dart';

class AddTransactionOptionsSheet extends StatefulWidget {
  final BuildContext parentContext;
  
  const AddTransactionOptionsSheet({super.key, required this.parentContext});

  static const Color purpleAccent = Color(0xFF7C4DFF);
  static const Color creamBackground = Color(0xFFFAF8F5);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddTransactionOptionsSheet(parentContext: context),
    );
  }

  @override
  State<AddTransactionOptionsSheet> createState() => _AddTransactionOptionsSheetState();
}

class _AddTransactionOptionsSheetState extends State<AddTransactionOptionsSheet> {
  bool _isScanning = false;
  String _scanStatus = '';
  double _scanProgress = 0;
  
  final ImagePickerService _imagePickerService = sl<ImagePickerService>();
  final OcrService _ocrService = sl<OcrService>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final isPremiumUser = authState is Authenticated && authState.user.isPremium;
    final isFreemiumUser = !isPremiumUser;
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40 * scale,
                height: 4 * scale,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24 * scale),

              // Title
              Text(
                'Thêm giao dịch',
                style: TextStyle(
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 8 * scale),
              Text(
                'Chọn cách bạn muốn thêm giao dịch',
                style: TextStyle(
                  fontSize: 14 * scale,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              SizedBox(height: 24 * scale),

              // Scanning Progress (if scanning)
              if (_isScanning) ...[
                _buildScanningProgress(isDark),
                SizedBox(height: 24 * scale),
              ] else ...[
                // Option 1: Scan Receipt (Premium Feature - Now Active!)
                _buildOptionCard(
                  context: context,
                  icon: Icons.document_scanner,
                  iconColor: const Color(0xFFE17055),
                  title: 'Quét hóa đơn',
                  subtitle: 'AI đọc hóa đơn tự động',
                  badgeText: 'Cao cấp',
                  badgeColor: const Color(0xFFE17055),
                  badgeIcon: Icons.workspace_premium,
                  onTap: _showImageSourcePicker,
                  isLocked: isFreemiumUser,
                ),
                SizedBox(height: 16 * scale),

                // Option 2: Manual Entry
                _buildOptionCard(
                  context: context,
                  icon: Icons.edit_note,
                  iconColor: AddTransactionOptionsSheet.purpleAccent,
                  title: 'Nhập thủ công',
                  subtitle: 'Tự nhập chi tiết giao dịch',
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push<bool>(
                      widget.parentContext,
                      MaterialPageRoute(
                        builder: (context) => const AddTransactionScreen(),
                      ),
                    );
                    // If transaction was created, refresh related data using parent context
                    if (result == true && widget.parentContext.mounted) {
                      _refreshData();
                    }
                  },
                ),
                SizedBox(height: 24 * scale),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImageSourcePicker() {
    final authState = context.read<AuthBloc>().state;
    final isPremiumUser = authState is Authenticated && authState.user.isPremium;
    if (!isPremiumUser) {
      _showPremiumRequiredDialog();
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24 * scale),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40 * scale,
              height: 4 * scale,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24 * scale),
            Text(
              'Chọn nguồn hóa đơn',
              style: TextStyle(
                fontSize: 18 * scale,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 24 * scale),
            Row(
              children: [
                Expanded(
                  child: _buildSourceItem(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFFE17055),
                    onTap: () {
                      Navigator.pop(context);
                      _startOcrScan(fromCamera: true);
                    },
                    isDark: isDark,
                  ),
                ),
                SizedBox(width: 16 * scale),
                Expanded(
                  child: _buildSourceItem(
                    icon: Icons.photo_library_rounded,
                    label: 'Thư viện',
                    color: const Color(0xFF6C5CE7),
                    onTap: () {
                      Navigator.pop(context);
                      _startOcrScan(fromCamera: false);
                    },
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24 * scale),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20 * scale),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30 * scale, color: color),
            SizedBox(height: 8 * scale),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13 * scale,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningProgress(bool isDark) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Container(
      padding: EdgeInsets.all(20 * scale),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE17055).withOpacity(0.1),
            const Color(0xFFE17055).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE17055).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Animated scanner icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.9 + (0.1 * value),
                child: Container(
                  width: 72 * scale,
                  height: 72 * scale,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE17055).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.document_scanner,
                    size: 40,
                    color: Color(0xFFE17055),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 16 * scale),
          
          // Status text
          Text(
            _scanStatus,
            style: TextStyle(
              fontSize: 15 * scale,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF2D3436),
            ),
          ),
          SizedBox(height: 12 * scale),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _scanProgress > 0 ? _scanProgress : null,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE17055)),
              minHeight: 6 * scale,
            ),
          ),
          SizedBox(height: 10 * scale),
          
          // Progress percentage
          if (_scanProgress > 0)
            Text(
              '${(_scanProgress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12 * scale,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            
          SizedBox(height: 12 * scale),
          
          // Cancel button
          TextButton(
            onPressed: () {
              setState(() {
                _isScanning = false;
                _scanProgress = 0;
                _scanStatus = '';
              });
            },
            child: Text(
              'Hủy',
              style: TextStyle(
                fontSize: 13 * scale,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    IconData? badgeIcon,
    bool isLocked = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);

    final card = Container(
      padding: EdgeInsets.all(18 * scale),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : AddTransactionOptionsSheet.creamBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? iconColor.withOpacity(0.3)
              : iconColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 52 * scale,
            height: 52 * scale,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withOpacity(0.15),
                  iconColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 26 * scale,
            ),
          ),
          SizedBox(width: 14 * scale),

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15 * scale,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (badgeText != null) ...[
                      SizedBox(width: 8 * scale),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * scale,
                          vertical: 3 * scale,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              badgeColor ?? Colors.orange,
                              (badgeColor ?? Colors.orange).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              badgeIcon ?? Icons.auto_awesome,
                              size: 10 * scale,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4 * scale),
                            Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10 * scale,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4 * scale),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12 * scale,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Arrow
          Container(
            width: 30 * scale,
            height: 30 * scale,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.arrow_forward_ios,
              size: 12 * scale,
              color: iconColor,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: isLocked ? _showPremiumRequiredDialog : onTap,
      child: card,
    );
  }

  Future<void> _startOcrScan({required bool fromCamera}) async {
    // Step 1: Capture image
    File? file;
    if (fromCamera) {
      file = await _imagePickerService.pickFromCamera(
        maxWidth: 1920,
        maxHeight: 1920,
        quality: 90,
      );
    } else {
      file = await _imagePickerService.pickFromGallery(
        maxWidth: 1920,
        maxHeight: 1920,
        quality: 90,
      );
    }
    
    if (file == null) return;
    
    setState(() {
      _isScanning = true;
      _scanStatus = 'Đang tải ảnh...';
      _scanProgress = 0;
    });

    // Step 2: Upload to Cloudinary
    final cloudinaryService = sl<CloudinaryService>();
    final uploadResult = await cloudinaryService.uploadImage(
      file,
      folder: CloudinaryService.billsFolder,
      onProgress: (sent, total) {
        setState(() {
          _scanProgress = (sent / total) * 0.5; // First 50% for upload
          _scanStatus = 'Đang tải ảnh...';
        });
      },
    );

    if (!uploadResult.success || uploadResult.secureUrl == null) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tải ảnh thất bại: ${uploadResult.error ?? "Lỗi không xác định"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _scanProgress = 0.6;
      _scanStatus = 'AI đang đọc hóa đơn...';
    });

    // Step 3: Call OCR API
    try {
      final ocrResult = await _ocrService.scanReceipt(uploadResult.secureUrl!);
      
      setState(() {
        _scanProgress = 1.0;
        _scanStatus = 'Hoàn tất!';
      });

      // Small delay to show completion
      await Future.delayed(const Duration(milliseconds: 300));
      
      setState(() {
        _isScanning = false;
      });

      if (!mounted) return;

      // Close this sheet
      Navigator.pop(context);

      // Step 4: Get wallets for the bottom sheet
      final walletState = widget.parentContext.read<WalletBloc>().state;
      List<Wallet> wallets = [];
      if (walletState is WalletLoaded) {
        wallets = walletState.wallets;
      } else if (walletState is WalletOperationSuccess) {
        wallets = walletState.wallets;
      }

      // Step 5: Show OCR Result Bottom Sheet
      if (widget.parentContext.mounted) {
        OcrResultBottomSheet.show(
          context: widget.parentContext,
          scanResult: ocrResult,
          billImageUrl: uploadResult.secureUrl!,
          wallets: wallets,
          onTransactionSaved: () {
            _refreshData();
          },
        );
      }
      
    } on OcrPremiumRequiredException {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        Navigator.pop(context);
        _showPremiumRequiredDialog();
      }
    } on OcrException catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR thất bại: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quét thất bại: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _refreshData() {
    // Refresh wallets to update balance
    widget.parentContext.read<WalletBloc>().add(WalletsLoadRequested());
    // Refresh transactions list
    widget.parentContext.read<TransactionBloc>().add(
      TransactionsLoadRequested(filter: TransactionFilter(pageSize: 100)),
    );
    // Refresh budget (since spending changed)
    widget.parentContext.read<BudgetBloc>().add(const BudgetsLoadRequested());
  }

  void _showPremiumRequiredDialog() {
    final isDark = Theme.of(widget.parentContext).brightness == Brightness.dark;
    final scale = (MediaQuery.of(widget.parentContext).size.width / 390).clamp(0.85, 1.0);
    showDialog(
      context: widget.parentContext,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE17055).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Color(0xFFE17055),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Tính năng cao cấp',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D3436),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quét hóa đơn thông minh dùng AI để tự động trích xuất chi tiết giao dịch từ hóa đơn.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildPremiumFeatureRow(Icons.auto_awesome, 'Tự động lấy số tiền', isDark),
                  _buildPremiumFeatureRow(Icons.calendar_today, 'Nhận diện ngày giao dịch', isDark),
                  _buildPremiumFeatureRow(Icons.store, 'Nhận diện cửa hàng', isDark),
                  _buildPremiumFeatureRow(Icons.category, 'Gợi ý danh mục', isDark),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Để sau',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                const SnackBar(
                  content: Text('Nâng cấp Premium sắp có!'),
                  backgroundColor: Color(0xFF6C5CE7),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE17055),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium, color: Colors.white, size: 16),
                SizedBox(width: 6 * scale),
                const Text(
                  'Nâng cấp ngay',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatureRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE17055)),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
