import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/contact_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/contact_repository.dart';
import 'add_contact_screen.dart';
import 'contact_suggestions_screen.dart';

class ContactsScreen extends StatefulWidget {
  final String societyId;
  final UserRole userRole;
  final String userName;

  const ContactsScreen({
    super.key,
    required this.societyId,
    required this.userRole,
    required this.userName,
  });

  @override
  State<ContactsScreen> createState() =>
      _ContactsScreenState();
}

class _ContactsScreenState
    extends State<ContactsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  bool get _isAdmin =>
      widget.userRole == UserRole.admin;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin)
            _SuggestionsButton(
              societyId: widget.societyId,
            ),
        ],
      ),
      body: Column(children: [

        // ── Search bar ──────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: TextFormField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                  icon: const Icon(
                      Icons.clear, size: 18),
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _searchQuery = '';
                  }))
                  : null,
              filled: true,
              fillColor: AppColors.bgLight,
              border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              contentPadding:
              const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
            ),
            onChanged: (v) => setState(
                    () => _searchQuery =
                    v.toLowerCase()),
          ),
        ),

        // ── Contact list ────────────────────────
        Expanded(
          child: _ContactList(
            societyId:   widget.societyId,
            isAdmin:     _isAdmin,
            searchQuery: _searchQuery,
          ),
        ),
      ]),

      // ── FAB ─────────────────────────────────────
      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AddContactScreen(
                  societyId: widget.societyId,
                  isAdmin:   _isAdmin,
                  userId: FirebaseAuth.instance
                      .currentUser!.uid,
                  userName:  widget.userName,
                ))),
        backgroundColor: AppColors.primary,
        icon: Icon(
            _isAdmin
                ? Icons.add
                : Icons.lightbulb_outline,
            color: Colors.white),
        label: Text(
            _isAdmin
                ? 'Add Contact'
                : 'Suggest Contact',
            style: const TextStyle(
                color: Colors.white)),
      ),
    );
  }
}

// ── Suggestions Button ────────────────────────────────────────────────────────
class _SuggestionsButton extends StatelessWidget {
  final String societyId;
  const _SuggestionsButton({
    required this.societyId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: ContactRepository()
          .watchPendingSuggestions(societyId),
      builder: (context,
          AsyncSnapshot<List<ContactSuggestionModel>>
          snap) {
        final count = snap.data?.length ?? 0;
        return Stack(children: [
          IconButton(
            icon: const Icon(
                Icons.lightbulb_outline,
                color: Colors.white),
            tooltip: 'Suggestions',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ContactSuggestionsScreen(
                          societyId: societyId,
                          adminId: FirebaseAuth
                              .instance.currentUser!.uid,
                        ))),
          ),
          if (count > 0)
            Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle),
                  child: Center(child: Text(
                      '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight:
                          FontWeight.w800))),
                )),
        ]);
      },
    );
  }
}

// ── Contact List ──────────────────────────────────────────────────────────────
class _ContactList extends StatelessWidget {
  final String societyId;
  final bool isAdmin;
  final String searchQuery;

  const _ContactList({
    required this.societyId,
    required this.isAdmin,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContactModel>>(
      stream: ContactRepository()
          .watchContacts(societyId),
      builder: (context, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary));
        }

        var contacts = snap.data ?? [];

        // Apply search filter
        if (searchQuery.isNotEmpty) {
          contacts = contacts.where((c) =>
          c.name.toLowerCase()
              .contains(searchQuery) ||
              c.phone.contains(searchQuery))
              .toList();
        }

        if (contacts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                const Text('📞',
                    style: TextStyle(fontSize: 52)),
                const SizedBox(height: 16),
                Text(
                    searchQuery.isNotEmpty
                        ? 'No contacts found'
                        : 'No contacts yet',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                    isAdmin
                        ? 'Tap + to add contacts'
                        : 'Tap + to suggest a contact',
                    style: const TextStyle(
                        color: AppColors.textMuted)),
              ],
            ),
          );
        }

        // Group by category
        final emergency = contacts.where((c) =>
        c.category ==
            ContactCategory.emergency).toList();
        final repairs = contacts.where((c) =>
        c.category ==
            ContactCategory.repairs).toList();
        final nearby = contacts.where((c) =>
        c.category ==
            ContactCategory.nearby).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (emergency.isNotEmpty) ...[
              _CategoryHeader(
                  icon:  '🚨',
                  title: 'Emergency',
                  color: AppColors.danger),
              ...emergency.map((c) =>
                  _ContactTile(
                    contact:   c,
                    isAdmin:   isAdmin,
                    societyId: societyId,
                  )),
              const SizedBox(height: 8),
            ],
            if (repairs.isNotEmpty) ...[
              _CategoryHeader(
                  icon:  '🔧',
                  title: 'Society Repairs',
                  color: AppColors.primary),
              ...repairs.map((c) =>
                  _ContactTile(
                    contact:   c,
                    isAdmin:   isAdmin,
                    societyId: societyId,
                  )),
              const SizedBox(height: 8),
            ],
            if (nearby.isNotEmpty) ...[
              _CategoryHeader(
                  icon:  '🏥',
                  title: 'Nearby Services',
                  color: AppColors.success),
              ...nearby.map((c) =>
                  _ContactTile(
                    contact:   c,
                    isAdmin:   isAdmin,
                    societyId: societyId,
                  )),
            ],
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

// ── Contact Tile ──────────────────────────────────────────────────────────────
class _ContactTile extends StatelessWidget {
  final ContactModel contact;
  final bool isAdmin;
  final String societyId;

  const _ContactTile({
    required this.contact,
    required this.isAdmin,
    required this.societyId,
  });

  Future<void> _call(BuildContext ctx) async {
    final uri =
    Uri.parse('tel:${contact.phone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(const SnackBar(
            content: Text('Cannot make call'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  void _copyNumber(BuildContext ctx) {
    Clipboard.setData(
        ClipboardData(text: contact.phone));
    ScaffoldMessenger.of(ctx)
        .showSnackBar(const SnackBar(
        content: Text(
            '📋 Number copied to clipboard'),
        backgroundColor: AppColors.success));
  }

  Future<void> _delete(
      BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Delete ${contact.name}?'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    await ContactRepository().deleteContact(
      societyId: societyId,
      contactId: contact.id,
    );
  }

  Future<void> _edit(BuildContext ctx) async {
    await Navigator.push(
        ctx,
        MaterialPageRoute(
            builder: (_) => AddContactScreen(
              societyId:   societyId,
              isAdmin:     true,
              userId:      contact.addedBy,
              userName:    '',
              editContact: contact,
            )));
  }

  @override
  Widget build(BuildContext context) {
    final catColor = switch (contact.category) {
      ContactCategory.emergency => AppColors.danger,
      ContactCategory.repairs   => AppColors.primary,
      ContactCategory.nearby    => AppColors.success,
    };
    final catBg = switch (contact.category) {
      ContactCategory.emergency =>
      AppColors.dangerLight,
      ContactCategory.repairs =>
      AppColors.accentLight,
      ContactCategory.nearby =>
      AppColors.successLight,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.border)),
      child: Row(children: [

        // Category icon
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
              color: catBg,
              borderRadius:
              BorderRadius.circular(14)),
          child: Center(child: Text(
              contact.categoryIcon,
              style: const TextStyle(
                  fontSize: 24))),
        ),
        const SizedBox(width: 12),

        // Details
        Expanded(child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(contact.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Text(contact.phone,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace')),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: catBg,
                      borderRadius:
                      BorderRadius.circular(20)),
                  child: Text(
                      contact.categoryLabel,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: catColor))),
              if (contact.isDefault) ...[
                const SizedBox(width: 6),
                Container(
                    padding:
                    const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.bgLight,
                        borderRadius:
                        BorderRadius.circular(20)),
                    child: const Text('DEFAULT',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted))),
              ],
            ]),
          ],
        )),

        // Call + Copy buttons
        Column(children: [
          GestureDetector(
              onTap: () => _call(context),
              child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius:
                      BorderRadius.circular(10)),
                  child: const Icon(
                      Icons.call,
                      color: AppColors.success,
                      size: 20))),
          const SizedBox(height: 6),
          GestureDetector(
              onTap: () => _copyNumber(context),
              child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius:
                      BorderRadius.circular(10)),
                  child: const Icon(
                      Icons.copy,
                      color: AppColors.textSecondary,
                      size: 18))),
        ]),

        // Admin edit + delete buttons
        if (isAdmin) ...[
          const SizedBox(width: 6),
          Column(children: [
            GestureDetector(
                onTap: () => _edit(context),
                child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius:
                        BorderRadius.circular(10)),
                    child: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.accent,
                        size: 18))),
            const SizedBox(height: 6),
            if (!contact.isDefault)
              GestureDetector(
                  onTap: () => _delete(context),
                  child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius:
                          BorderRadius.circular(10)),
                      child: const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                          size: 18))),
          ]),
        ],
      ]),
    );
  }
}

// ── Category Header ───────────────────────────────────────────────────────────
class _CategoryHeader extends StatelessWidget {
  final String icon, title;
  final Color color;
  const _CategoryHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Text(icon,
          style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5)),
      const SizedBox(width: 8),
      Expanded(child: Divider(
          color: color.withOpacity(0.3))),
    ]),
  );
}