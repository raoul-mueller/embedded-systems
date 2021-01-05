// © 2021 Raoul Müller. All rights reserved.

import 'package:habits/app.dart';
import 'package:habits/initialization/bloc.dart';

// todo: documentation
///
@immutable
class InitializationScreen extends StatefulWidget {
  /// The constructor.
  const InitializationScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _InitializationScreen();
}

class _InitializationScreen extends State<InitializationScreen> implements BlocView {
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
            Expanded(
                flex: 618,
                child: Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    child: FittedBox(
                        child: Text('habits', style: Theme.of(context).textTheme.headline1!.copyWith(color: Theme.of(context).colorScheme.primary))))),
            if (state is RunningState)
              Expanded(
                  flex: 382, child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)))),
            if (state is IdleState)
              Expanded(flex: 382, child: Center(child: IconButton(icon: const Icon(Icons.refresh), onPressed: () => _bloc.add(const StartEvent()))))
          ]));
        });
  }

  @override
  void replaceWithScreen(String route) => Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);

  @override
  void showError(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(backgroundColor: Theme.of(context).colorScheme.error, content: Text(message)));
}
