import 'package:flutter/foundation.dart';

import 'package:pi_task_watch/exports.dart';
import 'package:google_fonts/google_fonts.dart';

class SigninScreen extends StatefulWidget {
  static const String routeName = '/signin';
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _databaseSearchController = TextEditingController();
  String? _selectedDatabase;
  bool _isPasswordVisible = false;
  bool _rememberMe = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Auth controller
  final AuthController _authController = Get.find<AuthController>();

  // Database list
  final RxList<String> _databases = RxList<String>([]);
  final RxBool _loadingDatabases = RxBool(false);

  @override
  void initState() {
    super.initState();

    // Initialize server URL - show current active URL (user-given or default)
    _serverUrlController.text = AppConstant.apiServerUrl;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Restore server URL and attempt auto-login
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _authController.restoreServerUrl();

      // Update the controller text with the restored URL
      _serverUrlController.text = AppConstant.apiServerUrl;
      if (mounted) setState(() {});

      // Attempt auto-login if credentials exist
      final result = await _authController.attemptAutoLogin();

      // If auto-login was not successful or not attempted, fetch databases for current URL
      if (!result && _isValidUrl(AppConstant.apiServerUrl)) {
        _fetchDatabases();
      }
    });
  }

  Future<void> _fetchDatabases() async {
    _loadingDatabases.value = true;
    try {
      final databases = await _authController.getAllDb();
      _databases.value = databases;

      if (kDebugMode) {
        print(
          "✅ Fetched ${databases.length} databases from ${AppConstant.apiServerUrl}",
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Failed to fetch databases: $e");
      }
      _databases.value = [];
      showToast(
        "Failed to fetch databases. Please check your server URL.",
        idSuccess: false,
      );
    } finally {
      _loadingDatabases.value = false;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _databaseSearchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Helper method to validate URL format
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // Helper method to update server URL
  void _updateServerUrl() {
    final trimmedUrl = _serverUrlController.text.trim();

    if (trimmedUrl.isEmpty) {
      showToast("Please enter a server URL", idSuccess: false);
      return;
    }

    if (!_isValidUrl(trimmedUrl)) {
      showToast(
        "Please enter a valid URL (must start with http:// or https://)",
        idSuccess: false,
      );
      return;
    }

    // Update the server URL
    AppConstant.userGivenApiServerUrl = trimmedUrl;

    print("🔗 API Server URL updated: ${AppConstant.apiServerUrl}");
    print("🔗 API Base URL updated: ${AppConstant.apiBaseUrl}");

    // Fetch databases with new URL
    _fetchDatabases();

    // Reset selected database since URL changed
    setState(() {
      _selectedDatabase = null;
    });

    showToast("API Server URL updated successfully", idSuccess: true);
  }

  // Helper method to trim text
  String _trimText(String text) {
    return text.trim();
  }

  void _handleSignIn() async {
    // Prevent multiple simultaneous sign-in attempts
    if (_authController.authLoading.value ||
        _authController.settingsLoading.value ||
        _authController.timesheetLoading.value) {
      if (kDebugMode) print("⚠️ Sign-in already in progress, ignoring request");
      return;
    }

    // Trim text fields before validation
    _emailController.text = _trimText(_emailController.text);
    _passwordController.text = _trimText(_passwordController.text);

    if (_formKey.currentState!.validate() && _selectedDatabase != null) {
      // Get auth login values with trimming
      final email = _emailController.text; // Already trimmed
      final password = _passwordController.text; // Already trimmed
      final db = _selectedDatabase!;

      // Attempt sign in
      final signInResult = await _authController.signIn(
        db: db,
        email: email,
        password: password,
        rememberMe:
            _rememberMe, // Pass the remember me flag to save credentials
      );

      if (kDebugMode && signInResult != null) {
        print("📝 Credentials saved: ${_rememberMe ? 'Yes' : 'No'}");
      }
    } else if (_selectedDatabase == null) {
      //
      showToast("Please select a database", idSuccess: false);
    }
  }

  // Debug sign in with dummy credentials
  void _handleDebugSignIn() async {
    // Prevent multiple simultaneous sign-in attempts
    if (_authController.authLoading.value ||
        _authController.settingsLoading.value ||
        _authController.timesheetLoading.value) {
      if (kDebugMode) {
        print("⚠️ Debug sign-in already in progress, ignoring request");
      }
      return;
    }

    // Set dummy values

    _emailController.text = AppConstant.debugEmail;
    _passwordController.text = AppConstant.debugPassword;

    // Select first database if available
    if (_databases.isNotEmpty && _selectedDatabase == null) {
      setState(() {
        _selectedDatabase = _databases.first;
      });
    } else if (_selectedDatabase == null) {
      // Set a default if no database is available (use lowercase to match API)
      setState(() {
        _selectedDatabase = "primacy";
      });
    }

    // Call regular sign in handler after a short delay
    Future.delayed(Duration(milliseconds: 100), () {
      _handleSignIn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.editorialGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const LogoCaptionWidget(),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: AppTheme.glassDecoration(
                            borderRadius: 32,
                            color: Colors.white,
                          ),
                          child: Obx(
                            () => Column(
                              children: [
                                // WFH warning message
                                if (!_authController.isWfhApproved.value) ...[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 20),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.red.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Your wfh is not approved please contact with the hr',
                                            style: GoogleFonts.inter(
                                              color: Colors.red.shade800,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Auto-login indicator - shows when auto-login is happening
                                if (_authController.authLoading.value ||
                                    _authController.settingsLoading.value ||
                                    _authController.timesheetLoading.value) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                          AppTheme.secondary.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color:
                                            AppTheme.secondary.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    AppTheme.secondary),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                () {
                                                  if (_authController
                                                      .authLoading.value) {
                                                    return 'Authenticating...';
                                                  } else if (_authController
                                                      .settingsLoading.value) {
                                                    return 'Syncing Profile...';
                                                  } else if (_authController
                                                      .timesheetLoading.value) {
                                                    return 'Loading Logs...';
                                                  } else {
                                                    return 'Connecting...';
                                                  }
                                                }(),
                                                style: GoogleFonts.inter(
                                                  color: AppTheme.secondary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Restoring your session...',
                                                style: GoogleFonts.inter(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Wrap the entire form in IgnorePointer when auto-login is in progress
                                IgnorePointer(
                                  ignoring: _authController.authLoading.value ||
                                      _authController.settingsLoading.value ||
                                      _authController.timesheetLoading.value,
                                  child: Column(
                                    children: [
                                      // Server URL section - only show if user can change URL
                                      if (AppConstant.userCanChangeUrl) ...[
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: CompactTextField(
                                                controller:
                                                    _serverUrlController,
                                                hintText:
                                                    'e.g. https://demo.odoo.com',
                                                labelText: 'Server URL',
                                                prefixIcon: Icon(
                                                  Icons.web_asset_outlined,
                                                ),
                                                keyboardType: TextInputType.url,
                                                validator: (value) {
                                                  final trimmedValue =
                                                      _trimText(value ?? '');
                                                  if (trimmedValue.isEmpty) {
                                                    return 'Please enter your server URL';
                                                  }
                                                  if (!_isValidUrl(
                                                    trimmedValue,
                                                  )) {
                                                    return 'Please enter a valid URL (must start with http:// or https://)';
                                                  }
                                                  return null;
                                                },
                                                onChanged: (value) {
                                                  // Optional: Update the refresh icon color in real-time
                                                  // as the user types to provide visual feedback
                                                  if (mounted) {
                                                    setState(() {});
                                                  }
                                                },
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: InkWell(
                                                onTap: _updateServerUrl,
                                                child: Icon(
                                                  Icons.refresh,
                                                  color: () {
                                                    final currentUrl =
                                                        _serverUrlController
                                                            .text
                                                            .trim();
                                                    final hasUserUrl = AppConstant
                                                                .userGivenApiServerUrl !=
                                                            null &&
                                                        AppConstant
                                                            .userGivenApiServerUrl!
                                                            .isNotEmpty;
                                                    final isValidCurrentUrl =
                                                        currentUrl.isNotEmpty &&
                                                            _isValidUrl(
                                                                currentUrl);
                                                    final urlChanged =
                                                        currentUrl !=
                                                            AppConstant
                                                                .apiServerUrl;

                                                    if (hasUserUrl &&
                                                        !urlChanged) {
                                                      return Colors
                                                          .green; // URL is set and current
                                                    } else if (isValidCurrentUrl &&
                                                        urlChanged) {
                                                      return Colors
                                                          .orange; // Valid URL entered but not applied
                                                    } else if (currentUrl
                                                            .isNotEmpty &&
                                                        !_isValidUrl(
                                                          currentUrl,
                                                        )) {
                                                      return Colors
                                                          .red; // Invalid URL entered
                                                    } else {
                                                      return Colors
                                                          .grey; // Default state
                                                    }
                                                  }(),
                                                  size: 25,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                      ],

                                      // Database selector with enhanced display
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Database list info header
                                          if (_databases.isNotEmpty ||
                                              _loadingDatabases.value) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.storage,
                                                    size: 14,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _loadingDatabases.value
                                                        ? 'Fetching databases...'
                                                        : 'Found ${_databases.length} database${_databases.length != 1 ? 's' : ''}',
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      color: _loadingDatabases
                                                              .value
                                                          ? Colors
                                                              .orange.shade700
                                                          : Colors
                                                              .green.shade700,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  if (_loadingDatabases
                                                      .value) ...[
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                Color>(
                                                          Colors
                                                              .orange.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],

                                          // Database dropdown
                                          SearchableDropdown<String>(
                                            value: _selectedDatabase,
                                            items: _loadingDatabases.value
                                                ? ["Loading databases..."]
                                                : _databases.isEmpty
                                                    ? ["No databases found"]
                                                    : _databases,
                                            hint: _databases.isEmpty &&
                                                    !_loadingDatabases.value
                                                ? "No databases available"
                                                : "Select Database",
                                            onChanged: (value) {
                                              // Don't allow selection of placeholder items
                                              if (value !=
                                                      "Loading databases..." &&
                                                  value !=
                                                      "No databases found") {
                                                setState(() {
                                                  _selectedDatabase = value;
                                                });
                                              }
                                            },
                                            searchController:
                                                _databaseSearchController,
                                            itemToString: (item) => item,
                                          ),

                                          // Show database list pills if available
                                          if (_databases.isNotEmpty &&
                                              !_loadingDatabases.value) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.blue.shade200,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.info_outline,
                                                        size: 12,
                                                        color: Colors
                                                            .blue.shade700,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Available Databases:',
                                                        style: theme
                                                            .textTheme.bodySmall
                                                            ?.copyWith(
                                                          color: Colors
                                                              .blue.shade700,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    children:
                                                        _databases.map((db) {
                                                      final isSelected = db ==
                                                          _selectedDatabase;
                                                      return GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            _selectedDatabase =
                                                                db;
                                                          });
                                                        },
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isSelected
                                                                ? Colors.blue
                                                                    .shade700
                                                                : Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                            border: Border.all(
                                                              color: isSelected
                                                                  ? Colors.blue
                                                                      .shade700
                                                                  : Colors.blue
                                                                      .shade300,
                                                              width: 1.5,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              if (isSelected)
                                                                Icon(
                                                                  Icons
                                                                      .check_circle,
                                                                  size: 12,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              if (isSelected)
                                                                const SizedBox(
                                                                    width: 4),
                                                              Text(
                                                                db,
                                                                style: theme
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                  color: isSelected
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .blue
                                                                          .shade700,
                                                                  fontSize: 11,
                                                                  fontWeight: isSelected
                                                                      ? FontWeight
                                                                          .bold
                                                                      : FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Email/Username field with trimming
                                      CompactTextField(
                                        controller: _emailController,
                                        hintText: 'Enter email or username',
                                        labelText: 'Email or Username',
                                        prefixIcon: Icon(Icons.person_outline),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (value) {
                                          final trimmedValue = _trimText(
                                            value ?? '',
                                          );
                                          if (trimmedValue.isEmpty) {
                                            return 'Please enter your email or username';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 12),

                                      // Password field with trimming
                                      CompactTextField(
                                        controller: _passwordController,
                                        hintText: 'Enter password',
                                        labelText: 'Password',
                                        prefixIcon: Icon(Icons.lock_outline),
                                        obscureText: !_isPasswordVisible,
                                        suffixIcon: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () => setState(
                                            () => _isPasswordVisible =
                                                !_isPasswordVisible,
                                          ),
                                          child: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        validator: (value) {
                                          final trimmedValue = _trimText(
                                            value ?? '',
                                          );
                                          if (trimmedValue.isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 8),

                                      // Remember me checkbox
                                      Row(
                                        children: [
                                          SizedBox(
                                            height: 15,
                                            width: 15,
                                            child: Checkbox(
                                              value: _rememberMe,
                                              onChanged: (value) {
                                                setState(() {
                                                  _rememberMe = value ?? false;
                                                });
                                              },
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Remember me',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () {
                                              // Add forgot password functionality
                                            },
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 2,
                                                horizontal: 6,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: theme.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 14),

                                      // Sign in button
                                      CompactButton(
                                        onPressed:
                                            _authController.authLoading.value ||
                                                    _authController
                                                        .settingsLoading
                                                        .value ||
                                                    _authController
                                                        .timesheetLoading.value
                                                ? null
                                                : _handleSignIn,
                                        text: () {
                                          if (_authController
                                              .authLoading.value) {
                                            return 'SIGNING IN...';
                                          } else if (_authController
                                              .settingsLoading.value) {
                                            return 'LOADING SETTINGS...';
                                          } else if (_authController
                                              .timesheetLoading.value) {
                                            return 'LOADING TIMESHEETS...';
                                          } else {
                                            return 'SIGN IN';
                                          }
                                        }(),
                                        icon: () {
                                          if (_authController
                                                  .authLoading.value ||
                                              _authController
                                                  .settingsLoading.value ||
                                              _authController
                                                  .timesheetLoading.value) {
                                            return Icons.hourglass_empty;
                                          } else {
                                            return Icons.login;
                                          }
                                        }(),
                                      ),

                                      // Debug sign in button (only visible in debug mode)
                                      if (kDebugMode) ...[
                                        const SizedBox(height: 8),
                                        CompactButton(
                                          onPressed:
                                              _authController
                                                          .authLoading.value ||
                                                      _authController
                                                          .settingsLoading
                                                          .value ||
                                                      _authController
                                                          .timesheetLoading
                                                          .value
                                                  ? null
                                                  : _handleDebugSignIn,
                                          text: () {
                                            if (_authController
                                                .authLoading.value) {
                                              return 'SIGNING IN...';
                                            } else if (_authController
                                                .settingsLoading.value) {
                                              return 'LOADING SETTINGS...';
                                            } else if (_authController
                                                .timesheetLoading.value) {
                                              return 'LOADING TIMESHEETS...';
                                            } else {
                                              return 'DEBUG SIGN IN';
                                            }
                                          }(),
                                          icon: () {
                                            if (_authController
                                                    .authLoading.value ||
                                                _authController
                                                    .settingsLoading.value ||
                                                _authController
                                                    .timesheetLoading.value) {
                                              return Icons.hourglass_empty;
                                            } else {
                                              return Icons.bug_report;
                                            }
                                          }(),
                                          backgroundColor:
                                              Colors.amber.shade700,
                                        ),
                                        const SizedBox(height: 4),
                                        CompactButton(
                                          onPressed: () async {
                                            await _authController
                                                .clearSavedCredentials();
                                            showToast(
                                              "Debug: Credentials cleared",
                                              idSuccess: true,
                                            );
                                            if (kDebugMode) {
                                              print(
                                                "🗑️ Debug: Credentials manually cleared",
                                              );
                                            }
                                          },
                                          text: 'CLEAR SAVED CREDENTIALS',
                                          icon: Icons.delete_forever,
                                          backgroundColor: Colors.red.shade600,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Sign up link
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: theme.textTheme.bodySmall,
                            ),
                            TextButton(
                              onPressed: () {
                                // Navigate to sign up screen
                                showToast("Please contact you company");
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                  horizontal: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Sign Up',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
