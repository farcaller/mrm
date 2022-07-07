import 'package:args/command_runner.dart';

mixin CommonFlags on Command {
  setupCommonArgs() {
    argParser.addOption('shard', abbr: 's', mandatory: true);
  }

  String get argShard => argResults?['shard'];
}
