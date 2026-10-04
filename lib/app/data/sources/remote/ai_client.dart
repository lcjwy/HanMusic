import 'dart:async';
import 'dart:convert';

import 'package:han_music/app/core/constants/app_constants.dart';
import 'package:han_music/app/core/exceptions/app_exception.dart';
import 'package:http/http.dart' as http;

/// OpenAI 兼容 Chat Completions 客户端：阶跃星辰 / 智谱 / DeepSeek
/// 三家均兼容该协议，按 [baseUrl] 区分供应商。
/// 异常统一转 [AppException]，message 为用户可读文案。
class AiClient {
  AiClient({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// 供应商 API 根地址（如 https://api.deepseek.com/v1，不含尾斜杠）。
  final String baseUrl;
  final String apiKey;
  final String model;

  final http.Client _client;

  void close() => _client.close();

  /// 发起一次对话补全，返回首个回复文本。
  Future<String> chat({
    required String system,
    required String user,
  }) async {
    final uri = Uri.parse(
      baseUrl.endsWith('/') ? '$baseUrl/chat/completions' : '$baseUrl/chat/completions',
    );
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
              'temperature': 0.3,
              'stream': false,
            }),
          )
          .timeout(AppConstants.aiRequestTimeout);
    } on TimeoutException {
      throw const AppException('AI 服务连接超时，请检查网络后重试');
    } on Exception catch (e) {
      throw AppException('无法连接 AI 服务', cause: e);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AppException('AI Key 无效或无权限，请检查后重新填写');
    }
    if (response.statusCode == 402) {
      throw const AppException('AI 账户余额不足，请充值后重试');
    }
    if (response.statusCode == 429) {
      throw const AppException('请求过于频繁，请稍后重试');
    }
    if (response.statusCode != 200) {
      throw AppException('AI 服务响应异常（HTTP ${response.statusCode}）');
    }

    final Object? content;
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = data['choices'];
      content = choices is List && choices.isNotEmpty
          ? ((choices.first as Map)['message'] as Map)['content']
          : null;
    } on FormatException {
      throw const AppException('AI 服务返回内容无法解析');
    }
    final text = content?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw const AppException('AI 未返回内容，请重试');
    }
    return text;
  }
}
