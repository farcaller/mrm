import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
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
      await n.context('room "${room.name}"', () async {
        for (final roomRule in roomRules) {
          var ch = roomRule.check(room, n);
          if (ch is Future<bool>) {
            ch = await ch;
          }
          if (!ch) {
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
        (room, _) {
      assert(room.name.isNotEmpty);
      final firstLetter = room.name[0];
      return firstLetter == firstLetter.toUpperCase();
    }),
    RoomRule('the description must start from a capital letter', Severity.error,
        (room, _) {
      assert(room.description.isNotEmpty);
      final firstLetter = room.description[0];
      return firstLetter == firstLetter.toUpperCase();
    }),
    RoomRule('the description must end with a period', Severity.error,
        (room, _) {
      assert(room.description.isNotEmpty);
      return room.description[room.description.length - 1] == '.';
    }),
    RoomRule('the description must be grammatically sound', Severity.warning,
        (room, n) {
      assert(room.description.isNotEmpty);
      return lintDescription(n, room.description);
    }),
    RoomRule('the room should have a "back" exit', Severity.warning, (room, _) {
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
  final dynamic Function(Room room, Notifier n) check;
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

int skipWord(String text, int from, int count, {bool forward = true}) {
  if (count == 0) return from;
  final fun = forward ? text.indexOf : text.lastIndexOf;
  var i = fun(RegExp(r'\s+'), from + (forward ? 1 : -1));
  if (i == -1) {
    return forward ? text.length : 0;
  } else {
    return skipWord(text, i, count - 1, forward: forward);
  }
}

Future<bool> lintDescription(Notifier n, String text) async {
  final cookie = Platform.environment['PWA_COOKIE'];
  assert(cookie != null);

  final response = await http.post(
      Uri.parse('https://cloud.prowritingaid.com/analysis//api/async/text'),
      headers: {
        'cookie': cookie!,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'Text': text,
        'Language': 'en',
        'Style': 'Creative',
        'Reports': ['grammarheavy'],
      }));
  final data =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  final result = data['Result'] as Map<String, dynamic>;

  final tags = result['Tags'] as List;
  for (final t in tags) {
    final startPos = t['startPos'] as int;
    final endPos = (t['endPos'] as int) + 1;

    final printStart = skipWord(text, startPos, 3, forward: false);
    final printEnd = skipWord(text, endPos, 3, forward: true);
    final trimmedStart = printStart != 0;
    final trimmedEnd = printStart != 0;

    var message =
        '${trimmedStart ? '... ' : ''}${text.substring(printStart, printEnd)}${trimmedEnd ? ' ...' : ''}\n';
    message +=
        '${trimmedStart ? '    ' : ''}${' ' * (startPos - printStart)}${'^' * (endPos - startPos)}\n\n';
    message += '${t['hint']}\n';

    final suggestions = t['suggestions'] as List;
    if (suggestions.length == 1) {
      message += 'Suggestion: `${suggestions.first}`\n';
    } else {
      message += 'Suggestions:\n';
      for (final s in t['suggestions']) {
        message += '  `$s`\n';
      }
    }

    n.out(message);
  }
  return tags.isEmpty;
}
