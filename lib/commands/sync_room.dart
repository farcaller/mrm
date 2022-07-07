import 'package:args/command_runner.dart';
import 'package:glog/glog.dart';
import 'package:mrm/agent.dart';

import '../data.dart';
import '../notifier.dart';
import 'common.dart';

const logger = GlogContext('sync_room');

class SyncRoom extends Command with CommonFlags {
  @override
  final name = 'sync-room';
  @override
  final description = 'sync the specified room';

  SyncRoom() {
    argParser.addOption('room', abbr: 'r', mandatory: true);
    argParser.addFlag('apply');
    setupCommonArgs();
  }

  @override
  void run() async {
    final shard = await loadShard(argShard);
    final n = Notifier();
    final agent = Agent(shard);
    await agent.init();

    try {
      await agent.performSyncRoom(
          argResults?['room'], n, argResults!['apply'] == true);
    } catch (e, s) {
      logger.fatal('failed: $e\n$s');
    }
    agent.dispose();
  }
}
