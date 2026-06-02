import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/vote_model.dart';
import '../../data/repositories/vote_repository.dart';

class CreateVoteScreen extends StatefulWidget {
  final String societyId;
  final String adminId;
  final String adminName;

  const CreateVoteScreen({
    super.key,
    required this.societyId,
    required this.adminId,
    required this.adminName,
  });

  @override
  State<CreateVoteScreen> createState() =>
      _CreateVoteScreenState();
}

class _CreateVoteScreenState
    extends State<CreateVoteScreen> {
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _repo       = VoteRepository();

  VoteType _type       = VoteType.generalPoll;
  int      _duration   = 7;
  double   _threshold  = 60.0;
  bool     _loading    = false;
  String?  _error;

  // For maintenance change
  final _newAmountCtrl = TextEditingController();
  String? _selectedFlatTypeId;
  String? _selectedFlatTypeName;

  // For admin transfer
  String? _newAdminId;
  String? _newAdminName;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _newAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleCtrl.text.trim();
    final desc  = _descCtrl.text.trim();

    if (title.isEmpty) {
      setState(() =>
      _error = 'Enter a title');
      return;
    }
    if (desc.isEmpty) {
      setState(() =>
      _error = 'Enter a description');
      return;
    }

    // Validate type-specific fields
    if (_type == VoteType.maintenanceChange) {
      if (_newAmountCtrl.text.trim().isEmpty) {
        setState(() =>
        _error =
        'Enter the new maintenance amount');
        return;
      }
    }
    if (_type == VoteType.adminTransfer) {
      if (_newAdminId == null) {
        setState(() =>
        _error = 'Select the new admin');
        return;
      }
    }

    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      // Build proposal data
      Map<String, dynamic>? proposalData;
      if (_type == VoteType.maintenanceChange) {
        proposalData = {
          'newAmount':
          double.parse(
              _newAmountCtrl.text.trim()),
          'flatTypeId':  _selectedFlatTypeId,
          'flatTypeName':_selectedFlatTypeName,
        };
      } else if (_type ==
          VoteType.adminTransfer) {
        proposalData = {
          'newAdminId':  _newAdminId,
          'newAdminName':_newAdminName,
        };
      }

      await _repo.createVote(
        societyId:     widget.societyId,
        type:          _type,
        title:         title,
        description:   desc,
        createdBy:     widget.adminId,
        createdByName: widget.adminName,
        durationDays:  _duration,
        passThreshold: _threshold,
        proposalData:  proposalData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text('✅ Vote created!'),
            backgroundColor:
            AppColors.success));
        Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Vote'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [

            // ── Vote Type ──────────────────────────
            const Text('VOTE TYPE',
                style: AppText.label),
            const SizedBox(height: 10),
            ...VoteType.values.map((type) {
              final label = switch (type) {
                VoteType.adminTransfer =>
                'Admin Transfer',
                VoteType.maintenanceChange =>
                'Maintenance Change',
                VoteType.generalPoll =>
                'General Poll',
              };
              final desc = switch (type) {
                VoteType.adminTransfer =>
                'Transfer admin rights to another member',
                VoteType.maintenanceChange =>
                'Propose a change in monthly maintenance',
                VoteType.generalPoll =>
                'Any general society matter',
              };
              final icon = switch (type) {
                VoteType.adminTransfer  => '👑',
                VoteType.maintenanceChange => '💰',
                VoteType.generalPoll    => '🗳️',
              };

              return GestureDetector(
                onTap: () => setState(
                        () => _type = type),
                child: Container(
                  margin: const EdgeInsets.only(
                      bottom: 8),
                  padding:
                  const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _type == type
                          ? AppColors.accentLight
                          : Colors.white,
                      borderRadius:
                      BorderRadius.circular(12),
                      border: Border.all(
                          color: _type == type
                              ? AppColors.accent
                              : AppColors.border,
                          width: _type == type
                              ? 2 : 1)),
                  child: Row(children: [
                    Text(icon,
                        style: const TextStyle(
                            fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight:
                                FontWeight.w700,
                                color:
                                AppColors
                                    .textPrimary)),
                        Text(desc,
                            style: const TextStyle(
                                fontSize: 11,
                                color:
                                AppColors
                                    .textSecondary)),
                      ],
                    )),
                    if (_type == type)
                      const Icon(
                          Icons.check_circle,
                          color: AppColors.accent,
                          size: 20),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 16),

            // ── Title & Description ────────────────
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text('TITLE',
                      style: AppText.label),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration:
                    const InputDecoration(
                        hintText:
                        'e.g. Increase '
                            'maintenance by 10%'),
                  ),
                  const SizedBox(height: 16),
                  const Text('DESCRIPTION',
                      style: AppText.label),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration:
                    const InputDecoration(
                      hintText:
                      'Explain the reason '
                          'for this vote...',
                    ),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 16),

            // ── Type specific fields ───────────────
            if (_type ==
                VoteType.maintenanceChange)
              Card(child: Padding(
                padding:
                const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'NEW MAINTENANCE AMOUNT',
                        style: AppText.label),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _newAmountCtrl,
                      keyboardType:
                      TextInputType.number,
                      decoration:
                      const InputDecoration(
                          prefixText: '₹ ',
                          hintText: '3000'),
                    ),
                  ],
                ),
              )),

            if (_type == VoteType.adminTransfer)
              Card(child: Padding(
                padding:
                const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    const Text('NEW ADMIN',
                        style: AppText.label),
                    const SizedBox(height: 8),
                    const Text(
                        'Enter the user ID of '
                            'the new admin:',
                        style: AppText.small),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration:
                      const InputDecoration(
                          hintText:
                          'Member User ID'),
                      onChanged: (v) =>
                          setState(
                                  () => _newAdminId =
                                  v.trim()),
                    ),
                  ],
                ),
              )),

            const SizedBox(height: 16),

            // ── Settings ───────────────────────────
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text('VOTE SETTINGS',
                      style: AppText.label),
                  const SizedBox(height: 16),

                  // Duration
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      const Text(
                          'Duration',
                          style: AppText.bodyBold),
                      Text(
                          '$_duration days',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight:
                              FontWeight.w700)),
                    ],
                  ),
                  Slider(
                    value: _duration.toDouble(),
                    min: 1, max: 14,
                    divisions: 13,
                    activeColor: AppColors.accent,
                    onChanged: (v) => setState(
                            () => _duration = v.toInt()),
                  ),

                  const Divider(height: 16),

                  // Threshold
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      const Text(
                          'Pass Threshold',
                          style: AppText.bodyBold),
                      Text(
                          '$_threshold%',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight:
                              FontWeight.w700)),
                    ],
                  ),
                  Slider(
                    value: _threshold,
                    min: 50, max: 100,
                    divisions: 10,
                    activeColor: AppColors.accent,
                    onChanged: (v) => setState(
                            () => _threshold =
                            (v / 5).round() * 5.0),
                  ),
                  Text(
                      '$_threshold% of Yes votes '
                          'needed to pass',
                      style: AppText.small),
                ],
              ),
            )),

            const SizedBox(height: 16),

            if (_error != null)
              Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius:
                      BorderRadius.circular(10)),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 13))),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading
                    ? null : _create,
                child: _loading
                    ? const SizedBox(
                    width: 20, height: 20,
                    child:
                    CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : const Text(
                    '🗳️ Create Vote'),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}