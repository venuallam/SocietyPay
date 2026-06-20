import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/society_model.dart';
import '../../data/repositories/society_repository.dart';
import '../dashboard/admin_dashboard_screen.dart';

class SocietyWizardScreen extends StatefulWidget {
  const SocietyWizardScreen({super.key});

  @override
  State<SocietyWizardScreen> createState() =>
      _SocietyWizardScreenState();
}

class _SocietyWizardScreenState
    extends State<SocietyWizardScreen> {

  // ── Page controller ──────────────────────────────
  final _pageCtrl = PageController();
  int     _step   = 0;
  bool    _loading = false;
  String? _error;

  int     _totalSteps = 5;

  final _titles = [
    'Society Details',
    'Flat Types',
    'Organization',
    'Units & Types',
    'Preview',
  ];

  final _subtitles = [
    'Name and address of your society',
    'Define flat types and monthly maintenance',
    'Choose how to organize flats',
    'Configure units and assign types',
    'Review all generated flats and create',
  ];

  // ── Step 1 — Society Details ─────────────────────
  final _adminNameCtrl = TextEditingController();
  final _nameCtrl      = TextEditingController();
  final _addressCtrl   = TextEditingController();

  // ── Step 2 — Flat Types ──────────────────────────
  // [{typeName, amount}]
  final List<Map<String, dynamic>> _flatTypes = [];

  // ── Step 3 — Organization Toggle ─────────────────
  bool _useBlocks = false; // false = flat list, true = blocks

  // ── Step 3b — Blocks & Floors (if _useBlocks) ────
  int          _numBlocks      = 1;
  List<String> _blockNames     = ['A'];
  List<int>    _floorsPerBlock = [5];

  // ── Step 4 — Floor Template ──────────────────────
  int           _unitsPerFloor  = 2;
  int           _totalFloors    = 5; // Used when no blocks
  // Index = unit position (0-based), value = typeName
  List<String?> _unitTypes      = [null, null];

  // ── Step 5 — Generated Flats ─────────────────────
  List<Map<String, dynamic>> _generatedFlats = [];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _adminNameCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Build full flat list from current config ─────
  List<Map<String, dynamic>> _buildFlats() {
    final flats = <Map<String, dynamic>>[];

    if (_useBlocks) {
      // With blocks
      for (int b = 0; b < _numBlocks; b++) {
        final block  = _blockNames[b];
        final floors = _floorsPerBlock[b];
        for (int f = 1; f <= floors; f++) {
          for (int u = 1;
          u <= _unitsPerFloor; u++) {
            final unitStr = u
                .toString()
                .padLeft(2, '0');
            flats.add({
              'flatNumber':
              '$block-$f$unitStr',
              'typeName':
              _unitTypes[u - 1] ?? '',
            });
          }
        }
      }
    } else {
      // Without blocks — just floors
      for (int f = 1;
      f <= _totalFloors; f++) {
        for (int u = 1;
        u <= _unitsPerFloor; u++) {
          final unitStr = u
              .toString()
              .padLeft(2, '0');
          flats.add({
            'flatNumber':
            '$f$unitStr',
            'typeName':
            _unitTypes[u - 1] ?? '',
          });
        }
      }
    }

    return flats;
  }

  // ── Step total flat count ────────────────────────
  int get _totalFlats {
    if (_useBlocks) {
      int total = 0;
      for (int b = 0; b < _numBlocks; b++) {
        total +=
            _floorsPerBlock[b] *
                _unitsPerFloor;
      }
      return total;
    } else {
      return _totalFloors * _unitsPerFloor;
    }
  }

  // ── Type breakdown for preview ───────────────────
  Map<String, int> get _typeBreakdown {
    final map = <String, int>{};
    for (final flat in _generatedFlats) {
      final t = flat['typeName'] as String;
      map[t] = (map[t] ?? 0) + 1;
    }
    return map;
  }

  // ── Navigation ───────────────────────────────────
  void _next() {
    setState(() => _error = null);

    // ── Validate each step ──────────────────────
    switch (_step) {
      case 0:
        if (_adminNameCtrl.text.trim().isEmpty) {
          setState(() =>
          _error = 'Please enter your name');
          return;
        }
        if (_nameCtrl.text.trim().isEmpty) {
          setState(() =>
          _error = 'Please enter the society name');
          return;
        }

      case 1:
        if (_flatTypes.isEmpty) {
          setState(() => _error =
          'Add at least one flat type');
          return;
        }

      case 2:
        // Organization step — validate blocks if enabled
        if (_useBlocks) {
          for (int b = 0;
          b < _numBlocks; b++) {
            if (_floorsPerBlock[b] < 1) {
              setState(() => _error =
              'Each block must have '
                  'at least 1 floor');
              return;
            }
          }
        } else {
          if (_totalFloors < 1) {
            setState(() => _error =
            'Enter at least 1 floor');
            return;
          }
        }
        // Reset unit types for next step
        _unitTypes = List.filled(
            _unitsPerFloor, null);

      case 3:
        if (_unitTypes.any((t) => t == null)) {
          setState(() => _error =
          'Assign a flat type to '
              'every unit position');
          return;
        }
        // Generate flat list for preview
        setState(() =>
        _generatedFlats = _buildFlats());

      case 4:
        _createSociety();
        return;
    }

    setState(() => _step++);
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prev() {
    if (_step > 0) {
      setState(() { _step--; _error = null; });
      _pageCtrl.previousPage(
        duration:
        const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ── Block count helpers ──────────────────────────
  void _setNumBlocks(int n) {
    if (n < 1 || n > 26) return;
    setState(() {
      _numBlocks = n;
      // Grow/shrink names and floors lists
      while (_blockNames.length < n) {
        final idx = _blockNames.length;
        _blockNames.add(
            String.fromCharCode(65 + idx));
        _floorsPerBlock.add(5);
      }
      _blockNames     = _blockNames.sublist(0, n);
      _floorsPerBlock =
          _floorsPerBlock.sublist(0, n);
    });
  }

  // ── Unit count helpers ───────────────────────────
  void _setUnitsPerFloor(int n) {
    if (n < 1 || n > 10) return;
    setState(() {
      _unitsPerFloor = n;
      // Grow/shrink type assignment list
      while (_unitTypes.length < n) {
        _unitTypes.add(null);
      }
      _unitTypes = _unitTypes.sublist(0, n);
    });
  }

  // ── Create Society ───────────────────────────────
  Future<void> _createSociety() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final uid  =
          FirebaseAuth.instance.currentUser!.uid;
      final repo = SocietyRepository();

      final flatTypes = _flatTypes.map((ft) =>
          FlatTypeModel(
            id:                '',
            typeName:          ft['typeName']
            as String,
            maintenanceAmount: ft['amount']
            as double,
          )).toList();

      final society = await repo.createSociety(
        adminId:   uid,
        adminName: _adminNameCtrl.text.trim(),
        name:      _nameCtrl.text.trim(),
        address:   _addressCtrl.text.trim(),
        flatTypes: flatTypes,
        flats:     _generatedFlats,
      );

      if (mounted) {
        _showSuccessDialog(
          society.inviteCode,
          society.id,
          society.name,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ── Success Dialog ───────────────────────────────
  void _showSuccessDialog(
      String inviteCode,
      String societyId,
      String societyName,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20)),
        title: const Column(children: [
          Text('🎉',
              style: TextStyle(fontSize: 48)),
          SizedBox(height: 8),
          Text('Society Created!',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this invite code with '
                  'your residents:',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:
                  AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
              const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius:
                BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accent),
              ),
              child: Text(
                inviteCode,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This code is permanent.\n'
                  'Share it in your society '
                  'WhatsApp group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminDashboardScreen(
                          societyId:   societyId,
                          societyName: societyName,
                          inviteCode:  inviteCode,
                        ),
                  ),
                );
              },
              child: const Text(
                  'Go to Dashboard →'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add Flat Type Dialog ─────────────────────────
  void _showAddFlatTypeDialog() {
    final nameCtrl   = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16)),
        title: const Text('Add Flat Type',
            style: TextStyle(
                fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameCtrl,
              textCapitalization:
              TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Flat Type',
                hintText:
                'e.g. 1BHK, 2BHK, 3BHK',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText:
                'Monthly Maintenance (₹)',
                prefixText: '₹ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name   =
                  nameCtrl.text.trim()
                      .toUpperCase();
              final amount =
                  double.tryParse(
                      amountCtrl.text.trim());
              if (name.isNotEmpty &&
                  amount != null &&
                  amount > 0) {
                final exists = _flatTypes.any(
                        (ft) => ft['typeName']
                        .toString()
                        .toUpperCase() == name);
                if (!exists) {
                  setState(() =>
                      _flatTypes.add({
                        'typeName': name,
                        'amount':   amount,
                      }));
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [

        // ── Header ──────────────────────────────
        Container(
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
          padding: const EdgeInsets.fromLTRB(
              24, 60, 24, 24),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // Progress dots
              Row(
                children: List.generate(
                    _totalSteps, (i) =>
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                            right: i < _totalSteps - 1
                                ? 5 : 0),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? Colors.white
                              : Colors.white
                              .withOpacity(0.25),
                          borderRadius:
                          BorderRadius
                              .circular(2),
                        ),
                      ),
                    )),
              ),
              const SizedBox(height: 18),
              Text(
                'Step ${_step + 1} '
                    'of $_totalSteps',
                style: TextStyle(
                    color: Colors.white
                        .withOpacity(0.6),
                    fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _titles[_step] ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight:
                    FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitles[_step] ?? '',
                style: TextStyle(
                    color: Colors.white
                        .withOpacity(0.7),
                    fontSize: 12),
              ),
            ],
          ),
        ),

        // ── Page Content ─────────────────────────
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics:
            const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(),
              _buildStep2(),
              _buildStep3(),
              _buildStep4(),
              _buildStep5(),
            ],
          ),
        ),

        // ── Error ────────────────────────────────
        if (_error != null)
          Container(
            width: double.infinity,
            color: AppColors.dangerLight,
            padding:
            const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            child: Text(_error!,
                style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 13)),
          ),

        // ── Nav Buttons ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              20, 12, 20, 32),
          child: Row(children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed:
                  _loading ? null : _prev,
                  child: const Text('← Back'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed:
                _loading ? null : _next,
                child: _loading
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                        Colors.white))
                    : Text(_step == 4
                    ? '🎉 Create Society'
                    : 'Next →'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════
  // STEP 1 — Society Details
  // ══════════════════════════════════════════
  Widget _buildStep1() => _WizardPage(
    children: [
      const SizedBox(height: 8),
      TextFormField(
        controller: _adminNameCtrl,
        autofocus: true,
        textCapitalization:
        TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Your Name *',
          hintText: 'e.g. Ramesh Kumar',
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _nameCtrl,
        textCapitalization:
        TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Society Name *',
          hintText:
          'e.g. Sunrise Apartments',
          prefixIcon:
          Icon(Icons.apartment),
        ),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _addressCtrl,
        textCapitalization:
        TextCapitalization.sentences,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Address (optional)',
          hintText:
          'e.g. 12, MG Road, Bengaluru',
          prefixIcon:
          Icon(Icons.location_on_outlined),
        ),
      ),
      const SizedBox(height: 16),
      _InfoBox(
        icon: '💡',
        text: 'Your name will appear on '
            'reports and billing records. '
            'Society name appears in all '
            'resident notifications.',
      ),
    ],
  );

  // ══════════════════════════════════════════
  // STEP 2 — Flat Types
  // ══════════════════════════════════════════
  Widget _buildStep2() => _WizardPage(
    children: [
      const SizedBox(height: 8),

      ..._flatTypes.asMap().entries.map((e) {
        final i  = e.key;
        final ft = e.value;
        return Container(
          margin: const EdgeInsets.only(
              bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius:
            BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius:
                BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  ft['typeName']
                      .toString()
                      .substring(0, 1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight:
                      FontWeight.w800,
                      fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  ft['typeName'] as String,
                  style: const TextStyle(
                      fontWeight:
                      FontWeight.w700,
                      fontSize: 15,
                      color:
                      AppColors.textPrimary),
                ),
                Text(
                  '₹${NumberFormat('#,##0').format(ft['amount'])}'
                      '/month',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight:
                      FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            )),
            IconButton(
              onPressed: () => setState(
                      () => _flatTypes.removeAt(i)),
              icon: const Icon(
                  Icons.remove_circle_outline,
                  color: AppColors.danger),
            ),
          ]),
        );
      }),

      OutlinedButton.icon(
        onPressed: _showAddFlatTypeDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Flat Type'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
              double.infinity, 50),
        ),
      ),
      const SizedBox(height: 16),
      _InfoBox(
        icon: '💡',
        text: 'Add each flat type and its '
            'monthly maintenance charge. '
            'e.g. 2BHK = ₹2,500, '
            '3BHK = ₹3,500.',
      ),
    ],
  );

  // ══════════════════════════════════════════
  // STEP 3 — Organization (Blocks or Flat)
  // ══════════════════════════════════════════
  Widget _buildStep3() => _WizardPage(
    children: [
      const SizedBox(height: 8),

      // Toggle: Blocks or Flat List
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius:
            BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Organize by Blocks?',
                    style: AppText.bodyBold,
                  ),
                  Text(
                    _useBlocks
                        ? 'Each block has separate '
                        'floors and units'
                        : 'Simple flat list '
                        'across all floors',
                    style: const TextStyle(
                        fontSize: 11,
                        color:
                        AppColors.textMuted),
                  ),
                ],
              )),
              Switch.adaptive(
                value: _useBlocks,
                onChanged: (v) => setState(
                        () => _useBlocks = v),
              ),
            ]),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // Conditional: Blocks or Floors
      if (_useBlocks) ...[
        // Blocks config
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.border)),
          child: Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Number of Blocks',
                    style: AppText.bodyBold,
                  ),
                  Text(
                    'Wings / towers',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                        AppColors.textMuted),
                  ),
                ],
              ),
            ),
            _Stepper(
              value:    _numBlocks,
              min:      1,
              max:      26,
              onChanged: _setNumBlocks,
            ),
          ]),
        ),
        const SizedBox(height: 14),
        // Per-block config
        ...List.generate(_numBlocks, (b) =>
            Container(
              margin:
              const EdgeInsets.only(
                  bottom: 10),
              padding:
              const EdgeInsets.all(
                  16),
              decoration:
              BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius
                      .circular(14),
                  border: Border.all(
                      color:
                      AppColors.border)),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                  BoxDecoration(
                      color: AppColors
                          .primary,
                      borderRadius:
                      BorderRadius
                          .circular(12)),
                  child: Center(
                    child: Text(
                      _blockNames[b],
                      style:
                      const TextStyle(
                          color:
                          Colors.white,
                          fontSize: 18,
                          fontWeight:
                          FontWeight
                              .w800),
                    ),
                  ),
                ),
                const SizedBox(
                    width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        'Block ${_blockNames[b]}',
                        style:
                        AppText
                            .bodyBold,
                      ),
                      Text(
                        '${_floorsPerBlock[b]} floor(s)',
                        style:
                        const TextStyle(
                            fontSize:
                            11,
                            color: AppColors
                                .textMuted),
                      ),
                    ],
                  ),
                ),
                _Stepper(
                  value: _floorsPerBlock[b],
                  min:   1,
                  max:   50,
                  onChanged: (v) =>
                      setState(() =>
                      _floorsPerBlock[b] =
                          v),
                  label: 'floors',
                ),
              ]),
            ),
        ),
      ] else ...[
        // Flat list — just total floors
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.border)),
          child: Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Floors',
                    style: AppText.bodyBold,
                  ),
                  Text(
                    'All units across these '
                    'floors',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                        AppColors.textMuted),
                  ),
                ],
              ),
            ),
            _Stepper(
              value:   _totalFloors,
              min:     1,
              max:     100,
              onChanged: (v) => setState(
                      () => _totalFloors = v),
            ),
          ]),
        ),
      ],

      const SizedBox(height: 16),
      _InfoBox(
        icon: '💡',
        text: _useBlocks
            ? 'Blocks are named A, B, C…'
            'Each can have different '
            'numbers of floors.'
            : 'All flats organized by floor '
            'number only (no block prefix).',
      ),
    ],
  );

  // ══════════════════════════════════════════
  // STEP 4 — Floor Template
  // ══════════════════════════════════════════
  Widget _buildStep4() => _WizardPage(
    children: [
      const SizedBox(height: 8),

      // Units per floor stepper
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.border)),
        child: Row(children: [
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text('Units per Floor',
                    style: AppText.bodyBold),
                Text(
                    'How many flats on each floor?',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                        AppColors.textMuted)),
              ],
            ),
          ),
          _Stepper(
            value: _unitsPerFloor,
            min:   1,
            max:   10,
            onChanged: _setUnitsPerFloor,
          ),
        ]),
      ),

      const SizedBox(height: 20),

      const Text('Assign Flat Type per Unit',
          style: AppText.h4),
      const SizedBox(height: 4),
      Text(
        'This pattern repeats for every floor '
            'in every block.',
        style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted),
      ),
      const SizedBox(height: 12),

      // Unit type assignment rows
      ...List.generate(_unitsPerFloor, (u) {
        final unitLabel =
            'Unit ${(u + 1).toString().padLeft(2, '0')}';
        final selected = _unitTypes[u];

        return Container(
          margin: const EdgeInsets.only(
              bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected != null
                ? AppColors.accentLight
                : Colors.white,
            borderRadius:
            BorderRadius.circular(12),
            border: Border.all(
                color: selected != null
                    ? AppColors.accent
                    : AppColors.border),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: selected != null
                      ? AppColors.primary
                      : AppColors.bgLight,
                  borderRadius:
                  BorderRadius.circular(10)),
              child: Center(child: Text(
                  '${u + 1}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: selected != null
                          ? Colors.white
                          : AppColors.textMuted))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(unitLabel,
                  style: AppText.bodyBold),
            ),
            // Flat type dropdown
            DropdownButton<String>(
              value: selected,
              hint: const Text(
                  'Select type',
                  style: TextStyle(
                      fontSize: 13,
                      color:
                      AppColors.textMuted)),
              underline: const SizedBox(),
              isDense: true,
              borderRadius:
              BorderRadius.circular(10),
              items: _flatTypes.map((ft) =>
                  DropdownMenuItem(
                    value: ft['typeName']
                    as String,
                    child: Text(
                      ft['typeName']
                      as String,
                      style: const TextStyle(
                          fontWeight:
                          FontWeight.w700,
                          color:
                          AppColors.primary),
                    ),
                  )).toList(),
              onChanged: (v) => setState(
                      () => _unitTypes[u] = v),
            ),
          ]),
        );
      }),

      const SizedBox(height: 8),

      // Live preview chip row
      if (_unitTypes.every((t) => t != null))
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius:
              BorderRadius.circular(12)),
          child: Row(children: [
            const Text('✅ ',
                style:
                TextStyle(fontSize: 16)),
            Expanded(child: Text(
                'Floor template set. '
                    'Total ${_totalFlats} flats '
                    'will be generated.',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.success,
                    fontWeight:
                    FontWeight.w600))),
          ]),
        ),
    ],
  );

  // ══════════════════════════════════════════
  // STEP 5 — Preview
  // ══════════════════════════════════════════
  Widget _buildStep5() {
    final breakdown = _typeBreakdown;

    return _WizardPage(children: [
      const SizedBox(height: 8),

      // Summary card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius:
            BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              '🏢  ${_nameCtrl.text.trim()}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _SummaryChip(
                  label: '${_generatedFlats.length} Flats',
                  icon: '🏠'),
              const SizedBox(width: 8),
              _SummaryChip(
                  label: '$_numBlocks Block'
                      '${_numBlocks > 1 ? 's' : ''}',
                  icon: '🏗️'),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: breakdown.entries
                  .map((e) => _SummaryChip(
                  label:
                  '${e.value}× ${e.key}',
                  icon: '📐'))
                  .toList(),
            ),
          ],
        ),
      ),

      const SizedBox(height: 20),
      const Text('Generated Flats',
          style: AppText.h4),
      const SizedBox(height: 10),

      // Group flats by block for display
      ..._buildFlatPreviewGroups(),

      const SizedBox(height: 8),
      _InfoBox(
        icon: '⚠️',
        text: 'Flat numbers cannot be changed '
            'after creation. Review carefully '
            'before tapping Create Society.',
      ),
    ]);
  }

  List<Widget> _buildFlatPreviewGroups() {
    if (_useBlocks) {
      // Group by block prefix
      final groups =
          <String,
          List<Map<String,
          dynamic>>>{};
      for (final flat
      in _generatedFlats) {
        final block =
            (flat['flatNumber']
            as String)
            .split('-')
            .first;
        groups.putIfAbsent(
            block, () => [])
            .add(flat);
      }

      return groups.entries
          .map((entry) {
        final block = entry.key;
        final flats = entry.value;

        return Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
              const EdgeInsets
                  .only(
                  bottom: 8, top: 4),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration:
                  BoxDecoration(
                      color: AppColors
                          .primary,
                      borderRadius:
                      BorderRadius
                          .circular(6)),
                  child: Center(
                    child: Text(block,
                        style:
                        const TextStyle(
                            color:
                            Colors.white,
                            fontSize: 12,
                            fontWeight:
                            FontWeight
                                .w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Block $block',
                    style:
                    const TextStyle(
                        fontWeight:
                        FontWeight.w700,
                        fontSize: 13,
                        color: AppColors
                            .textPrimary)),
                const SizedBox(width: 8),
                Text('${flats.length}',
                    style:
                    const TextStyle(
                        fontSize: 11,
                        color: AppColors
                            .textMuted)),
              ]),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: flats
                  .map((flat) {
                final type = flat[
                'typeName'] as String;
                return Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                      horizontal: 10,
                      vertical: 6),
                  decoration:
                  BoxDecoration(
                      color: AppColors
                          .accentLight,
                      borderRadius:
                      BorderRadius
                          .circular(8),
                      border:
                      Border.all(
                          color: AppColors
                              .border)),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Text(
                        flat['flatNumber']
                        as String,
                        style:
                        const TextStyle(
                            fontSize: 12,
                            fontWeight:
                            FontWeight
                                .w800,
                            color:
                            AppColors
                                .primary),
                      ),
                      Text(type,
                          style:
                          const TextStyle(
                              fontSize: 9,
                              color:
                              AppColors
                                  .accent,
                              fontWeight:
                              FontWeight
                                  .w700)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList();
    } else {
      // No blocks — show all flats
      return [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _generatedFlats
              .map((flat) {
            final type =
                flat['typeName']
                as String;
            return Container(
              padding:
              const EdgeInsets
                  .symmetric(
                  horizontal: 10,
                  vertical: 6),
              decoration:
              BoxDecoration(
                  color: AppColors
                      .accentLight,
                  borderRadius:
                  BorderRadius
                      .circular(8),
                  border: Border.all(
                      color:
                      AppColors.border)),
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  Text(
                    flat['flatNumber']
                    as String,
                    style:
                    const TextStyle(
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w800,
                        color: AppColors
                            .primary),
                  ),
                  Text(type,
                      style:
                      const TextStyle(
                          fontSize: 9,
                          color: AppColors
                              .accent,
                          fontWeight:
                          FontWeight
                              .w700)),
                ],
              ),
            );
          }).toList(),
        ),
      ];
    }
  }
}

// ── Stepper Widget ────────────────────────────────────────────────────────────
class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? label;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min,
          children: [
            _StepBtn(
              icon: Icons.remove,
              onTap: value > min
                  ? () => onChanged(value - 1)
                  : null,
            ),
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight:
                        FontWeight.w800,
                        color:
                        AppColors.textPrimary),
                  ),
                  if (label != null)
                    Text(label!,
                        style: const TextStyle(
                            fontSize: 9,
                            color:
                            AppColors.textMuted)),
                ],
              ),
            ),
            _StepBtn(
              icon: Icons.add,
              onTap: value < max
                  ? () => onChanged(value + 1)
                  : null,
            ),
          ]);
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn(
      {required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
              color: onTap != null
                  ? AppColors.primary
                  : AppColors.bgLight,
              borderRadius:
              BorderRadius.circular(8)),
          child: Icon(icon,
              color: onTap != null
                  ? Colors.white
                  : AppColors.border,
              size: 18),
        ),
      );
}

// ── Summary Chip ──────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label, icon;
  const _SummaryChip(
      {required this.label, required this.icon});

  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color:
            Colors.white.withOpacity(0.15),
            borderRadius:
            BorderRadius.circular(20)),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon,
                  style: const TextStyle(
                      fontSize: 12)),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w700)),
            ]),
      );
}

// ── Shared Helper Widgets ──────────────────────────────────────────────────────
class _WizardPage extends StatelessWidget {
  final List<Widget> children;
  const _WizardPage({required this.children});

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: children,
        ),
      );
}

class _InfoBox extends StatelessWidget {
  final String icon, text;
  const _InfoBox(
      {required this.icon, required this.text});

  @override
  Widget build(BuildContext context) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius:
          BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(icon,
                style: const TextStyle(
                    fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    color:
                    AppColors.textSecondary))),
          ],
        ),
      );
}
