import 'package:flutter/material.dart';
import 'package:splitease_test/core/models/dummy_data.dart';
import 'package:splitease_test/core/models/group_model.dart';
import 'package:splitease_test/core/models/member_model.dart';
import 'package:splitease_test/core/theme/app_theme.dart';
import 'package:splitease_test/shared/widgets/app_button.dart';

class AddGroupTab extends StatefulWidget {
  const AddGroupTab({super.key});

  @override
  State<AddGroupTab> createState() => _AddGroupTabState();
}

class _AddGroupTabState extends State<AddGroupTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createGroup() {
    if (!_formKey.currentState!.validate()) return;

    // Create member mapping for creator
    final creatorMember = MemberModel(
      id: DummyData.currentUser.id,
      name: DummyData.currentUser.name,
      avatarInitials: DummyData.currentUser.avatarInitials,
      amountOwed: 0,
      isPaid: true,
    );

    // Create new group with just the current user
    final newGroup = GroupModel(
      id: 'g${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text,
      creatorId: DummyData.currentUser.id,
      createdDate: DateTime.now(),
      members: [creatorMember],
      expenses: [],
      messages: [],
    );

    // Add to dummy data
    DummyData.groups.insert(0, newGroup);

    // Navigate to group details
    Navigator.pushNamed(context, '/details', arguments: newGroup);

    // Reset form
    _nameController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Group "${newGroup.name}" created successfully!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    final surfaceColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Create Group',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.padding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Group Name',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                  ),
                ),
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Goa Trip, Flatmates, Weekend Party',
                    border: InputBorder.none,
                  ),
                  validator: (v) => v!.isEmpty ? 'Enter group name' : null,
                ),
              ),

              SizedBox(height: 48),

              AppButton(label: 'Create Group', onPressed: _createGroup),
            ],
          ),
        ),
      ),
    );
  }
}
