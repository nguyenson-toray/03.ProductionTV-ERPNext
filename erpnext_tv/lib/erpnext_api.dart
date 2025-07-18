import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

@immutable
class TVConfig {
  final String dashboardLink;
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
    required this.reloadInterval,
    this.timeExitApp,
    required this.announcementEnable,
    this.announcementBegin,
    this.announcementDuration,
    this.announcement,
    this.announcementTitle,
    this.announcementFontSize,
  });

  factory TVConfig.fromMap(
    Map<String, dynamic> config,
    Map<String, dynamic> detail,
  ) {
    return TVConfig(
      dashboardLink: detail['dashboard_link'] ?? '',
      reloadInterval: config['reload_interval'] ?? 30,
      timeExitApp: config['time_exit_app'],
      announcementEnable: (config['announcement_enable'] ?? 0) == 1,
      announcementBegin: config['announcement_begin'],
      announcementDuration: config['announcement_duration'],
      announcement: config['announcement'],
      announcementTitle: config['announcement_title'],
      announcementFontSize: config['announcement_font_size'],
    );
  }

  Map<String, dynamic> toMap() => {
    'dashboardLink': dashboardLink,
    'reloadInterval': reloadInterval,
    'timeExitApp': timeExitApp,
    'announcementEnable': announcementEnable,
    'announcementBegin': announcementBegin,
    'announcementDuration': announcementDuration,
    'announcement': announcement,
  };

  bool isEqual(TVConfig other) =>
      dashboardLink == other.dashboardLink &&
      reloadInterval == other.reloadInterval &&
      timeExitApp == other.timeExitApp &&
      announcementEnable == other.announcementEnable &&
      announcementBegin == other.announcementBegin &&
      announcementDuration == other.announcementDuration &&
      announcement == other.announcement;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TVConfig && runtimeType == other.runtimeType && isEqual(other);

  @override
  int get hashCode => Object.hash(
    dashboardLink,
    reloadInterval,
    timeExitApp,
    announcementEnable,
    announcementBegin,
    announcementDuration,
    announcement,
  );
}

Future<TVConfig?> fetchTVConfigByIp(String ip) async {
  final url = Uri.parse(
    kDebugMode
        ? 'http://erp-sonnt.tiqn.local/api/resource/TV Config/config'
        : 'http://erp.tiqn.local/api/resource/TV Config/config',
  );
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final config = data['data'];
    if (config == null || config['config'] == null) return null;
    final List details = config['config'];
    final detail = details.firstWhere(
      (item) => item['ip'] == ip,
      orElse: () => null,
    );
    if (detail == null) return null;
    return TVConfig.fromMap(config, detail);
  }
  return null;
}
