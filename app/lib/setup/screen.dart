// © 2021 Raoul Müller. All rights reserved.

import 'package:habits/app.dart';
import 'package:habits/setup/bloc.dart';
import 'package:image_picker/image_picker.dart'; // ignore: import_of_legacy_library_into_null_safe

// todo: documentation
///
class SetupScreen extends StatefulWidget {
  /// The constructor.
  const SetupScreen({Key? key}) : super(key: key);

  @override
  _SetupScreen createState() => _SetupScreen();
}

class _SetupScreen extends State<SetupScreen> implements BlocView {
  late final Bloc _bloc;

  @override
  void initState() {
    _bloc = Bloc(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _bloc.add(const BuildEvent());

    return StreamBuilder<BlocState>(
        initialData: Bloc.initialState,
        stream: _bloc,
        builder: (BuildContext context, AsyncSnapshot<BlocState> stateContainer) {
          final BlocState state = stateContainer.data ?? Bloc.initialState;

          return Scaffold(
              body: Column(children: <Widget>[
            Expanded(flex: 382, child: header(state)),
            if (state is LoadingState) Expanded(flex: 618, child: loadingIndicator(state)),
            if (state is IdleState) Expanded(flex: 618, child: form(state))
          ]));
        });
  }

  Widget header(BlocState state) => Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary]),
          borderRadius: const BorderRadius.only(bottomRight: Radius.circular(128))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        if (state.displayBackButton)
          SafeArea(
              child: Container(
                  alignment: Alignment.centerLeft,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => _bloc.add(const BackButtonPressedEvent())))),
        const Spacer(),
        Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('setup', style: Theme.of(context).textTheme.headline2!.copyWith(color: Colors.white)))
      ]));

  Widget loadingIndicator(BlocState state) =>
      Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)));

  Widget form(IdleState state) {
    final GlobalKey<FormFieldState<String>> displayNameInputKey = GlobalKey<FormFieldState<String>>();

    return ListView(children: <Widget>[
      Container(
          alignment: Alignment.center,
          child: GestureDetector(
              onTap: () => _bloc.add(const ImageTappedEvent()),
              child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
                  child: Stack(alignment: Alignment.center, children: <Widget>[
                    ClipRRect(borderRadius: BorderRadius.circular(48), child: Image.memory(state.profileImage, fit: BoxFit.cover, height: 192, width: 192)),
                    Image.asset('res/tap-to-change.png')
                  ])))),
      Center(
          child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 8, top: 12),
              width: 256,
              child: TextFormField(
                  key: displayNameInputKey,
                  decoration: const InputDecoration(hintText: 'display name'),
                  initialValue: state.displayName,
                  textAlign: TextAlign.center))),
      Center(
          child: SizedBox(
              width: 256,
              child: ElevatedButton(
                  onPressed: () => _bloc.add(SendButtonPressedEvent(displayName: displayNameInputKey.currentState!.value!, profileImage: state.profileImage)),
                  child: Text('send'.toUpperCase()))))
    ]);
  }

  @override
  void replaceWithScreen(String route) => Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);

  @override
  void showError(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(backgroundColor: Theme.of(context).colorScheme.error, content: Text(message)));

  @override
  void showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  void showSuccess(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text(message)));

  @override
  Future<Uint8List?> takeImage() async => (await ImagePicker().getImage(source: ImageSource.camera))?.readAsBytes();
}
