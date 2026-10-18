import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../auth/data/auth_storage.dart';
import '../../auth/data/user_api.dart';
class DeliveryWorkApi {
  Future<Map<String,dynamic>> request(String path,{Map<String,dynamic>? data}) async {
    var token=await AuthStorage.getAccessToken();
    if(token==null || token.isEmpty) throw Exception('Войдите в аккаунт заново');
    Future<http.Response> send(String t) {
      final uri=Uri.parse('${AppConfig.baseUrl}/api/v1$path');
      final headers={'Authorization':'Bearer $t','Accept':'application/json','Content-Type':'application/json'};
      return (data==null ? http.get(uri,headers:headers) : http.post(uri,headers:headers,body:jsonEncode(data))).timeout(const Duration(seconds:25));
    }
    var response=await send(token);
    if(response.statusCode==401) {
      final refresh=await AuthStorage.getRefreshToken();
      if(refresh==null || refresh.isEmpty) throw Exception('Войдите в аккаунт заново');
      final auth=await UserApi().refresh(refreshToken:refresh,deviceId:kIsWeb?'staff-web':'staff-mobile',platform:kIsWeb?'web':'mobile');
      if(!auth.ok || auth.accessToken.isEmpty) throw Exception('Войдите в аккаунт заново');
      await AuthStorage.saveAccessToken(auth.accessToken);
      if(auth.refreshToken.isNotEmpty) await AuthStorage.saveRefreshToken(auth.refreshToken);
      response=await send(auth.accessToken);
    }
    dynamic decoded;
    try{decoded=jsonDecode(utf8.decode(response.bodyBytes));}catch(_){throw Exception('Не удалось получить ответ. Попробуйте ещё раз');}
    if(response.statusCode<200 || response.statusCode>=300) {
      throw Exception(decoded is Map && decoded['detail'] is String ? decoded['detail'] : 'Не удалось выполнить действие');
    }
    return Map<String,dynamic>.from(decoded as Map);
  }
}
