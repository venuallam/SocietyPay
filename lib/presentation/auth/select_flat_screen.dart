import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/society_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/member_repository.dart';

class SelectFlatScreen extends StatefulWidget {
  final SocietyModel society;
  final String userName;
  final String userPhone;
  final UserRole role;

  const SelectFlatScreen({
    super.key,
    required this.society,
    required this.userName,
    required this.userPhone,
    required this.role,
  });

  @override
  State<SelectFlatScreen> createState() =>
      _SelectFlatScreenState();
}

class _SelectFlatScreenState
    extends State<SelectFlatScreen> {
  final _repo = MemberRepository();
  List<FlatModel> _flats = [];
  String? _selectedFlatId;
  String? _selectedFlatNumber;
  bool _loading    = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFlats();
  }

  Future<void> _loadFlats() async {
    setState(() => _loading = true);
    try {
      final flats = await _repo.getFlats(
          widget.society.id);
      setState(() => _flats = flats);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedFlatId == null) {
      setState(() =>
      _error = 'Please select your flat');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final uid = FirebaseAuth
          .instance.currentUser!.uid;

      await _repo.submitJoinRequest(
        societyId:  widget.society.id,
        userId:     uid,
        userName:   widget.userName,
        userPhone:  widget.userPhone,
        flatId:     _selectedFlatId!,
        flatNumber: _selectedFlatNumber!,
        role:       widget.role,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Column(children: [
          Text('🎉', style: TextStyle(fontSize: 48)),
          SizedBox(height: 8),
          Text('Request Submitted!',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 40),
                const SizedBox(height: 8),
                Text(
                    'Your request to join '
                        '${widget.society.name} '
                        'has been submitted.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 16),
            const Text(
                'The admin will review and approve '
                    'your request. You will be notified '
                    'once approved.',
                textAlign: TextAlign.center,
                style: AppText.small),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Pop all screens back to login
                Navigator.of(context)
                    .popUntil((route) => route.isFirst);
              },
              child: const Text('OK, I will wait'),
            ),
          ),
        ],
      ),
    );
  }

  // Filter flats based on role
  List<FlatModel> get _filteredFlats {
    if (widget.role == UserRole.owner) {
      // Owners can only pick vacant flats
      return _flats
          .where((f) => f.isVacant)
          .toList();
    } else {
      // Tenants can pick occupied flats
      // (that already have an owner)
      return _flats
          .where((f) => f.isOccupied && f.hasOwner)
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleIcon  = widget.role == UserRole.owner
        ? '🏠' : '🔑';
    final roleLabel = widget.role == UserRole.owner
        ? 'Owner' : 'Tenant';
    final filteredFlats = _filteredFlats;

    return Scaffold(
      body: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
              24, 60, 24, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                AppColors.primary,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(roleIcon,
                  style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 16),
              const Text('Select Your Flat',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('$roleIcon $roleLabel',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('🏢 ${widget.society.name}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),

        // Body
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(
            color: AppColors.primary))
            : Column(children: [
          // Info banner
          Container(
            color: AppColors.accentLight,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  color: AppColors.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  widget.role == UserRole.owner
                      ? 'Select the flat you own. Only vacant flats are shown.'
                      : 'Select the flat you are renting. Only occupied flats are shown.',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accent))),
            ]),
          ),

          // Flat list
          Expanded(child: filteredFlats.isEmpty
              ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏠',
                  style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                  widget.role == UserRole.owner
                      ? 'No vacant flats available'
                      : 'No occupied flats available',
                  style: AppText.h4),
              const SizedBox(height: 8),
              const Text(
                  'Contact your admin for help.',
                  style: AppText.body),
            ],
          ))
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredFlats.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final flat = filteredFlats[i];
              final isSelected =
                  _selectedFlatId == flat.id;

              return GestureDetector(
                onTap: () => setState(() {
                  _selectedFlatId     = flat.id;
                  _selectedFlatNumber =
                      flat.flatNumber;
                  _error = null;
                }),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentLight
                        : Colors.white,
                    borderRadius:
                    BorderRadius.circular(12),
                    border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.border,
                        width: isSelected ? 2 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.bgLight,
                          borderRadius:
                          BorderRadius.circular(12)),
                      child: Center(child: Text(
                        flat.flatNumber
                            .replaceAll('Flat-', ''),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary),
                      )),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(flat.flatNumber,
                            style: AppText.bodyBold),
                        Text(
                            flat.isVacant
                                ? '🟢 Vacant'
                                : '🟡 Occupied',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted)),
                      ],
                    )),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: AppColors.accent,
                          size: 24),
                  ]),
                ),
              );
            },
          ),
          ),

          // Error
          if (_error != null)
            Container(
                color: AppColors.dangerLight,
                padding: const EdgeInsets.all(12),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13))),

          // Submit button
          Padding(
            padding: const EdgeInsets.fromLTRB(
                16, 8, 16, 32),
            child: ElevatedButton(
              onPressed: _submitting
                  ? null : _submitRequest,
              child: _submitting
                  ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white))
                  : const Text(
                  'Submit Join Request →'),
            ),
          ),
        ]),
        ),
      ]),
    );
  }
}