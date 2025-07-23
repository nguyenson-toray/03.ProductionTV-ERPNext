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
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';

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
      home: const WebViewScreen(),
      debugShowCheckedModeBanner: false,
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
  bool _showAnnouncement = false, _loading = true;
  String? _appVersion, _wifiIp, _wifiMac, _lastContentHash;
  DateTime? _lastContentCheckTime;
  int _configRetryCount = 0;

  // Settings - Simplified
  static const Duration _timeout = Duration(seconds: 30);
  static const bool _enableContentChecking = true;
  static const int _contentCheckCooldown = 30;
  static const int _maxRetries = 3;

  // Status indicators
  bool _configLoadFailed = false;
  bool _webContentLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _initAppVersion();
    _initNetworkInfo();
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

      final oldConfig = _tvConfig;
      setState(() {
        _tvConfig = config;
        _loading = false;
        _configLoadFailed = false;
      });

      // Setup timers khi có config mới hoặc time changes
      if (oldConfig == null || _hasTimeChanges(oldConfig, config)) {
        if (kDebugMode) print('Setting up timers due to time changes');
        _setupAllTimers();
      } else if (_hasDashboardChanges(oldConfig, config)) {
        if (kDebugMode) print('Dashboard changed, updating WebView');
        _initializeWebView();
      } else if (oldConfig.reloadInterval != config.reloadInterval) {
        if (kDebugMode) print('Reload interval changed');
        _setupReloadTimer();
      }

      _configRetryCount = 0;
      WakelockPlus.enable();
    } catch (e) {
      _handleConfigError(e.toString());
    }
  }

  void _handleConfigError(String error) {
    _configRetryCount++;
    setState(() => _configLoadFailed = true);

    if (_configRetryCount < _maxRetries) {
      Future.delayed(const Duration(seconds: 10), _initConfig);
    } else {
      setState(() => _loading = false);
      _showErrorToast(error);
      _configRetryCount = 0;
    }
  }

  void _showErrorToast(String error) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      autoCloseDuration: const Duration(seconds: 30),
      title: const Text('Lỗi tải cấu hình'),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error),
          const SizedBox(height: 8),
          Text('IP: ${_wifiIp ?? 'N/A'}'),
          Text('MAC: ${_wifiMac ?? 'N/A'}'),
        ],
      ),
      alignment: Alignment.bottomRight,
      callbacks: ToastificationCallbacks(
        onAutoCompleteCompleted: (_) => _initConfig(),
      ),
    );
  }

  Future<String?> _getDeviceIp() async {
    if (kDebugMode && _manualIp?.isNotEmpty == true) return _manualIp;
    return await NetworkInfo().getWifiIP();
  }

  Future<void> _initAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = info.version);
  }

  Future<void> _initNetworkInfo() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    final mac = await info.getWifiBSSID();
    setState(() {
      _wifiIp = ip;
      _wifiMac = mac;
    });
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

  /// Smart reload - simplified
  Future<void> _smartReload() async {
    if (kDebugMode) print('Smart reload started');

    try {
      final newConfig = await fetchTVConfigByIpWithFallback(_deviceIp!);
      if (newConfig == null) return;

      final oldConfig = _tvConfig;
      if (oldConfig == null) {
        setState(() => _tvConfig = newConfig);
        _setupAllTimers();
        return;
      }

      if (oldConfig.toString() != newConfig.toString()) {
        if (kDebugMode) print('Config changed, updating...');
        setState(() => _tvConfig = newConfig);

        if (_hasTimeChanges(oldConfig, newConfig)) {
          _setupAllTimers();
        } else if (_hasDashboardChanges(oldConfig, newConfig)) {
          _initializeWebView();
        } else if (oldConfig.reloadInterval != newConfig.reloadInterval) {
          _setupReloadTimer();
        }
      } else if (_enableContentChecking) {
        await _checkWebContentChange();
      }
    } catch (e) {
      if (kDebugMode) print('Smart reload error: $e');
      _controller?.reload();
    }
  }

  /// Check web content với simplified logic
  Future<void> _checkWebContentChange() async {
    if (!_canCheckContent()) return;

    _lastContentCheckTime = DateTime.now();
    final dashboardUrl = _getDashboardLink();
    if (dashboardUrl.isEmpty) return;

    try {
      final response = await TVHttpClient.head(dashboardUrl, timeout: _timeout);
      if (response.statusCode == 200) {
        final newHash = _generateHeaderHash(
          response.headers['etag'],
          response.headers['last-modified'],
        );

        if (_lastContentHash != null && _lastContentHash != newHash) {
          if (kDebugMode) print('Content changed, reloading WebView');
          _controller?.reload();
        }
        _lastContentHash = newHash;
        setState(() => _webContentLoadFailed = false);
      }
    } catch (e) {
      if (kDebugMode) print('Content check failed: $e');
      setState(() => _webContentLoadFailed = true);
    }
  }

  bool _canCheckContent() {
    return _lastContentCheckTime == null ||
        DateTime.now().difference(_lastContentCheckTime!).inSeconds >=
            _contentCheckCooldown;
  }

  String _generateHeaderHash(String? etag, String? lastModified) {
    final headerString =
        '${etag ?? 'no-etag'}_${lastModified ?? 'no-modified'}';
    return sha256.convert(utf8.encode(headerString)).toString();
  }

  String _getDashboardLink() {
    if (_tvConfig == null) return '';

    if (kDebugMode && _tvConfig!.dashboardLinkDebug?.isNotEmpty == true) {
      return _tvConfig!.dashboardLinkDebug!;
    }
    return _tvConfig!.dashboardLink;
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
        ..setNavigationDelegate(_buildNavigationDelegate())
        ..loadRequest(Uri.parse(dashboardUrl));
    });
  }

  NavigationDelegate _buildNavigationDelegate() => NavigationDelegate(
    onWebResourceError: (error) {
      if (kDebugMode) print('WebView error: ${error.description}');
      setState(() => _webContentLoadFailed = true);
    },
    onPageStarted: (url) => _injectPolyfill(),
    onPageFinished: (url) => setState(() => _webContentLoadFailed = false),
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

    _reloadTimer = Timer.periodic(
      Duration(seconds: _tvConfig!.reloadInterval),
      (_) => _smartReload(),
    );
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

  Color _getStatusIndicatorColor() {
    if (_configLoadFailed) return Colors.red;
    if (_webContentLoadFailed) return Colors.orange;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        SafeArea(
          child: _loading || _controller == null
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
        Positioned(right: 5, top: 5, child: _DigitalClock()),

        // Announcement
        if (_showAnnouncement && _tvConfig?.announcement != null)
          _buildAnnouncementOverlay(),

        // Status & Version
        _buildStatusIndicator(),
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

  Widget _buildStatusIndicator() => Positioned(
    right: 2,
    bottom: 2,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'v${_appVersion ?? ''} - IT Team',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 6,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.right,
        ),
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 4, bottom: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusIndicatorColor(),
          ),
        ),
      ],
    ),
  );
}

class _DigitalClock extends StatefulWidget {
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
  Widget build(BuildContext context) => Text(
    "${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}",
    style: const TextStyle(
      color: Colors.black87,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      fontFamily: 'Courier',
    ),
  );
}
