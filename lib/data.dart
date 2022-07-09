import 'dart:convert';
import 'dart:io';

import 'package:glog/glog.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

part 'data.g.dart';

@JsonSerializable()
class AuthInfo {
  final String? username;
  final String? password;
  final String? characterName;
  final String? characterSurname;
  final String? authEnv;

  AuthInfo({
    this.username,
    this.password,
    this.characterName,
    this.characterSurname,
    this.authEnv,
  });

  factory AuthInfo.fromJson(Map<String, dynamic> json) =>
      _$AuthInfoFromJson(json);

  Map<String, dynamic> toJson() => _$AuthInfoToJson(this);
}

@JsonSerializable()
class Shard {
  final List<Room> rooms;
  final AuthInfo authInfo;
  final ExitMessages? defaultExitMessages;

  Shard(
      {required this.rooms, required this.authInfo, this.defaultExitMessages});

  factory Shard.fromJson(Map<String, dynamic> json) {
    var sh = _$ShardFromJson(json);
    sh = sh._resolveAuth();
    sh = sh._resolveExits();
    return sh;
  }

  Map<String, dynamic> toJson() => _$ShardToJson(this);

  Shard _resolveAuth() {
    var ai = authInfo;
    if (ai.authEnv != null) {
      final authData = Platform.environment[ai.authEnv]!;
      final authJson = jsonDecode(authData);
      ai = AuthInfo.fromJson(authJson);
    }
    return Shard(
        rooms: rooms, defaultExitMessages: defaultExitMessages, authInfo: ai);
  }

  Shard _resolveExits() {
    return Shard(
        rooms: rooms.map((room) {
          var idx = 0;
          final exits = room.exits.map((e) {
            var name = e.name;
            var keywords = e.keywords;
            var to = e.to;
            final back = e.back;
            bool hasCustomKeywords = keywords != null;

            if (back != null) {
              // if aliased via back: add the "back" kw as the first one
              to ??= back;
              keywords = keywords == null ? ['back'] : ['back', ...keywords];
              name ??= rooms.firstWhere((r) => r.tid == back).name;
            }

            assert(to != null);

            String targetId;
            Room? targetRoom;
            if (to!.startsWith('#')) {
              // if the target is a specific room id we're done here
              targetId = to.substring(1);
            } else {
              try {
                targetRoom = rooms.firstWhere((r) => r.tid == to);
                targetId = rooms.firstWhere((r) => r.tid == to).id ?? '';

                // if there's no name, use the target room name
                name ??= targetRoom.name;

                // if there are no kws, use the default; the "back" still goes first
                if (!hasCustomKeywords && targetRoom.designatedExits != null) {
                  if (back != null) {
                    keywords!.insertAll(1, targetRoom.designatedExits!);
                  } else {
                    keywords = targetRoom.designatedExits;
                  }
                }

                // if there are still no keywords, add the room's tid as one
                keywords ??= [to];
              } catch (e) {
                logger.fatal(
                    'cannot find room for exit $to in room ${room.name}');
                rethrow;
              }
            }

            final roomMessages = e.messages ??
                defaultExitMessages ??
                ExitMessages(leave: '', arrive: '', travel: '');

            final messages = ExitMessages(
              leave: targetRoom != null
                  ? roomMessages.leave
                      .replaceAll('\$SHORT', targetRoom.exitName)
                      .replaceAll('\$NAME', targetRoom.name)
                  : roomMessages.leave,
              arrive: roomMessages.arrive
                  .replaceAll('\$SHORT', room.exitName)
                  .replaceAll('\$NAME', room.name),
              travel: targetRoom != null
                  ? roomMessages.travel
                      .replaceAll('\$SHORT', targetRoom.exitName)
                      .replaceAll('\$NAME', targetRoom.name)
                  : roomMessages.travel,
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
  @JsonKey(readValue: parseMaybeList)
  final List<String>? designatedExits;

  Room(
      {required this.tid,
      this.id,
      required this.name,
      required this.exitName,
      required this.description,
      required this.exits,
      this.designatedExits});

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);

  Map<String, dynamic> toJson() => _$RoomToJson(this);

  static _readExitName(Map m, String k) =>
      m[k] ?? (m['name'] as String).toLowerCase();
  static _readDescription(Map m, String k) => (m[k] as String).trim();
}

@JsonSerializable()
class Exit {
  final String? name;
  final String? to;
  final String? back;
  final ExitMessages? messages;

  @JsonKey(readValue: parseMaybeList)
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

parseMaybeList(Map m, String k) => m[k] is String ? [m[k]] : m[k];
