import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/models/emergency_contact_model.dart';
import 'package:guardiancircle/services/emergency_contact_service.dart';
import 'package:guardiancircle/shared/widgets/slide_in_animation.dart';
import 'package:guardiancircle/shared/widgets/empty_state.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});
  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnim;
  late final StaggeredSlideIns _slideIns;
  late final EmergencyContactService _contactService;

  List<EmergencyContactModel> _contacts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contactService = EmergencyContactService.defaultClient();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideIns = StaggeredSlideIns(controller: _slideController, count: 5);
    _fadeController.forward();
    _slideController.forward();
    _loadContacts();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final contacts = await _contactService.fetchContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addContact() async {
    final result = await _showContactDialog(context, null);
    if (result == true && mounted) {
      await _loadContacts();
    }
  }

  Future<void> _editContact(EmergencyContactModel contact) async {
    final result = await _showContactDialog(context, contact);
    if (result == true && mounted) {
      await _loadContacts();
    }
  }

  Future<void> _deleteContact(EmergencyContactModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to remove ${contact.name} from your emergency contacts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _contactService.deleteContact(contact.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${contact.name} removed'),
            backgroundColor: AppTheme.success,
          ),
        );
        await _loadContacts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<bool?> _showContactDialog(
    BuildContext context,
    EmergencyContactModel? existing,
  ) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final relationController =
        TextEditingController(text: existing?.relationship ?? '');
    bool isSaving = false;
    final cs = Theme.of(context).colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(existing == null ? 'Add Contact' : 'Edit Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null
                      ? 'Add a new emergency contact.'
                      : 'Update contact details.',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  enabled: !isSaving,
                  decoration: const InputDecoration(
                    hintText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !isSaving,
                  decoration: const InputDecoration(
                    hintText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relationController,
                  textCapitalization: TextCapitalization.words,
                  enabled: !isSaving,
                  decoration: const InputDecoration(
                    hintText: 'Relationship (e.g. Mom, Friend)',
                    prefixIcon: Icon(Icons.people_outline_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            TextButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      final relation = relationController.text.trim();

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a name'),
                          ),
                        );
                        return;
                      }
                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a phone number'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        if (existing == null) {
                          await _contactService.addContact(
                            name: name,
                            phone: phone,
                            relationship: relation,
                          );
                        } else {
                          await _contactService.updateContact(
                            contactId: existing.id,
                            name: name,
                            phone: phone,
                            relationship: relation,
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                existing == null
                                    ? 'Contact added successfully'
                                    : 'Contact updated successfully',
                              ),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed: $e'),
                              backgroundColor: AppTheme.danger,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ext = theme.extension<AppThemeExtension>();

    return Scaffold(
      floatingActionButton: ScaleOnTap(
        onTap: _addContact,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.tertiary],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ext?.backgroundGradient ??
                (isDark
                    ? [const Color(0xFF0A0F1E), const Color(0xFF060A14)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)]),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: cs.onSurface,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Emergency Contacts',
                                style:
                                    theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_contacts.length} ${_contacts.length == 1 ? 'contact' : 'contacts'}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:
                                      cs.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SlideInAnimation(
                    animation: _slideIns.get(0),
                    child: _buildInfoBanner(theme, cs, isDark),
                  ),
                ),
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_error != null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.danger.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: AppTheme.danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadContacts,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_contacts.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.contacts_outlined,
                      title: 'No emergency contacts',
                      subtitle: 'Add contacts who should be notified in an emergency',
                      action: FilledButton.icon(
                        onPressed: _addContact,
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Add Contact'),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return SlideInAnimation(
                          animation: _slideIns.get(
                            (index + 1).clamp(0, _slideIns.animations.length - 1),
                          ),
                          child: _buildContactCard(
                            _contacts[index],
                            theme,
                            cs,
                            isDark,
                          ),
                        );
                      },
                      childCount: _contacts.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner(ThemeData theme, ColorScheme cs, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.danger.withValues(alpha: isDark ? 0.15 : 0.1),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppTheme.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'These contacts will be notified when you trigger an SOS alert.',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    EmergencyContactModel contact,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
  ) {
    final avatarColors = [
      const Color(0xFFEC4899),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
      const Color(0xFF06B6D4),
    ];
    final color =
        avatarColors[contact.name.hashCode.abs() % avatarColors.length];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.75),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.3),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      contact.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (contact.phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          contact.phone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                      if (contact.relationship.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            contact.relationship,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _editContact(contact),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteContact(contact),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(
                            alpha: isDark ? 0.12 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: AppTheme.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
