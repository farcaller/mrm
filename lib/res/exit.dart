import 'package:res_client/model.dart';

import 'room.dart';

class ResExit {
  bool _requestedDetails = false;

  final ResModel exit;

  ResExit(this.exit);

  String get id => exit['id'];
  String get name => exit['name'];
  List<String> get keys => exit['keys'];

  Future<ResExitDetails> get details async {
    if (!_requestedDetails) {
      _requestedDetails = true;
      await exit.client.subscribe(exit.rid, 'details');
    }

    return ResExitDetails(
        exit.client.get('${exit.rid}.details')!.item as ResModel);
  }
}

class ResExitDetails {
  final ResModel exit;

  ResExitDetails(this.exit);

  String get arriveMsg => exit['arriveMsg'];
  String get leaveMsg => exit['leaveMsg'];
  String get travelMsg => exit['travelMsg'];
  ResRoom get targetRoom => ResRoom(exit['targetRoom']);
}
