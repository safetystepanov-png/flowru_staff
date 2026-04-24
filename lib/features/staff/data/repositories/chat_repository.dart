import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../../core/config/app_config.dart';
import '../../../auth/data/auth_storage.dart';
import '../models/chat_message.dart';

class ChatRepository {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    headers: {'Accept': 'application/json'},
  ));

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) throw Exception('No access token');
    return {'Authorization': 'Bearer $token'};
  }

    Future<List<ChatMessage>> getMessages(int establishmentId, {int page = 1, int limit = 30}) async {
    final headers = await _authHeaders();
    final response = await _dio.get(
        '/api/v1/staff/chat/messages',
        queryParameters: {
        'establishment_id': establishmentId,
        'page': page,
        'limit': limit,
        },
        options: Options(headers: headers),
    );
    if (response.statusCode != 200) throw Exception('Failed to load messages');
    final data = response.data;
    final List list = (data is List) ? data : (data['items'] as List);
    return list.map((j) => ChatMessage.fromJson(j as Map<String, dynamic>)).toList();
    }

  Future<void> sendTextMessage(int establishmentId, String text, {String? replyToId}) async {
    final headers = await _authHeaders();
    await _dio.post(
      '/api/v1/staff/chat/messages',
      data: {
        'establishment_id': establishmentId,
        'message_text': text,
        if (replyToId != null) 'reply_to_message_id': replyToId,
      },
      options: Options(headers: headers),
    );
  }

    Future<void> sendImageMessage(int establishmentId, Uint8List bytes, String filename,
        {String? text, String? replyToId}) async {
    final headers = await _authHeaders();
    final formData = FormData.fromMap({
        'establishment_id': establishmentId,
        if (text != null && text.isNotEmpty) 'message_text': text,
        if (replyToId != null) 'reply_to_message_id': replyToId,
        'file': MultipartFile.fromBytes(bytes,
            filename: filename, contentType: MediaType('image', 'jpeg'))
    });
    await _dio.post('/api/v1/staff/chat/messages/upload-image',
        data: formData, options: Options(headers: headers));
    }
  // Остальные методы (изображения, файлы, голосовые, редактирование, удаление, реакции, закреп) добавим на следующем этапе.
  // Сейчас для базовой проверки хватит getMessages и sendTextMessage.
}