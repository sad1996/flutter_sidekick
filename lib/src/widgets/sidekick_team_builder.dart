import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sidekick/src/widgets/sidekick.dart';

/// Signature for building a sidekick team.
typedef StackViewBuilder<T> = Widget Function(
    BuildContext context,
    List<Del<T>> sourceBuilderDelegates,
    List<Del<T>> targetBuilderDelegates,
    );

class _SidekickMission<T> {
  _SidekickMission(
      this.id,
      this.message,
      TickerProvider vsync,
      Duration duration,
      ) : controller = SidekickController(vsync: vsync, duration: duration);

  final String id;
  final T message;
  final SidekickController controller;
  bool inFlightToTheSource = false;
  bool inFlightToTheTarget = false;

  bool get inFlight => inFlightToTheSource || inFlightToTheTarget;

  void startFlight(SidekickFlightDirection direction) =>
      _setInFlight(direction, true);

  void endFlight(SidekickFlightDirection direction) =>
      _setInFlight(direction, false);

  void _setInFlight(SidekickFlightDirection direction, bool inFlight) {
    if (direction == SidekickFlightDirection.toTarget) {
      inFlightToTheTarget = inFlight;
    } else {
      inFlightToTheSource = inFlight;
    }
  }

  void dispose() {
    controller?.dispose();
  }
}

/// A widget used to animate widgets from one container to another.
///
/// This is useful when you have two widgets that contains multiple
/// widgets and you want to be able to animate some widgets from one
/// container (the source) to the other (the target) and vice-versa.
class StackView<T> extends StatefulWidget {
  StackView({
    Key key,
    @required this.builder,
    this.sList,
    this.tList,
    this.animationDuration = const Duration(milliseconds: 300),
  })  : assert(animationDuration != null),
        super(key: key);

  /// The builder used to create the containers.
  final StackViewBuilder<T> builder;

  /// The initial items contained in the source container.
  final List<T> sList;

  /// The initial items contained in the target container.
  final List<T> tList;

  /// The duration of the flying animation.
  final Duration animationDuration;

  /// The state from the closest instance of this class that encloses the given context.
  static StackViewState<T> of<T>(BuildContext context) {
    assert(context != null);
    final StackViewState<T> result =
    context.ancestorStateOfType(TypeMatcher<StackViewState<T>>());
    return result;
  }

  @override
  StackViewState<T> createState() => StackViewState<T>();
}

/// State for [StackView].
///
/// Can animate widgets from one container to the other.
class StackViewState<T> extends State<StackView<T>>
    with TickerProviderStateMixin {
  static const String _sourceListPrefix = 's_';
  static const String _targetListPrefix = 't_';
  static int _nextId = 0;
  int _id;
  bool _allInFlight;
  SidekickController _sidekickController;
  List<_SidekickMission<T>> _sourceList;
  List<_SidekickMission<T>> _targetList;

  /// The items contained in the container labeled as the 'source'.
  List<T> get sourceList => _sourceList.map((item) => item.message).toList();

  /// The items contained in the container labeled as the 'target'.
  List<T> get targetList => _targetList.map((item) => item.message).toList();

  @override
  void initState() {
    super.initState();
    _id = ++_nextId;
    _allInFlight = false;
    _sidekickController = SidekickController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _initLists();
  }

  void _initLists() {
    _sourceList?.forEach((mission) => mission.dispose());
    _targetList?.forEach((mission) => mission.dispose());
    _sourceList = List<_SidekickMission<T>>();
    _targetList = List<_SidekickMission<T>>();
    _initList(
        _sourceList, widget.sList.reversed.toList(), _sourceListPrefix);
    _initList(
        _targetList, widget.tList.reversed.toList(), _targetListPrefix);
  }

  void _initList(
      List<_SidekickMission<T>> list, List<T> initialList, String prefix) {
    if (initialList != null) {
      for (var i = 0; i < initialList.length; i++) {
        final String id = '$prefix$i';
        list.add(_SidekickMission(
          id,
          initialList[i],
          this,
          widget.animationDuration,
        ));
      }
    }
  }

  void didUpdateWidget(covariant StackView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initLists();
  }

  /// Moves all the widgets from a container to the other, respecting the given [direction].
  Future<void> moveAll(SidekickFlightDirection direction) {
    assert(direction != null);
    if (!_allInFlight) {
      _allInFlight = true;
      final List<_SidekickMission> source = _getSource(direction);
      final List<_SidekickMission> target = _getTarget(direction);

      setState(() {
        source.forEach((mission) => mission.startFlight(direction));
        target.addAll(source);
      });

      return _sidekickController
          .move(
        context,
        direction,
        tags: source.map((mission) => _getTag(mission)).toList(),
      )
          .then((_) {
        setState(() {
          source.forEach((mission) => mission.endFlight(direction));
          source.clear();
        });
        _allInFlight = false;
      });
    } else {
      return Future<void>.value(null);
    }
  }

  /// Moves all the widgets from the target container to the source container.
  Future<void> moveAllToSource() => moveAll(SidekickFlightDirection.toSource);

  /// Moves all the widgets from the source container to the target container.
  Future<void> moveAllToTarget() => moveAll(SidekickFlightDirection.toTarget);

  /// Moves the widget containing the specifed [message] from its position to its
  /// position in the other container.
  Future<void> move(T message) {
    final _SidekickMission<T> sourceMission =
    _getFirstMissionInList(_sourceList, message);
    final _SidekickMission<T> targetMission =
    _getFirstMissionInList(_targetList, message);

    SidekickFlightDirection direction;
    _SidekickMission<T> mission;
    if (sourceMission != null) {
      direction = SidekickFlightDirection.toTarget;
      mission = sourceMission;
    } else if (targetMission != null) {
      direction = SidekickFlightDirection.toSource;
      mission = targetMission;
    }
    assert(direction != null);
    assert(mission != null);

    if (!mission.inFlight) {
      mission.startFlight(direction);
      final List<_SidekickMission> source = _getSource(direction);
      final List<_SidekickMission> target = _getTarget(direction);

      setState(() {
        target.add(mission);
      });
      return mission.controller
          .move(context, direction, tags: [_getTag(mission)]).then((_) {
        setState(() {
          mission.endFlight(direction);
          source.remove(mission);
        });
      });
    } else {
      return Future<void>.value(null);
    }
  }

  List<_SidekickMission<T>> _getSource(SidekickFlightDirection direction) {
    return direction == SidekickFlightDirection.toTarget
        ? _sourceList
        : _targetList;
  }

  List<_SidekickMission<T>> _getTarget(SidekickFlightDirection direction) {
    return direction == SidekickFlightDirection.toTarget
        ? _targetList
        : _sourceList;
  }

  _SidekickMission<T> _getFirstMissionInList(
      List<_SidekickMission<T>> list, T message) {
    return list.firstWhere((mission) => identical(mission.message, message),
        orElse: () => null);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            Container(
              padding: EdgeInsets.only(left: 5, right: 5, bottom: 12.0),
              child: SafeArea(
                bottom: false,
                child: Builder(
                  builder: (context) {
                    return widget.builder(
                        context,
                        _sourceList
                            .map((mission) => _buildSidekickBuilder(
                            context,
                            mission,
                            true,
                            _sourceList.length,
                            _sourceList.indexOf(mission),
                            _sourceList.indexOf(mission) ==
                                _sourceList.indexOf(_sourceList.last)))
                            .toList(),
                        _targetList
                            .map((mission) => _buildSidekickBuilder(
                            context,
                            mission,
                            false,
                            _targetList.length,
                            _targetList.indexOf(mission),
                            _targetList.indexOf(mission) ==
                                _targetList.indexOf(_targetList.last)))
                            .toList());
                  },
                ),
              ),
            ),
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              brightness: Brightness.dark,
            )
          ],
        ),
      ),
    );
  }

  Del<T> _buildSidekickBuilder(
      BuildContext context,
      _SidekickMission<T> mission,
      bool isSource,
      int length,
      int index,
      bool isLast) {
    return Del._internal(
        this,
        mission,
        _getTag(mission, isSource: isSource),
        isSource ? _getTag(mission, isSource: false) : null,
        isSource,
        length,
        index,
        isLast);
  }

  String _getTag(_SidekickMission<T> mission, {bool isSource = true}) {
    final String prefix = isSource ? 'source_' : 'target_';
    return '${_id}_$prefix${mission.id}';
  }

  @override
  void dispose() {
    _sidekickController?.dispose();
    _sourceList.forEach((mission) => mission.dispose());
    _targetList.forEach((mission) => mission.dispose());
    super.dispose();
  }
}

/// A delegate used to build a [Sidekick] and its child.
class Del<T> {
  Del._internal(
      this.state,
      this._mission,
      this._tag,
      this._targetTag,
      this._isSource,
      this._length,
      this._index,
      this._isLast,
      );

  /// The state of the [StackView] that created this delegate.
  final StackViewState<T> state;

  final _SidekickMission<T> _mission;
  final String _tag;
  final String _targetTag;
  final bool _isSource;
  final int _length;
  final int _index;
  final bool _isLast;

  /// The message transferred by the [Sidekick].
  T get message => _mission.message;

  var gestureStart;
  var gestureDirection;

  /// Builds the [Sidekick] widget and its child.
  Widget build(
      BuildContext context,
      Widget child, {
        CreateRectTween createRectTween,
        SidekickFlightShuttleBuilder flightShuttleBuilder,
        TransitionBuilder placeholderBuilder,
        SidekickAnimationBuilder animationBuilder,
      }) {
    return Opacity(
      opacity: _getOpacity(),
      child: Sidekick(
        key: ObjectKey(_mission),
        tag: _tag,
        targetTag: _targetTag,
        animationBuilder: animationBuilder == null
            ? (animation) => CurvedAnimation(
          parent: animation,
          curve: _isSource ? Curves.ease : FlippedCurve(Curves.ease),
        )
            : animationBuilder,
        createRectTween: createRectTween,
        flightShuttleBuilder: flightShuttleBuilder,
        placeholderBuilder: placeholderBuilder,
        child: _isSource
            ? Container(
          margin:
          EdgeInsets.only(top: double.parse('${_index + 2}0') / 1.5),
          child: IgnorePointer(
            ignoring: !_isLast,
            child: GestureDetector(
              onVerticalDragStart: (gestureDetails) {
                if (_length != 1) {
                  beginSwipe(_isSource, context, gestureDetails);
                }
              },
              onVerticalDragUpdate: (gestureDetails) =>
                  getDirection(gestureDetails),
              onVerticalDragEnd: (gestureDetails) {
                endSwipe(true, context, gestureDetails);
              },
              onTap: () => _length == 1 ? null : state.move(message),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 2, horizontal: 5),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  curve: Curves.bounceInOut,
                  child: child,
                ),
              ),
            ),
          ),
        )
            : IgnorePointer(
          ignoring: !_isLast,
          child: GestureDetector(
            onVerticalDragStart: (gestureDetails) {
              beginSwipe(_isSource, context, gestureDetails);
            },
            onVerticalDragUpdate: (gestureDetails) =>
                getDirection(gestureDetails),
            onVerticalDragEnd: (gestureDetails) {
              endSwipe(_isSource, context, gestureDetails);
            },
            onTap: () {
              state.move(message);
            },
            child: Container(
              padding: EdgeInsets.only(
                  left: 2,
                  right: 2,
                  top: 8,
                  bottom: double.parse('${_index}0') / 1.5),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  beginSwipe(
      bool isSource, BuildContext context, DragStartDetails gestureDetails) {
    gestureStart = gestureDetails.globalPosition.dy;
    if (gestureDirection == 'topToBottom' && isSource) {
      print(gestureDirection);
      state.move(message);
    }
  }

  getDirection(DragUpdateDetails gestureDetails) {
    if (gestureDetails.globalPosition.dy != null && gestureStart != null) {
      if (gestureDetails.globalPosition.dy < gestureStart) {
        gestureDirection = 'bottomToTop';
      } else {
        gestureDirection = 'topToBottom';
      }
    } else {
      gestureDirection = 'topToBottom';
    }
  }

  endSwipe(bool isSource, BuildContext context, DragEndDetails gestureDetails) {
    if (gestureDirection == 'bottomToTop' && !isSource) {
      state.move(message);
    }
  }

  double _getOpacity() {
    if (_mission.inFlightToTheSource && _isSource ||
        _mission.inFlightToTheTarget && !_isSource) {
      return 0.0;
    } else {
      return 1.0;
    }
  }
}
