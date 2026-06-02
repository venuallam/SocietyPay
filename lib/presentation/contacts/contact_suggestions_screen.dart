import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/contact_model.dart';
import '../../data/repositories/contact_repository.dart';

class ContactSuggestionsScreen
    extends StatelessWidget {
  final String societyId;
  final String adminId;

  const ContactSuggestionsScreen({
    super.key,
    required this.societyId,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Suggestions'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _SuggestionList(
        societyId: societyId,
        adminId:   adminId,
      ),
    );
  }
}

// ── Extracted Widget — avoids StreamBuilder type conflict ─────────────────────
class _SuggestionList extends StatelessWidget {
  final String societyId;
  final String adminId;

  const _SuggestionList({
    required this.societyId,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    final repo = ContactRepository();

    return StreamBuilder<List<ContactSuggestionModel>>(
      stream: repo.watchPendingSuggestions(societyId),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary));
        }

        final suggestions = snap.data ?? [];

        if (suggestions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                Text('💡',
                    style: TextStyle(fontSize: 52)),
                SizedBox(height: 16),
                Text(
                    'No pending suggestions',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                SizedBox(height: 8),
                Text(
                    'Member suggestions will '
                        'appear here.',
                    style: TextStyle(
                        color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: 10),
          itemBuilder: (ctx, i) =>
              _SuggestionCard(
                suggestion: suggestions[i],
                societyId:  societyId,
                adminId:    adminId,
              ),
        );
      },
    );
  }
}

// ── Suggestion Card ───────────────────────────────────────────────────────────
class _SuggestionCard extends StatefulWidget {
  final ContactSuggestionModel suggestion;
  final String societyId;
  final String adminId;

  const _SuggestionCard({
    required this.suggestion,
    required this.societyId,
    required this.adminId,
  });

  @override
  State<_SuggestionCard> createState() =>
      _SuggestionCardState();
}

class _SuggestionCardState
    extends State<_SuggestionCard> {
  bool _loading = false;
  final _repo   = ContactRepository();

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await _repo.approveSuggestion(
        societyId:    widget.societyId,
        suggestionId: widget.suggestion.id,
        adminId:      widget.adminId,
        suggestion:   widget.suggestion,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text(
                '✅ Contact approved and added'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    try {
      await _repo.rejectSuggestion(
        societyId:    widget.societyId,
        suggestionId: widget.suggestion.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(
            content: Text('Suggestion rejected'),
            backgroundColor: AppColors.warning));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s       = widget.suggestion;
    final catIcon = switch (s.category) {
      ContactCategory.emergency => '🚨',
      ContactCategory.repairs   => '🔧',
      ContactCategory.nearby    => '🏥',
    };
    final catLabel = switch (s.category) {
      ContactCategory.emergency => 'Emergency',
      ContactCategory.repairs   => 'Repairs',
      ContactCategory.nearby    => 'Nearby',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Contact info
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius:
                  BorderRadius.circular(12)),
              child: Center(child: Text(
                  catIcon,
                  style: const TextStyle(
                      fontSize: 24))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(s.phone,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                      padding:
                      const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius:
                          BorderRadius.circular(20)),
                      child: Text(catLabel,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent))),
                  const SizedBox(width: 6),
                  Text(
                      'by ${s.suggestedByName}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted)),
                ]),
              ],
            )),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Action buttons
          _loading
              ? const Center(
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2)))
              : Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _reject,
                    style: OutlinedButton.styleFrom(
                        foregroundColor:
                        AppColors.danger,
                        side: const BorderSide(
                            color: AppColors.danger),
                        padding:
                        const EdgeInsets.symmetric(
                            vertical: 8)),
                    child: const Text('Reject'))),
            const SizedBox(width: 10),
            Expanded(
                flex: 2,
                child: ElevatedButton(
                    onPressed: _approve,
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                        AppColors.success,
                        padding:
                        const EdgeInsets.symmetric(
                            vertical: 8)),
                    child: const Text(
                        '✅ Approve & Add'))),
          ]),
        ],
      ),
    );
  }
}