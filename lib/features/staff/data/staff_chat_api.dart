import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';

class StaffChatMessageItem {
  final String messageId;
  final int establishmentId;
  final String senderUserId;
  final String senderName;
  final String messageText;
  final String createdAt;
  final String? imageUrl;

  StaffChatMessageItem({
    required this.messageId,
    required this.establishmentId,
    required this.senderUserId,
    required this.senderName,
    required this.messageText,
    required this.createdAt,
    required this.imageUrl,
  });

  factory StaffChatMessageItem.fromJson(Map<String, dynamic> json) {
    return StaffChatMessageItem(
      messageId: json['message_id']?.toString() ?? '',
      establishmentId: (json['establishment_id'] as num?)?.toInt() ?? 0,
      senderUserId: json['sender_user_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? 'Сотрудник',
      messageText: json['message_text']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
    );
  }
}

class StaffChatSendResult {
  final bool ok;
  final String message;

  StaffChatSendResult({
    required this.ok,
    required this.message,
  });

  factory StaffChatSendResult.fromJson(Map<String, dynamic> json) {
    return StaffChatSendResult(
      ok: json['ok'] as bool? ?? false,
      message: json['message']?.toString() ?? '',
    );
  }
}

class StaffChatApi {
  Future<String> _token() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Access token not found');
    }
    return token;
  }

  Future<List<StaffChatMessageItem>> getMessages({
    required int establishmentId,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/chat/messages-feed?establishment_id=$establishmentId',
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'GET chat/messages-feed failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as List<dynamic>;

    return data
        .map((e) => StaffChatMessageItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StaffChatSendResult> sendMessage({
    required int establishmentId,
    required String text,
  }) async {
    final token = await _token();

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/api/v1/staff/chat/messages',
    );

    final response = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'establishment_id': establishmentId,
        'message_text': text,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'POST chat/messages failed: ${response.statusCode} ${response.body}',
      );
    }

    return StaffChatSendResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<StaffChatSendResult> sendImageMessage({
    required int establishmentId,
    required List<int> bytes,
    required String filename,
    String? caption,
  }) async {
    final token = await _token();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/api/v1/staff/chat/messages/image'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['establishment_id'] = establishmentId.toString();
    request.fields['message_text'] = caption ?? '';

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(
        'POST chat/messages/image failed: ${response.statusCode} ${response.body}',
      );
    }

    return StaffChatSendResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}