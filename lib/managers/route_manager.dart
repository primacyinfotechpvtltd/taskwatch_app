import 'package:pi_task_watch/exports.dart';

class RouteManager {
  // Initial route set to SigninScreen as per comment
  static const String initialRoute = DashboardScreen.routeName;

  static List<RouteItem> get _routes {
    return [
      RouteItem(
        screen: DashboardScreen(),
        routeName: DashboardScreen.routeName,
        isProtected: true,
      ),
      RouteItem(
        screen: const MaintenanceScreen(),
        routeName: MaintenanceScreen.routeName,
        isProtected: false,
      ),
      RouteItem(
        screen: const MyTaskListScreen(),
        routeName: MyTaskListScreen.routeName,
        isProtected: true,
      ),
      RouteItem(
        screen: const TaskDetailScreen(),
        routeName: TaskDetailScreen.routeName,
        isProtected: true,
      ),
      RouteItem(
        screen: const DiscussScreen(),
        routeName: DiscussScreen.routeName,
        isProtected: true,
      ),
      RouteItem(
        screen: const SigninScreen(),
        routeName: SigninScreen.routeName,
        isProtected: false,
      ),
    ];
  }

  static List<GetPage> get getPages {
    return _routes.map((routeItem) {
      return GetPage(
        name: routeItem.routeName,
        page: () {
          return RouteWrapper(routeItem: routeItem, child: routeItem.screen);
        },
        middlewares: [],
        transition: Transition.fadeIn,
        transitionDuration: const Duration(milliseconds: 300),
      );
    }).toList();
  }
}

class RouteItem {
  final Widget screen;
  final String routeName;
  final bool isProtected;

  RouteItem({
    required this.screen,
    required this.routeName,
    this.isProtected = true,
  });
}

class RouteWrapper extends StatefulWidget {
  final Widget child;
  final RouteItem routeItem;
  const RouteWrapper({super.key, required this.child, required this.routeItem});

  @override
  State<RouteWrapper> createState() => _RouteWrapperState();
}

class _RouteWrapperState extends State<RouteWrapper> {
  @override
  Widget build(BuildContext context) {
    debugPrint(
      'RouteWrapper: Building route for ${widget.routeItem.routeName}',
    );

    return GetX<AuthController>(
      builder: (authController) {
        // Check if app settings are loaded
        // if (authController.settings.value == null) {
        //   debugPrint(
        //     'RouteWrapper: Settings not loaded, showing LoadingScreen',
        //   );
        //   return const LoadingScreen();
        // }

        // Check maintenance mode
        final isInMaintenance =
            authController.settings.value?.maintenance ?? false;
        if (isInMaintenance) {
          return const MaintenanceScreen();
        }

        // Handle authentication - simplified logic
        final isAuthenticated = authController.user.value != null;

        // Redirect to SigninScreen if trying to access protected route without authentication
        if (widget.routeItem.isProtected && !isAuthenticated) {
          return SigninScreen();
        }

        // All checks passed, show requested screen
        return widget.child;
      },
    );
  }
}
