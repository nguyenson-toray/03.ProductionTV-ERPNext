import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:async';

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
