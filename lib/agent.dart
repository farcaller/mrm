import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
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

class _ExitsSyncResult {
  final List<ResExit> exitsToRemove;
  final List<Exit> exitsToSet;
  final List<Exit> exitsToAdd;

  _ExitsSyncResult(this.exitsToRemove, this.exitsToSet, this.exitsToAdd);

  bool get dirty =>
      exitsToRemove.isNotEmpty ||
      exitsToSet.isNotEmpty ||
      exitsToAdd.isNotEmpty;
}

class Agent {
  final Shard shard;
  final ResClient client;
  ResModel? _player;
  ResModel? _ctrl;
  Completer? _finishMove;

  Agent(this.shard) : client = ResClient();

  init() async {
    client.reconnect(Uri.parse('wss://api.wolfery.com'));

    await client.events.firstWhere((e) => e is ConnectedEvent);

    logger.info('authenticating as ${shard.authInfo.username}');
    await client.auth('auth', 'login', params: {
      'name': shard.authInfo.username,
      'hash': saltPassword(shard.authInfo.password!),
    });
    logger.info('auth success');
    _player = await client.call('core', 'getPlayer') as ResModel;
    logger.info('got player $player');
    final char = findCharacter(player, shard.authInfo.characterName!,
        shard.authInfo.characterSurname!);
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
    await client.subscribe('core.room.$roomId', 'exits.hidden');
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
      'hidden': exit.hidden,
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

  Future<_ExitsSyncResult> _syncExits(Notifier n, Room targetRoom,
      ResRoom resRoom, List<Exit> matchedExits, bool hidden) async {
    final exitsToRemove = <ResExit>[];
    final exitsToSet = <Exit>[];
    final processedExits = <Exit>[];

    final resExits = hidden
        ? resRoom.hiddenExits.asMap().entries
        : resRoom.exits.asMap().entries;

    // logger.warning(
    //     'sync ${matchedExits.map((e) => e.toJson())} against ${resExits.map((e) => e.value.exit.toJson())}');

    for (final resExitEntries in resExits) {
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
        processedExits.add(exit);
        bool dirty = false;
        await n.context('${hidden ? 'hidden ' : ''}exit "${exit.name}"', () {
          dirty = n.diff('name', resExit.name, exit.name!) || dirty;
          if (!hidden) {
            dirty = n.diff('position', resExitIndex.toString(),
                    exit.exitOrder.toString()) ||
                dirty;
          }
          dirty = n.diff('target', details.targetRoom.id, exit.targetRoomID!) ||
              dirty;
          dirty = n.diff('exits', resExit.keys.join(', '),
                  exit.keywords!.join(', ')) ||
              dirty;
          dirty =
              n.diff('leave message', details.leaveMsg, exit.messages!.leave) ||
                  dirty;
          dirty = n.diff(
                  'arrive message', details.arriveMsg, exit.messages!.arrive) ||
              dirty;
          dirty = n.diff(
                  'travel message', details.travelMsg, exit.messages!.travel) ||
              dirty;
        });
        if (dirty) exitsToSet.add(exit);
      }
    }
    for (final resExit in exitsToRemove) {
      final details = await resExit.details;
      await n.context(
          '${hidden ? 'hidden ' : ''}exit "${resExit.name}"',
          () => n.cross(
              'remove ${hidden ? 'hidden ' : ''}exit to #${details.targetRoom.id}'));
    }
    final exitsToAdd = targetRoom.exits
        .where((e) => e.hidden == hidden && !processedExits.contains(e))
        .toList();
    for (final exit in exitsToAdd) {
      await n.context(
          '${hidden ? 'hidden ' : ''}exit "${exit.name}"',
          () => n.plus(
              'add ${hidden ? 'hidden ' : ''}exit to #${exit.targetRoomID}'));
    }
    return _ExitsSyncResult(exitsToRemove, exitsToSet, exitsToAdd);
  }

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
      final regularExits =
          targetRoom.exits.whereNot((exit) => exit.hidden).toList();
      final hiddenExits =
          targetRoom.exits.where((exit) => exit.hidden).toList();

      final regularExitsSync =
          await _syncExits(n, targetRoom, resRoom, regularExits, false);
      final hiddenExitsSync =
          await _syncExits(n, targetRoom, resRoom, hiddenExits, true);

      if (dirtyRoom) {
        if (apply) {
          n.out('applying the changes');
          await setRoom(targetRoom);
        } else {
          n.out('the room has pending changes');
        }
      }

      if (regularExitsSync.dirty) {
        if (apply) {
          n.out('applying the changes for the exits');
          for (final exit in regularExitsSync.exitsToRemove) {
            await deleteExit(targetRoom, exit.exit.rid.split('.').last);
          }
          for (final exit in regularExitsSync.exitsToAdd) {
            final exitId = await createExit(targetRoom, exit);
            exit.exitId = exitId;
            await setExit(targetRoom, exit, exitId);
          }
          for (final exit in regularExitsSync.exitsToSet) {
            await setExit(targetRoom, exit, exit.exitId!);
          }

          // re-order after everything is settled
          final finalExits = [
            ...regularExitsSync.exitsToAdd,
            ...regularExitsSync.exitsToSet
          ];
          for (var i = 0; i < finalExits.length; i++) {
            final exit = finalExits.firstWhereOrNull((e) => e.exitOrder == i);
            if (exit == null) continue;
            await setExitOrder(targetRoom, exit.exitId!, exit.exitOrder!);
          }
        } else {
          n.out('the room has pending changes for the exits');
        }
      }
      if (hiddenExitsSync.dirty) {
        if (apply) {
          n.out('applying the changes for the hidden exits');
          for (final exit in hiddenExitsSync.exitsToRemove) {
            await deleteExit(targetRoom, exit.exit.rid.split('.').last);
          }
          for (final exit in hiddenExitsSync.exitsToAdd) {
            final exitId = await createExit(targetRoom, exit);
            exit.exitId = exitId;
            await setExit(targetRoom, exit, exitId);
          }
          for (final exit in hiddenExitsSync.exitsToSet) {
            await setExit(targetRoom, exit, exit.exitId!);
          }
        } else {
          n.out('the room has pending changes for the hidden exits');
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
