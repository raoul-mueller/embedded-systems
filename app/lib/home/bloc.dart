// © 2021 Raoul Müller. All rights reserved.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bloc/bloc.dart' as bloc;
import 'package:habits/utilities.dart';
import 'package:http/http.dart' as http; // ignore: import_of_legacy_library_into_null_safe

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// bloc class
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// The [Bloc].
///
/// The current standings are displayed through this [Bloc].
///
/// Available [BlocEvent]s are:
/// - [BuildEvent]
/// - [SetupButtonPressedEvent]
/// - [NewDataReceivedEvent]
///
/// Available [BlocState]s are:
/// - [NoDataReceivedYetState]
/// - [IdleState]
///
/// Available actions are:
/// - [BlocView.showError]
/// - [BlocView.navigateToScreen]
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
  static const BlocState initialState = NoDataReceivedYetState();

  /// A collection of possible events.
  static const Set<Type> events = <Type>{BuildEvent, SetupButtonPressedEvent, NewDataReceivedEvent};

  /// A collection of possible states.
  static const Set<Type> states = <Type>{NoDataReceivedYetState, IdleState};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// event handler methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  @override
  Stream<BlocState> mapEventToState(BlocEvent event) async* {
    // Add the current event to the archive.
    _archive.add(event);

    // Call the right event handler.
    if (event is BuildEvent) yield* _onBuildEvent(event);
    if (event is SetupButtonPressedEvent) yield* _onSetupButtonPressedEvent(event);
    if (event is NewDataReceivedEvent) yield* _onNewDataReceivedEvent(event);
  }

  /// The [BuildEvent] handler.
  Stream<BlocState> _onBuildEvent(BuildEvent event) async* {
    // Only execute this handler once.
    if (_archive.countOf<BuildEvent>() > 1) return;

    // Listen to the user data stream.
    (await WebSocket.connect('wss://embedded-systems.fantasia.dev/ws')).listen((dynamic data) => add(NewDataReceivedEvent(data as String)));
  }

  /// The [SetupButtonPressedEvent] handler.
  Stream<BlocState> _onSetupButtonPressedEvent(SetupButtonPressedEvent event) async* {
    _view.navigateToScreen('/setup');
  }

  /// The [NewDataReceivedEvent] handler.
  Stream<BlocState> _onNewDataReceivedEvent(NewDataReceivedEvent event) async* {
    try {
      final List<User> users = <User>[];
      int rank = 1;
      for (final Map<String, dynamic> userData in (jsonDecode(event.data) as Map<String, List<Map<String, dynamic>>>)['standings']!) {
        final bool ownDevice = userData['user']['uuid'] as String == HabitsApp().globals.deviceId;
        final String displayName = userData['user']['realname'] as String;
        // todo: cache images (add image change date to stream data)
        final Uint8List profileImage = (await http.get(userData['user']['pictureUrl'] as String)).bodyBytes;
        final List<int> scoreToday = (userData['score']['hourly']['today'] as List<dynamic>).map<int>((dynamic data) => int.parse(data.toString())).toList();
        final List<int> scoreYesterday =
            (userData['score']['hourly']['yesterday'] as List<dynamic>).map<int>((dynamic data) => int.parse(data.toString())).toList();
        final List<int> stepsToday = (userData['steps']['hourly']['today'] as List<dynamic>).map<int>((dynamic data) => int.parse(data.toString())).toList();
        final List<int> stepsYesterday =
            (userData['steps']['hourly']['yesterday'] as List<dynamic>).map<int>((dynamic data) => int.parse(data.toString())).toList();
        final List<int> standingToday =
            (userData['standing']['hourly']['today'] as List<dynamic>).map<int>((dynamic data) => int.parse(data.toString())).toList();
        final List<int> standingYesterday =
            (userData['standing']['hourly']['yesterday'] as List<dynamic>).map<int>((dynamic data) => int.parse(data.toString())).toList();
        final List<int> outsideToday =
            (userData['outside']['hourly']['today'] as List<dynamic>).map<int>((dynamic data) => int.parse(data.toString())).toList();
        final List<int> outsideYesterday =
            (userData['outside']['hourly']['yesterday'] as List<dynamic>).map<int>((dynamic data) => int.parse(data.toString())).toList();

        users.add(User(
            rank: rank++,
            ownDevice: ownDevice,
            displayName: displayName,
            profileImage: profileImage,
            scoreToday: scoreToday,
            scoreYesterday: scoreYesterday,
            stepsToday: stepsToday,
            stepsYesterday: stepsYesterday,
            standingToday: standingToday,
            standingYesterday: standingYesterday,
            outsideToday: outsideToday,
            outsideYesterday: outsideYesterday));
      }

      yield IdleState(
          users: users, highestScore: max(users.first.scoreToday.reduce((int a, int b) => a + b), users.first.scoreToday.reduce((int a, int b) => a + b)));
    } on Exception {
      _view.showError('Something went wrong while parsing the data received from the server. Please report to the developer.');
    }
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// bloc event classes
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// The abstract [BlocEvent] class.
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

/// The [SetupButtonPressedEvent].
@immutable
class SetupButtonPressedEvent extends BlocEvent {
  /// The constructor.
  const SetupButtonPressedEvent();
}

/// A [NewDataReceivedEvent] shall be added whenever the websocket has new data.
@immutable
class NewDataReceivedEvent extends BlocEvent {
  /// The constructor.
  const NewDataReceivedEvent(this.data);

  /// The data received from the server.
  final String data;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// bloc state classes
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// The abstract [BlocState] class.
///
/// [BlocState]s can be presented by the [Bloc._view].
@immutable
abstract class BlocState {
  /// The constructor.
  const BlocState();
}

/// A [NoDataReceivedYetState] shall be presented before the first data arrived.
@immutable
class NoDataReceivedYetState extends BlocState {
  /// The constructor.
  const NoDataReceivedYetState();
}

/// A [IdleState] shall be presented whenever there is nothing special to show.
@immutable
class IdleState extends BlocState {
  /// The constructor.
  const IdleState({required this.users, required this.highestScore});

  /// A list of all users.
  final List<User> users;

  /// The highest score of all users (today and yesterday)
  final int highestScore;
}

/// The view interface.
///
/// All views must implement this interface.
abstract class BlocView {
  /// A new screen is displayed on top of this screen.
  void navigateToScreen(String route);

  /// An error message is shown.
  void showError(String message);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// additional classes
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// This is the user data that should be displayed.
class User {
  /// The constructor.
  User(
      {required this.rank,
      required this.ownDevice,
      required this.displayName,
      required this.profileImage,
      required this.scoreToday,
      required this.scoreYesterday,
      required this.stepsToday,
      required this.stepsYesterday,
      required this.standingToday,
      required this.standingYesterday,
      required this.outsideToday,
      required this.outsideYesterday});

  /// The user's rank.
  final int rank;

  /// The user's phone's id.
  final bool ownDevice;

  /// The user's display name.
  final String displayName;

  /// The user's profile image data.
  final Uint8List profileImage;

  /// Today's score.
  final List<int> scoreToday;

  /// Yesterday's score.
  final List<int> scoreYesterday;

  /// Today's steps score.
  final List<int> stepsToday;

  /// Yesterday's steps score.
  final List<int> stepsYesterday;

  /// Today's standing score.
  final List<int> standingToday;

  /// Yesterday's standing score.
  final List<int> standingYesterday;

  /// Today's outside score.
  final List<int> outsideToday;

  /// Yesterday's outside score.
  final List<int> outsideYesterday;
}
