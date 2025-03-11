import 'dart:io';

import 'package:api/api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:scaled_app/scaled_app.dart';

import 'const.dart';
import 'pages_tv/home.dart';
import 'pages_tv/settings/settings_update.dart';
import 'providers/user_config.dart';
import 'theme.dart';
import 'utils/utils.dart';

void main() async {
  ScaledWidgetsFlutterBinding.ensureInitialized(scaleFactor: (deviceSize) => deviceSize.width / 960);
  await Api.initialized();
  HttpOverrides.global = MyHttpOverrides();
  final userConfig = await UserConfig.init();
  Provider.debugCheckInvalidValueType = null;
  if (userConfig.shouldCheckUpdate()) {
    Api.checkUpdate(
      updateUrl,
      Version.fromString(appVersion),
      needUpdate: (data, url) => navigateTo(navigatorKey.currentContext!, const SettingsUpdate()),
    );
  }
  runApp(ChangeNotifierProvider(create: (_) => userConfig, child: const MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: context.watch<UserConfig>().themeMode,
      theme: tvTheme,
      darkTheme: tvDarkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: context.watch<UserConfig>().locale,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [routeObserver],
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
      },
      home: const TVHomePage(),
      themeAnimationCurve: Curves.easeOut,
      builder: (context, widget) {
        return FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(requestFocusCallback: (
            FocusNode node, {
            ScrollPositionAlignmentPolicy? alignmentPolicy,
            double? alignment,
            Duration? duration,
            Curve? curve,
          }) {
            node.requestFocus();
            Scrollable.ensureVisible(
              node.context!,
              alignment: alignment ?? 1,
              alignmentPolicy: alignmentPolicy ?? ScrollPositionAlignmentPolicy.explicit,
              duration: duration ?? const Duration(milliseconds: 400),
              curve: curve ?? Curves.easeOut,
            );
          }),
          child: MediaQuery(
            data: MediaQuery.of(context).scale(),
            child: widget!,
          ),
        );
      },
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..badCertificateCallback = (X509Certificate cert, String host, int port) => host == 'image.tmdb.org';
  }
}
