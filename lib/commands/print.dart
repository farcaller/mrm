import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:args/command_runner.dart';
import 'package:glog/glog.dart';
import '../data.dart';
import '../notifier.dart';
import 'common.dart';

const logger = GlogContext('print_room');

class Print extends Command with CommonFlags {
  @override
  final name = 'print';
  @override
  final description = 'print the shard';

  Print() {
    argParser.addOption('room', abbr: 'r');
    argParser.addFlag('description', abbr: 'd');
    setupCommonArgs();
  }

  @override
  void run() async {
    final shard = await loadShard(argShard);

    for (final room in shard.rooms) {
      print('## ${room.name} <a name="${room.tid}">');
      // print('## ${room.name}');
      print('##### tid `${room.tid}` id `#${room.id}`\n');
      if (argResults?['description'] == true) {
        print('${room.description}\n');
      }
      if (room.exits.isNotEmpty) {
        print('### Exits');
      }
      for (final exit in room.exits) {
        print('* ${exit.name} &rarr; [${exit.to}](#${exit.to})');
        // print('* ${exit.name} to `${exit.to}`');
        print('  - keywords: ${exit.keywords?.map((k) => '`$k`').join(', ')}');
        print('  - messages:');
        print('    - leaves: ${exit.messages?.leave}');
        print('    - arrives: ${exit.messages?.arrive}');
        print('    - travels: ${exit.messages?.travel}');
      }
      print('');
    }
  }
}
