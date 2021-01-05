// © 2021 Raoul Müller. All rights reserved.

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habits/home/screen.dart';
import 'package:habits/initialization/screen.dart';
import 'package:habits/setup/screen.dart';

export 'dart:typed_data';

export 'package:flutter/foundation.dart';
export 'package:flutter/material.dart';

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// main function
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// The main function.
void main() {
  // Ensure flutter is fully initialized before starting the app. This could have nasty side effects otherwise.
  WidgetsFlutterBinding.ensureInitialized();

  // Run the app.
  runApp(HabitsApp());
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// app class
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// The app class.
///
/// This class should be treated as a singleton.
/// The app's global variable can be accessed through [HabitsApp.globals].
class HabitsApp extends MaterialApp {
  /// Since this class should be treated as a singleton, the default constructor returns the instance.
  factory HabitsApp() => _instance;

  HabitsApp._()
      : super(
            builder: (BuildContext context, Widget? child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaleFactor: 1), child: child!),
            initialRoute: '/initialization',
            routes: <String, WidgetBuilder>{
              '/initialization': (BuildContext context) => const InitializationScreen(),
              '/setup': (BuildContext context) => const SetupScreen(),
              '/home': (BuildContext context) => const HomeScreen()
            },
            theme: ThemeData(
                colorScheme: ColorScheme.light(
                    primary: Colors.orange,
                    primaryVariant: Color.lerp(Colors.orange, Colors.white, 0.5)!,
                    secondary: Colors.red,
                    secondaryVariant: Color.lerp(Colors.red, Colors.black, 0.5)!),

                // themes:
                accentIconTheme: const IconThemeData(),
                accentTextTheme: const TextTheme(),
                appBarTheme: const AppBarTheme(),
                bannerTheme: const MaterialBannerThemeData(),
                bottomAppBarTheme: const BottomAppBarTheme(),
                bottomNavigationBarTheme: const BottomNavigationBarThemeData(),
                bottomSheetTheme: const BottomSheetThemeData(),
                buttonBarTheme: const ButtonBarThemeData(),
                buttonTheme: const ButtonThemeData(),
                cardTheme: const CardTheme(),
                cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(),
                dataTableTheme: const DataTableThemeData(),
                dialogTheme: const DialogTheme(),
                dividerTheme: const DividerThemeData(),
                elevatedButtonTheme: const ElevatedButtonThemeData(),
                floatingActionButtonTheme: const FloatingActionButtonThemeData(),
                iconTheme: const IconThemeData(color: Colors.orange),
                inputDecorationTheme: const InputDecorationTheme(),
                navigationRailTheme: const NavigationRailThemeData(),
                outlinedButtonTheme: const OutlinedButtonThemeData(),
                pageTransitionsTheme: const PageTransitionsTheme(),
                popupMenuTheme: const PopupMenuThemeData(),
                primaryIconTheme: const IconThemeData(),
                primaryTextTheme: const TextTheme(),
                tabBarTheme: const TabBarTheme(),
                sliderTheme: const SliderThemeData(),
                snackBarTheme: const SnackBarThemeData(),
                textButtonTheme: const TextButtonThemeData(),
                textSelectionTheme: const TextSelectionThemeData(),
                textTheme: TextTheme(headline1: GoogleFonts.audiowide()),
                timePickerTheme: const TimePickerThemeData(),
                toggleButtonsTheme: const ToggleButtonsThemeData(),
                tooltipTheme: const TooltipThemeData()),
            title: 'Habits');

  /// The only instance.
  static final HabitsApp _instance = HabitsApp._();

  /// The app's global variables.
  final AppGlobals globals = AppGlobals();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) =>
      super.debugFillProperties(properties..add(DiagnosticsProperty<AppGlobals>('appGlobals', globals)));
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// app globals class
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// The app's global variables can be encapsulated in this class.
class AppGlobals {
  /// The [deviceId] is unique to this device.
  late final String deviceId;

  /// Whether there is an entry for this device in the database.
  bool deviceRegistered = false;
}
