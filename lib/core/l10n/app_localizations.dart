import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

// ---------------------------------------------------------------------------
// Locale provider – shared across the entire app
// ---------------------------------------------------------------------------
final localeProvider = StateProvider<Locale>((ref) {
  final box = Hive.box('settings');
  final code = box.get('locale', defaultValue: 'en');
  return Locale(code);
});

// ---------------------------------------------------------------------------
// Localized strings helper
// ---------------------------------------------------------------------------
class L {
  static String tr(WidgetRef ref, String key) {
    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';
    return (isTr ? _tr : _en)[key] ?? key;
  }

  static String trStatic(Locale locale, String key) {
    final isTr = locale.languageCode == 'tr';
    return (isTr ? _tr : _en)[key] ?? key;
  }

  // English
  static const Map<String, String> _en = {
    // Navigation
    'nav_home': 'Home',
    'nav_building': 'Building',
    'nav_alerts': 'Alerts',
    'nav_forum': 'Forum',
    'nav_community': 'Community',

    // Home
    'good_morning': 'Good Morning',
    'good_afternoon': 'Good Afternoon',
    'good_evening': 'Good Evening',
    'apartment_manager': 'Apartment Manager',
    'settings': 'Settings',
    'total_units': 'Total Units',
    'pending_dues': 'Pending Dues',
    'open_requests': 'Open Requests',
    'quick_actions': 'Quick Actions',
    'recent_activity': 'Recent Activity',
    'no_recent_activity': 'No recent activity',
    'activity_description': 'Activity from your building community will appear here.',
    'pay_dues': 'Pay Dues',
    'maintenance': 'Maintenance',
    'write_post': 'Write Post',
    'manage_community': 'Manage your apartment community',
    'welcome_back': 'Welcome Back',
    'something_wrong': 'Something went wrong',
    'retry': 'Retry',

    // Building
    'building': 'Building',
    'units': 'Units',
    'finances': 'Finances',
    'vendors': 'Vendors',
    'add_building': 'Add Building',
    'add_unit': 'Add Unit',
    'add_due': 'Add Due',
    'new_request': 'New Request',
    'add_vendor': 'Add Vendor',
    'no_building_selected': 'No building selected',
    'no_building_description': 'Create a new building or select an existing one to manage units, finances, and more.',
    'no_units_yet': 'No units yet',
    'add_units_description': 'Add units to your building to get started.',
    'no_dues_plans': 'No dues plans',
    'create_dues_description': 'Create a dues plan to start collecting.',
    'no_maintenance_requests': 'No maintenance requests',
    'maintenance_clear': 'All clear! Create a request if something needs fixing.',
    'no_vendors_yet': 'No vendors yet',
    'add_vendors_description': 'Add vendors to manage your building services.',
    'building_name': 'Building Name',
    'address': 'Address',
    'city': 'City',
    'total_units_field': 'Total Units',
    'create_building': 'Create Building',
    'unit_number': 'Unit Number',
    'floor': 'Floor',
    'block': 'Block (optional)',
    'area_sqm': 'Area (sqm) (optional)',
    'save': 'Save',
    'title': 'Title',
    'amount': 'Amount',
    'period_month': 'Period Month',
    'period_year': 'Period Year',
    'due_date': 'Due Date',
    'create_plan': 'Create Plan',
    'description': 'Description',
    'priority': 'Priority',
    'submit_request': 'Submit Request',
    'vendor_name': 'Vendor Name',
    'category': 'Category',
    'phone': 'Phone',
    'email': 'Email',
    'total_collected': 'Total Collected',
    'total_pending': 'Total Pending',
    'overdue': 'Overdue',
    'dues_plans': 'Dues Plans',
    'paid': 'paid',

    // Invitations
    'invite_user': 'Invite User',
    'invitations': 'Invitations',
    'invite_email': 'Email address',
    'invite_role': 'Role',
    'send_invitation': 'Send Invitation',
    'invitation_sent': 'Invitation sent successfully',
    'resident': 'Resident',
    'building_manager': 'Building Manager',
    'security': 'Security',
    'pending_label': 'Pending',
    'accepted': 'Accepted',
    'expired': 'Expired',

    // Notifications
    'notifications': 'Notifications',
    'no_notifications': 'No notifications',
    'notification_empty_desc': 'You\'re all caught up! New alerts will appear here.',
    'mark_all_read': 'Mark all as read',
    'just_now': 'Just now',

    // Forum
    'forum': 'Forum',
    'all': 'All',
    'no_posts_yet': 'No posts yet',
    'forum_empty_desc': 'Be the first to start a discussion in your building forum.',
    'create_post': 'Create Post',
    'post_title': 'Title',
    'post_body': 'Body',
    'post': 'Post',

    // Timeline / Community
    'community': 'Community',
    'whats_happening': "What's happening in your community?",
    'no_posts': 'No posts yet',
    'community_empty_desc': 'Share updates with your community.',
    'like': 'Like',
    'comment': 'Comment',
    'share': 'Share',
    'write_comment': 'Write a comment...',

    // Profile
    'profile': 'Profile',
    'edit_profile': 'Edit Profile',
    'notification_settings': 'Notification Settings',
    'language': 'Language',
    'privacy_security': 'Privacy & Security',
    'theme': 'Theme',
    'logout': 'Logout',
    'logout_confirm': 'Are you sure you want to logout?',
    'cancel': 'Cancel',
    'full_name': 'Full Name',
    'update': 'Update',
    'change_password': 'Change Password',
    'current_password': 'Current Password',
    'new_password': 'New Password',
    'confirm_password': 'Confirm Password',
    'push_notifications': 'Push Notifications',
    'email_notifications': 'Email Notifications',
    'system_default': 'System Default',
    'light': 'Light',
    'dark': 'Dark',
    'profile_visibility': 'Profile Visibility',
    'show_phone': 'Show Phone Number',
    'location_sharing': 'Location Sharing',
    'download_data': 'Download My Data',
    'delete_account': 'Delete Account',
  };

  // Turkish
  static const Map<String, String> _tr = {
    // Navigation
    'nav_home': 'Ana Sayfa',
    'nav_building': 'Bina',
    'nav_alerts': 'Bildirimler',
    'nav_forum': 'Forum',
    'nav_community': 'Topluluk',

    // Home
    'good_morning': 'Günaydın',
    'good_afternoon': 'İyi Günler',
    'good_evening': 'İyi Akşamlar',
    'apartment_manager': 'Apartman Yöneticisi',
    'settings': 'Ayarlar',
    'total_units': 'Toplam Daire',
    'pending_dues': 'Bekleyen Aidat',
    'open_requests': 'Açık Talepler',
    'quick_actions': 'Hızlı İşlemler',
    'recent_activity': 'Son Aktivite',
    'no_recent_activity': 'Henüz aktivite yok',
    'activity_description': 'Bina topluluğunuzdaki aktiviteler burada görünecek.',
    'pay_dues': 'Aidat Öde',
    'maintenance': 'Bakım',
    'write_post': 'Yazı Yaz',
    'manage_community': 'Apartman topluluğunuzu yönetin',
    'welcome_back': 'Tekrar Hoş Geldiniz',
    'something_wrong': 'Bir şeyler yanlış gitti',
    'retry': 'Tekrar Dene',

    // Building
    'building': 'Bina',
    'units': 'Daireler',
    'finances': 'Finans',
    'vendors': 'Tedarikçiler',
    'add_building': 'Bina Ekle',
    'add_unit': 'Daire Ekle',
    'add_due': 'Aidat Ekle',
    'new_request': 'Yeni Talep',
    'add_vendor': 'Tedarikçi Ekle',
    'no_building_selected': 'Bina seçilmedi',
    'no_building_description': 'Daire, finans ve diğer işlemleri yönetmek için yeni bir bina oluşturun veya mevcut birini seçin.',
    'no_units_yet': 'Henüz daire yok',
    'add_units_description': 'Başlamak için binanıza daire ekleyin.',
    'no_dues_plans': 'Henüz aidat planı yok',
    'create_dues_description': 'Tahsilata başlamak için bir aidat planı oluşturun.',
    'no_maintenance_requests': 'Bakım talebi yok',
    'maintenance_clear': 'Her şey yolunda! Tamir gereken bir şey varsa talep oluşturun.',
    'no_vendors_yet': 'Henüz tedarikçi yok',
    'add_vendors_description': 'Bina hizmetlerinizi yönetmek için tedarikçi ekleyin.',
    'building_name': 'Bina Adı',
    'address': 'Adres',
    'city': 'Şehir',
    'total_units_field': 'Toplam Daire',
    'create_building': 'Bina Oluştur',
    'unit_number': 'Daire Numarası',
    'floor': 'Kat',
    'block': 'Blok (opsiyonel)',
    'area_sqm': 'Alan (m²) (opsiyonel)',
    'save': 'Kaydet',
    'title': 'Başlık',
    'amount': 'Tutar',
    'period_month': 'Dönem Ayı',
    'period_year': 'Dönem Yılı',
    'due_date': 'Son Ödeme Tarihi',
    'create_plan': 'Plan Oluştur',
    'description': 'Açıklama',
    'priority': 'Öncelik',
    'submit_request': 'Talebi Gönder',
    'vendor_name': 'Tedarikçi Adı',
    'category': 'Kategori',
    'phone': 'Telefon',
    'email': 'E-posta',
    'total_collected': 'Toplam Tahsilat',
    'total_pending': 'Bekleyen Toplam',
    'overdue': 'Gecikmiş',
    'dues_plans': 'Aidat Planları',
    'paid': 'ödendi',

    // Invitations
    'invite_user': 'Kullanıcı Davet Et',
    'invitations': 'Davetler',
    'invite_email': 'E-posta adresi',
    'invite_role': 'Rol',
    'send_invitation': 'Davet Gönder',
    'invitation_sent': 'Davet başarıyla gönderildi',
    'resident': 'Sakin',
    'building_manager': 'Bina Yöneticisi',
    'security': 'Güvenlik',
    'pending_label': 'Beklemede',
    'accepted': 'Kabul Edildi',
    'expired': 'Süresi Doldu',

    // Notifications
    'notifications': 'Bildirimler',
    'no_notifications': 'Bildirim yok',
    'notification_empty_desc': 'Her şey güncel! Yeni bildirimler burada görünecek.',
    'mark_all_read': 'Tümünü okundu işaretle',
    'just_now': 'Az önce',

    // Forum
    'forum': 'Forum',
    'all': 'Tümü',
    'no_posts_yet': 'Henüz gönderi yok',
    'forum_empty_desc': 'Bina forumunuzda ilk tartışmayı başlatan siz olun.',
    'create_post': 'Gönderi Oluştur',
    'post_title': 'Başlık',
    'post_body': 'İçerik',
    'post': 'Gönder',

    // Timeline / Community
    'community': 'Topluluk',
    'whats_happening': 'Topluluğunuzda neler oluyor?',
    'no_posts': 'Henüz gönderi yok',
    'community_empty_desc': 'Topluluğunuzla güncellemeler paylaşın.',
    'like': 'Beğen',
    'comment': 'Yorum',
    'share': 'Paylaş',
    'write_comment': 'Bir yorum yazın...',

    // Profile
    'profile': 'Profil',
    'edit_profile': 'Profili Düzenle',
    'notification_settings': 'Bildirim Ayarları',
    'language': 'Dil',
    'privacy_security': 'Gizlilik ve Güvenlik',
    'theme': 'Tema',
    'logout': 'Çıkış Yap',
    'logout_confirm': 'Çıkış yapmak istediğinize emin misiniz?',
    'cancel': 'İptal',
    'full_name': 'Ad Soyad',
    'update': 'Güncelle',
    'change_password': 'Şifre Değiştir',
    'current_password': 'Mevcut Şifre',
    'new_password': 'Yeni Şifre',
    'confirm_password': 'Şifreyi Onayla',
    'push_notifications': 'Anlık Bildirimler',
    'email_notifications': 'E-posta Bildirimleri',
    'system_default': 'Sistem Varsayılanı',
    'light': 'Açık',
    'dark': 'Koyu',
    'profile_visibility': 'Profil Görünürlüğü',
    'show_phone': 'Telefon Numarasını Göster',
    'location_sharing': 'Konum Paylaşımı',
    'download_data': 'Verilerimi İndir',
    'delete_account': 'Hesabı Sil',
  };
}
