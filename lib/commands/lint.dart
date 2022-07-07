import 'package:args/command_runner.dart';
import 'package:glog/glog.dart';
import '../data.dart';
import '../notifier.dart';
import 'common.dart';

const logger = GlogContext('sync_room');

class Lint extends Command with CommonFlags {
  @override
  final name = 'lint';
  @override
  final description = 'lint the shard';

  Lint() {
    setupCommonArgs();
  }

  @override
  void run() async {
    final shard = await loadShard(argShard);
    final n = Notifier();

    for (final room in shard.rooms) {
      n.context('room "${room.name}"', () {
        for (final roomRule in roomRules) {
          if (!roomRule.check(room)) n.cross(roomRule.message);
        }

        for (final exit in room.exits) {
          n.context('exit "${exit.name}"', () {
            for (final exitRule in exitRules) {
              if (!exitRule.check(exit)) n.cross(exitRule.message);
            }
          });
        }
      });
    }
  }

  final roomRules = [
    RoomRule('the name must start from a capital letter', (room) {
      assert(room.name.isNotEmpty);
      final firstLetter = room.name[0];
      return firstLetter == firstLetter.toUpperCase();
    }),
    RoomRule('the description must start from a capital letter', (room) {
      assert(room.description.isNotEmpty);
      final firstLetter = room.description[0];
      return firstLetter == firstLetter.toUpperCase();
    }),
    RoomRule('the description must end with a period', (room) {
      assert(room.description.isNotEmpty);
      return room.description[room.description.length - 1] == '.';
    }),
    RoomRule('the room must have a "back" exit', (room) {
      for (final exit in room.exits) {
        if (exit.keywords!.contains('back')) return true;
      }
      return false;
    }),
  ];

  final exitRules = [
    ExitRule('the name must start from a capital letter', (exit) {
      assert(exit.name?.isNotEmpty == true);
      final firstLetter = exit.name![0];
      return firstLetter == firstLetter.toUpperCase();
    }),
    ExitRule('the "leave" message must end with a period', (exit) {
      return exit.messages?.leave.isNotEmpty == true &&
          exit.messages?.leave[exit.messages!.leave.length - 1] == '.';
    }),
    ExitRule('the "arrival" message must end with a period', (exit) {
      return exit.messages?.arrive.isNotEmpty == true &&
          exit.messages?.arrive[exit.messages!.arrive.length - 1] == '.';
    }),
    ExitRule('the "travel" message must end with a period', (exit) {
      return exit.messages?.travel.isNotEmpty == true &&
          exit.messages?.travel[exit.messages!.travel.length - 1] == '.';
    }),
  ];
}

class RoomRule {
  final bool Function(Room room) check;
  final String message;

  const RoomRule(this.message, this.check);
}

class ExitRule {
  final bool Function(Exit exit) check;
  final String message;

  const ExitRule(this.message, this.check);
}
