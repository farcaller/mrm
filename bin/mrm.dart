import 'package:args/command_runner.dart';
import 'package:glog/glog.dart';
import 'package:mrm/commands/lint.dart';
import 'package:mrm/commands/sync_shard.dart';
import 'package:mrm/commands/sync_room.dart';

void main(List<String> arguments) {
  GlogLogger.global.mutedContexts.add('res_client');
  GlogLogger.global.mutedContexts.add('res_model');
  final runner = CommandRunner('mucklet_roomer', 'The mucklet room manager')
    ..addCommand(SyncRoom())
    ..addCommand(SyncShard())
    ..addCommand(Lint())
    ..run(arguments);
}
