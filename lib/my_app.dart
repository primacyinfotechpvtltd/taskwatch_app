import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/widgets/app_wrapper.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      getPages: RouteManager.getPages,
      initialRoute: RouteManager.initialRoute,
      theme: AppTheme.compactTheme(context),
      builder: (context, child) {
        return AppWrapper(child: child ?? Container());
      },
    );
  }
}
