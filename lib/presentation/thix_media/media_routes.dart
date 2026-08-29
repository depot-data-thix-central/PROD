import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/media_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'create_post_page.dart';
import 'user_profile_page.dart';
import 'thix_media_page.dart';
import 'admin/thix_media_admin_page.dart';
import 'widgets/media_detail_page.dart';
import 'video_player_page.dart';

// ============================================================================
// ROUTES MEDIA — Module Thix Media (Production Enterprise)
// ============================================================================
class MediaRoutes {
  MediaRoutes._();

  // --------------------------------------------------------------------------
  // CONSTANTES DE ROUTES (évite les chemins hardcodés)
  // --------------------------------------------------------------------------
  static const String mediaHome = '/thix-media';
  static const String createPost = '/thix-media/create-post';
  static const String userProfile = '/thix-media/profile';
  static const String mediaDetail = '/thix-media/detail';
  static const String videoPlayer = '/thix-media/video';
  static const String admin = '/thix-media/admin';

  // --------------------------------------------------------------------------
  // HELPERS DE NAVIGATION (type-safe)
  // --------------------------------------------------------------------------
  
  /// Navigue vers le profil utilisateur par son ID
  static void goToUserProfile(BuildContext context, String userId) {
    if (userId.isEmpty) return;
    context.go('$userProfile/${Uri.encodeComponent(userId)}');
  }

  /// Navigue vers le détail d'un média avec son catalogue pour suggestions
  static void goToMediaDetail(BuildContext context, MediaContent item, List<MediaContent> catalog) {
    context.go(
      '$mediaDetail/${Uri.encodeComponent(item.id)}',
      extra: {'item': item, 'catalog': catalog},
    );
  }

  /// Navigue vers le lecteur vidéo avec titre et URL
  static void goToVideoPlayer(BuildContext context, {required String videoUrl, String title = ''}) {
    if (videoUrl.isEmpty) return;
    final queryParams = {
      'url': videoUrl,
      if (title.isNotEmpty) 'title': title,
    };
    context.go(Uri(path: videoPlayer, queryParameters: queryParams).toString());
  }

  // --------------------------------------------------------------------------
  // LISTE DES ROUTES
  // --------------------------------------------------------------------------
  static List<RouteBase> get routes => [
    // ═══════════════════════════════════════════════════════════════════════
    // FEED PRINCIPAL
    // ═══════════════════════════════════════════════════════════════════════
    GoRoute(
      path: mediaHome,
      name: 'thixMediaHome',
      pageBuilder: (context, state) => const NoTransitionPage(
        key: ValueKey('thix_media_home'),
        child: ThixMediaPage(),
      ),
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // CRÉATION DE CONTENU
    // ═══════════════════════════════════════════════════════════════════════
    GoRoute(
      path: createPost,
      name: 'createMediaPost',
      pageBuilder: (context, state) => const NoTransitionPage(
        key: ValueKey('create_media_post'),
        child: CreatePostPage(),
      ),
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // PROFIL UTILISATEUR (avec validation)
    // ═══════════════════════════════════════════════════════════════════════
    GoRoute(
      path: '$userProfile/:userId',
      name: 'mediaUserProfile',
      redirect: (context, state) {
        // ✅ Validation : redirige vers le feed si userId manquant ou vide
        final userId = state.pathParameters['userId'];
        if (userId == null || userId.trim().isEmpty) {
          return mediaHome;
        }
        return null;
      },
      pageBuilder: (context, state) {
        final userId = Uri.decodeComponent(state.pathParameters['userId']!);
        return NoTransitionPage(
          key: ValueKey('media_user_profile_$userId'),
          child: UserProfilePage(userId: userId),
        );
      },
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // DÉTAIL MÉDIA (avec épisodes + paywall + suggestions)
    // ═══════════════════════════════════════════════════════════════════════
    GoRoute(
      path: '$mediaDetail/:mediaId',
      name: 'mediaDetail',
      redirect: (context, state) {
        // ✅ Validation : redirige si pas de extra ou mediaId invalide
        final mediaId = state.pathParameters['mediaId'];
        final extra = state.extra;
        
        if (mediaId == null || mediaId.trim().isEmpty) {
          return mediaHome;
        }
        
        if (extra == null || extra is! Map) {
          return mediaHome;
        }
        
        return null;
      },
      pageBuilder: (context, state) {
        final mediaId = Uri.decodeComponent(state.pathParameters['mediaId']!);
        final extra = state.extra as Map;
        final item = extra['item'] as MediaContent;
        final catalog = (extra['catalog'] as List).cast<MediaContent>();
        
        return NoTransitionPage(
          key: ValueKey('media_detail_$mediaId'),
          child: MediaDetailPage(item: item, catalog: catalog),
        );
      },
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // LECTEUR VIDÉO PLEIN ÉCRAN (avec paramètres de requête)
    // ═══════════════════════════════════════════════════════════════════════
    GoRoute(
      path: videoPlayer,
      name: 'mediaVideoPlayer',
      redirect: (context, state) {
        // ✅ Validation : URL requise
        final videoUrl = state.uri.queryParameters['url']?.trim() ?? '';
        if (videoUrl.isEmpty) {
          return mediaHome;
        }
        return null;
      },
      pageBuilder: (context, state) {
        final videoUrl = state.uri.queryParameters['url']?.trim() ?? '';
        final title = (state.uri.queryParameters['title'] ?? '').trim().isEmpty
            ? 'Lecture vidéo'
            : (state.uri.queryParameters['title'] ?? '').trim();
        
        return NoTransitionPage(
          key: ValueKey('video_player_$videoUrl'),
          child: VideoPlayerPage(title: title, videoUrl: videoUrl),
        );
      },
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // ADMIN (réservé aux admins)
    // ═══════════════════════════════════════════════════════════════════════
    GoRoute(
      path: admin,
      name: 'mediaAdmin',
      redirect: (context, state) async {
        // ✅ Vérification d'accès admin (async pour pouvoir requêter)
        // Note : la page elle-même fait aussi la vérification, ceci est un garde supplémentaire
        try {
          final supabase = Supabase.instance.client;
          final user = supabase.auth.currentUser;
          if (user == null) return mediaHome;
          
          final role = user.appMetadata['role'] ?? user.userMetadata?['role'];
          if (role != 'admin' && role != 'superadmin') {
            return mediaHome; // Non-admin → redirigé vers le feed
          }
          return null;
        } catch (_) {
          return mediaHome;
        }
      },
      pageBuilder: (context, state) => const NoTransitionPage(
        key: ValueKey('media_admin'),
        child: ThixMediaAdminPage(),
      ),
    ),
  ];
}

// ============================================================================
// PAGE NO-TRANSITION (performance)
// ============================================================================
class NoTransitionPage<T> extends Page<T> {
  final Widget child;
  
  const NoTransitionPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) => PageRouteBuilder<T>(
    settings: this,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}
