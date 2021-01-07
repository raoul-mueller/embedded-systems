// © 2021 Raoul Müller. All rights reserved.

import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart' as bloc;
import 'package:habits/utilities.dart';
import 'package:http/http.dart' as http; // ignore: import_of_legacy_library_into_null_safe

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// bloc class
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// The [Bloc].
///
/// This [Bloc] is used to set or update this phone's user's display name and profile image.
///
/// Available [BlocEvent]s are:
/// - [BuildEvent]
/// - [StartFetchingUserDataEvent]
/// - [SendButtonPressedEvent]
/// - [BackButtonPressedEvent]
/// - [ImageTappedEvent]
///
/// Available [BlocState]s are:
/// - [UserDataNotFetchedYetState]
/// - [IdleState]
/// - [LoadingState]
///
/// Available actions are:
/// - [BlocView.popCurrentScreen]
/// - [BlocView.replaceWithScreen]
/// - [BlocView.showError]
/// - [BlocView.showMessage]
/// - [BlocView.showSuccess]
/// - [BlocView.takeImage]
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
  static const BlocState initialState = UserDataNotFetchedYetState();

  /// A collection of possible events.
  static const Set<Type> events = <Type>{BuildEvent, StartFetchingUserDataEvent, SendButtonPressedEvent, BackButtonPressedEvent, ImageTappedEvent};

  /// A collection of possible states.
  static const Set<Type> states = <Type>{UserDataNotFetchedYetState, IdleState, LoadingState};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// event handler methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  @override
  Stream<BlocState> mapEventToState(BlocEvent event) async* {
    // Add the current event to the archive.
    _archive.add(event);

    // Call the right event handler.
    if (event is BuildEvent) yield* _onBuildEvent(event);
    if (event is StartFetchingUserDataEvent) yield* _onStartFetchingUserDataEvent(event);
    if (event is SendButtonPressedEvent) yield* _onSendButtonPressedEvent(event);
    if (event is BackButtonPressedEvent) yield* _onBackButtonPressedEvent(event);
    if (event is ImageTappedEvent) yield* _onImageTappedEvent(event);
  }

  /// The [BuildEvent] handler.
  Stream<BlocState> _onBuildEvent(BuildEvent event) async* {
    // Only execute this handler once.
    if (_archive.countOf<BuildEvent>() > 1) return;

    add(const StartFetchingUserDataEvent());
  }

  /// The [StartFetchingUserDataEvent] handler.
  Stream<BlocState> _onStartFetchingUserDataEvent(StartFetchingUserDataEvent event) async* {
    // This event can only be processed, if the bloc is currently not loading.
    if (state is! UserDataNotFetchedYetState) {
      _view.showMessage('Please go back (or close the app) and try again.');
      return;
    }

    // Present a loading state.
    yield const LoadingState();

    if (!HabitsApp().globals.deviceRegistered) {
      try {
        // If the phone is not registered yet, use the default image and an empty display name.
        // todo: this line needs debugging
        final Uint8List profileImage = (await http.get('https://embedded-systems.fantasia.dev/static/default.jpeg')).bodyBytes;

        // End the loading state.
        yield IdleState(displayName: '', profileImage: profileImage);
      } on SocketException {
        yield const UserDataNotFetchedYetState();
        _view.showError('We have problems reaching the server. Please try connecting to the internet (differently) and try again.');
      }
      return;
    }

    try {
      // If the phone is already registered, fetch the display name and the profile image.
      // todo: this endpoint needs to be established
      // todo: this line needs debugging
      final Map<String, String> userData =
          jsonDecode((await http.get('https: //embedded-systems.fantasia.dev/api/v1/userData?uuid=${HabitsApp().globals.deviceId}')).body)
              as Map<String, String>;
      final String displayName = userData['realname']!;
      // todo: this line needs debugging
      final Uint8List profileImage = (await http.get(userData['pictureUrl'])).bodyBytes;

      // End the loading state.
      yield IdleState(displayName: displayName, profileImage: profileImage);
    } on SocketException {
      yield const UserDataNotFetchedYetState();
      _view.showError('We have problems reaching the server. Please try connecting to the internet (differently) and try again.');
    }
  }

  /// The [SendButtonPressedEvent] handler.
  Stream<BlocState> _onSendButtonPressedEvent(SendButtonPressedEvent event) async* {
    // This event can only be processed, if the bloc is currently not loading.
    if (state is! IdleState) {
      _view.showMessage('Please wait until loading has finished and try again.');
      return;
    }

    // The display name must be at least two characters long.
    if (event.displayName.length < 2) {
      _view.showError('Please enter a (longer) display name and try again.');
      return;
    }

    // Present a loading state.
    yield const LoadingState();

    try {
      // Upload the display name.
      // todo: this line needs debugging
      await http.post('https://embedded-systems.fantasia.dev/api/v1/users',
          headers: <String, String>{'content-type': 'application/json'},
          body: jsonEncode(<String, String>{'uuid': HabitsApp().globals.deviceId, 'realname': event.displayName}));
      // todo: this line needs debugging
      // todo: error: request entry too large
      // Upload the profile image.
      final http.MultipartRequest request = http.MultipartRequest('POST', Uri.parse('https://embedded-systems.fantasia.dev/api/v1/image'));
      request.files.add(http.MultipartFile.fromBytes('image', event.profileImage));
      print(request);
      http.StreamedResponse response = await request.send();
      print(response.statusCode);
      print(response.reasonPhrase);

      // Go to home screen and display a success message.
      state.displayBackButton //
          ? _view.popCurrentScreen()
          : _view.replaceWithScreen('/home');

      // Update the deviceRegistered flag.
      HabitsApp().globals.deviceRegistered = true;

      _view.showSuccess('User data has successfully been updated.');
    } on SocketException {
      _view.showError('We have problems reaching the server. Please try connecting to the internet (differently) and try again.');
    } finally {
      // End the loading state.
      yield IdleState(displayName: event.displayName, profileImage: event.profileImage);
    }
  }

  /// The [BackButtonPressedEvent] handler.
  Stream<BlocState> _onBackButtonPressedEvent(BackButtonPressedEvent event) async* {
    // This event can only be processed, if the device is already registered.
    HabitsApp().globals.deviceRegistered
        ? _view.replaceWithScreen('/home')
        : _view.showError('This option should not be available. Please report to the developer.');
  }

  /// The [ImageTappedEvent] handler.
  Stream<BlocState> _onImageTappedEvent(ImageTappedEvent event) async* {
    // This event can only be processed, if the bloc is currently not loading.
    if (state is! IdleState) {
      _view.showMessage('Please wait until loading has finished and try again.');
      return;
    }

    // Take an image.
    final IdleState oldState = state as IdleState;
    yield const LoadingState();
    final Uint8List? profileImage = await _view.takeImage();
    yield IdleState(displayName: oldState.displayName, profileImage: profileImage ?? oldState.profileImage);
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

/// A [StartFetchingUserDataEvent] shall be added immediately after the [Bloc._view] is built.
@immutable
class StartFetchingUserDataEvent extends BlocEvent {
  /// The constructor.
  const StartFetchingUserDataEvent();
}

/// The [SendButtonPressedEvent].
@immutable
class SendButtonPressedEvent extends BlocEvent {
  /// The constructor.
  const SendButtonPressedEvent({required this.displayName, required this.profileImage});

  /// The [displayName].
  final String displayName;

  /// The [profileImage].
  final Uint8List profileImage;
}

/// The [BackButtonPressedEvent].
@immutable
class BackButtonPressedEvent extends BlocEvent {
  /// The constructor.
  const BackButtonPressedEvent();
}

/// The [ImageTappedEvent].
@immutable
class ImageTappedEvent extends BlocEvent {
  /// The constructor.
  const ImageTappedEvent();
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

  /// Whether the [Bloc._view] should display a back button or not.
  bool get displayBackButton => HabitsApp().globals.deviceRegistered;
}

/// A [UserDataNotFetchedYetState] shall be presented before the user data is fetched.
@immutable
class UserDataNotFetchedYetState extends BlocState {
  /// The constructor.
  const UserDataNotFetchedYetState();
}

/// A [IdleState] shall be presented whenever there is nothing special to show.
@immutable
class IdleState extends BlocState {
  /// The constructor.
  const IdleState({required this.displayName, required this.profileImage});

  /// The [displayName].
  final String displayName;

  /// The [profileImage]
  final Uint8List profileImage;
}

/// A [LoadingState] shall be presented when the user should not be able to interact with the screen.
@immutable
class LoadingState extends BlocState {
  /// The constructor
  const LoadingState();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// bloc view interface
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/// The view interface.
///
/// All views must implement this interface.
abstract class BlocView {
  /// The current screen is popped.
  void popCurrentScreen();

  /// All screens are popped and replaced with the given path.
  void replaceWithScreen(String route);

  /// An error message is shown.
  void showError(String message);

  /// A neutral message is shown.
  void showMessage(String message);

  /// A success message is shown.
  void showSuccess(String message);

  /// A new image is taken.
  Future<Uint8List?> takeImage();
}
