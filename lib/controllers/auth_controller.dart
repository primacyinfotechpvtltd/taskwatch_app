import 'package:flutter/foundation.dart';
import 'package:pi_task_watch/controllers/timesheet_controller.dart';
import 'package:pi_task_watch/exports.dart';
import 'package:pi_task_watch/models/timesheet_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pi_task_watch/utils/log_utils.dart';

class AuthController extends GetxController {
  // Shared preferences keys
  static const String _keyEmail = 'user_email';
  static const String _keyPassword = 'user_password';
  static const String _keyDb = 'user_db';
  static const String _keyServerUrl = 'server_url';
  static const String _keyIsLoggedIn = 'is_logged_in';

  /// Safely converts any value to boolean
  /// Handles: bool, int (1=true, 0=false), string ('true', '1', 'yes'=true)
  static bool _safeBoolConversion(dynamic value) {
    if (value == null) return false;

    if (value is bool) {
      return value;
    } else if (value is int) {
      return value == 1;
    } else if (value is String) {
      final lowerCase = value.toLowerCase().trim();
      return lowerCase == 'true' || lowerCase == '1' || lowerCase == 'yes';
    } else {
      // For any other type, convert to string and check
      final stringValue = value.toString().toLowerCase().trim();
      return stringValue == 'true' || stringValue == '1';
    }
  }

  /// Safely extracts the database name from dynamic value (handles Map, String, etc.)
  static String _extractDbName(dynamic e) {
    if (e == null) return '';
    if (e is Map) {
      if (e.containsKey('name')) {
        return e['name']?.toString() ?? '';
      } else if (e.containsKey('db_name')) {
        return e['db_name']?.toString() ?? '';
      } else if (e.containsKey('database')) {
        return e['database']?.toString() ?? '';
      }
    }
    return e.toString();
  }

  //
  final Rx<UserModel?> _user = Rx<UserModel?>(null);
  Rx<UserModel?> get user => _user;
  final RxBool _authLoading = false.obs;
  RxBool get authLoading => _authLoading;

  // Add specific loading states for post-login operations
  final RxBool _settingsLoading = false.obs;
  RxBool get settingsLoading => _settingsLoading;
  final RxBool _timesheetLoading = false.obs;
  RxBool get timesheetLoading => _timesheetLoading;

  // settings rx
  final Rx<SettingsModel?> _settings = Rx<SettingsModel?>(null);
  Rx<SettingsModel?> get settings => _settings;

  /// Restores only the server URL from saved preferences
  Future<void> restoreServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString(_keyServerUrl) ?? '';
      if (serverUrl.isNotEmpty) {
        AppConstant.userGivenApiServerUrl = serverUrl;
        // Ensure OdooRpcApiManager is also updated with the restored URL
        OdooRpcApiManager.configure(serverUrl: serverUrl);
        if (kDebugMode) print("🌐 Restored saved server URL: $serverUrl");
      }
    } catch (e) {
      if (kDebugMode) print("❌ Error restoring server URL: $e");
    }
  }

  /// Simple auto-login method - checks for saved credentials and logs in if found
  Future<bool> attemptAutoLogin() async {
    try {
      // Don't auto-login if user is already logged in
      if (_user.value != null) {
        if (kDebugMode) print("✅ User already logged in");
        return true;
      }

      // Don't auto-login if already in progress
      if (_authLoading.value) {
        if (kDebugMode) print("⏳ Login already in progress");
        return false;
      }

      if (kDebugMode) print("🔍 Checking for saved credentials...");

      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

      if (!isLoggedIn) {
        if (kDebugMode) print("❌ No saved login flag found");
        return false;
      }

      final email = prefs.getString(_keyEmail) ?? '';
      final password = prefs.getString(_keyPassword) ?? '';
      final db = prefs.getString(_keyDb) ?? '';

      if (email.isEmpty || password.isEmpty || db.isEmpty) {
        if (kDebugMode) print("❌ Incomplete saved credentials");
        return false;
      }

      // Restore server URL if it was saved (now call the dedicated method)
      await restoreServerUrl();

      if (kDebugMode) {
        print("✅ Found complete credentials:");
        print("   Email: $email");
        print("   Database: $db");
        print("   Starting auto-login...");
      }

      // Perform the login
      final user = await signIn(
        db: db,
        email: email,
        password: password,
        rememberMe: true,
      );

      return user != null;
    } catch (e) {
      if (kDebugMode) print("❌ Auto-login error: $e");
      return false;
    }
  }

  // Save user credentials
  Future<void> saveUserCredentials({
    required String email,
    required String password,
    required String db,
    required bool rememberMe,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (rememberMe) {
        await prefs.setString(_keyEmail, email);
        await prefs.setString(_keyPassword, password);
        await prefs.setString(_keyDb, db);
        await prefs.setString(_keyServerUrl, AppConstant.apiServerUrl);
        await prefs.setBool(_keyIsLoggedIn, true);
        if (kDebugMode) {
          print("✅ Credentials saved successfully: email=$email, db=$db");
        }
      } else {
        await clearSavedCredentials();
        if (kDebugMode) print("🗑️ Credentials cleared (rememberMe=false)");
      }
    } catch (e) {
      if (kDebugMode) print("❌ Error saving credentials: $e");
    }
  }

  // Clear saved credentials
  Future<void> clearSavedCredentials() async {
    try {
      Get.find<TrackerController>().setUser(user: null);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyPassword);
      await prefs.remove(_keyDb);
      await prefs.remove(_keyServerUrl);
      await prefs.setBool(_keyIsLoggedIn, false);
      if (kDebugMode) print("🗑️ All saved credentials cleared");
    } catch (e) {
      if (kDebugMode) print("Error clearing credentials: $e");
    }
  }

  /// Debug method to check what's currently saved
  Future<void> debugSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final email = prefs.getString(_keyEmail) ?? '';
      final password = prefs.getString(_keyPassword) ?? '';
      final db = prefs.getString(_keyDb) ?? '';

      if (kDebugMode) {
        print("🔍 DEBUG - Current saved credentials:");
        print("   isLoggedIn: $isLoggedIn");
        print("   email: ${email.isNotEmpty ? email : 'EMPTY'}");
        print("   password: ${password.isNotEmpty ? '***SET***' : 'EMPTY'}");
        print("   database: ${db.isNotEmpty ? db : 'EMPTY'}");
      }
    } catch (e) {
      if (kDebugMode) print("❌ Error checking saved credentials: $e");
    }
  }

  /// Fetches database list from /public/config endpoint
  /// Fetches database list from /public/config endpoint with fallback to Odoo RPC
  /// Fetches database list from /public/config endpoint with fallback to Odoo RPC
  Future<List<String>> getAllDb() async {
    try {
      // Get the base server URL entered by user
      final baseUrl = AppConstant.apiConfigUrl; // Changed from apiConfigUrl

      if (baseUrl.isEmpty) {
        print("❌ No server URL configured. Please enter a server URL first.");
        return [];
      }

      // Always print the database fetch URL
      print(
        "╔════════════════════════════════════════════════════════════════",
      );
      print("║ 📡 FETCHING DATABASE LIST");
      print("║ Base URL (apiConfigUrl): $baseUrl");
      print("║ Endpoint: public/config");
      print("║ Full URL: ${baseUrl}public/config");
      print("║ Attempting /public/config endpoint first...");
      print(
        "╚════════════════════════════════════════════════════════════════",
      );

      // Try Method 1: Use /public/config endpoint
      // Use apiConfigUrl (has trailing /) + endpoint
      try {
        final apiResponse = await ApiManager.getRequest(
          endPoint: "${baseUrl}public/config",
          isFullUrl: true,
        );

        print("📥 Config API Response received");
        print("   Status Code: ${apiResponse.statusCode}");
        print("   Raw Response Body: ${apiResponse.rawResponse.body}");
        print("   Parsed Body: ${apiResponse.body}");
        print("   Is Success: ${apiResponse.isSuccess}");

        // Check if we got a valid response (200 status code)
        if (apiResponse.statusCode == 200 && apiResponse.body != null) {
          // Extract the database list from the response
          List<String> databases = [];

          // The response format is: {"list_db": false, "db_name": ["primacy"]}
          // We need to extract from the body directly, not from apiResponse.data
          if (apiResponse.body is Map) {
            final bodyMap = apiResponse.body as Map;

            print("   Response body keys: ${bodyMap.keys.toList()}");

            // Try to find database list in various possible keys
            if (bodyMap.containsKey('db_name')) {
              final dbList = bodyMap['db_name'];
              if (dbList is List) {
                databases = dbList.map((e) => _extractDbName(e)).toList();
                print("   ✅ Found databases in 'db_name': $databases");
              }
            } else if (bodyMap.containsKey('databases')) {
              final dbList = bodyMap['databases'];
              if (dbList is List) {
                databases = dbList.map((e) => _extractDbName(e)).toList();
                print("   ✅ Found databases in 'databases': $databases");
              }
            } else if (bodyMap.containsKey('database')) {
              final dbList = bodyMap['database'];
              if (dbList is List) {
                databases = dbList.map((e) => _extractDbName(e)).toList();
                print("   ✅ Found databases in 'database': $databases");
              }
            } else if (bodyMap.containsKey('db_list')) {
              final dbList = bodyMap['db_list'];
              if (dbList is List) {
                databases = dbList.map((e) => _extractDbName(e)).toList();
                print("   ✅ Found databases in 'db_list': $databases");
              }
            } else if (bodyMap.containsKey('result')) {
              final result = bodyMap['result'];
              if (result is List) {
                databases = result.map((e) => _extractDbName(e)).toList();
                print("   ✅ Found databases in 'result': $databases");
              } else if (result is Map && result.containsKey('databases')) {
                final dbList = result['databases'];
                if (dbList is List) {
                  databases = dbList.map((e) => _extractDbName(e)).toList();
                  print(
                      "   ✅ Found databases in 'result.databases': $databases");
                }
              }
            }

            // If no databases found in expected keys, log all available keys
            if (databases.isEmpty) {
              print(
                "⚠️ No databases found in /public/config. Available keys: ${bodyMap.keys.toList()}",
              );
            }
          } else if (apiResponse.body is List) {
            // If the response is directly a list
            databases =
                (apiResponse.body as List).map((e) => _extractDbName(e)).toList();
            print("   ✅ Response body is directly a list: $databases");
          }

          if (databases.isNotEmpty) {
            print(
              "✅ Successfully fetched ${databases.length} database(s) from /public/config: $databases",
            );
            return databases;
          }
        } else {
          print(
            "⚠️ /public/config endpoint failed or returned no data (Status: ${apiResponse.statusCode})",
          );
          if (!apiResponse.isSuccess) {
            print("   Error message: ${apiResponse.message}");
          }
        }
      } catch (e) {
        print("⚠️ /public/config endpoint error: $e");
        // Don't print full stack trace here, just the error message
      }

      // Method 2: Fallback to Odoo RPC method
      print("\n║ 🔄 Falling back to Odoo RPC getDbList method...");

      final dbListResponse = await OdooRpcApiManager.getDbList(
        serverUrl: baseUrl, // Use baseUrl without trailing slash
      );

      print("📥 Odoo RPC Response received");
      print("   Is Error: ${dbListResponse.isError}");

      if (dbListResponse.rawData != null) {
        print("   Raw data type: ${dbListResponse.rawData.runtimeType}");
        // Only print first 200 chars to avoid huge logs
        final dataStr = dbListResponse.rawData.toString();
        print(
            "   Raw data: ${dataStr.length > 200 ? dataStr.substring(0, 200) + '...' : dataStr}");
      } else {
        print("   Raw data is null");
      }

      // Check if the request was successful
      if (dbListResponse.isError) {
        // Print a shorter error message
        final errorMsg = dbListResponse.message;
        print("❌ Error fetching databases via RPC");
        if (errorMsg.contains('502')) {
          print(
              "   Server returned 502 Bad Gateway - server may be down or unreachable");
        } else if (errorMsg.contains('404')) {
          print("   Server returned 404 Not Found - endpoint doesn't exist");
        } else {
          // Print just the first line of error
          final firstLine = errorMsg.split('\n').first;
          print(
              "   Error: ${firstLine.length > 100 ? firstLine.substring(0, 100) + '...' : firstLine}");
        }
        return [];
      }

      // Extract the database list
      List<String> databases = [];

      if (dbListResponse.rawData != null) {
        dynamic dbList;

        // Check if rawData is a Map with a 'result' field
        if (dbListResponse.rawData is Map) {
          final dataMap = dbListResponse.rawData as Map;
          dbList = dataMap['result'];
        } else if (dbListResponse.rawData is List) {
          // If it's already a List, use it directly
          dbList = dbListResponse.rawData;
        }

        // Now check if we have a valid list
        if (dbList != null && dbList is List) {
          databases = dbList.map((e) => _extractDbName(e)).toList();
        }
      }

      if (databases.isNotEmpty) {
        print(
          "✅ Successfully fetched ${databases.length} database(s) via RPC: $databases",
        );
        return databases;
      }

      print("⚠️ No databases found via any method");
      return [];
    } catch (e) {
      print("❌ Error fetching databases: $e");
      // Only print stack trace in debug mode
      if (kDebugMode) {
        print("   Stack trace: ${StackTrace.current}");
      }
      return [];
    }
  }

  //
  //
  Future<UserModel?> signIn({
    required String db,
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      // Check if user is already logged in
      if (_user.value != null) {
        if (kDebugMode) print("✅ User already logged in");
        return _user.value;
      }

      if (kDebugMode) {
        print("\n════════════════════════════════════════════════════════");
        print("🔐 LOGIN REQUEST DETAILS");
        print("════════════════════════════════════════════════════════");
        print("📍 API Server URL: ${AppConstant.apiServerUrl}");
        print("📍 API Base URL: ${AppConstant.apiBaseUrl}");
        print("📍 Login Endpoint: ${AppConstant.apiBaseUrl}/login");
        print("────────────────────────────────────────────────────────");
        print("📊 Login Data:");
        print("   • Database: $db");
        print("   • Email/Username: $email");
        print("   • Password: ${"*" * password.length}");
        print("   • Remember Me: $rememberMe");
        print("════════════════════════════════════════════════════════\n");
      }

      _authLoading.value = true;
      // Get all databases for verification
      await getAllDb();

      // Configure and authenticate with OdooRpcApiManager
      // Configure OdooRpcApiManager initially
      OdooRpcApiManager.configure(
        authMode: OdooAuthMode.session,
        serverUrl: AppConstant.apiServerUrl,
        database: db,
        username: email,
        password: password,
      );

      final apiResponse = await ApiManager.postRequest(
        endPoint: "login",
        data: {"db": db, "login": email, "password": password},
      );

      if (kDebugMode) {
        print("────────────────────────────────────────────────────────");
        print("📥 LOGIN API RESPONSE");
        print("────────────────────────────────────────────────────────");
        print("   • Status Code: ${apiResponse.statusCode}");
        print("   • Response Body: ${apiResponse.rawResponse.body}");
        print("   • Parsed Body: ${apiResponse.body}");
        print("────────────────────────────────────────────────────────\n");
      }

      if (apiResponse.statusCode != 200 || apiResponse.body == null || apiResponse.body['result'] == null) {
        showToast(
          "Invalid credentials or database not found",
          idSuccess: false,
        );
        return null;
      }

      final result = apiResponse.body['result'];

      // Safely convert success to boolean using helper function
      final bool isSuccess = _safeBoolConversion(result['success']);

      if (kDebugMode) {
        print(
          "Success value: ${result['success']} (${result['success'].runtimeType}) → converted to: $isSuccess",
        );
      }

      if (!isSuccess) {
        showToast(result['message'] ?? "Invalid credentials", idSuccess: false);
        return null;
      }

      // Extract session ID from cookies with proper error handling
      String nSessionId = '';

      // Get all headers and look for set-cookie
      final headers = apiResponse.rawResponse.headers;

      // Check for set-cookie header (case-insensitive)
      String? cookieValue;
      for (final entry in headers.entries) {
        if (entry.key.toLowerCase() == 'set-cookie') {
          cookieValue = entry.value;
          break;
        }
      }

      if (cookieValue != null && cookieValue.isNotEmpty) {
        // Split by comma to handle multiple cookies in one header
        final cookies = cookieValue.split(',');

        for (String cookie in cookies) {
          final trimmedCookie = cookie.trim();
          if (trimmedCookie.startsWith('session_id=')) {
            final parts = trimmedCookie.split('=');
            if (parts.length >= 2) {
              // Extract value and remove any trailing attributes (like path, domain, etc.)
              nSessionId = parts.sublist(1).join('=').split(';')[0].trim();
              break;
            }
          }
        }
      }

      if (nSessionId.isNotEmpty) {
        final parsedUser = UserModel.fromJson(result);
        OdooRpcApiManager.setSession(
          sessionId: nSessionId,
          uid: parsedUser.userId,
          serverUrl: AppConstant.apiServerUrl,
          database: db,
          username: email,
          password: password,
        );
        if (kDebugMode) print("Session established in OdooRpcApiManager successfully");
      } else {
        if (kDebugMode) print("Warning: No valid session_id found in cookies");
      }

      if (kDebugMode) {
        print(
          "Success value: ${result['success']} (${result['success'].runtimeType}) → converted to: $isSuccess",
        );
      }

      // Show toast message based on success/failure
      showToast(result['message'], idSuccess: isSuccess);

      // If login successful
      if (isSuccess) {
        final user = UserModel.fromJson(result);
        LogUtils.i('AUTH_STATE: Setting _user.value to user.id=${user.userId}, email=${user.email}');
        _user.value = user;
        LogUtils.i('AUTH_STATE: _user.value successfully set to ${user.email}.');

        if (kDebugMode) print("🔧 Loading user settings...");
        _settingsLoading.value = true;

        // Get settings after successful login
        final settings = await getSettingData();
        _settingsLoading.value = false;

        SettingsModel finalSettings;
        if (settings == null) {
          if (kDebugMode) {
            print("⚠️ Settings API failed, using default settings");
          }
          finalSettings = SettingsModel.createDefault();
          showToast(
            "Login successful. Using default settings.",
            idSuccess: true,
          );
        } else {
          finalSettings = settings;
          if (kDebugMode) {
            print(
              "✅ Settings loaded: idle=${finalSettings.idleThreshold.inMinutes}min, "
              "session=${finalSettings.calculationDuration.inMinutes}min, "
              "screenshots=${finalSettings.perSessionScreenshot}",
            );

            // Check if settings are using fallback values due to API returning zeros
            if (finalSettings.isUsingFallbackValues) {
              print(
                "⚠️ Warning: Using fallback values - API may have returned zeros",
              );
            }
          }
        }

        if (kDebugMode) print("📋 Loading user timesheets...");
        _timesheetLoading.value = true;

        final timesheets = await Get.find<TimesheetController>()
            .getAllTimesheet(date: DateTime.now());

        _timesheetLoading.value = false;

        Get.find<TrackerController>().onFullyReady(
          settings: finalSettings,
          user: user,
          workedDuration: TimesheetModel.calculateTotalDuration(
            timesheetList: timesheets,
          ),
        );

        // Save credentials if login is successful - regardless of rememberMe
        // We'll use rememberMe parameter to determine saving behavior
        await saveUserCredentials(
          email: email,
          password: password,
          db: db,
          rememberMe: rememberMe,
        );

        if (kDebugMode) print("✅ Authentication flow completed successfully");
        return user;
      }

      return null;
    } catch (e) {
      if (kDebugMode) print("Error during sign in: $e");
      showToast("Sign in failed. Please try again.", idSuccess: false);

      // _user.value = null;

      return null;
    } finally {
      _authLoading.value = false;
      _settingsLoading.value = false;
      _timesheetLoading.value = false;
    }
  }

  // Logout method to clear credentials and all cached data
  Future<void> logout() async {
    try {
      if (kDebugMode) print('🚪 [LOGOUT] Starting logout process...');

      // 1. Clear user data
      LogUtils.i('AUTH_STATE: Setting _user.value to null (logout)');
      _user.value = null;
      _settings.value = null;

      if (kDebugMode) print('🚪 [LOGOUT] Cleared user and settings data');

      // 2. Clear saved credentials from SharedPreferences
      await clearSavedCredentials();

      if (kDebugMode) print('🚪 [LOGOUT] Cleared saved credentials');

      // 3. Clear all SharedPreferences (complete cache clear)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (kDebugMode) print('🚪 [LOGOUT] Cleared all SharedPreferences cache');

      // 4. Clear Odoo session
      OdooRpcApiManager.clearSession();

      if (kDebugMode) print('🚪 [LOGOUT] Cleared Odoo session');

      // 5. Reset tracker controller if it exists
      try {
        final trackerController = Get.find<TrackerController>();
        trackerController.setUser(user: null);
        if (kDebugMode) print('🚪 [LOGOUT] Reset tracker controller');
      } catch (e) {
        if (kDebugMode) print('🚪 [LOGOUT] Tracker controller not found (OK)');
      }

      // 6. Navigate to login screen
      Get.offAllNamed(SigninScreen.routeName);

      if (kDebugMode) print('✅ [LOGOUT] Logout completed successfully');

      showToast('Logged out successfully', idSuccess: true);
    } catch (e) {
      if (kDebugMode) print('🚨 [LOGOUT] Error during logout: $e');
      showToast('Logout failed. Please try again.', idSuccess: false);
    }
  }

  Future<SettingsModel?> getSettingData() async {
    try {
      if (kDebugMode) print("🔧 Fetching settings from API...");

      final apiResponse = await ApiManager.getRequest(endPoint: "settings");

      if (!apiResponse.isSuccess) {
        if (kDebugMode) {
          print("❌ Settings API returned error: ${apiResponse.message}");
        }
        return null;
      }

      if (apiResponse.data == null) {
        if (kDebugMode) print("❌ Settings API returned null data");
        return null;
      }

      // Log the raw API response for debugging
      if (kDebugMode) {
        print("📋 Raw settings data: ${apiResponse.data}");
      }

      final result = SettingsModel.fromJson(apiResponse.data);
      _settings.value = result;

      if (kDebugMode) {
        print("✅ Settings processed successfully:");
        print("   - Idle threshold: ${result.idleThreshold.inMinutes} minutes");
        print(
          "   - Session duration: ${result.calculationDuration.inMinutes} minutes",
        );
        print("   - Screenshots per session: ${result.perSessionScreenshot}");
        print("   - Offline time: ${result.offlineTime} minutes");
        print("   - Timezone: ${result.timezone}");
        print("   - Maintenance mode: ${result.maintenance}");
      }

      return result;
    } catch (e) {
      if (kDebugMode) print("❌ Error fetching settings data: $e");
      return null;
    }
  }
}
