import 'dart:io';

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

    int warnings = 0;
    int errors = 0;

    for (final room in shard.rooms) {
      n.context('room "${room.name}"', () {
        for (final roomRule in roomRules) {
          if (!roomRule.check(room)) {
            n.cross(roomRule.message);
            roomRule.severity == Severity.error ? errors++ : warnings++;
          }
        }

        for (final exit in room.exits) {
          n.context('exit "${exit.name}"', () {
            for (final exitRule in exitRules) {
              if (!exitRule.check(exit)) {
                n.cross(exitRule.message);
                exitRule.severity == Severity.error ? errors++ : warnings++;
              }
            }
          });
        }
      });
    }

    if (errors > 0) exit(10);
  }

  final roomRules = [
    RoomRule('the name must start from a capital letter', Severity.error,
        (room) {
      assert(room.name.isNotEmpty);
      final firstLetter = room.name[0];
      return firstLetter == firstLetter.toUpperCase();
    }),
    RoomRule('the description must start from a capital letter', Severity.error,
        (room) {
      assert(room.description.isNotEmpty);
      final firstLetter = room.description[0];
      return firstLetter == firstLetter.toUpperCase();
    }),
    RoomRule('the description must end with a period', Severity.error, (room) {
      assert(room.description.isNotEmpty);
      return room.description[room.description.length - 1] == '.';
    }),
    RoomRule('the room should have a "back" exit', Severity.warning, (room) {
      for (final exit in room.exits) {
        if (exit.keywords!.contains('back')) return true;
      }
      return false;
    }),
  ];

  final exitRules = [
    ExitRule('the name must start from a capital letter', Severity.error,
        (exit) {
      assert(exit.name?.isNotEmpty == true);
      final firstLetter = exit.name![0];
      return firstLetter == firstLetter.toUpperCase();
    }),
    ExitRule('the "leave" message must end with a period', Severity.error,
        (exit) {
      return exit.messages?.leave.isNotEmpty == true &&
          exit.messages?.leave[exit.messages!.leave.length - 1] == '.';
    }),
    ExitRule('the "arrival" message must end with a period', Severity.error,
        (exit) {
      return exit.messages?.arrive.isNotEmpty == true &&
          exit.messages?.arrive[exit.messages!.arrive.length - 1] == '.';
    }),
    ExitRule('the "travel" message must end with a period', Severity.error,
        (exit) {
      return exit.messages?.travel.isNotEmpty == true &&
          exit.messages?.travel[exit.messages!.travel.length - 1] == '.';
    }),
  ];
}

enum Severity {
  warning,
  error,
}

class RoomRule {
  final bool Function(Room room) check;
  final String message;
  final Severity severity;

  const RoomRule(this.message, this.severity, this.check);
}

class ExitRule {
  final bool Function(Exit exit) check;
  final String message;
  final Severity severity;

  const ExitRule(this.message, this.severity, this.check);
}
