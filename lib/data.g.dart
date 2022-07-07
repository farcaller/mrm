// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthInfo _$AuthInfoFromJson(Map<String, dynamic> json) => AuthInfo(
      username: json['username'] as String,
      password: json['password'] as String,
      characterName: json['characterName'] as String,
      characterSurname: json['characterSurname'] as String,
    );

Map<String, dynamic> _$AuthInfoToJson(AuthInfo instance) => <String, dynamic>{
      'username': instance.username,
      'password': instance.password,
      'characterName': instance.characterName,
      'characterSurname': instance.characterSurname,
    };

Shard _$ShardFromJson(Map<String, dynamic> json) => Shard(
      rooms: (json['rooms'] as List<dynamic>)
          .map((e) => Room.fromJson(e as Map<String, dynamic>))
          .toList(),
      authInfo: AuthInfo.fromJson(json['authInfo'] as Map<String, dynamic>),
      defaultExitMessages: json['defaultExitMessages'] == null
          ? null
          : ExitMessages.fromJson(
              json['defaultExitMessages'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ShardToJson(Shard instance) => <String, dynamic>{
      'rooms': instance.rooms,
      'authInfo': instance.authInfo,
      'defaultExitMessages': instance.defaultExitMessages,
    };

Room _$RoomFromJson(Map<String, dynamic> json) => Room(
      tid: json['tid'] as String,
      id: json['id'] as String?,
      name: json['name'] as String,
      exitName: Room._readExitName(json, 'exitName') as String,
      description: Room._readDescription(json, 'description') as String,
      exits: (json['exits'] as List<dynamic>)
          .map((e) => Exit.fromJson(e as Map<String, dynamic>))
          .toList(),
      designatedExits:
          (parseMaybeList(json, 'designatedExits') as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
    );

Map<String, dynamic> _$RoomToJson(Room instance) => <String, dynamic>{
      'tid': instance.tid,
      'id': instance.id,
      'name': instance.name,
      'exitName': instance.exitName,
      'description': instance.description,
      'exits': instance.exits,
      'designatedExits': instance.designatedExits,
    };

Exit _$ExitFromJson(Map<String, dynamic> json) => Exit(
      name: json['name'] as String?,
      to: json['to'] as String?,
      back: json['back'] as String?,
      keywords: (parseMaybeList(json, 'keywords') as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      messages: json['messages'] == null
          ? null
          : ExitMessages.fromJson(json['messages'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ExitToJson(Exit instance) => <String, dynamic>{
      'name': instance.name,
      'to': instance.to,
      'back': instance.back,
      'messages': instance.messages,
      'keywords': instance.keywords,
    };

ExitMessages _$ExitMessagesFromJson(Map<String, dynamic> json) => ExitMessages(
      leave: json['leave'] as String,
      arrive: json['arrive'] as String,
      travel: json['travel'] as String,
    );

Map<String, dynamic> _$ExitMessagesToJson(ExitMessages instance) =>
    <String, dynamic>{
      'leave': instance.leave,
      'arrive': instance.arrive,
      'travel': instance.travel,
    };
