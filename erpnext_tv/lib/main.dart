import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter_html/flutter_html.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'erpnext_api.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:toastification/toastification.dart';

void main() => runApp(const ToastificationWrapper(child: MyApp()));

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    return MaterialApp(
      title: 'ERP TV App',
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WebViewScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/logo.png'),
            const SizedBox(height: 16.0),
            const Text(
              textAlign: TextAlign.center,
              'Công Ty TNHH TORAY International Việt Nam\nChi Nhánh Quảng Ngãi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  String? _deviceIp;
  final String? _manualIp = '10.0.1.51';
  TVConfig? _tvConfig;
  Timer? _reloadTimer, _exitTimer, _announcementTimer, _announcementHideTimer;
  bool _showAnnouncement = false;
  String? _appVersion;
  int _consecutiveTimeouts = 0;
  TVConfig? _savedConfig;
  bool _hasNetworkError = false;
  bool _hasConfigError = false;
  Timer? _forceReloadTimer;
  Timer? _configRetryTimer;
  bool _isAppInitialized = false;


  @override
  void initState() {
    super.initState();
    _initAppVersion();
    _initConfig();
  }

  @override
  void dispose() {
    _cancelAllTimers();
    super.dispose();
  }

  void _cancelAllTimers() {
    [
      _reloadTimer,
      _exitTimer,
      _announcementTimer,
      _announcementHideTimer,
      _forceReloadTimer,
      _configRetryTimer,
    ].forEach((timer) => timer?.cancel());
  }

  Future<void> _initConfig() async {
    _deviceIp = await _getDeviceIp();
    if (_deviceIp == null) {
      _handleConfigError('Không lấy được IP thiết bị');
      return;
    }

    try {
      final config = await fetchTVConfigByIpWithFallback(_deviceIp!);
      if (config == null) {
        _handleConfigError('Không lấy được config từ server');
        return;
      }

      // First time load: Save config and mark as initialized
      if (!_isAppInitialized) {
        if (kDebugMode) print('Initial app startup - saving config and marking as initialized');
        _savedConfig = config;
        setState(() {
          _tvConfig = config;
          _hasNetworkError = false;
          _hasConfigError = false;
          _isAppInitialized = true; // Mark app as initialized
        });
        _configRetryTimer?.cancel(); // Cancel retry timer on success
        _forceReloadTimer?.cancel(); // Cancel force reload timer on success
        _setupAllTimers();
        WakelockPlus.enable();
        return;
      }

      // Post-initialization: Apply config and check for changes
      setState(() {
        _tvConfig = config;
        _hasNetworkError = false;
        _hasConfigError = false;
      });

      // Compare with saved config for changes
      if (_hasTimeChanges(_savedConfig!, config)) {
        if (kDebugMode) print('Time changes detected → Setup timers');
        _setupAllTimers();
        _savedConfig = config;
      } else if (_hasDashboardChanges(_savedConfig!, config)) {
        if (kDebugMode) print('Link changes detected → Reinit WebView');
        _initializeWebView();
        _savedConfig = config;
      } else {
        if (kDebugMode) print('No config changes → Reload WebView with check');
        _reloadWebViewWithCheck();
      }
    } catch (e) {
      if (kDebugMode) print('Config loading exception: $e');
      _handleConfigError(e.toString());
    }
  }

  void _handleConfigError(String error) {
    setState(() {
      _hasConfigError = true;
      _hasNetworkError = false;
    });

    if (!_isAppInitialized) {
      // During startup: Retry config loading every 30s until success
      if (kDebugMode) print('Startup config error: $error - retrying in 30s');
      _configRetryTimer?.cancel();
      _configRetryTimer = Timer(const Duration(seconds: 30), () {
        if (kDebugMode) print('Retrying config load after 30s...');
        _initConfig();
      });
    } else {
      // After initialization: Don't retry config, just log error
      if (kDebugMode) print('Post-init config error: $error - keeping current config');
    }
  }


  Future<String?> _getDeviceIp() async {
    // Debug mode: Use manual IP if set
    if (kDebugMode && _manualIp?.isNotEmpty == true) return _manualIp;
    return await NetworkInfo().getWifiIP();
  }

  Future<void> _initAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = info.version);
  }


  /// Setup tất cả timers khi có thay đổi time-related
  void _setupAllTimers() {
    _cancelAllTimers();
    _initializeWebView();
    _setupReloadTimer();
    _setupExitTimer();
    _setupAnnouncementTimer();
  }

  /// Kiểm tra thay đổi liên quan time
  bool _hasTimeChanges(TVConfig oldConfig, TVConfig newConfig) {
    return oldConfig.timeExitApp != newConfig.timeExitApp ||
        oldConfig.announcementBegin != newConfig.announcementBegin ||
        oldConfig.announcementDuration != newConfig.announcementDuration ||
        oldConfig.announcementEnable != newConfig.announcementEnable;
  }

  /// Kiểm tra thay đổi dashboard
  bool _hasDashboardChanges(TVConfig oldConfig, TVConfig newConfig) {
    return oldConfig.dashboardLink != newConfig.dashboardLink ||
        oldConfig.dashboardLinkDebug != newConfig.dashboardLinkDebug;
  }

  /// Smart reload based on initialization state
  Future<void> _smartReload() async {
    if (kDebugMode) print('Smart reload started');

    if (!_isAppInitialized) {
      // During startup: Try to load initial config
      if (kDebugMode) print('App not initialized yet, attempting config load');
      await _initConfig();
    } else {
      // After initialization: Only reload config to check for changes
      if (kDebugMode) print('App initialized, checking for config changes');
      await _initConfig();
    }
  }



  String _getDashboardLink() {
    if (_tvConfig == null) return '';

    // Debug mode: Use debug link if available
    if (kDebugMode && _tvConfig!.dashboardLinkDebug?.isNotEmpty == true) {
      return _tvConfig!.dashboardLinkDebug!;
    }
    return _tvConfig!.dashboardLink;
  }

  /// Check URL content and reload WebView if valid
  Future<void> _reloadWebViewWithCheck() async {
    final dashboardUrl = _getDashboardLink();
    if (dashboardUrl.isEmpty || dashboardUrl == 'about:blank') {
      if (kDebugMode) print('Invalid URL, setting config error');
      setState(() {
        _hasConfigError = true;
        _hasNetworkError = false;
      });
      return;
    }

    try {
      if (kDebugMode) print('Checking URL before reload: $dashboardUrl');
      final response = await TVHttpClient.get(dashboardUrl, timeout: Duration(seconds: 10));
      
      if (response.statusCode >= 200 && response.statusCode < 400) {
        if (kDebugMode) print('URL valid, reloading WebView');
        _controller?.loadRequest(Uri.parse(dashboardUrl));
        setState(() {
          _hasNetworkError = false;
          _hasConfigError = false;
        });
        _forceReloadTimer?.cancel();
      } else {
        if (kDebugMode) print('URL error ${response.statusCode}, keeping current WebView');
        _handleUrlError();
      }
    } catch (e) {
      if (kDebugMode) print('URL check failed: $e, keeping current WebView');
      _handleUrlError();
    }
  }

  /// Handle URL errors - keep current WebView, start force reload timer
  void _handleUrlError() {
    setState(() {
      _hasNetworkError = true;
      _hasConfigError = false;
    });
    _startForceReloadTimer();
  }

  void _initializeWebView() {
    final dashboardUrl = _getDashboardLink();
    if (dashboardUrl.isEmpty) return;

    setState(() {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; Android TV) AppleWebKit/537.36',
        )
        ..setNavigationDelegate(_buildNavigationDelegate());
    });
    
    // Check if URL is valid before loading
    if (dashboardUrl == 'about:blank') {
      if (kDebugMode) print('Mock config detected, setting config error (no URL force reload needed)');
      setState(() {
        _hasConfigError = true;
        _hasNetworkError = false;
      });
      // Mock config doesn't need URL force reload
    } else {
      // Load URL with validation
      _loadUrlSafely(dashboardUrl);
    }
  }
  
  /// Start 30s force reload timer for URL only (not config)
  void _startForceReloadTimer() {
    _forceReloadTimer?.cancel();
    if (kDebugMode) print('Starting 30s URL force reload timer');
    
    _forceReloadTimer = Timer(const Duration(seconds: 30), () {
      if (kDebugMode) print('Force reload URL after 30s error timeout (no config reload)');
      _performForceReload();
    });
  }
  
  /// Force reload WebView after error timeout - simple URL reload
  void _performForceReload() {
    final dashboardUrl = _getDashboardLink();
    if (dashboardUrl.isEmpty || dashboardUrl == 'about:blank') {
      if (kDebugMode) print('Force reload skipped: Invalid URL');
      return;
    }
    
    if (kDebugMode) print('Force reload: Loading $dashboardUrl');
    _controller?.loadRequest(Uri.parse(dashboardUrl));
  }

  /// Load URL with validation and error handling
  Future<void> _loadUrlSafely(String url) async {
    if (kDebugMode) print('Validating URL before loading: $url');
    
    // First validate URL by checking if it's reachable
    final isValid = await _validateUrl(url);
    if (!isValid) {
      if (kDebugMode) print('URL validation failed, setting error state but NOT loading');
      setState(() {
        _hasNetworkError = true;
        _hasConfigError = false;
      });
      _startForceReloadTimer();
      return;
    }
    
    try {
      if (kDebugMode) print('URL validated successfully, loading: $url');
      await _controller?.loadRequest(Uri.parse(url));
    } catch (e) {
      if (kDebugMode) print('URL loading failed after validation: $e');
      // Don't change WebView content on loading error, just set error state
      setState(() {
        _hasNetworkError = true;
        _hasConfigError = false;
      });
      _startForceReloadTimer();
    }
  }
  
  /// Validate URL by attempting to connect
  Future<bool> _validateUrl(String url) async {
    try {
      final response = await TVHttpClient.get(url, timeout: Duration(seconds: 5));
      final isValid = response.statusCode >= 200 && response.statusCode < 400;
      if (kDebugMode) print('URL validation result: $isValid (status: ${response.statusCode})');
      return isValid;
    } catch (e) {
      if (kDebugMode) print('URL validation error: $e');
      return false;
    }
  }

  NavigationDelegate _buildNavigationDelegate() => NavigationDelegate(
    onWebResourceError: (error) {
      if (kDebugMode) print('WebView error: ${error.description}');

      // Track consecutive timeouts
      if (error.description.contains('TIMED_OUT') || 
          error.description.contains('ERR_NETWORK') ||
          error.description.contains('ERR_CONNECTION')) {
        _consecutiveTimeouts++;
        if (kDebugMode) print('Network error (consecutive: $_consecutiveTimeouts): ${error.description}');
      } else {
        _consecutiveTimeouts = 0;
      }

      setState(() {
        _hasNetworkError = true; // Update network error state for clock
        _hasConfigError = false; // Clear config error when network error
      });
      
      // Start 30s force reload timer on network error
      _startForceReloadTimer();
      
      if (kDebugMode) print('Network error detected, error state set but WebView content unchanged');
    },
    onNavigationRequest: (request) {
      // Always block navigation to error pages
      if (request.url.contains('chrome-error://') || 
          request.url.contains('chrome://') ||
          request.url.contains('data:text/html,<')) {
        if (kDebugMode) print('Blocked navigation to error page: ${request.url}');
        return NavigationDecision.prevent;
      }
      
      // Allow about:blank and data:text/html for our offline page
      if (request.url == 'about:blank' || 
          request.url.startsWith('data:text/html')) {
        return NavigationDecision.navigate;
      }
      
      // Allow navigation to dashboard URLs
      final dashboardUrl = _getDashboardLink();
      if (dashboardUrl.isNotEmpty && 
          dashboardUrl != 'about:blank' &&
          request.url.startsWith(dashboardUrl.split('?')[0])) {
        return NavigationDecision.navigate;
      }
      
      // Block all other navigation
      if (kDebugMode) print('Blocked navigation to unknown URL: ${request.url}');
      return NavigationDecision.prevent;
    },
    onPageStarted: (url) {
      // Only inject polyfill for valid dashboard URLs
      if (!url.contains('chrome-error://')) {
        _injectPolyfill();
      }
    },
    onPageFinished: (url) {
      // Only consider it successful if it's not an error page
      if (!url.contains('chrome-error://') && !url.contains('data:text/html')) {
        _consecutiveTimeouts = 0; // Reset on successful load
        setState(() {
          _hasNetworkError = false; // Clear network error on successful page load
          _hasConfigError = false; // Clear config error on successful page load
        });
        _forceReloadTimer?.cancel(); // Cancel force reload timer on success
        if (kDebugMode) print('Page loaded successfully: $url');
      } else {
        if (kDebugMode) print('Error page detected, keeping previous state: $url');
      }
    },
  );

  Future<void> _injectPolyfill() async {
    try {
      await _controller?.runJavaScript('''
        if (!Object.hasOwn) {
          Object.hasOwn = function(obj, prop) {
            return Object.prototype.hasOwnProperty.call(obj, prop);
          }
        }
      ''');
    } catch (e) {
      if (kDebugMode) print('Polyfill injection failed: $e');
    }
  }

  void _setupReloadTimer() {
    _reloadTimer?.cancel();
    if (_tvConfig == null) return;

    final interval = _getReloadInterval(_tvConfig!);
    _reloadTimer = Timer.periodic(
      Duration(seconds: interval),
      (_) => _smartReload(),
    );
    if (kDebugMode) print('Reload timer set to ${interval}s (${kDebugMode ? 'debug' : 'release'} mode)');
  }

  void _setupExitTimer() {
    _exitTimer?.cancel();
    if (_tvConfig?.timeExitApp == null) return;

    final exitTime = _parseTime(_tvConfig!.timeExitApp!);
    if (exitTime == null) return;

    final now = DateTime.now();
    final diff = exitTime.difference(now);
    if (diff.isNegative) return;

    _exitTimer = Timer(diff, () => SystemNavigator.pop());
    if (kDebugMode)
      print(
        'Exit timer set for ${exitTime.hour}:${exitTime.minute}:${exitTime.second}',
      );
  }

  void _setupAnnouncementTimer() {
    _announcementTimer?.cancel();
    _announcementHideTimer?.cancel();

    if (_tvConfig == null ||
        !_tvConfig!.announcementEnable ||
        _tvConfig!.announcementBegin == null ||
        _tvConfig!.announcementDuration == null)
      return;

    final beginTime = _parseTime(_tvConfig!.announcementBegin!);
    if (beginTime == null) return;

    final endTime = beginTime.add(
      Duration(minutes: _tvConfig!.announcementDuration!),
    );
    final now = DateTime.now();

    if (now.isAfter(beginTime) && now.isBefore(endTime)) {
      // Currently in announcement period
      setState(() => _showAnnouncement = true);
      _announcementHideTimer = Timer(
        endTime.difference(now),
        () => setState(() => _showAnnouncement = false),
      );
    } else if (now.isBefore(beginTime)) {
      // Schedule announcement
      _announcementTimer = Timer(beginTime.difference(now), () {
        setState(() => _showAnnouncement = true);
        _announcementHideTimer = Timer(
          Duration(minutes: _tvConfig!.announcementDuration!),
          () => setState(() => _showAnnouncement = false),
        );
      });
    }

    if (kDebugMode) {
      print(
        'Announcement timer set: ${beginTime.hour}:${beginTime.minute} for ${_tvConfig!.announcementDuration}min',
      );
    }
  }

  DateTime? _parseTime(String timeString) {
    final parts = timeString.split(':');
    if (parts.length != 3) return null;

    try {
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (e) {
      return null;
    }
  }



  /// Get appropriate reload interval based on app mode
  int _getReloadInterval(TVConfig config) {
    // Debug mode: Use debug reload interval if available
    if (kDebugMode && config.reloadIntervalDebug != null) {
      return config.reloadIntervalDebug!;
    }
    return config.reloadInterval;
  }


  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        SafeArea(
          child: _controller == null
              ? _buildLoadingWidget()
              : WebViewWidget(controller: _controller!),
        ),

        // Logo
        Positioned(
          left: 5,
          top: 5,
          child: SizedBox(
            width: 90,
            height: 36,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
        ),

        // Clock
        Positioned(right: 5, top: 5, child: _DigitalClock(
          hasNetworkError: _hasNetworkError,
          hasConfigError: _hasConfigError,
        )),

        // Announcement
        if (_showAnnouncement && _tvConfig?.announcement != null)
          _buildAnnouncementOverlay(),

        // Version only
        _buildVersionInfo(),
      ],
    ),
  );

  Widget _buildLoadingWidget() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const CircularProgressIndicator(
            strokeWidth: 7,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Đang tải dữ liệu...',
          style: TextStyle(
            fontSize: 18,
            color: kDebugMode ? Colors.orange : Colors.blue,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _buildAnnouncementOverlay() => Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_tvConfig?.announcementTitle?.isNotEmpty == true)
                  Text(
                    _tvConfig!.announcementTitle!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 12),
                Html(
                  data: _tvConfig!.announcement!,
                  style: {
                    "body": Style(
                      fontSize: FontSize(
                        (_tvConfig?.announcementFontSize ?? 18).toDouble(),
                      ),
                      lineHeight: LineHeight(1.1),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildVersionInfo() => Positioned(
    right: 2,
    bottom: 2,
    child: Text(
      'v${_appVersion ?? ''} - IT Team',
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 6,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.right,
    ),
  );
}

class _DigitalClock extends StatefulWidget {
  final bool hasNetworkError;
  final bool hasConfigError;
  
  const _DigitalClock({
    super.key, 
    this.hasNetworkError = false,
    this.hasConfigError = false,
  });
  
  @override
  State<_DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<_DigitalClock> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color clockColor = Colors.black87; // Default color
    
    if (widget.hasConfigError) {
      clockColor = Colors.orange; // Config error = orange
    } else if (widget.hasNetworkError) {
      clockColor = Colors.red; // Network error = red
    }
    
    return Text(
      "${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}",
      style: TextStyle(
        color: clockColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Courier',
      ),
    );
  }
}
