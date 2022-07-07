import 'dart:async';
import 'dart:io';

import 'package:glog/glog.dart';
import 'package:mrm/res/exit.dart';
import 'package:res_client/client.dart';
import 'package:res_client/event.dart';
import 'package:res_client/model.dart';
import 'package:res_client/password.dart';

import 'data.dart';
import 'notifier.dart';
import 'res/room.dart';

const logger = GlogContext('agent');

class Agent {
  final Shard shard;
  final ResClient client;
  ResModel? _player;
  ResModel? _ctrl;
  Completer? _finishMove;

  Agent(this.shard) : client = ResClient(Uri.parse('wss://api.wolfery.com'));

  init() async {
    client.reconnect();

    await client.events.firstWhere((e) => e is ConnectedEvent);

    logger.info('authenticating as ${shard.authInfo.username}');
    await client.auth('auth', 'login', params: {
      'name': shard.authInfo.username,
      'hash': saltPassword(shard.authInfo.password),
    });
    logger.info('auth success');
    _player = await client.call('core', 'getPlayer') as ResModel;
    logger.info('got player $player');
    final char = findCharacter(
        player, shard.authInfo.characterName, shard.authInfo.characterSurname);
    logger.info('got character $char');
    _ctrl = await controlCharacter(client, player, char);

    client.events.listen((event) {
      if (event is ModelChangedEvent && event.rid == _ctrl!.rid) {
        _finishMove?.complete();
      }
    });
  }

  dispose() {
    client.dispose();
  }

  ResModel get player => _player!;
  ResModel get ctrl => _ctrl!;

  _teleport(String roomId) async {
    if (ctrl['inRoom']['id'] == roomId) {
      logger.debug('already in #$roomId, skipping teleport');
      return;
    }
    _finishMove = Completer();
    await client.call(ctrl.rid, 'teleport', params: {'roomId': roomId});
    await _finishMove!.future;
  }

  teleport(Room room) async {
    assert(room.id != null);
    await _teleport(room.id!);
  }

  createRoom(Room room) async {
    assert(room.id != null);
    final res =
        await client.call(ctrl.rid, 'createRoom', params: {'name': room.name});
    await _teleport(res['id']!);
  }

  Future<String> createExit(Room room, Exit exit) async {
    await _teleport(room.id!);
    final res = await client.call(ctrl.rid, 'createExit', params: {
      'name': exit.name,
      'keys': exit.keywords,
      'targetRoom': exit.targetRoomID,
    });
    return res['exit']['id'];
  }

  setRoom(Room room) async {
    await _teleport(room.id!);
    await client.call(ctrl.rid, 'setRoom', params: {
      // 'autosweep':
      // 'autosweepDelay':
      'desc': room.description,
      // 'isDark':
      // 'isHome':
      // 'isQuiet':
      // 'isTeleport':
      'name': room.name,
    });
  }

  setExit(Room room, Exit exit, String exitId) async {
    await _teleport(room.id!);
    await client.call(ctrl.rid, 'setExit', params: {
      'arriveMsg': exit.messages!.arrive,
      'exitId': exitId,
      'keys': exit.keywords!,
      'leaveMsg': exit.messages!.leave,
      'name': exit.name,
      'travelMsg': exit.messages!.travel,
    });
  }

  setExitOrder(Room room, String exitId, int order) async {
    await _teleport(room.id!);
    await client.call(ctrl.rid, 'setExitOrder', params: {
      'exitId': exitId,
      'order': order,
    });
  }

  deleteExit(Room room, String exitId) async {
    await _teleport(room.id!);
    await client.call(ctrl.rid, 'deleteExit', params: {
      'exitId': exitId,
    });
  }

  ResModel get character {
    return (player['chars'] as ResCollection)
        .items
        .where((e) => e['id'] == ctrl['id'])
        .first;
  }

  ResRoom get room => ResRoom(ctrl['inRoom']);

  performSyncRoom(String roomName, Notifier n, bool apply) async {
    final targetRoom = shard.rooms.firstWhere((r) => r.tid == roomName);
    await teleport(targetRoom);

    final resRoom = room;
    assert(room.id == resRoom.id);

    await n.context('room "${room.name}"', () async {
      bool dirtyRoom = false;
      dirtyRoom = n.diff('name', resRoom.name, room.name) || dirtyRoom;
      dirtyRoom = n.diff('description', resRoom.desc, targetRoom.description) ||
          dirtyRoom;
      final exitsToRemove = <ResExit>[];
      final exitsToSet = <Exit>[];
      final matchedExits = [...targetRoom.exits];
      for (final resExitEntries in resRoom.exits.asMap().entries) {
        final resExit = resExitEntries.value;
        final resExitIndex = resExitEntries.key;

        final details = await resExit.details;
        final exitIdx = matchedExits
            .indexWhere((e) => e.targetRoomID == details.targetRoom.id);
        if (exitIdx == -1) {
          exitsToRemove.add(resExit);
        } else {
          final exit = matchedExits.removeAt(exitIdx);
          exit.exitId = resExit.exit.rid.split('.').last;
          exitsToSet.add(exit);
          await n.context('exit "${exit.name}"', () {
            n.diff('name', resExit.name, exit.name!);
            n.diff(
                'position', resExitIndex.toString(), exit.exitOrder.toString());
            n.diff('target', details.targetRoom.id, exit.targetRoomID!);
            n.diff('leave message', details.leaveMsg, exit.messages!.leave);
            n.diff('arrive message', details.arriveMsg, exit.messages!.arrive);
            n.diff('travel message', details.travelMsg, exit.messages!.travel);
          });
        }
      }
      for (final resExit in exitsToRemove) {
        await n.context('exit "${resExit.name}"',
            () => n.cross('remove exit to #${resExit.id}'));
      }
      final exitsToAdd =
          targetRoom.exits.where((e) => !exitsToSet.contains(e)).toList();
      for (final exit in exitsToAdd) {
        await n.context('exit "${exit.name}"',
            () => n.plus('add exit to #${exit.targetRoomID}'));
      }

      if (dirtyRoom) {
        if (apply) {
          n.out('applying the changes');
          await setRoom(targetRoom);
        } else {
          n.out('the room has pending changes');
        }
      }

      final dirtyExits = exitsToRemove.isNotEmpty ||
          exitsToSet.isNotEmpty ||
          exitsToAdd.isNotEmpty;
      if (dirtyExits) {
        if (apply) {
          n.out('applying the changes for the exits');
          for (final exit in exitsToRemove) {
            await deleteExit(targetRoom, exit.exit.rid.split('.').last);
          }
          for (final exit in exitsToAdd) {
            final exitId = await createExit(targetRoom, exit);
            exit.exitId = exitId;
            await setExit(targetRoom, exit, exitId);
          }
          for (final exit in exitsToSet) {
            await setExit(targetRoom, exit, exit.exitId!);
          }

          // re-order after everything is settled
          final finalExits = [...exitsToAdd, ...exitsToSet];
          for (var i = 0; i < finalExits.length; i++) {
            final exit = finalExits.firstWhere((e) => e.exitOrder == i);
            await setExitOrder(targetRoom, exit.exitId!, exit.exitOrder!);
          }
        } else {
          n.out('the room has pending changes for the exits');
        }
      }
    });
  }
}

ResModel findCharacter(ResModel user, String name, String surname) {
  try {
    return (user['chars'] as ResCollection)
        .items
        .where((e) => e['name'] == name && e['surname'] == surname)
        .first;
  } catch (e) {
    logger.error('failed to resolve the character: $e');
    rethrow;
  }
}

Future<ResModel> controlCharacter(
    ResClient client, ResModel player, ResModel char) async {
  final charId = char['id'] as String;
  var ctrl = (player['controlled'] as ResCollection)
      .items
      .firstWhere((c) => c['id'] == charId, orElse: () => null) as ResModel?;
  logger.debug('existing ctrl: $ctrl');
  ctrl ??=
      await client.call(player.rid, 'controlChar', params: {'charId': charId});
  logger.debug('final ctrl: $ctrl');
  if (ctrl == null) {
    throw 'failed to get ctrl';
  }
  if (ctrl['state'] != 'awake') {
    logger.info('ctrl state is ${ctrl['state']}, waking up');
    await client.call(ctrl.rid, 'wakeup');
  }
  return ctrl;
}
