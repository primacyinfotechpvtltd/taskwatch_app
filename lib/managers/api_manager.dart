import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:logger/logger.dart';
import 'package:pi_task_watch/utils/get_secure_http_dio_client.dart';
import 'package:pi_task_watch/utils/log_utils.dart'; // Added

import 'package:pi_task_watch/exports.dart';

enum RequestType { get, post, put, delete, patch, head }

class ApiManager {
  static const bool showLogGlobal = true;
  static const bool showMessageGlobal = false;
  static const bool showLoaderGlobal = false;

  static String get baseUrl => AppConstant.apiBaseUrl;

  static Future<http.Client> get httpClient => getSecureHttpClient();

  static Uri buildUri({
    required String endpoint,
    bool isFullUrl = false,
    Map<String, dynamic>? queryParameters,
  }) {
    // Remove any leading slashes from endpoint to avoid double slashes
    final String cleanEndpoint =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;

    // Create full URL, ensuring no double slashes after the domain
    String url = isFullUrl ? endpoint : "$baseUrl/$cleanEndpoint";

    // Validate URL doesn't contain "null" string as a segment
    // This often happens if some dynamic variable was null during concatenation
    if (url.contains("/null") || url.endsWith("/null")) {
      //LogUtils.e("URL contains 'null' segment: $url");
      // Fix the URL by removing the "null" segment correctly
      final cleanUrl = url.replaceAll("/null", "");
      //LogUtils.i("Cleaned URL: $cleanUrl");

      if (queryParameters != null && queryParameters.isNotEmpty) {
        // Convert all values to strings for the URI builder
        final Map<String, String> stringParams = {};
        queryParameters.forEach((key, value) {
          stringParams[key] = value.toString();
        });
        return Uri.parse(cleanUrl).replace(queryParameters: stringParams);
      }

      return Uri.parse(cleanUrl);
    }

    if (queryParameters != null && queryParameters.isNotEmpty) {
      // Convert all values to strings for the URI builder
      final Map<String, String> stringParams = {};
      queryParameters.forEach((key, value) {
        stringParams[key] = value.toString();
      });
      return Uri.parse(url).replace(queryParameters: stringParams);
    }

    return Uri.parse(url);
  }

  static Future<ApiResponse> request({
    required RequestType type,
    Map<String, dynamic>? data = const <String, dynamic>{},
    required String endPoint,
    bool isFullUrl = false,
    bool showLog = showLogGlobal,
    bool showMessage = showMessageGlobal,
    bool showLoader = showLoaderGlobal,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? customHeaders, // Add custom headers parameter
  }) async {

    try {
      final DateTime startTime = DateTime.now();
      final String requestId = Uuid().v1();

      // Build URI with query parameters
      final uri = buildUri(
        endpoint: endPoint,
        isFullUrl: isFullUrl,
        queryParameters: queryParameters,
      );

      final String requestUrl = uri.toString();
      final jsonBody =
          data != null && data.isNotEmpty ? jsonEncode(data) : null;

      if (showLog) {
        //LogUtils.i("\n" + "=" * 80);
        //LogUtils.i("🌐 [API REQUEST] ${type.name.toUpperCase()}");
        //LogUtils.i("🔗 URL: $requestUrl");
        if (queryParameters != null && queryParameters.isNotEmpty) {
          //LogUtils.i("❓ QUERY PARAMS: $queryParameters");
        }
        if (jsonBody != null) {
          //LogUtils.i("📤 BODY: $jsonBody");
        }
        //LogUtils.i("-" * 80);
      }

      late http.Response rawResponse;

      if (showLoader) {
        LoadingManager.startLoading();
      }

      final client = 1 == 1 ? await httpClient : http.Client();

      // Merge default headers with custom headers
      final mergedHeaders = {...headers(), ...?customHeaders};

      switch (type) {
        case RequestType.get:
          rawResponse = await client.get(uri, headers: mergedHeaders);
          break;
        case RequestType.post:
          rawResponse = await client.post(
            uri,
            headers: mergedHeaders,
            body: jsonBody,
          );
          break;
        case RequestType.put:
          rawResponse = await client.put(
            uri,
            headers: mergedHeaders,
            body: jsonBody,
          );
          break;
        case RequestType.delete:
          rawResponse = await client.delete(
            uri,
            headers: mergedHeaders,
            body: jsonBody,
          );
          break;
        case RequestType.patch:
          rawResponse = await client.patch(
            uri,
            headers: mergedHeaders,
            body: jsonBody,
          );
          break;
        case RequestType.head:
          rawResponse = await client.head(uri, headers: mergedHeaders);
          break;
      }

      if (showLoader) {
        LoadingManager.dismissLoading();
      }

      final DateTime endTime = DateTime.now();
      final Duration duration = endTime.difference(startTime);

      final apiResponse = ApiResponse(
        rawResponse: rawResponse,
        requestId: requestId,
      );

      if (showMessage && apiResponse.message.trim().isNotEmpty) {
        showToast(apiResponse.message, idSuccess: apiResponse.isSuccess);
      }

      if (showLog) {
        //LogUtils.i("📥 [API RESPONSE] ${apiResponse.statusCode}");
        //LogUtils.i("🕒 DURATION: ${duration.inMilliseconds}ms");
        //LogUtils.i("📦 BODY: ${apiResponse.body}");
        //LogUtils.i("=" * 80 + "\n");
      }

      return apiResponse;
    } catch (e) {
      if (showLoader) {
        LoadingManager.dismissLoading();
      }
      //LogUtils.e("API REQUEST EXCEPTION: ${e.toString()}");
      throw Exception(e);
    }
  }

  static Future<ApiResponse> getRequest({
    Map<String, dynamic>? data,
    required String endPoint,
    bool isFullUrl = false,
    bool showLog = showLogGlobal,
    bool showMessage = showMessageGlobal,
    bool showLoader = showLoaderGlobal,
    Map<String, dynamic>? queryParameters,
  }) {
    return ApiManager.request(
      type: RequestType.get,
      data: data,
      endPoint: endPoint,
      isFullUrl: isFullUrl,
      showLog: showLog,
      showMessage: showMessage,
      showLoader: showLoader,
      queryParameters: queryParameters,
    );
  }

  static Future<ApiResponse> postRequest({
    Map<String, dynamic>? data,
    required String endPoint,
    bool isFullUrl = false,
    bool showLog = showLogGlobal,
    bool showMessage = showMessageGlobal,
    bool showLoader = showLoaderGlobal,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? customHeaders,
  }) {
    return ApiManager.request(
      type: RequestType.post,
      data: data,
      endPoint: endPoint,
      isFullUrl: isFullUrl,
      showLog: showLog,
      showMessage: showMessage,
      showLoader: showLoader,
      queryParameters: queryParameters,
      customHeaders: customHeaders,
    );
  }

  static Future<ApiResponse> putRequest({
    Map<String, dynamic>? data,
    required String endPoint,
    bool isFullUrl = false,
    bool showLog = showLogGlobal,
    bool showMessage = showMessageGlobal,
    bool showLoader = showLoaderGlobal,
    Map<String, dynamic>? queryParameters,
  }) {
    return ApiManager.request(
      type: RequestType.put,
      data: data,
      endPoint: endPoint,
      isFullUrl: isFullUrl,
      showLog: showLog,
      showMessage: showMessage,
      showLoader: showLoader,
      queryParameters: queryParameters,
    );
  }

  static Future<ApiResponse> patchRequest({
    Map<String, dynamic>? data,
    required String endPoint,
    bool isFullUrl = false,
    bool showLog = showLogGlobal,
    bool showMessage = showMessageGlobal,
    bool showLoader = showLoaderGlobal,
    Map<String, dynamic>? queryParameters,
  }) {
    return ApiManager.request(
      type: RequestType.patch,
      data: data,
      endPoint: endPoint,
      isFullUrl: isFullUrl,
      showLog: showLog,
      showMessage: showMessage,
      showLoader: showLoader,
      queryParameters: queryParameters,
    );
  }

  static Future<ApiResponse> deleteRequest({
    Map<String, dynamic>? data,
    required String endPoint,
    bool isFullUrl = false,
    bool showLog = showLogGlobal,
    bool showMessage = showMessageGlobal,
    bool showLoader = showLoaderGlobal,
    Map<String, dynamic>? queryParameters,
  }) {
    return ApiManager.request(
      type: RequestType.delete,
      data: data,
      endPoint: endPoint,
      isFullUrl: isFullUrl,
      showLog: showLog,
      showMessage: showMessage,
      showLoader: showLoader,
      queryParameters: queryParameters,
    );
  }

  static Future<ApiResponse> headRequest({
    Map<String, dynamic>? data,
    required String endPoint,
    bool isFullUrl = false,
    bool showLog = showLogGlobal,
    bool showMessage = showMessageGlobal,
    bool showLoader = showLoaderGlobal,
    Map<String, dynamic>? queryParameters,
  }) {
    return ApiManager.request(
      type: RequestType.head,
      data: data,
      endPoint: endPoint,
      isFullUrl: isFullUrl,
      showLog: showLog,
      showMessage: showMessage,
      showLoader: showLoader,
      queryParameters: queryParameters,
    );
  }

  static Map<String, String> headers() {
    final token = Get.find<AuthController>().user.value?.token;
    return <String, String>{
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-Requested-With": "XMLHttpRequest",
      "Access-Control-Allow-Origin": "*",
      if (token != null) "Authorization": "Bearer $token",
      if (OdooRpcApiManager.currentDatabase != null)
        "X-Odoo-Database": OdooRpcApiManager.currentDatabase!,
      // add standers session cockie header
      // "Cookie": "session=${OdooRpcApiManager.currentSessionId}",
      // "Cookie": "session_id=${OdooRpcApiManager.currentSessionId}",
      "Cookie":
          "session=${OdooRpcApiManager.currentSessionId}; session_id=${OdooRpcApiManager.currentSessionId}",

      // add any other headers you need
    };
  }
}

class ApiResponse<T> {
  final String requestId;
  final http.Response rawResponse;

  dynamic get body {
    dynamic r;
    try {
      r = jsonDecode(rawResponse.body);
    } catch (e) {
      print("""
        
      ---------- RESPONSE ----------
      
      ID: $requestId      
      RAW RESPONSE BODY: ${rawResponse.body}

      ---------- RESPONSE ----------
      
      """);
    }
    return r;
  }

  bool get isSuccess {
    if (body == null || body is! Map) return false;
    return body['success'] == true ||
        body['status'] == 'success' ||
        body['status'] == 'ok' ||
        body['status'] == '1' ||
        body['status'] == 1;
  }

  bool get isNotSuccess => !isSuccess;

  String get message => "${body['message'] ?? ""}";

  dynamic get data => body['data'];

  int get statusCode => rawResponse.statusCode;

  bool get isSuccessStatusCode => statusCode >= 200 && statusCode < 300;

  ApiResponse({required this.rawResponse, required this.requestId});

  // withG<T>() {}
}
