import 'package:args/command_runner.dart';
import 'package:glog/glog.dart';
import 'package:mrm/agent.dart';

import '../data.dart';
import '../notifier.dart';
import 'common.dart';

const logger = GlogContext('sync');

class Sync extends Command with CommonFlags {
  @override
  final name = 'sync';
  @override
  final description = 'sync the whole shard';

  Sync() {
    argParser.addOption('room', abbr: 'r');
    argParser.addFlag('apply');
    setupCommonArgs();
  }

  @override
  void run() async {
    final roomToSync = argResults?['room'];

    final shard = await loadShard(argShard);
    final n = Notifier();
    final agent = Agent(shard);
    await agent.init();

    try {
      for (final room in shard.rooms) {
        if (roomToSync != null && roomToSync != room.tid) continue;
        await agent.performSyncRoom(room.tid, n, argResults!['apply'] == true);
      }
    } catch (e, s) {
      logger.fatal('failed: $e\n${s.toString()}');
    }

    agent.dispose();
  }
}
