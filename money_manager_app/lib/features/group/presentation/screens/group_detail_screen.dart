import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/signalr_service.dart';
import '../../../../core/utils/category_icons.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_member.dart';
import '../../../transaction/domain/entities/transaction.dart';
import '../bloc/group_bloc.dart';
import '../bloc/group_event.dart';
import '../bloc/group_state.dart';

/// Group detail screen
class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  
  // SignalR subscriptions
  final SignalRService _signalRService = sl<SignalRService>();
  StreamSubscription? _newTransactionSub;
  StreamSubscription? _groupUpdatedSub;
  StreamSubscription? _memberJoinedSub;
  StreamSubscription? _memberLeftSub;
  StreamSubscription? _memberKickedSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<GroupBloc>().add(LoadGroupDetail(widget.groupId));
    _initSignalR();
  }
  
  Future<void> _initSignalR() async {
    // Initialize and join group
    await _signalRService.initialize();
    await _signalRService.joinGroup(widget.groupId);
    
    // Listen for real-time updates
    _newTransactionSub = _signalRService.onNewTransaction.listen((data) {
      // Refresh group detail when new transaction is added
      if (mounted) {
        context.read<GroupBloc>().add(LoadGroupDetail(widget.groupId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Có giao dịch mới!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
    
    _groupUpdatedSub = _signalRService.onGroupUpdated.listen((data) {
      if (mounted) {
        context.read<GroupBloc>().add(LoadGroupDetail(widget.groupId));
      }
    });
    
    _memberJoinedSub = _signalRService.onMemberJoined.listen((data) {
      if (mounted) {
        context.read<GroupBloc>().add(LoadGroupDetail(widget.groupId));
        final memberName = data['userName'] ?? 'Thành viên mới';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$memberName đã tham gia nhóm'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
    
    _memberLeftSub = _signalRService.onMemberLeft.listen((data) {
      if (mounted) {
        context.read<GroupBloc>().add(LoadGroupDetail(widget.groupId));
      }
    });
    
    _memberKickedSub = _signalRService.onMemberKicked.listen((data) {
      if (mounted) {
        context.read<GroupBloc>().add(LoadGroupDetail(widget.groupId));
      }
    });
  }

  @override
  void dispose() {
    // Cleanup SignalR subscriptions
    _newTransactionSub?.cancel();
    _groupUpdatedSub?.cancel();
    _memberJoinedSub?.cancel();
    _memberLeftSub?.cancel();
    _memberKickedSub?.cancel();
    _signalRService.leaveGroup(widget.groupId);
    
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupBloc, GroupState>(
      listener: (context, state) {
        if (state is GroupError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
        if (state is GroupLeft) {
          Navigator.pop(context);
        }
        if (state is InviteCodeRegenerated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mã mời mới: ${state.inviteCode}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        if (state is MemberKicked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa thành viên'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      builder: (context, state) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (state is GroupLoading) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
            appBar: AppBar(
              backgroundColor: const Color(0xFF6C5CE7),
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Chi tiết nhóm',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              centerTitle: true,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is! GroupDetailLoaded) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
            appBar: AppBar(
              backgroundColor: const Color(0xFF6C5CE7),
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Chi tiết nhóm',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              centerTitle: true,
            ),
            body: const Center(child: Text('Không tìm thấy nhóm')),
          );
        }

        final group = state.group;
        final members = state.members;
        final transactions = state.transactions;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildSliverAppBar(context, group),
                SliverToBoxAdapter(
                  child: _buildSummarySection(group, members),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppColors.primary,
                      tabs: const [
                        Tab(text: 'Thành viên'),
                        Tab(text: 'Giao dịch'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildMembersTab(context, group, members),
                _buildTransactionsTab(transactions),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Group group) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: const Color(0xFF6C5CE7),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          group.name,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (group.isAdmin)
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value, group),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Chỉnh sửa'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'regenerate_code',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Đổi mã mời'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: AppColors.error),
                  title: Text('Xóa nhóm',
                      style: TextStyle(color: AppColors.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          )
        else
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _showLeaveConfirmDialog(context),
            tooltip: 'Rời nhóm',
          ),
      ],
    );
  }

  Widget _buildSummarySection(Group group, List<GroupMember> members) {
    final totalSpent = group.totalExpense;
    final perPerson = members.isNotEmpty ? totalSpent / members.length : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Total spending card
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'TỔNG CHI NHÓM',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currencyFormat.format(totalSpent),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.expense,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSummaryItem(
                        'Tổng thu',
                        _currencyFormat.format(group.totalIncome),
                        AppColors.income,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[200]),
                      _buildSummaryItem(
                        'Theo người',
                        _currencyFormat.format(perPerson),
                        AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Invite code section (only for admin)
          if (group.isAdmin && group.inviteCode != null) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.vpn_key,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mã mời',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            group.inviteCode!,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyInviteCode(group.inviteCode!),
                      tooltip: 'Sao chép',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => _shareInviteCode(group),
                      tooltip: 'Chia sẻ',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab(
      BuildContext context, Group group, List<GroupMember> members) {
    if (members.isEmpty) {
      return const Center(child: Text('Chưa có thành viên'));
    }

    // Sort: Admin trước, sau đó theo contribution
    final sortedMembers = List<GroupMember>.from(members)
      ..sort((a, b) {
        if (a.isAdmin && !b.isAdmin) return -1;
        if (!a.isAdmin && b.isAdmin) return 1;
        return b.totalContribution.compareTo(a.totalContribution);
      });

    // Calculate who owes whom
    final totalSpent = group.totalExpense;
    final perPerson = members.isNotEmpty ? totalSpent / members.length : 0.0;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedMembers.length,
      itemBuilder: (context, index) {
        final member = sortedMembers[index];
        final balance = member.totalContribution - perPerson;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: member.isAdmin
                      ? [const Color(0xFF6C5CE7), const Color(0xFF8B7CF7)]
                      : [Colors.grey.shade400, Colors.grey.shade600],
                ),
              ),
              child: Center(
                child: Text(
                  member.initials.isNotEmpty ? member.initials[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    member.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (member.isAdmin) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Quản trị viên',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              'Đã chi: ${_currencyFormat.format(member.totalContribution)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  balance >= 0
                      ? '+${_formatShortCurrency(balance)}'
                      : _formatShortCurrency(balance),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: balance >= 0 ? AppColors.income : AppColors.expense,
                  ),
                ),
                Text(
                  balance >= 0 ? 'Sẽ nhận' : 'Cần trả',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            onLongPress: group.isAdmin && !member.isAdmin
                ? () => _showMemberOptionsDialog(context, member)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Chưa có giao dịch',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Group by date
    final groupedTransactions = <String, List<Transaction>>{};
    for (final tx in transactions) {
      final dateKey = DateFormat('dd/MM/yyyy').format(tx.transactionDate);
      groupedTransactions.putIfAbsent(dateKey, () => []).add(tx);
    }

    final sortedDates = groupedTransactions.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('dd/MM/yyyy').parse(a);
        final dateB = DateFormat('dd/MM/yyyy').parse(b);
        return dateB.compareTo(dateA);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final dateTxs = groupedTransactions[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ...dateTxs.map((tx) => _buildTransactionTile(tx)),
          ],
        );
      },
    );
  }

  Widget _buildTransactionTile(Transaction tx) {
    final isExpense = tx.type == TransactionType.expense;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showTransactionDetail(context, tx, isDark),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (isExpense ? AppColors.expense : AppColors.income)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            CategoryIcons.getIcon(tx.categoryIcon ?? 'receipt'),
            color: isExpense ? AppColors.expense : AppColors.income,
            size: 22,
          ),
        ),
        title: Text(
          tx.categoryName ?? 'Không xác định',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tx.note != null && tx.note!.isNotEmpty)
              Text(
                tx.note!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (tx.createdByUserName != null)
              Row(
                children: [
                  Icon(Icons.person_outline, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    tx.createdByUserName!,
                    style: TextStyle(
                      fontSize: 11, 
                      color: const Color(0xFF6C5CE7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}${_currencyFormat.format(tx.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isExpense ? AppColors.expense : AppColors.income,
          ),
        ),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, Transaction transaction, bool isDark) {
    final isExpense = transaction.type == TransactionType.expense;
    final hasReceipt = transaction.receiptUrl != null && transaction.receiptUrl!.isNotEmpty;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (isExpense ? AppColors.expense : AppColors.income)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      CategoryIcons.getIcon(transaction.categoryIcon ?? 'receipt'),
                      color: isExpense ? AppColors.expense : AppColors.income,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.categoryName ?? 'Giao dịch',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF2D3436),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isExpense ? 'Chi tiêu' : 'Thu nhập',
                          style: TextStyle(
                            fontSize: 14,
                            color: isExpense ? AppColors.expense : AppColors.income,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isExpense ? '-' : '+'}${_currencyFormat.format(transaction.amount)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isExpense ? AppColors.expense : AppColors.income,
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
            
            // Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    _buildDetailRow(
                      'Ngày',
                      DateFormat('dd MMM yyyy').format(transaction.transactionDate),
                      Icons.calendar_today_outlined,
                      isDark,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Wallet
                    if (transaction.walletName != null)
                      _buildDetailRow(
                        'Ví',
                        transaction.walletName!,
                        Icons.account_balance_wallet_outlined,
                        isDark,
                      ),
                    
                    // Created by (for group transactions)
                    if (transaction.createdByUserName != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Tạo bởi',
                        transaction.createdByUserName!,
                        Icons.person_outline,
                        isDark,
                        valueColor: const Color(0xFF6C5CE7),
                      ),
                    ],
                    
                    // Note
                    if (transaction.note != null && transaction.note!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Ghi chú',
                        transaction.note!,
                        Icons.note_outlined,
                        isDark,
                      ),
                    ],
                    
                    // Group
                    if (transaction.groupId != null && transaction.groupName != null) ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        'Nhóm',
                        transaction.groupName!,
                        Icons.group_outlined,
                        isDark,
                        valueColor: const Color(0xFF6C5CE7),
                      ),
                    ],
                    
                    // Bill Image Section
                    if (hasReceipt) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 20,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hóa đơn / Biên lai',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            transaction.receiptUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: const Color(0xFF6C5CE7),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      size: 48,
                                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Không thể tải ảnh',
                                      style: TextStyle(
                                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Close button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? (isDark ? Colors.white : const Color(0xFF2D3436)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, String action, Group group) {
    switch (action) {
      case 'edit':
        // TODO: Navigate to edit screen
        break;
      case 'regenerate_code':
        _showRegenerateCodeDialog(context, group);
        break;
      case 'delete':
        _showDeleteConfirmDialog(context, group);
        break;
    }
  }

  void _showLeaveConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rời nhóm?'),
        content: const Text('Bạn sẽ không còn xem được chi tiêu của nhóm này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<GroupBloc>().add(LeaveGroup(widget.groupId));
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Rời'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa nhóm?'),
        content: Text(
          'Nhóm "${group.name}" và toàn bộ dữ liệu sẽ bị xóa vĩnh viễn. '
          'Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<GroupBloc>().add(DeleteGroup(group.id));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showRegenerateCodeDialog(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mã mời?'),
        content: const Text(
          'Mã mời cũ sẽ không còn hiệu lực. '
          'Người chưa tham gia sẽ cần mã mới.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<GroupBloc>().add(RegenerateInviteCode(group.id));
            },
            child: const Text('Đổi'),
          ),
        ],
      ),
    );
  }

  void _showMemberOptionsDialog(BuildContext context, GroupMember member) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Đặt làm quản trị viên'),
              onTap: () {
                Navigator.pop(ctx);
                context.read<GroupBloc>().add(ChangeRole(
                      groupId: widget.groupId,
                      userId: member.userId,
                      newRole: 'ADMIN',
                    ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: AppColors.error),
              title: const Text('Xóa khỏi nhóm',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                context.read<GroupBloc>().add(KickMember(
                      groupId: widget.groupId,
                      userId: member.userId,
                    ));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép mã mời'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareInviteCode(Group group) {
    final message = 'Tham gia nhóm "${group.name}" trên Smart Money!\n'
        'Mã mời: ${group.inviteCode}';
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép nội dung chia sẻ'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatShortCurrency(double amount) {
    final absAmount = amount.abs();
    if (absAmount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (absAmount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

/// Delegate cho sticky tab bar
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

