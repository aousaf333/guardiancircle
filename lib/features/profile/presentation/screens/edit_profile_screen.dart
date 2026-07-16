import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:guardiancircle/app/profile_state.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/models/profile_model.dart';
import 'package:guardiancircle/services/family_service.dart';
import 'package:guardiancircle/shared/widgets/glass_card.dart';
import 'package:guardiancircle/shared/widgets/slide_in_animation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentPhone;
  final String currentEmail;
  final String currentEmergency;

  const EditProfileScreen({
    super.key,
    this.currentName = '',
    this.currentPhone = '',
    this.currentEmail = '',
    this.currentEmergency = '',
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final FamilyService _familyService;
  bool _isLoading = true;
  bool _isSaving = false;
  ProfileModel? _profile;
  String? _photoUrl;
  Uint8List? _pickedImageBytes;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _familyService = FamilyService.defaultClient();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  String get _avatarInitial {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) return name.characters.first.toUpperCase();
    return 'G';
  }

  Future<void> _loadProfile() async {
    final userId = _userId;
    if (userId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final profile = await _familyService.fetchProfile(userId);
      if (mounted && profile != null) {
        setState(() {
          _profile = profile;
          _nameController.text = profile.name ?? '';
          _phoneController.text = profile.phone ?? '';
          _photoUrl = profile.photoUrl;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (picked != null && mounted) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _photoUrl = null;
      });
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_pickedImageBytes == null) return _photoUrl;
    final userId = _userId;
    if (userId.isEmpty) return null;

    try {
      final url = await _familyService.uploadAvatar(
        userId: userId,
        bytes: _pickedImageBytes!,
      );
      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final userId = _userId;
    if (userId.isEmpty) return;

    setState(() => _isSaving = true);

    final uploadedUrl = await _uploadAvatar();
    if (uploadedUrl == null && _pickedImageBytes != null) {
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    final finalPhotoUrl = _pickedImageBytes != null ? uploadedUrl : _photoUrl;

    try {
      await _familyService.updateProfile(
        userId: userId,
        name: name,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        photoUrl: finalPhotoUrl,
      );

      final refreshed = await _familyService.fetchProfile(userId);
      if (refreshed != null) updateProfile(refreshed);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ext = theme.extension<AppThemeExtension>();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: cs.primary),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        FadeIn(
                          duration: const Duration(milliseconds: 400),
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
                              Text(
                                'Edit Profile',
                                style:
                                    theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        FadeIn(
                          delay: const Duration(milliseconds: 100),
                          duration: const Duration(milliseconds: 500),
                          beginScale: 0.85,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              _pickedImageBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(50),
                                      child: Image.memory(
                                        _pickedImageBytes!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : _photoUrl != null &&
                                          _photoUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(50),
                                          child: Image.network(
                                            _photoUrl!,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                _buildDefaultAvatar(cs),
                                          ),
                                        )
                                  : _buildDefaultAvatar(cs),
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cs.surface,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        FadeIn(
                          delay: const Duration(milliseconds: 200),
                          duration: const Duration(milliseconds: 500),
                          beginOffset: const Offset(0, 0.08),
                          child: GlassCard(
                            child: Column(
                              children: [
                                _buildField(
                                  controller: _nameController,
                                  icon: Icons.person_outline_rounded,
                                  label: 'Full Name',
                                  theme: theme,
                                  cs: cs,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Name is required';
                                    }
                                    return null;
                                  },
                                ),
                                Divider(
                                    color: cs.outline.withValues(alpha: 0.2)),
                                _buildField(
                                  controller: _phoneController,
                                  icon: Icons.phone_outlined,
                                  label: 'Phone Number',
                                  theme: theme,
                                  cs: cs,
                                  keyboardType: TextInputType.phone,
                                ),
                                Divider(
                                    color: cs.outline.withValues(alpha: 0.2)),
                                _InfoRow(
                                  icon: Icons.email_outlined,
                                  label: 'Email',
                                  value: _profile?.email ??
                                      _userEmail,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        FadeIn(
                          delay: const Duration(milliseconds: 320),
                          duration: const Duration(milliseconds: 500),
                          child: GestureDetector(
                            onTap: _isSaving ? null : _save,
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isSaving
                                      ? [
                                          cs.onSurface.withValues(alpha: 0.2),
                                          cs.onSurface.withValues(alpha: 0.15),
                                        ]
                                      : [
                                          cs.primary,
                                          cs.primary.withValues(alpha: 0.8),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: _isSaving
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: cs.primary
                                              .withValues(alpha: 0.3),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(ColorScheme cs) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary, cs.tertiary],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Text(
          _avatarInitial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 40,
          ),
        ),
      ),
    );
  }

  String get _userEmail =>
      _profile?.email ?? Supabase.instance.client.auth.currentUser?.email ?? '';

  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required ThemeData theme,
    required ColorScheme cs,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.35),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.only(top: 2),
                  ),
                  validator: validator,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.35),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
