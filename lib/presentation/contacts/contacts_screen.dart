import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/contact_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/contact_repository.dart';
import '../../core/ads/banner_ad_widget.dart';
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
      bottomNavigationBar: const BannerAdWidget(),
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
    // No dialer on web — copy instead
    if (kIsWeb) {
      _copyNumber(ctx);
      return;
    }
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
    final catBg = switch (contact.category) {
      ContactCategory.emergency =>
      AppColors.dangerLight,
      ContactCategory.repairs =>
      AppColors.accentLight,
      ContactCategory.nearby =>
      AppColors.successLight,
    };

    // Admin gets a three-dot menu for low-priority actions
    final showMenu = isAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.border)),
      child: Row(children: [

        // Compact category icon
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: catBg,
              borderRadius:
              BorderRadius.circular(10)),
          child: Center(child: Text(
              contact.categoryIcon,
              style: const TextStyle(
                  fontSize: 20))),
        ),
        const SizedBox(width: 12),

        // Name + phone (category is shown by the
        // section header, so no per-tile chip)
        Expanded(child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Flexible(
                child: Text(contact.name,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color:
                        AppColors.textPrimary)),
              ),
              if (contact.isDefault) ...[
                const SizedBox(width: 6),
                const Icon(Icons.lock_outline,
                    size: 11,
                    color: AppColors.textMuted),
              ],
            ]),
            const SizedBox(height: 2),
            Text(contact.phone,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace')),
          ],
        )),

        // ── Inline actions (same row) ──────────
        // Call — hidden on web (no dialer)
        if (!kIsWeb)
          _ActionIcon(
            icon:  Icons.call,
            color: AppColors.success,
            bg:    AppColors.successLight,
            onTap: () => _call(context),
          ),
        if (!kIsWeb) const SizedBox(width: 6),

        // Copy — always available
        _ActionIcon(
          icon:  Icons.copy,
          color: AppColors.textSecondary,
          bg:    AppColors.bgLight,
          onTap: () => _copyNumber(context),
        ),

        // Three-dot menu for admin (edit / delete)
        if (showMenu)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                size: 20,
                color: AppColors.textMuted),
            padding: EdgeInsets.zero,
            onSelected: (v) {
              if (v == 'edit') _edit(context);
              if (v == 'delete') _delete(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined,
                      size: 18,
                      color: AppColors.accent),
                  SizedBox(width: 10),
                  Text('Edit'),
                ]),
              ),
              if (!contact.isDefault)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18,
                        color: AppColors.danger),
                    SizedBox(width: 10),
                    Text('Delete',
                        style: TextStyle(
                            color:
                            AppColors.danger)),
                  ]),
                ),
            ],
          ),
      ]),
    );
  }
}

// ── Small inline action icon button ───────────────────────────────────────────
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final VoidCallback onTap;
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: bg,
              borderRadius:
              BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 18),
        ),
      );
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