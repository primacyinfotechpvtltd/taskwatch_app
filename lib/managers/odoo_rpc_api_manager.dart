import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import 'package:pi_task_watch/utils/get_secure_http_dio_client.dart';
import 'package:pi_task_watch/constants/app_constants.dart';

class OdooException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const OdooException(this.message, {this.code, this.details});

  @override
  String toString() {
    if (code != null) {
      return 'OdooException [$code]: $message';
    }
    return 'OdooException: $message';
  }
}

class OdooResponse<T> {
  final String requestId;
  final dio.Response rawResponse;
  final bool isOdooRpc;

  OdooResponse({
    required this.rawResponse,
    required this.requestId,
    this.isOdooRpc = false,
  });

  factory OdooResponse.success({
    required T data,
    required String message,
    required String requestId,
  }) {
    final response = dio.Response(
      data: {'result': data, 'success': true, 'message': message},
      statusCode: 200,
      requestOptions: dio.RequestOptions(path: ''),
    );

    return OdooResponse<T>(
      rawResponse: response,
      requestId: requestId,
      isOdooRpc: true,
    );
  }

  factory OdooResponse.error({
    required String message,
    required String requestId,
    int statusCode = 400,
  }) {
    final response = dio.Response(
      data: {
        'error': {'message': message},
        'success': false,
        'message': message,
      },
      statusCode: statusCode,
      requestOptions: dio.RequestOptions(path: ''),
    );

    return OdooResponse<T>(
      rawResponse: response,
      requestId: requestId,
      isOdooRpc: true,
    );
  }

  dynamic get rawData {
    try {
      if (rawResponse.data is String) {
        return jsonDecode(rawResponse.data);
      }
      return rawResponse.data;
    } catch (e) {
      return rawResponse.data;
    }
  }

  T? get data {
    if (isOdooRpc && rawData is Map) {
      final Map<String, dynamic> responseMap = rawData;

      dynamic result;
      if (responseMap.containsKey('result')) {
        result = responseMap['result'];
      } else if (responseMap.containsKey('data')) {
        result = responseMap['data'];
      } else {
        result = rawData;
      }

      // Safe type casting with fallback handling
      try {
        return result as T?;
      } catch (e) {
        // Log the type mismatch for debugging
        print(
          'OdooResponse: Type cast failed. Expected: $T, Got: ${result.runtimeType}',
        );
        print('OdooResponse: Result value: $result');

        // Handle common type mismatches
        if (T.toString().contains('List') && result is Map) {
          // If expecting a List but got a Map, wrap it in a list
          print('OdooResponse: Wrapping Map in List for compatibility');
          return [result] as T?;
        } else if (T.toString().contains('Map') &&
            result is List &&
            result.isNotEmpty) {
          // If expecting a Map but got a List, return the first item
          print('OdooResponse: Using first item from List for compatibility');
          return result.first as T?;
        }

        // If no safe conversion is possible, return null and log the issue
        print(
          'OdooResponse: No safe type conversion available, returning null',
        );
        return null;
      }
    }

    // For non-Odoo RPC responses, try direct casting
    try {
      return rawData as T?;
    } catch (e) {
      print(
        'OdooResponse: Direct cast failed. Expected: $T, Got: ${rawData.runtimeType}',
      );
      return null;
    }
  }

  bool get isSuccess {
    if (isOdooRpc && rawData is Map) {
      final Map<String, dynamic> responseMap = rawData;

      if (responseMap.containsKey('error')) {
        return false;
      }

      if (responseMap.containsKey('success')) {
        return responseMap['success'] == true;
      }

      if (responseMap.containsKey('result')) {
        return true;
      }
    }

    return isSuccessStatusCode;
  }

  bool get isError => !isSuccess;

  String get message {
    if (rawData is Map) {
      final Map<String, dynamic> responseMap = rawData;

      if (responseMap.containsKey('error')) {
        final error = responseMap['error'];
        if (error is Map) {
          return error['message']?.toString() ??
              error['data']?['message']?.toString() ??
              'Unknown error';
        }
        return error.toString();
      }

      return responseMap['message']?.toString() ?? '';
    }

    return '';
  }

  int get statusCode => rawResponse.statusCode ?? 0;

  bool get isSuccessStatusCode => statusCode >= 200 && statusCode < 300;
}

class OdooUserInfo {
  final int id;
  final String name;
  final String login;
  final String? email;
  final String? image1920;
  final String? phone;
  final String? mobile;
  final bool active;
  final String? partnerName;
  final int? partnerId;
  final String? companyName;
  final int? companyId;
  final List<int> groupsId;
  final String? lang;
  final String? tz;
  final DateTime? createDate;
  final DateTime? writeDate;
  final String? sessionId;

  const OdooUserInfo({
    required this.id,
    required this.name,
    required this.login,
    this.email,
    this.image1920,
    this.phone,
    this.mobile,
    required this.active,
    this.partnerName,
    this.partnerId,
    this.companyName,
    this.companyId,
    required this.groupsId,
    this.lang,
    this.tz,
    this.createDate,
    this.writeDate,
    this.sessionId,
  });

  factory OdooUserInfo.fromOdooData(
    Map<String, dynamic> data, {
    String? sessionId,
  }) {
    return OdooUserInfo(
      id: data['id'] ?? 0,
      name: data['name']?.toString() ?? '',
      login: data['login']?.toString() ?? '',
      email: data['email']?.toString(),
      image1920: data['image_1920'] is String ? data['image_1920'] : null,
      phone: data['phone']?.toString(),
      mobile: data['mobile']?.toString(),
      active: data['active'] ?? false,
      partnerName:
          data['partner_id'] is List && (data['partner_id'] as List).length > 1
              ? (data['partner_id'] as List)[1]?.toString()
              : null,
      partnerId:
          data['partner_id'] is List && (data['partner_id'] as List).isNotEmpty
              ? (data['partner_id'] as List)[0] as int?
              : data['partner_id'] as int?,
      companyName:
          data['company_id'] is List && (data['company_id'] as List).length > 1
              ? (data['company_id'] as List)[1]?.toString()
              : null,
      companyId:
          data['company_id'] is List && (data['company_id'] as List).isNotEmpty
              ? (data['company_id'] as List)[0] as int?
              : data['company_id'] as int?,
      groupsId: (data['groups_id'] as List?)?.cast<int>() ?? [],
      lang: data['lang']?.toString(),
      tz: data['tz']?.toString(),
      createDate: data['create_date'] != null
          ? DateTime.tryParse(data['create_date'].toString())
          : null,
      writeDate: data['write_date'] != null
          ? DateTime.tryParse(data['write_date'].toString())
          : null,
      sessionId: sessionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'login': login,
      'email': email,
      'image_1920': image1920,
      'phone': phone,
      'mobile': mobile,
      'active': active,
      'partner_name': partnerName,
      'partner_id': partnerId,
      'company_name': companyName,
      'company_id': companyId,
      'groups_id': groupsId,
      'lang': lang,
      'tz': tz,
      'create_date': createDate?.toIso8601String(),
      'write_date': writeDate?.toIso8601String(),
      'session_id': sessionId,
    };
  }

  @override
  String toString() {
    return 'OdooUserInfo(id: $id, name: $name, login: $login, email: $email, sessionId: $sessionId)';
  }
}

enum OdooAuthMode { password, session }

enum OdooDataModelType {
  resUsers('res.users'),
  resPartner('res.partner'),
  resPartnerTitle('res.partner.title'),
  resPartnerCategory('res.partner.category'),
  resCompany('res.company'),
  resCountry('res.country'),
  resCountryState('res.country.state'),
  utmSource('utm.source'),
  utmMedium('utm.medium'),
  utmCampaign('utm.campaign'),
  utm('res.country.state'),

  irAttachment('ir.attachment'),
  irModel('ir.model'),
  irModelFields('ir.model.fields'),

  saleOrder('sale.order'),
  saleOrderLine('sale.order.line'),
  crmLead('crm.lead'),
  // mail.activity
  mailActivity('mail.activity'),
  crmStage('crm.stage'),
  crmTeam('crm.team'),

  purchaseOrder('purchase.order'),
  purchaseOrderLine('purchase.order.line'),

  accountMove('account.move'),
  accountMoveLine('account.move.line'),
  accountJournal('account.journal'),
  accountPayment('account.payment'),
  accountTax('account.tax'),

  productProduct('product.product'),
  productTemplate('product.template'),
  productCategory('product.category'),
  productPricelist('product.pricelist'),
  uomUom('uom.uom'),

  stockPicking('stock.picking'),
  stockMove('stock.move'),
  stockLocation('stock.location'),
  stockWarehouse('stock.warehouse'),
  stockInventory('stock.inventory'),

  hrEmployee('hr.employee'),
  hrDepartment('hr.department'),
  hrJob('hr.job'),
  hrAttendance('hr.attendance'),
  hrLeave('hr.leave'),
  hrPayslip('hr.payslip'),

  projectProject('project.project'),
  projectTask('project.task'),
  accountAnalyticLine('account.analytic.line'),

  website('website'),
  websitePage('website.page'),
  websiteSale('website.sale'),
  blogPost('blog.post'),
  blogTag('blog.tag'),

  helpdeskTicket('helpdesk.ticket'),
  helpdeskTeam('helpdesk.team'),

  marketingAutomation('marketing.automation'),
  mailTemplate('mail.template'),
  mailMessage('mail.message'),

  fleetVehicle('fleet.vehicle'),
  fleetVehicleModel('fleet.vehicle.model'),

  calendarEvent('calendar.event'),
  hrExpense('hr.expense'),

  posOrder('pos.order'),

  resCurrency('res.currency'),
  posSession('pos.session');

  const OdooDataModelType(this.value);
  final String value;

  static OdooDataModelType? fromValue(String modelName) {
    return OdooDataModelType.values.firstWhere(
      (e) => e.value == modelName,
      orElse: () => throw ArgumentError('Unknown model: $modelName'),
    );
  }
}

class OdooRpcApiManager {
  static const bool _defaultShowLog = false;
  static const Duration _defaultTimeout = Duration(seconds: 30);

  static const String _jsonRpcEndpoint = '/jsonrpc';
  static const String _xmlRpcObjectEndpoint = '/xmlrpc/2/object';
  static const String _webSessionEndpoint = '/web/session/authenticate';
  static const String _webDatabaseEndpoint = '/web/database/list';
  static const String _webDatasetCallKwEndpoint = '/web/dataset/call_kw';

  static dio.Dio? _dio;
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 120,
      colors: false,
      printEmojis: true,
      // dateTimeFormat: DateTimeFormat.none,
      noBoxingByDefault: true,
    ),
  );

  static String? _serverUrl;
  static String? _database;
  static String? _username;
  static String? _password;
  static OdooAuthMode _authMode = OdooAuthMode.session;

  static int? _uid;
  static String? _sessionId;
  static DateTime? _lastAuthTime;
  static bool useFullUrl = false;

  static String get _effectiveServerUrl {
    if (_serverUrl != null && _serverUrl!.isNotEmpty) {
      return _serverUrl!;
    }
    return AppConstant.apiServerUrl;
  }

  static Future<dio.Dio> _getDio() async {
    if (_dio == null) {
      _dio = await getSecureDioClient();
      _dio!.options.connectTimeout = _defaultTimeout;
      _dio!.options.receiveTimeout = _defaultTimeout;
      _dio!.options.sendTimeout = _defaultTimeout;

      _dio!.interceptors.add(
        dio.InterceptorsWrapper(
          onRequest: (options, handler) {
            if (_defaultShowLog) {
              _logRequest(options);
            }
            handler.next(options);
          },
          onResponse: (response, handler) {
            if (_defaultShowLog) {
              _logResponse(response);
            }
            handler.next(response);
          },
          onError: (error, handler) {
            if (_defaultShowLog) {
              _logError(error);
            }
            handler.next(error);
          },
        ),
      );
    }
    return _dio!;
  }

  static void configure({
    required String serverUrl,
    String? database,
    String? username,
    String? password,
    OdooAuthMode authMode = OdooAuthMode.session,
  }) {
    _serverUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    _database = database;
    _username = username;
    _password = password;
    _authMode = authMode;

    _clearAuthState();
  }

  static void _clearAuthState() {
    _uid = null;
    _sessionId = null;
    _lastAuthTime = null;
  }

  static Map<String, String> _getHeaders({bool includeSession = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    };

    if (includeSession && _sessionId != null && _sessionId!.isNotEmpty) {
      // Some Odoo versions expect 'session' while others expect 'session_id'
      headers['Cookie'] = 'session=$_sessionId; session_id=$_sessionId';
    }

    return headers;
  }

  static Future<OdooResponse<List<String>>> getDbList({
    String? serverUrl,
    bool showLog = _defaultShowLog,
  }) async {
    try {
      if (serverUrl == null || serverUrl.isEmpty) {
        return OdooResponse<List<String>>.error(
          message: 'Server URL is required',
          requestId: const Uuid().v4(),
        );
      }

      final originalUrl = _serverUrl;
      _serverUrl = serverUrl;

      final response = await _makeJsonRpcCall(
        endpoint: _webDatabaseEndpoint,
        method: 'list',
        params: [],
        includeSession: false,
        showLog: showLog,
      );

      _serverUrl = originalUrl;

      if (response.isSuccess) {
        final databases = <String>[];

        if (response.data is List) {
          databases.addAll(List<String>.from(response.data));
        } else if (response.data is Map && response.data['result'] is List) {
          databases.addAll(List<String>.from(response.data['result']));
        }

        return OdooResponse<List<String>>.success(
          data: databases,
          message: 'Database list retrieved successfully',
          requestId: response.requestId,
        );
      } else {
        return OdooResponse<List<String>>.error(
          message: 'Failed to get database list: ${response.message}',
          requestId: response.requestId,
        );
      }
    } catch (e) {
      if (showLog) {
        _logger.e('Failed to get database list: $e');
      }
      return OdooResponse<List<String>>.error(
        message: 'Failed to get database list: $e',
        requestId: const Uuid().v4(),
      );
    }
  }

  static Future<OdooResponse<Map<String, dynamic>>> getServerInfo({
    String? serverUrl,
    bool showLog = _defaultShowLog,
  }) async {
    try {
      if (serverUrl == null || serverUrl.isEmpty) {
        return OdooResponse<Map<String, dynamic>>.error(
          message: 'Server URL is required',
          requestId: const Uuid().v4(),
        );
      }

      final originalUrl = _serverUrl;
      _serverUrl = serverUrl;

      final response = await _makeJsonRpcCall(
        endpoint: _jsonRpcEndpoint,
        service: 'common',
        method: 'version',
        params: [],
        includeSession: false,
        showLog: showLog,
      );

      _serverUrl = originalUrl;

      if (response.isSuccess) {
        final serverInfo = response.data as Map<String, dynamic>? ?? {};

        return OdooResponse<Map<String, dynamic>>.success(
          data: serverInfo,
          message: 'Server info retrieved successfully',
          requestId: response.requestId,
        );
      } else {
        return OdooResponse<Map<String, dynamic>>.error(
          message: 'Failed to get server info: ${response.message}',
          requestId: response.requestId,
        );
      }
    } catch (e) {
      if (showLog) {
        _logger.e('Failed to get server info: $e');
      }
      return OdooResponse<Map<String, dynamic>>.error(
        message: 'Failed to get server info: $e',
        requestId: const Uuid().v4(),
      );
    }
  }

  static Future<OdooResponse<String>> checkCredentialsAndReturnSession({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
    bool showLog = _defaultShowLog,
  }) async {
    try {
      if (serverUrl.isEmpty) {
        return OdooResponse<String>.error(
          message: 'Server URL is required',
          requestId: const Uuid().v4(),
        );
      }
      if (database.isEmpty) {
        return OdooResponse<String>.error(
          message: 'Database name is required',
          requestId: const Uuid().v4(),
        );
      }
      if (username.isEmpty) {
        return OdooResponse<String>.error(
          message: 'Username is required',
          requestId: const Uuid().v4(),
        );
      }
      if (password.isEmpty) {
        return OdooResponse<String>.error(
          message: 'Password is required',
          requestId: const Uuid().v4(),
        );
      }

      final normalizedUrl = serverUrl.endsWith('/')
          ? serverUrl.substring(0, serverUrl.length - 1)
          : serverUrl;

      if (showLog) {
        _logger.i(
          'Checking credentials for user: $username on database: $database',
        );
      }

      final originalUrl = _serverUrl;
      _serverUrl = normalizedUrl;

      try {
        final authResponse = await _makeJsonRpcCall(
          endpoint: _jsonRpcEndpoint,
          service: 'common',
          method: 'authenticate',
          params: [database, username, password, {}],
          includeSession: false,
          showLog: showLog,
        );

        if (!authResponse.isSuccess ||
            authResponse.data == null ||
            authResponse.data is! int ||
            authResponse.data <= 0) {
          throw OdooException('Authentication failed: Invalid credentials');
        }

        if (showLog) {
          _logger.i('Credentials validated successfully');
        }

        final sessionResponse = await _getWebSession(
          database: database,
          username: username,
          password: password,
          showLog: showLog,
        );

        if (sessionResponse.isSuccess && sessionResponse.data != null) {
          final sessionId = sessionResponse.data!;

          if (showLog) {
            _logger.i('Session obtained: ${sessionId.substring(0, 8)}...');
          }

          return OdooResponse<String>.success(
            data: sessionId,
            message: 'Credentials validated and session created',
            requestId: sessionResponse.requestId,
          );
        } else {
          throw OdooException(
            'Failed to establish session: ${sessionResponse.message}',
          );
        }
      } finally {
        _serverUrl = originalUrl;
      }
    } catch (e) {
      if (showLog) {
        _logger.e('Credential check failed: $e');
      }
      return OdooResponse<String>.error(
        message: 'Credential check failed: $e',
        requestId: const Uuid().v4(),
      );
    }
  }

  static Future<OdooResponse<OdooUserInfo>> authenticate({
    String? serverUrl,
    String? database,
    String? username,
    String? password,
    OdooAuthMode authMode = OdooAuthMode.session,
    bool showLog = _defaultShowLog,
  }) async {
    try {
      final url = serverUrl ?? _effectiveServerUrl;
      final db = database ?? _database;
      final user = username ?? _username;
      final pass = password ?? _password;

      if (url.isEmpty) {
        return OdooResponse<OdooUserInfo>.error(
          message: 'Server URL is required',
          requestId: const Uuid().v4(),
        );
      }
      if (db == null || db.isEmpty) {
        return OdooResponse<OdooUserInfo>.error(
          message: 'Database name is required',
          requestId: const Uuid().v4(),
        );
      }
      if (user == null || user.isEmpty) {
        return OdooResponse<OdooUserInfo>.error(
          message: 'Username is required',
          requestId: const Uuid().v4(),
        );
      }
      if (pass == null || pass.isEmpty) {
        return OdooResponse<OdooUserInfo>.error(
          message: 'Password is required',
          requestId: const Uuid().v4(),
        );
      }

      configure(
        serverUrl: url,
        database: db,
        username: user,
        password: pass,
        authMode: authMode,
      );

      if (showLog) {
        _logger.i('Authenticating user: $user on database: $db');
      }

      final authResponse = await _makeJsonRpcCall(
        endpoint: _jsonRpcEndpoint,
        service: 'common',
        method: 'authenticate',
        params: [db, user, pass, {}],
        includeSession: false,
        showLog: showLog,
      );

      if (!authResponse.isSuccess ||
          authResponse.data == null ||
          authResponse.data is! int ||
          authResponse.data <= 0) {
        throw OdooException('Authentication failed: Invalid credentials');
      }

      _uid = authResponse.data;
      _lastAuthTime = DateTime.now();

      if (showLog) {
        _logger.i('Authentication successful. UID: $_uid');
        _logger.i('Attempting to establish web session...');
      }

      final sessionResponse = await _getWebSession(
        database: db,
        username: user,
        password: pass,
        showLog: showLog,
      );

      if (sessionResponse.isSuccess && sessionResponse.data != null) {
        _sessionId = sessionResponse.data;

        if (showLog) {
          _logger.i(
            '✅ Web session established: ${_sessionId?.substring(0, 8)}...',
          );
        }
      } else {
        if (showLog) {
          _logger.w(
            '⚠️ Failed to establish web session: ${sessionResponse.message}',
          );
          _logger.w('Continuing with UID-based authentication only');
        }
      }

      final userInfo = await _getUserInfo(showLog: showLog);

      if (userInfo.isSuccess) {
        return OdooResponse<OdooUserInfo>.success(
          data: userInfo.data!,
          message: 'Authentication successful',
          requestId: userInfo.requestId,
        );
      } else {
        throw OdooException(
          'Failed to get user information: ${userInfo.message}',
        );
      }
    } catch (e) {
      _clearAuthState();
      if (showLog) {
        _logger.e('Authentication failed: $e');
      }
      return OdooResponse<OdooUserInfo>.error(
        message: 'Authentication failed: $e',
        requestId: const Uuid().v4(),
      );
    }
  }

  static Future<OdooResponse<String?>> _getWebSession({
    required String database,
    required String username,
    required String password,
    bool showLog = false,
  }) async {
    try {
      final dioInstance = await _getDio();
      final baseUrl = _effectiveServerUrl;
      final uri = Uri.parse('$baseUrl$_webSessionEndpoint');

      final requestData = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {'db': database, 'login': username, 'password': password},
        'id': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await dioInstance.post(
        uri.toString(),
        data: jsonEncode(requestData),
        options: dio.Options(headers: _getHeaders(includeSession: false)),
      );

      if (response.statusCode == 200) {
        if (showLog) {
          _logger.d(
            'Web session response cookies: ${response.headers['set-cookie']}',
          );
        }

        final sessionId = _extractSessionFromCookies(
          response.headers['set-cookie'],
        );

        if (sessionId != null) {
          if (showLog) {
            _logger.i(
              '✅ Session extracted from cookies: ${sessionId.substring(0, 8)}...',
            );
          }
          return OdooResponse<String?>.success(
            data: sessionId,
            message: 'Web session established',
            requestId: const Uuid().v4(),
          );
        } else {
          if (showLog) {
            _logger.w('❌ No session ID found in cookies');
          }
        }
      }

      return OdooResponse<String?>.error(
        message: 'Failed to establish web session',
        requestId: const Uuid().v4(),
      );
    } catch (e) {
      return OdooResponse<String?>.error(
        message: 'Web session error: $e',
        requestId: const Uuid().v4(),
      );
    }
  }

  static String? _extractSessionFromCookies(List<String>? cookies) {
    if (cookies == null || cookies.isEmpty) {
      if (_defaultShowLog) {
        _logger.w('No cookies received from server');
      }
      return null;
    }

    if (_defaultShowLog) {
      _logger.d('Extracting session from ${cookies.length} cookies:');
      for (int i = 0; i < cookies.length; i++) {
        _logger.d('Cookie $i: ${cookies[i]}');
      }
    }

    for (final cookie in cookies) {
      final sessionMatch = RegExp(r'session_id=([^;,\s]+)').firstMatch(cookie);
      if (sessionMatch != null) {
        final sessionId = sessionMatch.group(1);
        if (sessionId != null && sessionId.isNotEmpty && sessionId != 'false') {
          if (_defaultShowLog) {
            _logger.i('✅ Found session_id: ${sessionId.substring(0, 8)}...');
          }
          return sessionId;
        }
      }
    }

    if (_defaultShowLog) {
      _logger.w('❌ No valid session_id found in any cookie');
    }
    return null;
  }

  static Future<OdooResponse<OdooUserInfo>> _getUserInfo({
    bool showLog = false,
  }) async {
    if (_uid == null) {
      throw OdooException('Not authenticated');
    }

    try {
      final response = await _executeKw(
        model: 'res.users',
        method: 'read',
        args: [
          [_uid],
          [
            'id',
            'name',
            'login',
            'email',
            'image_1920',
            'phone',
            'mobile',
            'active',
            'partner_id',
            'company_id',
            'groups_id',
            'lang',
            'tz',
            'create_date',
            'write_date',
          ],
        ],
        showLog: showLog,
      );

      if (response.isSuccess && response.data != null) {
        final userData = response.data as List;
        if (userData.isNotEmpty) {
          final userInfo = OdooUserInfo.fromOdooData(
            userData.first,
            sessionId: _sessionId,
          );

          return OdooResponse<OdooUserInfo>.success(
            data: userInfo,
            message: 'User info retrieved',
            requestId: response.requestId,
          );
        }
      }

      throw OdooException('Failed to get user information');
    } catch (e) {
      return OdooResponse<OdooUserInfo>.error(
        message: 'Failed to get user info: $e',
        requestId: const Uuid().v4(),
      );
    }
  }

  static void setSession({
    required String sessionId,
    required int uid,
    required String serverUrl,
    required String database,
    String? username,
    String? password,
    OdooAuthMode authMode = OdooAuthMode.session,
    Map<String, dynamic>? userContext,
  }) {
    _sessionId = sessionId;
    _uid = uid;
    _serverUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    _database = database;
    _username = username;
    _password = password;
    _authMode = authMode;
    _lastAuthTime = DateTime.now();
  }

  static void setSessionId(String sessionId) {
    _sessionId = sessionId;
  }

  static bool get isAuthenticated => _uid != null && _sessionId != null;

  static bool get hasValidSession => isAuthenticated;

  static String? get currentSessionId => _sessionId;

  static int? get currentUserId => _uid;

  static OdooAuthMode get currentAuthMode => _authMode;

  static void setUseFullUrl(bool value) {
    useFullUrl = value;
  }

  static bool get isUsingFullUrl => useFullUrl;

  static Map<String, dynamic> get authenticationState => {
        'isAuthenticated': isAuthenticated,
        'uid': _uid,
        'sessionId':
            _sessionId != null ? '${_sessionId!.substring(0, 8)}...' : null,
        'database': _database,
        'username': _username,
        'serverUrl': _effectiveServerUrl,
        'authMode': _authMode.name,
        'useFullUrl': useFullUrl,
        'lastAuthTime': _lastAuthTime?.toIso8601String(),
      };

  static Future<bool> validateSession({bool showLog = false}) async {
    if (!isAuthenticated) return false;

    try {
      final response = await _executeKw(
        model: 'res.users',
        method: 'read',
        args: [
          [_uid],
          {
            'fields': ['id'],
          },
        ],
        showLog: showLog,
      );

      return response.isSuccess;
    } catch (e) {
      if (showLog) {
        _logger.w('Session validation failed: $e');
      }
      return false;
    }
  }

  static void clearSession() {
    _clearAuthState();
  }

  static void clearAll() {
    _serverUrl = null;
    _database = null;
    _username = null;
    _password = null;
    _clearAuthState();
  }

  static Future<OdooResponse<dynamic>> _executeKw({
    required String model,
    required String method,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    bool showLog = _defaultShowLog,
  }) async {
    if (!isAuthenticated) {
      return OdooResponse<dynamic>.error(
        message:
            'Not authenticated. Call authenticate() or setSession() first.',
        requestId: const Uuid().v4(),
      );
    }

    if (_authMode == OdooAuthMode.password) {
      return await _executeKwPasswordBased(
        model: model,
        method: method,
        args: args,
        kwargs: kwargs,
        showLog: showLog,
      );
    } else {
      return await _executeKwSessionBased(
        model: model,
        method: method,
        args: args,
        kwargs: kwargs,
        showLog: showLog,
      );
    }
  }

  static Future<OdooResponse<dynamic>> _executeKwPasswordBased({
    required String model,
    required String method,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    bool showLog = false,
  }) async {
    if (_password == null || _password!.isEmpty) {
      return OdooResponse<dynamic>.error(
        message: 'Password required for password-based authentication',
        requestId: const Uuid().v4(),
      );
    }

    try {
      final List<dynamic> finalArgs = [];
      final Map<String, dynamic> finalKwargs = {};

      if (kwargs != null) {
        finalKwargs.addAll(kwargs);
      }
      if (args != null) {
        finalArgs.addAll(args);
      }
      final params = [
        _database,
        _uid,
        _password,
        model,
        method,
        finalArgs,
        finalKwargs,
      ];

      final requestId = const Uuid().v4();
      final baseUrl = _effectiveServerUrl;
      final endpoint = '$baseUrl$_xmlRpcObjectEndpoint';

      if (showLog) {
        _logger.d(
          'Making password-based API call to $model.$method via $endpoint',
        );
      }

      final requestData = {
        'jsonrpc': '2.0',
        'method': 'execute_kw',
        'params': params,
        'id': requestId,
      };

      final dioInstance = await _getDio();
      final response = await dioInstance.post(
        endpoint,
        data: jsonEncode(requestData),
        options: dio.Options(headers: _getHeaders(includeSession: false)),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('error')) {
            final error = responseData['error'];
            final errorMessage = _extractErrorMessage(error);
            return OdooResponse<dynamic>.error(
              message: 'API Error: $errorMessage',
              requestId: requestId,
            );
          }

          return OdooResponse<dynamic>.success(
            data: responseData['result'],
            message: 'Request successful',
            requestId: requestId,
          );
        }
      }

      return OdooResponse<dynamic>.error(
        message: 'Invalid response from server',
        requestId: requestId,
      );
    } catch (e) {
      if (showLog) {
        _logger.e('Password-based API call failed: $e');
      }
      return OdooResponse<dynamic>.error(
        message: 'API call failed: $e',
        requestId: const Uuid().v4(),
      );
    }
  }

  static Future<OdooResponse<dynamic>> _executeKwSessionBased({
    required String model,
    required String method,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    bool showLog = false,
  }) async {
    try {
      // Clean separation: positional args stay in finalArgs, keyword args in finalKwargs.
      // All callers must use the kwargs parameter — never append a Map to args.
      final List<dynamic> finalArgs = args != null ? List<dynamic>.from(args) : [];
      final Map<String, dynamic> finalKwargs = kwargs != null ? Map<String, dynamic>.from(kwargs) : {};

      final requestData = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'model': model,
          'method': method,
          'args': finalArgs,
          'kwargs': finalKwargs,
        },
        'id': DateTime.now().millisecondsSinceEpoch,
      };

      final dioInstance = await _getDio();
      final baseUrl = _effectiveServerUrl;
      String endpoint;
      if (useFullUrl) {
        endpoint = '$baseUrl$_webDatasetCallKwEndpoint/$model/$method';
      } else {
        endpoint = '$baseUrl$_webDatasetCallKwEndpoint';
      }

      // Ensure no double slashes after schema (http://)
      if (endpoint.contains('://')) {
        final schemaPart = endpoint.split('://')[0];
        final pathPart = endpoint.split('://')[1].replaceAll('//', '/');
        endpoint = '$schemaPart://$pathPart';
      }

      _logger.i('SESSION_RPC: [START] $model.$method, endpoint=$endpoint, headers=${_getHeaders(includeSession: true)}, requestData=$requestData');

      final response = await dioInstance.post(
        endpoint,
        data: jsonEncode(requestData),
        options: dio.Options(headers: _getHeaders(includeSession: true)),
      );

      _logger.i('SESSION_RPC: [END] $model.$method, statusCode=${response.statusCode}, body=${response.data}');

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('error')) {
            final error = responseData['error'];
            String errorMessage;
            if (error is Map<String, dynamic>) {
              errorMessage = error['message']?.toString() ??
                  error['data']?['message']?.toString() ??
                  'Unknown error';
            } else {
              errorMessage = error.toString();
            }

            // Check for session expired and attempt re-authentication
            final isSessionExpired = errorMessage.toLowerCase().contains('session expired') ||
                errorMessage.toLowerCase().contains('sessionexpiredexception') ||
                errorMessage.toLowerCase().contains('not authenticated');

            if (isSessionExpired && _database != null && _username != null && _password != null) {
              _logger.w('Odoo session expired during API call. Attempting to re-authenticate...');
              final authRes = await authenticate(
                database: _database!,
                username: _username!,
                password: _password!,
                showLog: showLog,
              );

              if (authRes.isSuccess) {
                _logger.i('Re-authentication successful. Retrying original API call...');
                final retryResponse = await dioInstance.post(
                  endpoint,
                  data: jsonEncode(requestData),
                  options: dio.Options(headers: _getHeaders(includeSession: true)),
                );

                if (retryResponse.statusCode == 200) {
                  final retryData = retryResponse.data;
                  if (retryData is Map<String, dynamic>) {
                    if (!retryData.containsKey('error')) {
                      return OdooResponse<dynamic>.success(
                        data: retryData['result'],
                        message: 'Request successful after re-authentication',
                        requestId: retryData['id']?.toString() ?? const Uuid().v4(),
                      );
                    } else {
                      final retryError = retryData['error'];
                      if (retryError is Map<String, dynamic>) {
                        errorMessage = retryError['message']?.toString() ??
                            retryError['data']?['message']?.toString() ??
                            'Unknown error';
                      } else {
                        errorMessage = retryError.toString();
                      }
                    }
                  }
                }
              }
            }

            return OdooResponse<dynamic>.error(
              message: 'API Error: $errorMessage',
              requestId: responseData['id']?.toString() ?? const Uuid().v4(),
            );
          }

          return OdooResponse<dynamic>.success(
            data: responseData['result'],
            message: 'Request successful',
            requestId: responseData['id']?.toString() ?? const Uuid().v4(),
          );
        }
      }

      return OdooResponse<dynamic>.error(
        message: 'Invalid response from server',
        requestId: const Uuid().v4(),
      );
    } catch (e) {
      if (showLog) {
        _logger.e('Session-based API call failed: $e');
      }
      return OdooResponse<dynamic>.error(
        message: 'API call failed: $e',
        requestId: const Uuid().v4(),
      );
    }
  }

  static Future<OdooResponse<dynamic>> _makeJsonRpcCall({
    required String endpoint,
    String? service,
    required String method,
    required List<dynamic> params,
    bool includeSession = true,
    bool showLog = _defaultShowLog,
  }) async {
    final baseUrl = _effectiveServerUrl;
    if (baseUrl.isEmpty) {
      return OdooResponse<dynamic>.error(
        message: 'Server URL not configured',
        requestId: const Uuid().v4(),
      );
    }

    final requestId = const Uuid().v4();
    final uri = Uri.parse('$baseUrl$endpoint');

    final requestData = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': service != null ? 'call' : method,
      'id': requestId,
    };

    if (service != null) {
      requestData['params'] = {
        'service': service,
        'method': method,
        'args': params,
      };
    } else {
      requestData['params'] = params;
    }

    try {
      final dioInstance = await _getDio();
      final response = await dioInstance.post(
        uri.toString(),
        data: jsonEncode(requestData),
        options: dio.Options(
          headers: _getHeaders(includeSession: includeSession),
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (includeSession) {
          final newSessionId = _extractSessionFromCookies(
            response.headers['set-cookie'],
          );
          if (newSessionId != null && newSessionId != _sessionId) {
            _sessionId = newSessionId;
            if (showLog) {
              _logger.i('Session updated from response');
            }
          }
        }

        if (responseData is Map) {
          if (responseData.containsKey('error')) {
            final error = responseData['error'];
            final errorMessage = _extractErrorMessage(error);
            return OdooResponse<dynamic>.error(
              message: errorMessage,
              requestId: requestId,
            );
          } else if (responseData.containsKey('result')) {
            return OdooResponse<dynamic>.success(
              data: responseData['result'],
              message: 'Success',
              requestId: requestId,
            );
          }
        }

        return OdooResponse<dynamic>.success(
          data: responseData,
          message: 'Success',
          requestId: requestId,
        );
      } else {
        throw OdooException(
          'HTTP ${response.statusCode}: ${response.statusMessage}',
        );
      }
    } catch (e) {
      if (showLog) {
        _logger.e('RPC call failed: $e');
      }

      if (e is OdooException) {
        rethrow;
      }

      return OdooResponse<dynamic>.error(
        message: 'RPC call failed: $e',
        requestId: requestId,
      );
    }
  }

  static String _extractErrorMessage(dynamic error) {
    if (error is Map) {
      if (error['data'] is Map) {
        final data = error['data'] as Map;
        if (data['message'] != null) {
          return data['message'].toString();
        }
        if (data['name'] != null) {
          return data['name'].toString();
        }
      }
      if (error['message'] != null) {
        return error['message'].toString();
      }
    }
    return error.toString();
  }

  static Future<OdooResponse<List<int>>> search({
    required dynamic model,
    List<dynamic>? domain,
    int? offset,
    int? limit,
    String? order,
    bool showLog = _defaultShowLog,
  }) async {
    final String modelName = model is String ? model : model.value;

    final args = <dynamic>[domain ?? []];
    final kwargs = <String, dynamic>{};

    if (offset != null) kwargs['offset'] = offset;
    if (limit != null) kwargs['limit'] = limit;
    if (order != null) kwargs['order'] = order;

    if (kwargs.isNotEmpty) {
      args.add(kwargs);
    }

    final response = await _executeKw(
      model: modelName,
      method: 'search',
      args: args,
      showLog: showLog,
    );

    if (response.isSuccess) {
      final ids = List<int>.from(response.data ?? []);
      return OdooResponse<List<int>>.success(
        data: ids,
        message: 'Search completed',
        requestId: response.requestId,
      );
    } else {
      return OdooResponse<List<int>>.error(
        message: response.message,
        requestId: response.requestId,
      );
    }
  }

  static Future<OdooResponse<int>> searchCount({
    required dynamic model,
    List<dynamic>? domain,
    bool showLog = _defaultShowLog,
  }) async {
    final String modelName = model is String ? model : model.value;

    final response = await _executeKw(
      model: modelName,
      method: 'search_count',
      args: [domain ?? []],
      showLog: showLog,
    );

    if (response.isSuccess) {
      return OdooResponse<int>.success(
        data: response.data ?? 0,
        message: 'Count completed',
        requestId: response.requestId,
      );
    } else {
      return OdooResponse<int>.error(
        message: response.message,
        requestId: response.requestId,
      );
    }
  }

  static Future<OdooResponse<List<Map<String, dynamic>>>> read({
    required dynamic model,
    required List<int> ids,
    List<String>? fields,
    bool showLog = _defaultShowLog,
  }) async {
    final String modelName = model is String ? model : model.value;

    final kwargs = <String, dynamic>{};
    if (fields != null && fields.isNotEmpty) kwargs['fields'] = fields;

    final response = await _executeKw(
      model: modelName,
      method: 'read',
      args: [ids],
      kwargs: kwargs.isNotEmpty ? kwargs : null,
      showLog: showLog,
    );

    if (response.isSuccess) {
      final records = List<Map<String, dynamic>>.from(response.data ?? []);
      return OdooResponse<List<Map<String, dynamic>>>.success(
        data: records,
        message: 'Read completed',
        requestId: response.requestId,
      );
    } else {
      return OdooResponse<List<Map<String, dynamic>>>.error(
        message: response.message,
        requestId: response.requestId,
      );
    }
  }

  static Future<OdooResponse<List<Map<String, dynamic>>>> searchRead({
    required dynamic model,
    List<dynamic>? domain,
    List<String>? fields,
    int? offset,
    int? limit,
    String? order,
    bool showLog = _defaultShowLog,
  }) async {
    late String modelName;
    if (model is String) {
      modelName = model;
    } else if (model is OdooDataModelType) {
      modelName = model.value;
    } else {
      throw OdooException('Invalid model type');
    }

    // Domain is always the sole positional arg.
    // All query options go into kwargs so the server never sees
    // duplicate keyword arguments.
    final kwargs = <String, dynamic>{};
    if (fields != null && fields.isNotEmpty) kwargs['fields'] = fields;
    if (offset != null) kwargs['offset'] = offset;
    if (limit != null) kwargs['limit'] = limit;
    if (order != null) kwargs['order'] = order;

    final response = await _executeKw(
      model: modelName,
      method: 'search_read',
      args: [domain ?? []],
      kwargs: kwargs.isNotEmpty ? kwargs : null,
      showLog: showLog,
    );

    if (response.isSuccess) {
      final records = List<Map<String, dynamic>>.from(response.data ?? []);
      return OdooResponse<List<Map<String, dynamic>>>.success(
        data: records,
        message: 'Search and read completed',
        requestId: response.requestId,
      );
    } else {
      return OdooResponse<List<Map<String, dynamic>>>.error(
        message: response.message,
        requestId: response.requestId,
      );
    }
  }

  static Future<OdooResponse<int>> create({
    required dynamic model,
    required Map<String, dynamic> values,
    bool showLog = _defaultShowLog,
  }) async {
    final String modelName = model is String ? model : model.value;

    final response = await _executeKw(
      model: modelName,
      method: 'create',
      args: [values],
      showLog: showLog,
    );

    if (response.isSuccess) {
      return OdooResponse<int>.success(
        data: response.data,
        message: 'Record created',
        requestId: response.requestId,
      );
    } else {
      return OdooResponse<int>.error(
        message: response.message,
        requestId: response.requestId,
      );
    }
  }

  static Future<OdooResponse<bool>> write({
    required dynamic model,
    required List<int> ids,
    required Map<String, dynamic> values,
    bool showLog = _defaultShowLog,
  }) async {
    final String modelName = model is String ? model : model.value;

    final response = await _executeKw(
      model: modelName,
      method: 'write',
      args: [ids, values],
      showLog: showLog,
    );

    if (response.isSuccess) {
      return OdooResponse<bool>.success(
        data: response.data == true,
        message: 'Records updated',
        requestId: response.requestId,
      );
    } else {
      return OdooResponse<bool>.error(
        message: response.message,
        requestId: response.requestId,
      );
    }
  }

  static Future<OdooResponse<bool>> unlink({
    required dynamic model,
    required List<int> ids,
    bool showLog = _defaultShowLog,
  }) async {
    final String modelName = model is String ? model : model.value;

    final response = await _executeKw(
      model: modelName,
      method: 'unlink',
      args: [ids],
      showLog: showLog,
    );

    if (response.isSuccess) {
      return OdooResponse<bool>.success(
        data: response.data == true,
        message: 'Records deleted',
        requestId: response.requestId,
      );
    } else {
      return OdooResponse<bool>.error(
        message: response.message,
        requestId: response.requestId,
      );
    }
  }

  static Future<OdooResponse<Map<String, dynamic>>> fieldsGet({
    required dynamic model,
    List<String>? fields,
    List<String>? attributes,
    bool showLog = _defaultShowLog,
  }) async {
    final String modelName = model is String ? model : model.value;

    final args = <dynamic>[];
    if (fields != null && fields.isNotEmpty) {
      args.add(fields);
    }

    final kwargs = <String, dynamic>{};
    if (attributes != null && attributes.isNotEmpty) {
      kwargs['attributes'] = attributes;
    }

    if (kwargs.isNotEmpty) {
      args.add(kwargs);
    }

    final response = await _executeKw(
      model: modelName,
      method: 'fields_get',
      args: args,
      showLog: showLog,
    );

    if (response.isSuccess) {
      return OdooResponse<Map<String, dynamic>>.success(
        data: Map<String, dynamic>.from(response.data ?? {}),
        message: 'Fields retrieved',
        requestId: response.requestId,
      );
    } else {
      return OdooResponse<Map<String, dynamic>>.error(
        message: response.message,
        requestId: response.requestId,
      );
    }
  }

  static Future<OdooResponse<dynamic>> call({
    required dynamic model,
    required String method,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    bool showLog = _defaultShowLog,
  }) async {
    final String modelName = model is String ? model : model.value;

    final response = await _executeKw(
      model: modelName,
      method: method,
      args: args,
      kwargs: kwargs,
      showLog: showLog,
    );

    return response;
  }

  static Future<OdooResponse<List<List<dynamic>>>> nameSearch({
    dynamic model,
    String name = '',
    List<dynamic>? domain,
    String operator = 'ilike',
    int limit = 100,
    bool showLog = _defaultShowLog,
  }) async {
    final String modelName = model is String ? model : model.value;

    // name_search: first positional arg is the search string;
    // domain, operator, limit go as proper kwargs.
    final response = await _executeKw(
      model: modelName,
      method: 'name_search',
      args: [name],
      kwargs: {
        'args': domain ?? [],
        'operator': operator,
        'limit': limit,
      },
      showLog: showLog,
    );

    if (response.isSuccess) {
      final results = List<List<dynamic>>.from(response.data ?? []);
      return OdooResponse<List<List<dynamic>>>.success(
        data: results,
        message: 'Name search completed',
        requestId: response.requestId,
      );
    } else {
      return OdooResponse<List<List<dynamic>>>.error(
        message: response.message,
        requestId: response.requestId,
      );
    }
  }

  static Future<OdooResponse<bool>> testAuthentication({
    bool showLog = true,
  }) async {
    if (!isAuthenticated) {
      return OdooResponse<bool>.error(
        message: 'Not authenticated',
        requestId: const Uuid().v4(),
      );
    }

    try {
      final response = await read(
        model: 'res.users',
        ids: [_uid!],
        fields: ['id', 'name'],
        showLog: showLog,
      );

      if (response.isSuccess) {
        if (showLog) {
          _logger.i('Authentication test successful');
        }
        return OdooResponse<bool>.success(
          data: true,
          message: 'Authentication test successful',
          requestId: response.requestId,
        );
      } else {
        return OdooResponse<bool>.error(
          message: 'Authentication test failed: ${response.message}',
          requestId: response.requestId,
        );
      }
    } catch (e) {
      return OdooResponse<bool>.error(
        message: 'Authentication test failed: $e',
        requestId: const Uuid().v4(),
      );
    }
  }

  static String? getUserImageUrl({int? userId, String field = 'image_1920'}) {
    final baseUrl = _effectiveServerUrl;
    if (baseUrl.isEmpty) return null;

    final id = userId ?? _uid;
    if (id == null) return null;

    return '$baseUrl/web/image?model=res.users&id=$id&field=$field';
  }

  static void _logRequest(dio.RequestOptions options) {
    _logger.i('→ ${options.method} ${options.uri}');
  }

  static void _logResponse(dio.Response response) {
    _logger.i('← ${response.statusCode} ${response.requestOptions.uri}');
  }

  static void _logError(dio.DioException error) {
    _logger.e(
      '✗ ${error.requestOptions.method} ${error.requestOptions.uri}: ${error.message}',
    );
  }
}

/// 📝 OdooDomainOperators.dart
/// Official Odoo domain condition operators with behind-the-scenes examples.
/// Author: Jayadrata Middey
/// Updated: 2025-07-11

class OdooDomainOperators {
  // ================================
  // ⚡ Logical Operators
  // ================================

  /// OR operator: combines two conditions as OR.
  /// Example (Odoo domain syntax):
  /// ['|', ('name', '=', 'A'), ('name', '=', 'B')]
  static const String or = "|";

  /// AND operator: combines conditions as AND (default in absence of '|' or '&').
  /// Example (implicit):
  /// [('active', '=', True), ('state', '=', 'done')]
  static const String and = "&";

  /// NOT operator: negates a condition.
  /// Example:
  /// ['!', ('active', '=', True)]
  static const String not = "!";

  // ================================
  // 🔎 Comparison Operators
  // ================================

  /// Equals
  /// [('name', '=', 'Test')]
  static const String eq = "=";

  /// Not equals
  /// [('state', '!=', 'draft')]
  static const String neq = "!=";

  /// Less than
  /// [('price', '<', 10)]
  static const String lt = "<";

  /// Less than or equal to
  /// [('price', '<=', 100)]
  static const String lte = "<=";

  /// Greater than
  /// [('price', '>', 10)]
  static const String gt = ">";

  /// Greater than or equal to
  /// [('price', '>=', 100)]
  static const String gte = ">=";

  /// Equals or True if right side is null/False.
  /// Useful for optional fields with fallback logic.
  /// [('user_id', '=?', uid)]
  static const String eqShortCircuit = "=?";

  // ================================
  // 🔍 Pattern Matching Operators
  // ================================

  /// LIKE (case-sensitive substring match, % as wildcard)
  /// [('name', 'like', '%Test%')]
  static const String like = "like";

  /// =LIKE (exact LIKE match)
  /// [('barcode', '=like', '12345')]
  static const String likeExact = "=like";

  /// ILIKE (case-insensitive substring match)
  /// [('name', 'ilike', '%test%')]
  static const String iLike = "ilike";

  /// =ILIKE (exact ILIKE match)
  /// [('email', '=ilike', 'abc@example.com')]
  static const String iLikeExact = "=ilike";

  /// NOT LIKE (case-sensitive negative match)
  /// [('name', 'not like', '%Test%')]
  static const String notLike = "not like";

  /// NOT ILIKE (case-insensitive negative match)
  /// [('name', 'not ilike', '%test%')]
  static const String notILike = "not ilike";

  // ================================
  // 🔗 Membership Operators
  // ================================

  /// IN (value in list)
  /// [('id', 'in', [1,2,3])]
  static const String inList = "in";

  /// NOT IN (value not in list)
  /// [('state', 'not in', ['draft', 'cancel'])]
  static const String notInList = "not in";

  // ================================
  // 🌳 Hierarchical Operators
  // ================================

  /// CHILD OF (includes given record and its children in hierarchical models)
  /// [('category_id', 'child_of', 5)]
  static const String childOf = "child_of";

  /// PARENT OF (selects parent records)
  /// [('category_id', 'parent_of', 10)]
  static const String parentOf = "parent_of";

  // ================================
  // 🧠 Utility
  // ================================

  /// Builds a domain condition tuple.
  /// Example:
  /// OdooDomainOperators.condition('name', OdooDomainOperators.iLike, 'test')
  static List<dynamic> condition({
    required String field,
    required String operator,
    required dynamic value,
  }) {
    return [field, operator, value];
  }
}
