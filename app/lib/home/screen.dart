// © 2021 Raoul Müller. All rights reserved.

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:habits/app.dart';
import 'package:habits/home/bloc.dart';

// todo: documentation
///
class HomeScreen extends StatefulWidget {
  /// The constructor.
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreen createState() => _HomeScreen();
}

class _HomeScreen extends State<HomeScreen> implements BlocView {
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
            if (state is NoDataReceivedYetState) Expanded(flex: 618, child: loadingIndicator(state)),
            if (state is IdleState) Expanded(flex: 618, child: standings(state))
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
        SafeArea(
            child: Container(
                alignment: Alignment.centerRight,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () => _bloc.add(const SetupButtonPressedEvent())))),
        const Spacer(),
        Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('habits', style: Theme.of(context).textTheme.headline2!.copyWith(color: Colors.white)))
      ]));

  Widget loadingIndicator(BlocState state) =>
      Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)));

  Widget standings(IdleState state) => ListView.builder(
      itemCount: state.users.length,
      itemBuilder: (BuildContext context, int index) {
        final User user = state.users[index];
        final int rank = index + 1;

        return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Column(children: <Widget>[
              GestureDetector(
                  onTap: () => _bloc.add(UserTileTappedEvent(user.deviceId)),
                  child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      leading: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(user.profileImage)),
                      trailing: Container(alignment: Alignment.centerRight, width: 48, child: rank <= 3 ? Image.asset('res/rank$rank.png') : null),
                      title: Text(user.displayName, style: Theme.of(context).textTheme.headline5),
                      subtitle: Row(children: <Widget>[
                        Expanded(
                            child: LinearProgressIndicator(
                                value: sumOf(user.scoreToday) / state.highestScore,
                                backgroundColor: Theme.of(context).colorScheme.primaryVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary))),
                        SizedBox(width: 32, child: Text(sumOf(user.scoreToday).toString(), textAlign: TextAlign.right))
                      ]))),
              if (user.deviceId == state.expandedUser)
                SizedBox(
                    height: 256,
                    child: PageView(children: <Widget>[
                      chart('score', user.scoreToday, user.scoreYesterday),
                      chart('steps', user.stepsToday, user.stepsYesterday),
                      chart('standing', user.standingToday, user.standingYesterday),
                      chart('outside', user.outsideToday, user.outsideYesterday)
                    ]))
            ]));
      });

  Widget chart(String name, List<int> today, List<int> yesterday) {
    int Function(int) generator = (int index) => ((Random().nextBool() ? -10 : 10) * pow(Random().nextDouble(), 0.25) + 10).toInt();
    today = List.generate(16, generator);
    yesterday = List.generate(24, generator);

    print(today);
    print(yesterday);

    return LineChart(LineChartData(
        minX: 0,
        maxX: 23,
        minY: 0,
        maxY: max(sumOf(today), sumOf(yesterday)).toDouble(),
        titlesData: FlTitlesData(
            topTitles: SideTitles(showTitles: true, margin: -8, getTitles: (_) => ''),
            leftTitles: SideTitles(showTitles: true, margin: 8, interval: _interval(max(sumOf(today), sumOf(yesterday)))),
            rightTitles: SideTitles(showTitles: true, margin: -8, getTitles: (_) => ''),
            bottomTitles:
                SideTitles(showTitles: true, margin: 8, getTitles: (double hour) => hour != 0 && hour % 6 == 0 ? '${hour.toStringAsFixed(0)}:00' : '')),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(border: Border.all(color: Colors.grey)),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
              isCurved: true,
              dotData: FlDotData(show: false),
              barWidth: 5,
              preventCurveOverShooting: true,
              colors: <Color>[Colors.grey],
              belowBarData: BarAreaData(show: true, colors: <Color>[Colors.grey.withOpacity(0.25)]),
              spots: List<FlSpot>.generate(24, (final int index) => FlSpot(index.toDouble(), sumOf(yesterday.take(index + 1)).toDouble()))),
          LineChartBarData(
              isCurved: true,
              dotData: FlDotData(show: false),
              barWidth: 5,
              preventCurveOverShooting: true,
              colors: <Color>[Theme.of(context).colorScheme.primary],
              belowBarData: BarAreaData(show: true, colors: <Color>[Theme.of(context).colorScheme.primary.withOpacity(0.5)]),
              spots: List<FlSpot>.generate(today.length, (final int index) => FlSpot(index.toDouble(), sumOf(today.take(index + 1)).toDouble())))
        ]));
  }

  @override
  void navigateToScreen(String route) => Navigator.pushNamed(context, route);

  @override
  void showError(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(backgroundColor: Theme.of(context).colorScheme.error, content: Text(message)));
}

double _interval(int maxY) {
  const List<int> intervals = <int>[10, 25, 50];
  const int maxSteps = 5;

  if (maxY <= 1 * maxSteps) return 1;
  if (maxY <= 2 * maxSteps) return 2;
  if (maxY <= 5 * maxSteps) return 5;

  int factor = 1;
  // ignore: literal_only_boolean_expressions
  while (true) {
    for (final int interval in intervals)
      if (maxY <= interval * factor * maxSteps) {
        return interval * factor.toDouble();
      }
    factor *= 10;
  }
}
