import 'admin_service.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'catalog_service.dart';
export 'crop_course_service.dart' show cropCourseService;
export 'admin_service.dart' show adminService;
import 'chat_limits_store.dart';
import 'crop_track_service.dart';
import 'language_service.dart';
import 'profile_service.dart';
import 'support_service.dart';
import 'theme_service.dart';

final catalogService = CatalogService();
final chatLimitsService = ChatLimitsStore();
final languageService = LanguageService();
final profileService = ProfileService(catalogService);
final themeService = ThemeService();
final authService = AuthService();
final supportService = SupportService();
final cropTrackService = CropTrackService();
final apiClient = ApiClient.instance;
// adminService exported from admin_service.dart
// cropCourseService exported from crop_course_service.dart
