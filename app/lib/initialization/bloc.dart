// © 2021 Raoul Müller. All rights reserved.

import 'dart:io';

import 'package:bloc/bloc.dart' as bloc;
import 'package:device_info/device_info.dart';
import 'package:habits/utilities.dart';
import 'package:http/http.dart' as http; // ignore: import_of_legacy_library_into_null_safe

/// The [Bloc].
///
/// This [Bloc] requires neither any [HabitsApp.globals] nor any advanced actions and its only task is the app's initialization.
/// After the initialization is finished, the user is either forwarded to the home screen or to the setup screen,
/// depending on whether this device was used before or not.
///
/// Available [BlocEvent]s are:
/// - [BuildEvent]
/// - [StartEvent]
///
/// Available [BlocState]s are:
/// - [IdleState]
/// - [RunningState]
///
/// Available actions are:
/// - [BlocView.showError]
class Bloc extends bloc.Bloc<BlocEvent, BlocState> {
  /// The constructor.
  Bloc(this._view) : super(initialState);

  /// The [BlocView].
  final BlocView _view;

  /// All [BlocEvent]s are archived here (in order of addition).
  final Archive<BlocEvent> _archive = Archive<BlocEvent>();

  /// The fallback [BlocState].
  ///
  /// If not stated otherwise, this [BlocState] should be presented.
  static const BlocState initialState = IdleState();

  /// A collection of possible events.
  static const Set<Type> events = <Type>{BuildEvent, StartEvent};

  /// A collection of possible states.
  static const Set<Type> states = <Type>{IdleState, RunningState};

  @override
  Stream<BlocState> mapEventToState(BlocEvent event) async* {
    // Add the new event to the archive.
    _archive.add(event);

    // Call the right event handler.
    if (event is BuildEvent) yield* _onBuildEvent(event);
    if (event is StartEvent) yield* _onStartEvent(event);
  }

  /// The [BuildEvent] handler.
  Stream<BlocState> _onBuildEvent(BuildEvent event) async* {
    // Only execute this handler once.
    if (_archive.containsOf<BuildEvent>()) return;

    // Start the initialization immediately after the screen is built.
    add(const StartEvent());
  }

  /// The [StartEvent] handler.
  Stream<BlocState> _onStartEvent(StartEvent event) async* {
    try {
      late final bool deviceInDatabase;
      await Future.wait<dynamic>(<Future<dynamic>>[
        // Initialization should not be shorter than 500ms. A flashing screen is considered as unpleasant.
        Future<void>.delayed(const Duration(milliseconds: 500)),
        // Find device id and check whether the device exists in the database.
        (() async {
          HabitsApp().globals.deviceId = await _deviceId;
          // todo: this endpoint needs to be established
          // todo: this line needs debugging
          deviceInDatabase =
              (await http.get('https://embedded-systems.fantasia.dev/api/v1/deviceInDatabase?uuid=${HabitsApp().globals.deviceId}')).body == 'true';
        })()
      ]);

      // If the device exists in the database, show the home screen. If not, show the setup screen.
      if (deviceInDatabase) {
        HabitsApp().globals.deviceRegistered = true;
        _view.replaceWithScreen('/home');
      } else {
        _view.replaceWithScreen('/setup');
      }
    } on InvalidDeviceException {
      _view.showError('This device is neither an android device nor an iOS device and therefore not compatible with this app.');
    } on SocketException {
      _view.showError('We have problems reaching the internet. Please try connecting to the internet (differently) and try again.');
    } finally {
      yield const IdleState();
    }
  }

  Future<String> get _deviceId async {
    if (Platform.isAndroid == Platform.isIOS) throw InvalidDeviceException();
    return Platform.isAndroid //
        ? (await DeviceInfoPlugin().androidInfo).androidId
        : (await DeviceInfoPlugin().iosInfo).identifierForVendor;
  }
}

/// The [BlocEvent] interface.
///
/// [BlocEvent]s can be added to a [Bloc] via its add method.
@immutable
abstract class BlocEvent {
  /// The constructor.
  const BlocEvent();
}

/// A [BuildEvent] shall be added whenever the [Bloc._view]'s build method is called.
@immutable
class BuildEvent extends BlocEvent {
  /// The constructor.
  const BuildEvent();
}

/// A [StartEvent] shall be added the [Bloc] should start the app's initialization.
@immutable
class StartEvent extends BlocEvent {
  /// The constructor.
  const StartEvent();
}

/// The [BlocState] interface.
///
/// [BlocState]s can be presented by the [Bloc._view].
@immutable
abstract class BlocState {
  /// The constructor.
  const BlocState();
}

/// An [IdleState] shall be presented whenever there is nothing special to show.
@immutable
class IdleState extends BlocState {
  /// The constructor.
  const IdleState();
}

/// A [RunningState] shall be presented whenever the [Bloc] is currently initializing the app.
@immutable
class RunningState extends BlocState {
  /// The constructor.
  const RunningState();
}

/// The view interface.
///
/// All views must implement this interface.
/// The [Bloc] can call actions the [Bloc._view] executes.
abstract class BlocView {
  /// An error message is shown.
  void showError(String message);

  /// All screens are popped and replaced with the given path.
  void replaceWithScreen(String route, [Map<String, dynamic>? options]);
}

/// This exception is thrown, if the device is neither an android device nor an iOS device.
class InvalidDeviceException implements Exception {}
