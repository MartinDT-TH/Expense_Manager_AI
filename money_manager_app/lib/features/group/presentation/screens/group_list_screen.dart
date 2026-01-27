import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/group.dart';
import '../bloc/group_bloc.dart';
import '../bloc/group_event.dart';
import '../bloc/group_state.dart';
import 'group_detail_screen.dart';
import 'create_group_screen.dart';
import 'join_group_screen.dart';

/// Screen showing list of groups that user has joined
class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GroupBloc>().add(const LoadGroups());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C5CE7),
        elevation: 0,
        title: Text(
          'Group Fund',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18 * scale,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<GroupBloc, GroupState>(
        listener: (context, state) {
          if (state is GroupError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
          if (state is GroupJoined) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Joined group "${state.group.name}"'),
                backgroundColor: AppColors.success,
              ),
            );
            context.read<GroupBloc>().add(const RefreshGroups());
          }
          if (state is GroupCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Created group "${state.group.name}"'),
                backgroundColor: AppColors.success,
              ),
            );
            context.read<GroupBloc>().add(const RefreshGroups());
          }
          if (state is GroupLeft) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Left the group'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is GroupLoading && state is! GroupsLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = context.read<GroupBloc>().groups;

          return RefreshIndicator(
            onRefresh: () async {
              context.read<GroupBloc>().add(const RefreshGroups());
            },
            child: CustomScrollView(
              slivers: [
                // Header section
                SliverToBoxAdapter(
                  child: _buildHeaderSection(context),
                ),

                // Groups list
                if (groups.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildGroupCard(context, groups[index]),
                        childCount: groups.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Container(
      padding: EdgeInsets.all(16 * scale),
      child: Column(
        children: [
          // Create group button (Premium)
          _buildActionCard(
            context,
            icon: Icons.add_circle_outline,
            title: 'Create New Group',
            subtitle: 'Create a group to share expenses',
            color: AppColors.primary,
            badgeText: 'Premium',
            onTap: () => _navigateToCreateGroup(context),
          ),
          SizedBox(height: 12 * scale),

          // Join group button
          _buildActionCard(
            context,
            icon: Icons.group_add,
            title: 'Join Group',
            subtitle: 'Enter invite code to join a group',
            color: AppColors.accent,
            onTap: () => _navigateToJoinGroup(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(14 * scale),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10 * scale),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24 * scale),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15 * scale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (badgeText != null)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8 * scale,
                              vertical: 2 * scale,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10 * scale,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, Group group) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToGroupDetail(context, group),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Group avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getGroupColor(group.name).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _getGroupEmoji(group.name),
                    style: TextStyle(fontSize: 22 * scale),
                      ),
                    ),
                  ),
              SizedBox(width: 10 * scale),
                  
                  // Group info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.name,
                                style: TextStyle(
                                  fontSize: 15 * scale,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (group.isAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4 * scale),
                        Text(
                          '${group.memberCount} members',
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
              
              SizedBox(height: 12 * scale),
              
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Total Expense',
                      _formatCurrency(group.totalExpense),
                      AppColors.expense,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey[200],
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Total Income',
                      _formatCurrency(group.totalIncome),
                      AppColors.income,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11 * scale,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4 * scale),
        Text(
          value,
          style: TextStyle(
            fontSize: 13 * scale,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28 * scale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 68 * scale,
              color: Colors.grey[300],
            ),
            SizedBox(height: 12 * scale),
            Text(
              'No groups yet',
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8 * scale),
            Text(
              'Create a new group or join with invite code\nto share expenses with friends and family',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12 * scale,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCreateGroup(BuildContext context) {
    final groupBloc = context.read<GroupBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: groupBloc,
          child: const CreateGroupScreen(),
        ),
      ),
    ).then((result) {
      if (result == true) {
        groupBloc.add(const RefreshGroups());
      }
    });
  }

  void _navigateToJoinGroup(BuildContext context) {
    final groupBloc = context.read<GroupBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: groupBloc,
          child: const JoinGroupScreen(),
        ),
      ),
    ).then((result) {
      if (result == true) {
        groupBloc.add(const RefreshGroups());
      }
    });
  }

  void _navigateToGroupDetail(BuildContext context, Group group) {
    final groupBloc = context.read<GroupBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: groupBloc,
          child: GroupDetailScreen(groupId: group.id),
        ),
      ),
    ).then((_) {
      groupBloc.add(const RefreshGroups());
    });
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Color _getGroupColor(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  String _getGroupEmoji(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('gia đình') || nameLower.contains('family')) return '🏠';
    if (nameLower.contains('du lịch') || nameLower.contains('travel')) return '🏖️';
    if (nameLower.contains('công ty') || nameLower.contains('team')) return '👔';
    if (nameLower.contains('bạn') || nameLower.contains('friend')) return '👥';
    if (nameLower.contains('nhà') || nameLower.contains('home')) return '🏡';
    if (nameLower.contains('quỹ')) return '💰';
    return '👥';
  }
}
