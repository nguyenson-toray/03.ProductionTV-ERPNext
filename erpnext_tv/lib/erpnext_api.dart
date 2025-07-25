import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

/// HTTP Client for TV App
class TVHttpClient {
  static const Duration _timeout = Duration(seconds: 30);

  static Future<http.Response> get(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return await http
        .get(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'ERP-TV-App/1.0',
            'Connection': 'keep-alive',
            ...?headers,
          },
        )
        .timeout(timeout ?? _timeout);
  }
}

class TVConfig {
  final String dashboardLink;
  final String? dashboardLinkDebug;
  final int reloadInterval;
  final int? reloadIntervalDebug;
  final String? timeExitApp;
  final bool announcementEnable;
  final String? announcementBegin;
  final int? announcementDuration;
  final String? announcement;
  final String? announcementTitle;
  final int? announcementFontSize;

  const TVConfig({
    required this.dashboardLink,
    this.dashboardLinkDebug,
    required this.reloadInterval,
    this.reloadIntervalDebug,
    this.timeExitApp,
    required this.announcementEnable,
    this.announcementBegin,
    this.announcementDuration,
    this.announcement,
    this.announcementTitle,
    this.announcementFontSize,
  });

  factory TVConfig.fromJson(Map<String, dynamic> json) {
    return TVConfig(
      dashboardLink: json['dashboard_link'] ?? '',
      dashboardLinkDebug: json['dashboard_link_debug'],
      reloadInterval: json['reload_interval'] ?? 60,
      reloadIntervalDebug: json['reload_interval_debug'],
      timeExitApp: json['time_exit_app'],
      announcementEnable: _parseBool(json['announcement_enable']),
      announcementBegin: json['announcement_begin'],
      announcementDuration: json['announcement_duration'],
      announcement: json['announcement'],
      announcementTitle: json['announcement_title'],
      announcementFontSize: json['announcement_font_size'],
    );
  }

  static bool _parseBool(dynamic value) {
    if (value is int) return value == 1;
    if (value is bool) return value;
    return false;
  }

  @override
  String toString() {
    return 'TVConfig{'
        'dashboardLink: "$dashboardLink", '
        'dashboardLinkDebug: "${dashboardLinkDebug ?? 'null'}", '
        'reloadInterval: $reloadInterval, '
        'reloadIntervalDebug: ${reloadIntervalDebug ?? 'null'}, '
        'timeExitApp: "${timeExitApp ?? 'null'}", '
        'announcementEnable: $announcementEnable, '
        'announcementBegin: "${announcementBegin ?? 'null'}", '
        'announcementDuration: ${announcementDuration ?? 'null'}, '
        'announcementTitle: "${announcementTitle ?? 'null'}", '
        'announcementFontSize: ${announcementFontSize ?? 'null'}'
        '}';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TVConfig &&
            other.dashboardLink == dashboardLink &&
            other.dashboardLinkDebug == dashboardLinkDebug &&
            other.reloadInterval == reloadInterval &&
            other.reloadIntervalDebug == reloadIntervalDebug &&
            other.timeExitApp == timeExitApp &&
            other.announcementEnable == announcementEnable &&
            other.announcementBegin == announcementBegin &&
            other.announcementDuration == announcementDuration &&
            other.announcement == announcement &&
            other.announcementTitle == announcementTitle &&
            other.announcementFontSize == announcementFontSize;
  }

  @override
  int get hashCode => Object.hash(
    dashboardLink,
    dashboardLinkDebug,
    reloadInterval,
    reloadIntervalDebug,
    timeExitApp,
    announcementEnable,
    announcementBegin,
    announcementDuration,
    announcement,
    announcementTitle,
    announcementFontSize,
  );
}

/// Fetch TV Config from ERPNext API
Future<TVConfig?> fetchTVConfigByIp(String deviceIp) async {
  try {
    String apiUrl;
    if (kDebugMode) {
      apiUrl = 'http://erp-sonnt.tiqn.local/api/resource/TV Config/config';
    } else {
      apiUrl = 'http://erp.tiqn.local/api/resource/TV Config/config';
    }

    final response = await TVHttpClient.get(apiUrl);
    if (response.statusCode != 200) return null;

    final responseData = json.decode(response.body) as Map<String, dynamic>;
    final configData = _extractConfigData(responseData);
    if (configData == null) return null;

    final matchedConfig = _findMatchingConfig(configData, deviceIp);
    return matchedConfig != null ? TVConfig.fromJson(matchedConfig) : null;
  } catch (e) {
    if (kDebugMode) print('Config fetch error: $e');
    return null;
  }
}

Map<String, dynamic>? _extractConfigData(Map<String, dynamic> responseData) {
  final data = responseData['data'];
  if (data is Map<String, dynamic>) {
    return data;
  } else if (data is List && data.isNotEmpty) {
    return data.first as Map<String, dynamic>?;
  }
  return null;
}

Map<String, dynamic>? _findMatchingConfig(
  Map<String, dynamic> configData,
  String deviceIp,
) {
  final configs = configData['config'];
  if (configs == null) return configData;

  final configList = configs is List ? configs : [configs];

  // Find exact IP match
  for (final detail in configList) {
    if (detail is Map<String, dynamic> && detail['ip'] == deviceIp) {
      return {...configData, ...detail};
    }
  }

  // Use first config if no IP match
  if (configList.isNotEmpty && configList.first is Map<String, dynamic>) {
    return {...configData, ...configList.first};
  }

  return configData;
}

/// Test network connectivity using internal network (gateway + server)
Future<bool> pingServer(String host, {int timeout = 5}) async {
  if (kDebugMode) print('🔍 Testing internal network connectivity to: $host (timeout: ${timeout}s)');
  
  // Method 1: Test local network connectivity via default gateway
  final hasLocalNetwork = await _testGatewayConnectivity();
  if (!hasLocalNetwork) {
    if (kDebugMode) print('❌ No local network connectivity - Gateway unreachable');
    return false;
  }
  
  // Method 2: Test target server connectivity  
  final serverReachable = await _testServerConnectivity(host, timeout);
  if (kDebugMode) print(serverReachable ? '✅ Server reachable' : '❌ Server unreachable');
  
  return serverReachable;
}

/// Test local network connectivity via default gateway
Future<bool> _testGatewayConnectivity() async {
  const defaultGateway = '10.0.0.1';
  
  try {
    if (kDebugMode) print('📡 Testing gateway connectivity: $defaultGateway');
    
    // Try to connect to default gateway via HTTP (most routers have web interface)
    final stopwatch = Stopwatch()..start();
    final response = await TVHttpClient.get(
      'http://$defaultGateway',
      timeout: Duration(seconds: 3),
    );
    stopwatch.stop();
    
    // Any response from gateway means local network is working
    if (response.statusCode > 0) {
      if (kDebugMode) print('✅ Gateway reachable: $defaultGateway (${stopwatch.elapsedMilliseconds}ms) - Status ${response.statusCode}');
      return true;
    }
    
    if (kDebugMode) print('❌ Gateway HTTP failed: $defaultGateway');
    return false;
  } catch (e) {
    // Try fallback method - DNS lookup of gateway
    try {
      final addresses = await InternetAddress.lookup(defaultGateway)
          .timeout(Duration(seconds: 2));
      
      if (addresses.isNotEmpty) {
        if (kDebugMode) print('✅ Gateway reachable via DNS lookup: $defaultGateway');
        return true;
      }
    } catch (e2) {
      if (kDebugMode) print('❌ Gateway completely unreachable: $defaultGateway - $e');
    }
    
    return false;
  }
}

/// Test connectivity to server host using internal network
Future<bool> _testServerConnectivity(String host, int timeout) async {
  try {
    if (kDebugMode) print('🎯 Testing server connectivity: $host');
    final stopwatch = Stopwatch()..start();
    
    // Try DNS lookup first to get server IP
    final addresses = await InternetAddress.lookup(host)
        .timeout(Duration(seconds: timeout ~/ 2));
    
    if (addresses.isEmpty) {
      if (kDebugMode) print('❌ Server DNS lookup failed: $host');
      return false;
    }
    
    final serverIp = addresses.first.address;
    if (kDebugMode) print('✅ Server DNS lookup OK: $host → $serverIp');
    
    // Try HTTP connection to verify actual server connectivity
    try {
      final response = await TVHttpClient.get(
        'http://$host',
        timeout: Duration(seconds: timeout),
      );
      stopwatch.stop();
      
      if (kDebugMode) print('✅ Server HTTP test: $host (${stopwatch.elapsedMilliseconds}ms) - Status ${response.statusCode}');
      return true;
    } catch (e) {
      stopwatch.stop();
      if (kDebugMode) print('❌ Server HTTP test failed: $host (${stopwatch.elapsedMilliseconds}ms) - $e');
      return false;
    }
  } catch (e) {
    if (kDebugMode) print('❌ Server connectivity test error: $host - $e');
    return false;
  }
}

/// Get server host from API URL
String getServerHost() {
  if (kDebugMode) {
    return 'erp-sonnt.tiqn.local';
  } else {
    return 'erp.tiqn.local';
  }
}

/// Wifi IOT control for turning wifi off/on
Future<bool> toggleWifi({required bool enable}) async {
  try {
    if (kDebugMode) print('Toggle WiFi: ${enable ? "ON" : "OFF"}');
    
    // Try multiple methods for WiFi control
    bool success = false;
    
    // Method 1: Try with su -c (requires root)
    try {
      final command = enable ? 'svc wifi enable' : 'svc wifi disable';
      final result = await Process.run('su', ['-c', command]);
      
      if (result.exitCode == 0) {
        if (kDebugMode) print('WiFi toggle successful (su): ${enable ? "enabled" : "disabled"}');
        success = true;
      } else {
        if (kDebugMode) print('WiFi toggle failed (su): ${result.stderr}');
      }
    } catch (e) {
      if (kDebugMode) print('WiFi toggle (su) error: $e');
    }
    
    // Method 2: Try direct shell command if su failed
    if (!success) {
      try {
        final command = enable ? 'svc wifi enable' : 'svc wifi disable';
        final result = await Process.run('sh', ['-c', command]);
        
        if (result.exitCode == 0) {
          if (kDebugMode) print('WiFi toggle successful (sh): ${enable ? "enabled" : "disabled"}');
          success = true;
        } else {
          if (kDebugMode) print('WiFi toggle failed (sh): ${result.stderr}');
        }
      } catch (e) {
        if (kDebugMode) print('WiFi toggle (sh) error: $e');
      }
    }
    
    // Method 3: Fallback - just log and return true (for testing)
    if (!success) {
      if (kDebugMode) print('WiFi toggle fallback: Simulating ${enable ? "ON" : "OFF"} (no actual control)');
      // In production, you might want to return false here
      // For testing/debugging, we'll return true to continue the flow
      success = kDebugMode; // true in debug, false in release
    }
    
    return success;
  } catch (e) {
    if (kDebugMode) print('WiFi toggle general error: $e');
    return false;
  }
}

/// Fetch config with fallback to mock data
Future<TVConfig?> fetchTVConfigByIpWithFallback(String deviceIp) async {
  final config = await fetchTVConfigByIp(deviceIp);
  if (config != null) return config;

  // Mock data for debug mode when server unavailable
  if (kDebugMode) {
    if (kDebugMode) print('Using mock config - server unavailable');
    return TVConfig(
      dashboardLink: 'about:blank',
      dashboardLinkDebug: 'about:blank',
      reloadInterval: 600,
      reloadIntervalDebug: 10,
      timeExitApp: '16:5:00',
      announcementEnable: true,
      announcementBegin: '07:50:00',
      announcementDuration: 5,
      announcement: '<p>Không thể kết nối server. Chế độ offline.</p>',
      announcementTitle: 'CHẾ ĐỘ OFFLINE',
      announcementFontSize: 18,
    );
  }
  return null;
}
