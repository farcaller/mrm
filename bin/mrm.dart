import 'package:args/command_runner.dart';
import 'package:glog/glog.dart';
import 'package:mrm/commands/lint.dart';
import 'package:mrm/commands/print.dart';
import 'package:mrm/commands/sync.dart';

void main(List<String> arguments) {
  GlogLogger.global.mutedContexts.add('res_client');
  GlogLogger.global.mutedContexts.add('res_model');
  final runner = CommandRunner('mucklet_roomer', 'The mucklet room manager')
    ..addCommand(Sync())
    ..addCommand(Lint())
    ..addCommand(Print())
    ..run(arguments);
}
