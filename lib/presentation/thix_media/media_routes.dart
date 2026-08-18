import 'package:go_router/go_router.dart';
import 'create_post_page.dart';
import 'user_profile_page.dart';
import 'thix_media_page.dart';

class MediaRoutes {
  static const String mediaHome = '/media';
  static const String createPost = '/create-post';
  static const String userProfile = '/profile';

  static List<RouteBase> get routes => [
        GoRoute(
          path: mediaHome,
          builder: (context, state) => const ThixMediaPage(),
        ),
        GoRoute(
          path: createPost,
          builder: (context, state) => const CreatePostPage(),
        ),
        GoRoute(
          path: '$userProfile/:userId',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return UserProfilePage(userId: userId);
          },
        ),
      ];
}
