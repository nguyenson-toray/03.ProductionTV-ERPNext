import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async';

/// Simplified HTTP Client
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

  static Future<http.Response> head(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return await http
        .head(
          Uri.parse(url),
          headers: {
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
    timeExitApp,
    announcementEnable,
    announcementBegin,
    announcementDuration,
    announcement,
    announcementTitle,
    announcementFontSize,
  );
}

/// Fetch TV Config từ ERPNext API
Future<TVConfig?> fetchTVConfigByIp(String deviceIp) async {
  try {
    const String baseUrl = 'http://10.0.1.21';
    final response = await TVHttpClient.get(
      '$baseUrl/api/resource/TV Config/config',
    );

    if (response.statusCode != 200) {
      if (kDebugMode) print('HTTP Error: ${response.statusCode}');
      return null;
    }

    final responseData = json.decode(response.body) as Map<String, dynamic>;
    final configData = _extractConfigData(responseData);

    if (configData == null) {
      if (kDebugMode) print('No valid config data found');
      return null;
    }

    // Find matching IP config or use first available
    final matchedConfig = _findMatchingConfig(configData, deviceIp);
    return matchedConfig != null ? TVConfig.fromJson(matchedConfig) : null;
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching TV config: $e');
      if (e is TimeoutException) {
        print('Timeout - check network connection');
      } else if (e is SocketException) {
        print('Network error: ${e.message}');
      }
    }
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

/// Fetch with fallback to mock data
Future<TVConfig?> fetchTVConfigByIpWithFallback(String deviceIp) async {
  final config = await fetchTVConfigByIp(deviceIp);
  if (config != null) return config;

  // Mock data for debug mode
  if (kDebugMode) {
    if (kDebugMode) print('Using mock TV config');
    return TVConfig(
      dashboardLink: 'https://example.com/dashboard',
      dashboardLinkDebug: 'https://localhost:3000/debug',
      reloadInterval: 30,
      timeExitApp: '23:00:00',
      announcementEnable: true,
      announcementBegin: '09:00:00',
      announcementDuration: 30,
      announcement: '<p>Mock announcement</p>',
      announcementTitle: 'TEST MODE',
      announcementFontSize: 18,
    );
  }

  return null;
}

/// Network diagnostics utility
class NetworkDiagnostics {
  static Future<bool> pingHost(
    String host, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final result = await InternetAddress.lookup(host).timeout(timeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      if (kDebugMode) print('Ping failed for $host: $e');
      return false;
    }
  }

  static Future<bool> hasInternetConnection() async {
    try {
      return await pingHost('8.8.8.8');
    } catch (e) {
      return false;
    }
  }

  static Future<Duration?> measureLatency(String host) async {
    try {
      final stopwatch = Stopwatch()..start();
      final result = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 10));
      stopwatch.stop();
      return result.isNotEmpty ? stopwatch.elapsed : null;
    } catch (e) {
      if (kDebugMode) print('Latency measurement failed for $host: $e');
      return null;
    }
  }
}

/// Validation utility
bool isValidTVConfig(TVConfig config) {
  if (config.dashboardLink.isEmpty || config.reloadInterval <= 0) return false;

  // Validate time formats
  return _isValidTimeFormat(config.timeExitApp) &&
      _isValidTimeFormat(config.announcementBegin);
}

bool _isValidTimeFormat(String? timeString) {
  if (timeString == null) return true;

  final parts = timeString.split(':');
  if (parts.length != 3) return false;

  try {
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final second = int.parse(parts[2]);
    return hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59 &&
        second >= 0 &&
        second <= 59;
  } catch (e) {
    return false;
  }
}
