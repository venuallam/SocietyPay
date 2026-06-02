import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/contact_repository.dart';

class AddContactScreen extends StatefulWidget {
  final String societyId;
  final bool isAdmin;
  final String userId;
  final String userName;
  final ContactModel? editContact;

  const AddContactScreen({
    super.key,
    required this.societyId,
    required this.isAdmin,
    required this.userId,
    required this.userName,
    this.editContact,
  });

  @override
  State<AddContactScreen> createState() =>
      _AddContactScreenState();
}

class _AddContactScreenState
    extends State<AddContactScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _repo      = ContactRepository();

  ContactCategory _category =
      ContactCategory.repairs;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.editContact != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text  = widget.editContact!.name;
      _phoneCtrl.text = widget.editContact!.phone;
      _category       = widget.editContact!.category;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      setState(() =>
      _error = 'Enter contact name');
      return;
    }
    if (phone.isEmpty || phone.length < 3) {
      setState(() =>
      _error = 'Enter a valid phone number');
      return;
    }

    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      if (_isEdit && widget.isAdmin) {
        // Edit existing contact
        await _repo.editContact(
          societyId: widget.societyId,
          contactId: widget.editContact!.id,
          name:      name,
          phone:     phone,
          category:  _category,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(
              content: Text(
                  '✅ Contact updated'),
              backgroundColor:
              AppColors.success));
          Navigator.pop(context);
        }
      } else if (widget.isAdmin) {
        // Add new contact directly
        await _repo.addContact(
          societyId: widget.societyId,
          name:      name,
          phone:     phone,
          category:  _category,
          adminId:   widget.userId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(
              content: Text(
                  '✅ Contact added'),
              backgroundColor:
              AppColors.success));
          Navigator.pop(context);
        }
      } else {
        // Member suggests contact
        await _repo.submitSuggestion(
          societyId:  widget.societyId,
          name:       name,
          phone:      phone,
          category:   _category,
          userId:     widget.userId,
          userName:   widget.userName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(
              content: Text(
                  '✅ Suggestion submitted '
                      'for admin approval'),
              backgroundColor:
              AppColors.success));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit
        ? 'Edit Contact'
        : widget.isAdmin
        ? 'Add Contact'
        : 'Suggest Contact';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // Member info banner
            if (!widget.isAdmin) ...[
              Container(
                padding:
                const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius:
                    BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(Icons.info_outline,
                      color: AppColors.accent,
                      size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                      'Your suggestion will be '
                          'sent to admin for review '
                          'before publishing.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.accent))),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            Card(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // Category
                  const Text('CATEGORY',
                      style: AppText.label),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children:
                    ContactCategory.values
                        .map((cat) {
                      final selected =
                          _category == cat;
                      final icon =
                      switch (cat) {
                        ContactCategory
                            .emergency => '🚨',
                        ContactCategory
                            .repairs => '🔧',
                        ContactCategory
                            .nearby => '🏥',
                      };
                      final label =
                      switch (cat) {
                        ContactCategory
                            .emergency =>
                        'Emergency',
                        ContactCategory
                            .repairs =>
                        'Repairs',
                        ContactCategory
                            .nearby =>
                        'Nearby',
                      };
                      return GestureDetector(
                        onTap: () =>
                            setState(() =>
                            _category = cat),
                        child: Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                              horizontal:
                              12,
                              vertical:
                              8),
                          decoration:
                          BoxDecoration(
                              color:
                              selected
                                  ? AppColors
                                  .primary
                                  : AppColors
                                  .bgLight,
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  20),
                              border:
                              Border.all(
                                  color:
                                  selected
                                      ? AppColors
                                      .primary
                                      : AppColors
                                      .border)),
                          child: Text(
                              '$icon $label',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                  FontWeight
                                      .w600,
                                  color:
                                  selected
                                      ? Colors
                                      .white
                                      : AppColors
                                      .textSecondary)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  const Text('NAME',
                      style: AppText.label),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization:
                    TextCapitalization.words,
                    decoration:
                    const InputDecoration(
                      hintText:
                      'e.g. Suresh Plumber',
                      prefixIcon: Icon(
                          Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  const Text('PHONE NUMBER',
                      style: AppText.label),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType:
                    TextInputType.phone,
                    decoration:
                    const InputDecoration(
                      hintText:
                      'e.g. 9876543210',
                      prefixIcon: Icon(
                          Icons.phone_outlined),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                        padding:
                        const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color:
                            AppColors.dangerLight,
                            borderRadius:
                            BorderRadius
                                .circular(8)),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13))),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null : _save,
                      child: _loading
                          ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                              Colors.white))
                          : Text(_isEdit
                          ? 'Save Changes'
                          : widget.isAdmin
                          ? 'Add Contact'
                          : 'Submit Suggestion'),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}