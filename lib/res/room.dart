import 'package:res_client/model.dart';

import 'exit.dart';

class ResRoom {
  final ResModel room;

  ResRoom(this.room);

  bool get autosweep => room['autosweep'];
  int get autosweepDelay => room['autosweepDelay'];
  ResCollection get chars => room['chars'];
  String get desc => room['desc'];
  List<ResExit> get exits =>
      (room['exits'] as ResCollection).items.map((e) => ResExit(e)).toList();
  String get id => room['id'];
  // image
  String get name => room['name'];
}
