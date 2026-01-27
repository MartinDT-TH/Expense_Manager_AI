import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../bloc/group_bloc.dart';
import '../bloc/group_event.dart';
import '../bloc/group_state.dart';

/// Create new group screen (Premium only)
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.of(context).size.width / 390).clamp(0.85, 1.0);
    return BlocListener<GroupBloc, GroupState>(
      listener: (context, state) {
        if (state is GroupCreated) {
          setState(() => _isLoading = false);
          Navigator.pop(context, true);
        }
        if (state is GroupError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
        if (state is GroupLoading) {
          setState(() => _isLoading = true);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF121212) 
            : const Color(0xFFF8F9FE),
        appBar: AppBar(
          backgroundColor: const Color(0xFF6C5CE7),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Create New Group',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18 * scale,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16 * scale),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium badge
                Container(
                  padding: EdgeInsets.all(14 * scale),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.accent.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8 * scale),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.workspace_premium,
                          color: Colors.amber,
                          size: 20 * scale,
                        ),
                      ),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium Feature',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13 * scale,
                              ),
                            ),
                            SizedBox(height: 2 * scale),
                            Text(
                              'Create a group to share expenses with friends and family',
                              style: TextStyle(fontSize: 11 * scale, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20 * scale),

                // Group name
                Text(
                  'Group Name',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13 * scale,
                      ),
                ),
                SizedBox(height: 8 * scale),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'E.g. Family Fund, Trip to Paris',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.group),
                  ),
                  style: TextStyle(fontSize: 13 * scale),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter group name';
                    }
                    if (value.trim().length < 2) {
                      return 'Group name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16 * scale),

                // Description
                Text(
                  'Description (optional)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13 * scale,
                      ),
                ),
                SizedBox(height: 8 * scale),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Brief description of this group',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  style: TextStyle(fontSize: 13 * scale),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                SizedBox(height: 24 * scale),

                // Suggestions
                Text(
                  'Group Name Suggestions',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13 * scale,
                      ),
                ),
                SizedBox(height: 10 * scale),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSuggestionChip('🏠 Family Fund'),
                    _buildSuggestionChip('🏖️ Travel'),
                    _buildSuggestionChip('👔 Office Team'),
                    _buildSuggestionChip('🎉 Party'),
                    _buildSuggestionChip('🏠 Rent'),
                    _buildSuggestionChip('🎓 Classroom'),
                  ],
                ),
                SizedBox(height: 28 * scale),

                // Create button
                SizedBox(
                  width: double.infinity,
                  height: 48 * scale,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Create Group',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        // Remove emoji from text for name
        final name = text.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '').trim();
        _nameController.text = name;
      },
      backgroundColor: Colors.grey[100],
    );
  }

  void _createGroup() {
    if (_formKey.currentState!.validate()) {
      context.read<GroupBloc>().add(CreateGroup(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          ));
    }
  }
}
