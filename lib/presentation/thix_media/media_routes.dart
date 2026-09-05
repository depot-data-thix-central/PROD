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
import 'live/pages/go_live_page.dart';
import 'live/pages/live_viewer_page.dart';
import 'live/pages/live_tab_page.dart';

// ============================================================================
// ROUTES MEDIA — Module Thix Media (Production Enterprise)
// ============================================================================
class MediaRoutes {
  MediaRoutes._();

  // --------------------------------------------------------------------------
  // CONSTANTES DE ROUTES
  // --------------------------------------------------------------------------
  static const String mediaHome = '/thix-media';
  static const String createPost = '/thix-media/create-post';
  static const String userProfile = '/thix-media/profile';
  static const String mediaDetail = '/thix-media/detail';
  static const String videoPlayer = '/thix-media/video';
  static const String admin = '/thix-media/admin';

  // Live
  static const String liveTab = '/thix-media/live';
  static const String goLive = '/thix-media/live/go';
  static const String liveWatch = '/thix-media/live/watch';

  // --------------------------------------------------------------------------
  // HELPERS DE NAVIGATION
  // --------------------------------------------------------------------------

  static void goToUserProfile(BuildContext context, String userId) {
    if (userId.isEmpty) return;
    context.go('\( userProfile/ \){Uri.encodeComponent(userId)}');
  }

  static void goToMediaDetail(
    BuildContext context,
    MediaContent item,
    List<MediaContent> catalog,
  ) {
    context.go(
      '\( mediaDetail/ \){Uri.encodeComponent(item.id)}',
      extra: {'item': item, 'catalog': catalog},
    );
  }

  static void goToVideoPlayer(
    BuildContext context, {
    required String videoUrl,
    String title = '',
  }) {
    if (videoUrl.isEmpty) return;
    final queryParams = {
      'url': videoUrl,
      if (title.isNotEmpty) 'title': title,
    };
    context.go(
      Uri(path: videoPlayer, queryParameters: queryParams).toString(),
    );
  }

  /// Ouvre l'onglet / liste des lives
  static void goToLiveTab(BuildContext context) {
    context.go(liveTab);
  }

  /// Lance le flux Go Live (host)
  static void goToGoLive(BuildContext context) {
    context.push(goLive);
  }

  /// Rejoindre un live (viewer)
  static void goToWatchLive(BuildContext context, String liveId) {
    if (liveId.trim().isEmpty) return;
    context.push('\( liveWatch/ \){Uri.encodeComponent(liveId)}');
  }

  // --------------------------------------------------------------------------
  // LISTE DES ROUTES
  // --------------------------------------------------------------------------
  static List<RouteBase> get routes => [
        // FEED PRINCIPAL
        GoRoute(
          path: mediaHome,
          name: 'thixMediaHome',
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('thix_media_home'),
            child: ThixMediaPage(),
          ),
        ),

        // CRÉATION DE CONTENU
        GoRoute(
          path: createPost,
          name: 'createMediaPost',
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('create_media_post'),
            child: CreatePostPage(),
          ),
        ),

        // PROFIL UTILISATEUR
        GoRoute(
          path: '$userProfile/:userId',
          name: 'mediaUserProfile',
          redirect: (context, state) {
            final userId = state.pathParameters['userId'];
            if (userId == null || userId.trim().isEmpty) {
              return mediaHome;
            }
            return null;
          },
          pageBuilder: (context, state) {
            final userId =
                Uri.decodeComponent(state.pathParameters['userId']!);
            return NoTransitionPage(
              key: ValueKey('media_user_profile_$userId'),
              child: UserProfilePage(userId: userId),
            );
          },
        ),

        // DÉTAIL MÉDIA
        GoRoute(
          path: '$mediaDetail/:mediaId',
          name: 'mediaDetail',
          redirect: (context, state) {
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
            final mediaId =
                Uri.decodeComponent(state.pathParameters['mediaId']!);
            final extra = state.extra as Map;
            final item = extra['item'] as MediaContent;
            final catalog = (extra['catalog'] as List).cast<MediaContent>();

            return NoTransitionPage(
              key: ValueKey('media_detail_$mediaId'),
              child: MediaDetailPage(item: item, catalog: catalog),
            );
          },
        ),

        // LECTEUR VIDÉO
        GoRoute(
          path: videoPlayer,
          name: 'mediaVideoPlayer',
          redirect: (context, state) {
            final videoUrl =
                state.uri.queryParameters['url']?.trim() ?? '';
            if (videoUrl.isEmpty) return mediaHome;
            return null;
          },
          pageBuilder: (context, state) {
            final videoUrl =
                state.uri.queryParameters['url']?.trim() ?? '';
            final title =
                (state.uri.queryParameters['title'] ?? '').trim().isEmpty
                    ? 'Lecture vidéo'
                    : (state.uri.queryParameters['title'] ?? '').trim();

            return NoTransitionPage(
              key: ValueKey('video_player_$videoUrl'),
              child: VideoPlayerPage(title: title, videoUrl: videoUrl),
            );
          },
        ),

        // ═══════════════════════════════════════════════════════════════════
        // LIVE — liste / go live / watch
        // ═══════════════════════════════════════════════════════════════════
        GoRoute(
          path: liveTab,
          name: 'thixMediaLiveTab',
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('thix_media_live_tab'),
            child: LiveTabPage(),
          ),
        ),

        GoRoute(
          path: goLive,
          name: 'thixMediaGoLive',
          redirect: (context, state) {
            // Auth requise pour lancer un live
            final user = Supabase.instance.client.auth.currentUser;
            if (user == null) return mediaHome;
            return null;
          },
          pageBuilder: (context, state) => const NoTransitionPage(
            key: ValueKey('thix_media_go_live'),
            child: GoLivePage(),
          ),
        ),

        GoRoute(
          path: '$liveWatch/:liveId',
          name: 'thixMediaWatchLive',
          redirect: (context, state) {
            final liveId = state.pathParameters['liveId'];
            if (liveId == null || liveId.trim().isEmpty) {
              return liveTab;
            }
            return null;
          },
          pageBuilder: (context, state) {
            final liveId =
                Uri.decodeComponent(state.pathParameters['liveId']!);
            return NoTransitionPage(
              key: ValueKey('thix_media_watch_$liveId'),
              child: LiveViewerPage(liveId: liveId),
            );
          },
        ),

        // ADMIN
        GoRoute(
          path: admin,
          name: 'mediaAdmin',
          redirect: (context, state) async {
            try {
              final supabase = Supabase.instance.client;
              final user = supabase.auth.currentUser;
              if (user == null) return mediaHome;

              final role =
                  user.appMetadata['role'] ?? user.userMetadata?['role'];
              if (role != 'admin' && role != 'superadmin') {
                return mediaHome;
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
// PAGE NO-TRANSITION
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      );
}
