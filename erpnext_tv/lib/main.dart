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
    // Set landscape orientation
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
  final String? _manualIp = '10.0.1.51'; // Debug IP
  TVConfig? _tvConfig;
  Timer? _reloadTimer, _exitTimer, _announcementTimer, _announcementHideTimer;
  bool _showAnnouncement = false, _loading = true;
  String? _appVersion;
  int _configRetryCount = 0;
  final int _maxConfigRetry = 3;
  String? _wifiIp;
  String? _wifiMac;

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
    _reloadTimer?.cancel();
    _exitTimer?.cancel();
    _announcementTimer?.cancel();
    _announcementHideTimer?.cancel();
  }

  Future<void> _initConfig() async {
    _deviceIp = await _getDeviceIp();
    if (_deviceIp == null) {
      _handleConfigError('Không lấy được IP thiết bị');
      return;
    }
    try {
      final config = await fetchTVConfigByIp(_deviceIp!);
      if (config == null) {
        _handleConfigError('Không lấy được config từ server');
        return;
      }
      final needReload =
          _tvConfig == null ||
          _tvConfig!.dashboardLink != config.dashboardLink ||
          _tvConfig!.reloadInterval != config.reloadInterval ||
          _tvConfig!.timeExitApp != config.timeExitApp;

      setState(() {
        _tvConfig = config;
        _loading = false;
      });

      if (needReload) {
        _setupAll();
      }
      // Reset retry count nếu thành công
      _configRetryCount = 0;

      // The following line will enable the Android and iOS wakelock.
      WakelockPlus.enable();
    } catch (e) {
      _handleConfigError(e.toString());
    }
  }

  void _handleConfigError(String error) {
    _configRetryCount++;
    if (_configRetryCount < _maxConfigRetry) {
      Future.delayed(const Duration(seconds: 10), () => _initConfig());
    } else {
      setState(() => _loading = false);
      final ip = _wifiIp ?? 'N/A';
      final mac = _wifiMac ?? 'N/A';
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flatColored,
        autoCloseDuration: const Duration(seconds: 30),
        title: const Text('Lỗi tải cấu hình'),
        showProgressBar: true,
        progressBarTheme: ProgressIndicatorThemeData(),
        icon: Icon(Icons.error_sharp, color: Colors.redAccent),
        showIcon: true,
        closeButtonShowType: CloseButtonShowType.none,
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error),
            const SizedBox(height: 8),
            Text('IP : $ip'),
            Text('MAC : $mac'),
          ],
        ),
        alignment: Alignment.bottomRight,
        padding: EdgeInsets.all(3),
        callbacks: ToastificationCallbacks(
          onAutoCompleteCompleted: (_) => _initConfig(),
        ),
      );
      _configRetryCount = 0;
    }
  }

  Future<String?> _getDeviceIp() async {
    if (kDebugMode && _manualIp != null && _manualIp.isNotEmpty)
      return _manualIp;
    final info = NetworkInfo();
    return await info.getWifiIP();
  }

  Future<void> _initAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
    });
  }

  Future<void> _initNetworkInfo() async {
    final info = NetworkInfo();
    var ip = await info.getWifiIP();
    // if (ip == '10.0.3.1') ip = '10.0.1.51'; // phone SonNT
    final mac = await info.getWifiBSSID();
    setState(() {
      _wifiIp = ip;
      _wifiMac = mac;
    });
  }

  void _setupAll() {
    _initializeWebView();
    _setupReload();
    _setupExitApp();
    _setupAnnouncement();
  }

  /// Lấy dashboard link phù hợp theo mode
  String _getDashboardLink() {
    if (_tvConfig == null) return '';

    // Nếu đang ở debug mode và có dashboardLinkDebug thì sử dụng
    if (kDebugMode &&
        _tvConfig!.dashboardLinkDebug != null &&
        _tvConfig!.dashboardLinkDebug!.isNotEmpty) {
      return _tvConfig!.dashboardLinkDebug!;
    }

    // Ngược lại sử dụng dashboardLink thông thường
    return _tvConfig!.dashboardLink;
  }

  void _initializeWebView() {
    if (_tvConfig == null) return;

    final dashboardUrl = _getDashboardLink();
    if (dashboardUrl.isEmpty) return;

    setState(() {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; Android TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        )
        ..setNavigationDelegate(_buildNavigationDelegate())
        ..addJavaScriptChannel(
          'Flutter',
          onMessageReceived: (JavaScriptMessage message) {
            print('JS Message: ${message.message}');
          },
        )
        ..loadRequest(Uri.parse(dashboardUrl));
    });
  }

  Future<void> _injectHasOwnPolyfill() async {
    const js = '''
      if (!Object.hasOwn) {
        Object.hasOwn = function(obj, prop) {
          return Object.prototype.hasOwnProperty.call(obj, prop);
        }
      }
    ''';
    try {
      await _controller?.runJavaScript(js);
    } catch (e) {
      print('Error injecting hasOwn polyfill: $e');
    }
  }

  NavigationDelegate _buildNavigationDelegate() => NavigationDelegate(
    onWebResourceError: (error) => print('WebView error: ${error.description}'),
    onPageStarted: (url) async {
      await _injectHasOwnPolyfill(); // Inject polyfill càng sớm càng tốt
    },
    onPageFinished: (url) async {}, // Không kiểm tra nội dung dashboard nữa
  );

  void _setupReload() {
    _reloadTimer?.cancel();
    if (_tvConfig == null) return;
    _reloadTimer = Timer.periodic(
      Duration(seconds: _tvConfig!.reloadInterval),
      (_) => _controller?.reload(),
    );
  }

  void _setupExitApp() {
    _exitTimer?.cancel();
    if (_tvConfig?.timeExitApp == null) return;
    final now = DateTime.now();
    final parts = _tvConfig!.timeExitApp!.split(":");
    if (parts.length != 3) return;
    final exitTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final diff = exitTime.difference(now);
    if (diff.isNegative) return;
    _exitTimer = Timer(diff, () => SystemNavigator.pop());
  }

  void _setupAnnouncement() {
    _announcementTimer?.cancel();
    _announcementHideTimer?.cancel();
    if (_tvConfig == null ||
        !_tvConfig!.announcementEnable ||
        _tvConfig!.announcementBegin == null ||
        _tvConfig!.announcementDuration == null)
      return;
    final now = DateTime.now();
    final beginParts = _tvConfig!.announcementBegin!.split(":");
    if (beginParts.length != 3) return;
    final beginTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(beginParts[0]),
      int.parse(beginParts[1]),
      int.parse(beginParts[2]),
    );
    final endTime = beginTime.add(
      Duration(minutes: _tvConfig!.announcementDuration!),
    );
    if (now.isAfter(beginTime) && now.isBefore(endTime)) {
      setState(() => _showAnnouncement = true);
      _announcementHideTimer = Timer(endTime.difference(now), () {
        setState(() => _showAnnouncement = false);
      });
    } else if (now.isBefore(beginTime)) {
      final untilBegin = beginTime.difference(now);
      _announcementTimer = Timer(untilBegin, () {
        setState(() => _showAnnouncement = true);
        _announcementHideTimer = Timer(
          Duration(minutes: _tvConfig!.announcementDuration!),
          () => setState(() => _showAnnouncement = false),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        // WebView luôn ở dưới cùng
        SafeArea(
          child: _loading || _controller == null
              ? Center(
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
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
                )
              : WebViewWidget(controller: _controller!),
        ),
        // Logo ở góc trái trên, overlay nhỏ, không che WebView
        Positioned(
          left: 5,
          top: 5,
          child: SizedBox(
            width: 90,
            height: 36,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
          ),
        ),
        // Đồng hồ ở góc phải trên
        Positioned(right: 5, top: 5, child: _DigitalClock()),
        // Announcement overlay
        if (_showAnnouncement && _tvConfig?.announcement != null)
          Positioned.fill(
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_tvConfig?.announcementTitle != null &&
                            _tvConfig!.announcementTitle!.isNotEmpty)
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
                                (_tvConfig?.announcementFontSize ?? 18)
                                    .toDouble(),
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
          ),
        // Góc phải dưới: version + Dev by Sơn.NT
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'v${_appVersion ?? ''} \nDev by Sơn.NT',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      "${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}",
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Courier',
      ),
    ),
  );
}
