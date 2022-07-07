import 'dart:convert';
import 'dart:io';

import 'package:glog/glog.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

part 'data.g.dart';

@JsonSerializable()
class AuthInfo {
  final String username;
  final String password;
  final String characterName;
  final String characterSurname;

  AuthInfo(
      {required this.username,
      required this.password,
      required this.characterName,
      required this.characterSurname});

  factory AuthInfo.fromJson(Map<String, dynamic> json) =>
      _$AuthInfoFromJson(json);

  Map<String, dynamic> toJson() => _$AuthInfoToJson(this);
}

@JsonSerializable()
class Shard {
  final List<Room> rooms;
  final AuthInfo authInfo;

  Shard({required this.rooms, required this.authInfo});

  factory Shard.fromJson(Map<String, dynamic> json) {
    var sh = _$ShardFromJson(json);
    sh = sh._resolveExits();
    return sh;
  }

  Map<String, dynamic> toJson() => _$ShardToJson(this);

  Shard _resolveExits() {
    return Shard(
        rooms: rooms.map((room) {
          var idx = 0;
          final exits = room.exits.map((e) {
            var name = e.name;
            var keywords = e.keywords;
            var to = e.to;
            final back = e.back;

            if (back != null) {
              to ??= back;
              keywords = keywords == null ? ['back'] : ['back', ...keywords];
              name ??= rooms.firstWhere((r) => r.tid == back).name;
            }
            if (to != null) {
              keywords ??= [to];
              try {
                name ??= rooms.firstWhere((r) => r.tid == to).name;
              } catch (e) {
                logger.fatal(
                    'cannot find room for exit $to in room ${room.name}');
                rethrow;
              }
            }
            assert(to != null);

            String targetId;
            Room? targetRoom;
            if (to!.startsWith('#')) {
              targetId = to.substring(1);
            } else {
              try {
                targetRoom = rooms.firstWhere((r) => r.tid == to);
                targetId = rooms.firstWhere((r) => r.tid == to).id ?? '';
              } catch (e) {
                logger.fatal(
                    'cannot find room for exit $to in room ${room.name}');
                rethrow;
              }
            }

            final messages = ExitMessages(
              leave: targetRoom != null
                  ? e.messages!.leave
                      .replaceAll('\$SHORT', targetRoom.exitName)
                      .replaceAll('\$NAME', targetRoom.name)
                  : e.messages!.leave,
              arrive: e.messages!.arrive
                  .replaceAll('\$SHORT', room.exitName)
                  .replaceAll('\$NAME', room.name),
              travel: targetRoom != null
                  ? e.messages!.travel
                      .replaceAll('\$SHORT', targetRoom.exitName)
                      .replaceAll('\$NAME', targetRoom.name)
                  : e.messages!.travel,
            );

            return Exit(
              name: name,
              keywords: keywords,
              to: to,
              back: back,
              messages: messages,
              targetRoomID: targetId,
              exitOrder: idx++,
            );
          }).toList();
          return Room(
              id: room.id,
              tid: room.tid,
              name: room.name,
              exitName: room.exitName,
              description: room.description,
              exits: exits);
        }).toList(),
        authInfo: authInfo);
  }
}

@JsonSerializable()
class Room {
  final String tid;
  final String? id;
  final String name;
  @JsonKey(readValue: _readExitName)
  final String exitName;
  @JsonKey(readValue: _readDescription)
  final String description;
  final List<Exit> exits;

  Room(
      {required this.tid,
      this.id,
      required this.name,
      required this.exitName,
      required this.description,
      required this.exits});

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);

  Map<String, dynamic> toJson() => _$RoomToJson(this);

  static _readExitName(Map m, String k) => m[k] ?? m['name'];
  static _readDescription(Map m, String k) => (m[k] as String).trim();
}

@JsonSerializable()
class Exit {
  final String? name;
  final String? to;
  final String? back;
  final ExitMessages? messages;

  @JsonKey(readValue: _readKeywords)
  final List<String>? keywords;

  @JsonKey(ignore: true)
  final String? targetRoomID;
  @JsonKey(ignore: true)
  String? exitId;
  @JsonKey(ignore: true)
  final int? exitOrder;

  Exit(
      {this.name,
      this.to,
      this.back,
      required this.keywords,
      required this.messages,
      this.targetRoomID,
      this.exitOrder});

  factory Exit.fromJson(Map<String, dynamic> json) => _$ExitFromJson(json);

  Map<String, dynamic> toJson() => _$ExitToJson(this);

  static _readKeywords(Map m, String k) => m[k] is String ? [m[k]] : m[k];
}

@JsonSerializable()
class ExitMessages {
  final String leave;
  final String arrive;
  final String travel;

  ExitMessages({
    required this.leave,
    required this.arrive,
    required this.travel,
  });

  factory ExitMessages.fromJson(Map<String, dynamic> json) =>
      _$ExitMessagesFromJson(json);

  Map<String, dynamic> toJson() => _$ExitMessagesToJson(this);
}

const logger = GlogContext('data');

Future<Shard> loadShard(String fileName) async {
  final bytes = await File(fileName).readAsString();
  final data = jsonEncode(loadYaml(bytes));
  final shard = Shard.fromJson(jsonDecode(data));
  return shard;
}
