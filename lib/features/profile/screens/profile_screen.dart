import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../main.dart';

// ---------------------------------------------------------------------------
// Profile Screen
// ---------------------------------------------------------------------------
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Profil' : 'Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          // Avatar with photo picker
          Center(
            child: GestureDetector(
              onTap: () => _pickPhoto(context, ref),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: user?['avatar_url'] != null
                        ? ClipOval(
                            child: Image.network(
                              user!['avatar_url'],
                              width: 112,
                              height: 112,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person, size: 56, color: AppColors.primary,
                              ),
                            ),
                          )
                        : const Icon(Icons.person, size: 56, color: AppColors.primary),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user?['full_name'] ?? 'User',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              user?['email'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (user?['role'] != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Chip(
                label: Text(
                  (user!['role'] as String).replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(height: 1),

          // Edit Profile
          _SettingsTile(
            icon: Icons.edit_outlined,
            title: isTr ? 'Profili Düzenle' : 'Edit Profile',
            onTap: () => _showEditProfileSheet(context, ref, user),
          ),
          // Role
          _RoleTile(isTr: isTr, currentRole: user?['role'] as String?),
          // Notification Settings
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: isTr ? 'Bildirim Ayarları' : 'Notification Settings',
            onTap: () => _showNotificationSettings(context, ref, isTr),
          ),
          // Theme
          _ThemeTile(isTr: isTr),
          // Language
          _SettingsTile(
            icon: Icons.language_outlined,
            title: isTr ? 'Dil' : 'Language',
            trailing: Text(
              isTr ? 'Türkçe' : 'English',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            onTap: () => _showLanguagePicker(context, ref, isTr),
          ),
          const Divider(height: 1),
          // Privacy & Security
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: isTr ? 'Gizlilik ve Güvenlik' : 'Privacy & Security',
            onTap: () => _showPrivacySecurity(context, isTr),
          ),
          // About
          _SettingsTile(
            icon: Icons.info_outline,
            title: isTr ? 'Hakkında' : 'About',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Apartment Manager',
                applicationVersion: '1.0.0',
                applicationLegalese: '2024 Apartment Management System',
              );
            },
          ),
          const Divider(height: 1),
          // Logout
          _SettingsTile(
            icon: Icons.logout,
            title: isTr ? 'Çıkış Yap' : 'Logout',
            iconColor: AppColors.error,
            titleColor: AppColors.error,
            onTap: () => _showLogoutDialog(context, ref, isTr),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---- Photo Picker ----
  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, maxWidth: 512, imageQuality: 80);
      if (image == null) return;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo selected. Upload will be available when MinIO is configured.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  // ---- Edit Profile ----
  void _showEditProfileSheet(BuildContext context, WidgetRef ref, Map<String, dynamic>? user) {
    final nameController = TextEditingController(text: user?['full_name'] ?? '');
    final phoneController = TextEditingController(text: user?['phone'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit Profile', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  final api = ref.read(apiClientProvider);
                  await api.updateProfile({
                    'full_name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  // Refresh profile from server
                  try {
                    final profileResp = await api.getProfile();
                    if (profileResp.data['success'] == true) {
                      final userData = profileResp.data['data'] as Map<String, dynamic>;
                      ref.read(authStateProvider.notifier).updateUser(userData);
                    }
                  } catch (_) {}
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Notification Settings ----
  void _showNotificationSettings(BuildContext context, WidgetRef ref, bool isTr) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NotificationSettingsSheet(isTr: isTr),
    );
  }

  // ---- Language Picker ----
  void _showLanguagePicker(BuildContext context, WidgetRef ref, bool isTr) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(isTr ? 'Dil Seçin' : 'Select Language',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: isTr ? 'tr' : 'en',
              activeColor: AppColors.primary,
              onChanged: (v) {
                ref.read(localeProvider.notifier).state = const Locale('en');
                Hive.box('settings').put('locale', 'en');
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('Türkçe'),
              value: 'tr',
              groupValue: isTr ? 'tr' : 'en',
              activeColor: AppColors.primary,
              onChanged: (v) {
                ref.read(localeProvider.notifier).state = const Locale('tr');
                Hive.box('settings').put('locale', 'tr');
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---- Privacy & Security ----
  void _showPrivacySecurity(BuildContext context, bool isTr) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PrivacySecurityScreen(isTr: isTr),
    ));
  }

  // ---- Logout ----
  void _showLogoutDialog(BuildContext context, WidgetRef ref, bool isTr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTr ? 'Çıkış Yap' : 'Logout'),
        content: Text(isTr ? 'Çıkış yapmak istediğinize emin misiniz?' : 'Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isTr ? 'İptal' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authStateProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(isTr ? 'Çıkış Yap' : 'Logout'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification Settings Sheet
// ---------------------------------------------------------------------------
class _NotificationSettingsSheet extends ConsumerStatefulWidget {
  final bool isTr;
  const _NotificationSettingsSheet({required this.isTr});

  @override
  ConsumerState<_NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends ConsumerState<_NotificationSettingsSheet> {
  bool _pushPayment = true;
  bool _pushMaintenance = true;
  bool _pushAnnouncement = true;
  bool _pushForum = true;
  bool _emailPayment = false;
  bool _emailMaintenance = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.getNotificationPreferences();
      if (response.data['success'] == true) {
        final prefs = response.data['data'] as List? ?? [];
        for (final p in prefs) {
          final cat = p['category'] as String?;
          final push = p['push_enabled'] as bool? ?? true;
          final email = p['email_enabled'] as bool? ?? false;
          setState(() {
            switch (cat) {
              case 'payment':
                _pushPayment = push;
                _emailPayment = email;
              case 'maintenance':
                _pushMaintenance = push;
                _emailMaintenance = email;
              case 'announcement':
                _pushAnnouncement = push;
              case 'forum':
                _pushForum = push;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _updatePref(String category, {bool? push, bool? email}) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.updateNotificationPreferences({
        'category': category,
        if (push != null) 'push_enabled': push,
        if (email != null) 'email_enabled': email,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isTr = widget.isTr;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTr ? 'Bildirim Ayarları' : 'Notification Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(isTr ? 'Ödeme Bildirimleri' : 'Payment Notifications'),
              subtitle: Text(isTr ? 'Push bildirim' : 'Push notification'),
              value: _pushPayment,
              activeThumbColor: AppColors.primary,
              onChanged: (v) { setState(() => _pushPayment = v); _updatePref('payment', push: v); },
            ),
            SwitchListTile(
              title: Text(isTr ? 'Bakım Bildirimleri' : 'Maintenance Notifications'),
              value: _pushMaintenance,
              activeThumbColor: AppColors.primary,
              onChanged: (v) { setState(() => _pushMaintenance = v); _updatePref('maintenance', push: v); },
            ),
            SwitchListTile(
              title: Text(isTr ? 'Duyurular' : 'Announcements'),
              value: _pushAnnouncement,
              activeThumbColor: AppColors.primary,
              onChanged: (v) { setState(() => _pushAnnouncement = v); _updatePref('announcement', push: v); },
            ),
            SwitchListTile(
              title: Text(isTr ? 'Forum Bildirimleri' : 'Forum Notifications'),
              value: _pushForum,
              activeThumbColor: AppColors.primary,
              onChanged: (v) { setState(() => _pushForum = v); _updatePref('forum', push: v); },
            ),
            const Divider(),
            SwitchListTile(
              title: Text(isTr ? 'Ödeme E-posta' : 'Payment Email'),
              value: _emailPayment,
              activeThumbColor: AppColors.primary,
              onChanged: (v) { setState(() => _emailPayment = v); _updatePref('payment', email: v); },
            ),
            SwitchListTile(
              title: Text(isTr ? 'Bakım E-posta' : 'Maintenance Email'),
              value: _emailMaintenance,
              activeThumbColor: AppColors.primary,
              onChanged: (v) { setState(() => _emailMaintenance = v); _updatePref('maintenance', email: v); },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy & Security Screen
// ---------------------------------------------------------------------------
class _PrivacySecurityScreen extends ConsumerWidget {
  final bool isTr;
  const _PrivacySecurityScreen({required this.isTr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Gizlilik ve Güvenlik' : 'Privacy & Security'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _SectionHeader(title: isTr ? 'Hesap Güvenliği' : 'Account Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(isTr ? 'Şifre Değiştir' : 'Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: Text(isTr ? 'Aktif Oturumlar' : 'Active Sessions'),
            subtitle: Text(isTr ? 'Tüm cihazlardaki oturumları yönet' : 'Manage sessions on all devices'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isTr ? 'Yakında' : 'Coming soon')),
              );
            },
          ),
          const Divider(),
          _SectionHeader(title: isTr ? 'Gizlilik' : 'Privacy'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: Text(isTr ? 'Profil Görünürlüğü' : 'Profile Visibility'),
            subtitle: Text(isTr ? 'Diğer sakinler profilinizi görebilir' : 'Other residents can see your profile'),
            value: true,
            activeThumbColor: AppColors.primary,
            onChanged: (v) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.phone_outlined),
            title: Text(isTr ? 'Telefon Numarasını Göster' : 'Show Phone Number'),
            subtitle: Text(isTr ? 'Telefon numaranız diğerlerine görünür' : 'Your phone is visible to others'),
            value: false,
            activeThumbColor: AppColors.primary,
            onChanged: (v) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.location_on_outlined),
            title: Text(isTr ? 'Konum Paylaşımı' : 'Location Sharing'),
            subtitle: Text(isTr ? 'Topluluk gönderilerinde konum' : 'Location in community posts'),
            value: true,
            activeThumbColor: AppColors.primary,
            onChanged: (v) {},
          ),
          const Divider(),
          _SectionHeader(title: isTr ? 'Veri' : 'Data'),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(isTr ? 'Verilerimi İndir' : 'Download My Data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isTr ? 'Verileriniz hazırlanıyor...' : 'Preparing your data...')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
            title: Text(isTr ? 'Hesabı Sil' : 'Delete Account',
                style: const TextStyle(color: AppColors.error)),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(isTr ? 'Hesabı Sil' : 'Delete Account'),
                  content: Text(isTr
                      ? 'Bu işlem geri alınamaz. Tüm verileriniz silinecektir.'
                      : 'This action cannot be undone. All your data will be permanently deleted.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(isTr ? 'İptal' : 'Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: Text(isTr ? 'Sil' : 'Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentPw = TextEditingController();
    final newPw = TextEditingController();
    final confirmPw = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTr ? 'Şifre Değiştir' : 'Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPw,
              obscureText: true,
              decoration: InputDecoration(labelText: isTr ? 'Mevcut Şifre' : 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPw,
              obscureText: true,
              decoration: InputDecoration(labelText: isTr ? 'Yeni Şifre' : 'New Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPw,
              obscureText: true,
              decoration: InputDecoration(labelText: isTr ? 'Şifre Tekrar' : 'Confirm Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isTr ? 'İptal' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPw.text != confirmPw.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(isTr ? 'Şifreler eşleşmiyor' : 'Passwords do not match')),
                );
                return;
              }
              if (currentPw.text.isEmpty || newPw.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(isTr ? 'Tüm alanları doldurun' : 'Fill in all fields')),
                );
                return;
              }
              try {
                final api = ref.read(apiClientProvider);
                await api.changePassword({
                  'current_password': currentPw.text,
                  'new_password': newPw.text,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isTr ? 'Şifre güncellendi' : 'Password updated')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(isTr ? 'Hata: $e' : 'Error: $e')),
                  );
                }
              }
            },
            child: Text(isTr ? 'Kaydet' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.titleColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(title, style: TextStyle(color: titleColor)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}

class _RoleTile extends ConsumerWidget {
  final bool isTr;
  final String? currentRole;
  const _RoleTile({required this.isTr, this.currentRole});

  String _roleLabel(String role, bool isTr) {
    switch (role) {
      case 'building_manager':
        return isTr ? 'Bina Yöneticisi' : 'Building Manager';
      case 'resident':
        return isTr ? 'Sakin' : 'Resident';
      case 'security':
        return isTr ? 'Güvenlik' : 'Security';
      case 'super_admin':
        return isTr ? 'Süper Admin' : 'Super Admin';
      default:
        return role.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = currentRole ?? 'resident';

    return ListTile(
      leading: const Icon(Icons.badge_outlined, color: AppColors.textSecondary),
      title: Text(isTr ? 'Rol' : 'Role'),
      trailing: role == 'super_admin'
          ? Text(
              _roleLabel(role, isTr),
              style: const TextStyle(color: AppColors.textSecondary),
            )
          : DropdownButton<String>(
              value: role,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: 'resident',
                  child: Text(_roleLabel('resident', isTr)),
                ),
                DropdownMenuItem(
                  value: 'building_manager',
                  child: Text(_roleLabel('building_manager', isTr)),
                ),
                DropdownMenuItem(
                  value: 'security',
                  child: Text(_roleLabel('security', isTr)),
                ),
              ],
              onChanged: (newRole) async {
                if (newRole == null || newRole == role) return;
                try {
                  final api = ref.read(apiClientProvider);
                  await api.updateProfile({'role': newRole});
                  // Refresh profile from server
                  final profileResp = await api.getProfile();
                  if (profileResp.data['success'] == true) {
                    final userData =
                        profileResp.data['data'] as Map<String, dynamic>;
                    ref.read(authStateProvider.notifier).updateUser(userData);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isTr ? 'Rol güncellendi' : 'Role updated'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  final bool isTr;
  const _ThemeTile({required this.isTr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return ListTile(
      leading: const Icon(Icons.palette_outlined, color: AppColors.textSecondary),
      title: Text(isTr ? 'Tema' : 'Theme'),
      trailing: DropdownButton<ThemeMode>(
        value: themeMode,
        underline: const SizedBox(),
        items: [
          DropdownMenuItem(value: ThemeMode.system, child: Text(isTr ? 'Sistem' : 'System')),
          DropdownMenuItem(value: ThemeMode.light, child: Text(isTr ? 'Açık' : 'Light')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text(isTr ? 'Koyu' : 'Dark')),
        ],
        onChanged: (mode) {
          if (mode != null) {
            ref.read(themeModeProvider.notifier).state = mode;
            Hive.box('settings').put('themeMode', mode.name);
          }
        },
      ),
    );
  }
}
