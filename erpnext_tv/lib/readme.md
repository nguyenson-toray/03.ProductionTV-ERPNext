# TV Dashboard Flutter App - Enhanced Version

## 🚀 Overview

Enhanced ERP TV Dashboard App với smart reload system, intelligent timer management, và comprehensive error handling.

## ✨ Key Features

### 🎯 Smart Reload System
- **Config-based reload**: Chỉ reload khi cần thiết
- **Content change detection**: Monitor dashboard content changes
- **Intelligent updates**: Phân biệt loại thay đổi và xử lý phù hợp

### ⏱️ Unified Timeout System  
- **30 seconds timeout** cho tất cả HTTP requests
- **30 seconds timeout** cho WebView loading
- **30 seconds cooldown** cho content checking
- **Simplified configuration** - không còn multiple timeout settings

### 🔄 Smart Timer Management
- **Time changes detection**: Tự động restart timers khi time settings thay đổi
- **Selective updates**: Chỉ update components cần thiết
- **Robust scheduling**: Exit app timer và announcement timer

### 📱 Status Indicator
- **Visual feedback**: Ô tròn nhỏ 8x8px ở góc phải dưới
- **3 trạng thái**: 🔴 Config fail, 🟠 WebView fail, ⚪ Normal
- **Real-time status**: Cập nhật theo tình trạng hệ thống

## 📦 Installation

### 1. Dependencies
Thêm vào `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  webview_flutter: ^4.4.2
  http: ^1.1.0
  crypto: ^3.0.3
  network_info_plus: ^4.1.0
  wakelock_plus: ^1.1.4
  package_info_plus: ^4.2.0
  toastification: ^1.2.1
  flutter_html: ^3.0.0-beta.2
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Copy Files
- Copy `main.dart` → Replace existing main.dart
- Copy `erpnext_api.dart` → Add to `lib/` folder

### 4. Configure API
Edit `erpnext_api.dart` line 115:
```dart
const String baseUrl = 'http://YOUR_ERPNEXT_IP';
```

## ⚙️ Configuration

### Timeout Settings
```dart
// main.dart line 29
static const Duration _timeout = Duration(seconds: 30);
```

### Content Checking
```dart
// main.dart lines 30-31
static const bool _enableContentChecking = true;
static const int _contentCheckCooldown = 30; // seconds
```

### Retry Settings  
```dart
// main.dart line 32
static const int _maxRetries = 3;
```

## 🏗️ ERPNext Setup

### DocType Structure

#### TV Config (Parent)
```
- reload_interval (Int): Seconds between reloads
- time_exit_app (Time): Time to auto-exit app (HH:MM:SS)
- announcement_enable (Check): Enable/disable announcements
- announcement_begin (Time): Announcement start time (HH:MM:SS)  
- announcement_duration (Int): Duration in minutes
- announcement_title (Small Text): Announcement title
- announcement (Text Editor): HTML announcement content
- announcement_font_size (Int): Font size for announcement
- config (Table): TV Config Detail records
```

#### TV Config Detail (Child Table)
```
- location (Select): Device location
- ip (Data): Device IP address
- mac (Data): Device MAC address  
- dashboard_link (Data): Production dashboard URL
- dashboard_link_debug (Data): Debug dashboard URL
```

### API Endpoint
```
GET /api/resource/TV Config/config
```

### Sample Response
```json
{
  "data": {
    "reload_interval": 60,
    "time_exit_app": "23:00:00",
    "announcement_enable": 1,
    "announcement_begin": "09:00:00",
    "announcement_duration": 30,
    "announcement_title": "COMPANY ANNOUNCEMENT",
    "announcement": "<p>Important announcement content</p>",
    "announcement_font_size": 18,
    "config": [
      {
        "location": "Line 1",
        "ip": "10.0.1.51",
        "mac": "AA:BB:CC:DD:EE:FF",
        "dashboard_link": "https://erp.company.com/dashboard/line1",
        "dashboard_link_debug": "http://localhost:3000/debug"
      }
    ]
  }
}
```

## 🔄 Smart Logic Flow

### Config Change Detection
```
Timer Trigger → Fetch New Config
├── Config unchanged? → Check web content (if enabled)
├── Time settings changed? → Restart ALL timers
├── Dashboard URL changed? → Reload WebView only
├── Reload interval changed? → Restart reload timer only
└── Other changes? → Full setup
```

### Timer Management
```
Time Settings Changed Detection:
├── timeExitApp → Restart exit timer
├── announcementBegin → Restart announcement timer
├── announcementDuration → Restart announcement timer  
└── announcementEnable → Restart announcement timer
```

## 📱 UI Layout

```
┌─────────────────────────────────┐
│ Logo (90x36)            Clock   │
│                                 │
│                                 │
│         WebView Content         │
│                                 │
│                                 │
│                        ●v1.0.0  │ ← Status (8x8px)
│                        IT Team  │
└─────────────────────────────────┘
```

### Components
- **Logo**: Top-left corner, 90x36px
- **Digital Clock**: Top-right corner, updates every second
- **WebView**: Full screen dashboard content
- **Announcement**: Full-screen overlay when active
- **Status Indicator**: Bottom-right, 8x8px circle
- **Version Info**: Bottom-right, small text

## 🎯 Status Indicator

### Colors & Meanings
- 🔴 **Red**: Config API failed
  - ERPNext server not reachable
  - API authentication failed
  - Network connectivity issues

- 🟠 **Orange**: WebView/Content load failed  
  - Dashboard URL not accessible
  - WebView timeout
  - Content checking failed

- ⚪ **Transparent**: All systems operational
  - Config loaded successfully
  - WebView working
  - All timers active

## 🔍 Debug & Logging

### Console Output Examples
```
I/flutter: Smart reload started
I/flutter: Config changed, updating...
I/flutter: Setting up timers due to time changes
I/flutter: Exit timer set for 23:00:00
I/flutter: Announcement timer set: 09:00 for 30min
I/flutter: Content changed, reloading WebView
I/flutter: Using mock TV config
```

### Error Messages
```
I/flutter: Error fetching TV config: TimeoutException
I/flutter: Timeout - check network connection
I/flutter: Network error: Connection refused
I/flutter: WebView error: net::ERR_CONNECTION_TIMED_OUT
```

## 🛠 Troubleshooting

### Common Issues

#### Status Indicator Always Red 🔴
**Symptoms**: Config không load được
**Causes**:
- ERPNext server down
- Wrong API URL
- Network connectivity issues
- Authentication problems

**Solutions**:
1. Check ERPNext server status
2. Verify API URL: `http://IP:PORT/api/resource/TV Config/config`
3. Test network connectivity
4. Check firewall settings
5. Verify API permissions

#### Status Indicator Always Orange 🟠
**Symptoms**: WebView không load dashboard
**Causes**:
- Dashboard URL không accessible
- WebView timeout
- Firewall blocking dashboard

**Solutions**:
1. Test dashboard URL in browser
2. Check network connectivity to dashboard server
3. Verify dashboard_link in ERPNext config
4. Check firewall/proxy settings

#### Timers Không Hoạt Động
**Symptoms**: Exit timer hoặc announcement không chạy
**Causes**:
- Invalid time format
- Timezone issues
- Timer setup failed

**Solutions**:
1. Check time format: `HH:MM:SS` (e.g., `23:00:00`)
2. Verify ERPNext time fields not null
3. Check console for "timer set" messages
4. Ensure announcement_enable = 1

#### App Không Smart Reload
**Symptoms**: Config changes không được detect
**Causes**:
- Network issues
- API timeout
- Config comparison failed

**Solutions**:
1. Check console for "Smart reload started"
2. Verify reload_interval > 0
3. Test API manually
4. Check network stability

### Debug Commands

#### Enable Detailed Logging
```dart
// Temporary debug trong main.dart
if (kDebugMode) {
  print('=== Debug Info ===');
  print('Config: ${_tvConfig?.toString()}');
  print('Device IP: $_deviceIp');
  print('Dashboard URL: ${_getDashboardLink()}');
  print('================');
}
```

#### Test API Manually
```bash
curl -X GET "http://YOUR_IP/api/resource/TV Config/config" \
  -H "Content-Type: application/json"
```

#### Check Network Connectivity
```dart
// Trong _performNetworkDiagnostics()
final hasInternet = await NetworkDiagnostics.hasInternetConnection();
final latency = await NetworkDiagnostics.measureLatency('google.com');
```

## 📈 Performance Optimizations

### HTTP Client Optimizations
- **Connection reuse**: `Connection: keep-alive` header
- **Timeout handling**: Unified 30s timeout
- **Retry mechanism**: Smart retry với exponential backoff
- **Error handling**: Specific error types detection

### Content Checking Optimizations
- **HEAD requests**: Ít bandwidth hơn GET requests
- **ETag/Last-Modified**: Cache-friendly headers
- **Cooldown period**: Tránh spam requests
- **Fallback mechanism**: Graceful degradation

### Memory Management
- **Timer cleanup**: Proper disposal trong dispose()
- **HTTP response**: Không cache unnecessarily
- **WebView memory**: Automatic management
- **State management**: Efficient setState() usage

## 🔐 Security Considerations

### API Security
```dart
// Add authentication headers
headers: {
  'Authorization': 'token api_key:api_secret',
  'X-API-Key': 'your_api_key',
}
```

### Network Security
- Use HTTPS cho production
- Implement certificate pinning nếu cần
- Validate server certificates
- Secure API key storage

## 📋 Production Deployment

### Pre-deployment Checklist
- [ ] Update ERPNext API URL
- [ ] Configure authentication credentials
- [ ] Set production timeout values
- [ ] Test on target devices
- [ ] Verify network connectivity
- [ ] Test all timer scenarios
- [ ] Check announcement functionality

### Production Settings
```dart
// Conservative timeouts for production
static const Duration _timeout = Duration(seconds: 45);
static const bool _enableContentChecking = false; // Disable if not needed
static const int _contentCheckCooldown = 60; // Longer cooldown
```

### Monitoring
- Monitor error rates trong logs
- Track timeout frequency
- Check status indicator patterns
- Monitor memory usage
- Track reload success rates

## 🎛️ Advanced Features

### Feature Flags
```dart
class FeatureFlags {
  static const bool enableSmartReload = true;
  static const bool enableNetworkDiagnostics = true;
  static const bool enableContentChecking = true;
  static const bool enableRetryMechanism = true;
}
```

### Custom Error Handling
```dart
void _handleCustomError(String errorType, String message) {
  switch (errorType) {
    case 'timeout':
      // Handle timeout specifically
      break;
    case 'network':
      // Handle network issues
      break;
    case 'auth':
      // Handle authentication issues
      break;
  }
}
```

### Performance Monitoring
```dart
class PerformanceMonitor {
  static void trackConfigLoadTime(Duration duration) {
    if (kDebugMode) print('Config load: ${duration.inMilliseconds}ms');
  }
  
  static void trackWebViewLoadTime(Duration duration) {
    if (kDebugMode) print('WebView load: ${duration.inMilliseconds}ms');
  }
}
```

## 📚 API Reference

### TVConfig Class
```dart
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
}
```

### TVHttpClient Class
```dart
class TVHttpClient {
  static Future<http.Response> get(String url, {headers, timeout});
  static Future<http.Response> head(String url, {headers, timeout});
}
```

### NetworkDiagnostics Class
```dart
class NetworkDiagnostics {
  static Future<bool> pingHost(String host);
  static Future<bool> hasInternetConnection();
  static Future<Duration?> measureLatency(String host);
}
```

## 🔄 Version History

### v1.0.0 - Enhanced Version
- ✅ Smart reload system
- ✅ Unified 30s timeout
- ✅ Intelligent timer management
- ✅ Status indicator
- ✅ Enhanced error handling
- ✅ Network diagnostics
- ✅ Content change detection
- ✅ Code optimization (50% reduction)

## 📞 Support

### Getting Help
1. Check console logs for specific errors
2. Verify ERPNext API accessibility
3. Test network connectivity
4. Review configuration settings
5. Check this documentation

### Common Resources
- ERPNext API Documentation
- Flutter WebView Documentation
- Network debugging tools
- Device-specific configurations

---

**Happy Coding!** 🚀

Developed by IT Team - Optimized for reliability and performance.