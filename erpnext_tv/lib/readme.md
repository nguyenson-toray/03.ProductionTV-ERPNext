# TV Dashboard Flutter App - Enhanced Version

## 🚀 Overview

Enhanced ERP TV Dashboard App với ping-based smart reload system, intelligent timer management, wifi auto-recovery, comprehensive error handling, và real-time error display widget.

## ✨ Key Features

### 🎯 Ping-Based Smart Reload System
- **HTTP-first approach**: Thử load config/content bình thường trước
- **Internal network testing**: Ping default gateway (10.0.0.1) + server IP thay vì Google
- **Wifi auto-recovery**: Tự động reset wifi khi ping thất bại
- **Intelligent error handling**: Phân biệt HTTP error vs network error
- **Real-time error display**: Widget hiển thị lỗi chi tiết ở góc dưới bên trái

### ⏱️ Unified Timeout System  
- **30 seconds timeout** cho tất cả HTTP requests
- **30 seconds timeout** cho WebView loading
- **30 seconds cooldown** cho content checking
- **Simplified configuration** - không còn multiple timeout settings

### 🔄 Smart Timer Management
- **Time changes detection**: Tự động restart timers khi time settings thay đổi
- **Selective updates**: Chỉ update components cần thiết
- **Robust scheduling**: Exit app timer và announcement timer

### 📱 Visual Status Indicators
- **Clock Color Indicator**: Màu sắc đồng hồ thay đổi theo trạng thái
  - 🔴 Ping fail, 🟡 HTTP fail, 🟠 Config error, ⚫ Normal
- **Error Display Widget**: Chi tiết lỗi ở góc dưới bên trái
  - Màu chấm tròn tương ứng với loại lỗi
  - Thông báo lỗi chi tiết và rõ ràng
  - Tự động ẩn khi không có lỗi

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
// HTTP request timeout
static const Duration _timeout = Duration(seconds: 30);

// Ping server timeout
static const int _pingTimeout = 5; // seconds
```

### WiFi Auto-Recovery Settings
```dart
// WiFi control delays
static const Duration _wifiOffDelay = Duration(seconds: 2);
static const Duration _wifiReconnectWait = Duration(seconds: 10);
```

### Server Configuration
```dart
// erpnext_api.dart
String getServerHost() {
  if (kDebugMode) {
    return 'erp-sonnt.tiqn.local';  // Debug server
  } else {
    return 'erp.tiqn.local';       // Production server
  }
}
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

## 🔄 Ping-Based Smart Logic Flow

### New Reload Algorithm
```
Timer Trigger → Try Normal HTTP Request
├── HTTP Success → Update WebView (Clock: Black ⚫)
├── HTTP Failed → Ping Server
│   ├── Ping Success → Retry HTTP (Clock: Yellow 🟡)
│   └── Ping Failed → Reset WiFi (Clock: Red 🔴)
│       ├── WiFi Off → Wait 2s → WiFi On
│       ├── Wait 10s for reconnection
│       └── Retry config load
└── Config Error → Show error (Clock: Orange 🟠)
```

### Internal Network Ping Process
```
HTTP Error Detected:
├── Step 1: Test Gateway Connectivity (10.0.0.1)
│   ├── HTTP request to default gateway
│   └── Fallback: DNS lookup if HTTP fails
├── Step 2: Test Server Connectivity
│   ├── DNS lookup: 'erp-sonnt.tiqn.local' (debug) | 'erp.tiqn.local' (production)
│   └── HTTP request to server
├── Results:
│   ├── Gateway OK + Server OK → HTTP problem only (Yellow 🟡)
│   ├── Gateway OK + Server Fail → Server problem (Yellow 🟡)
│   └── Gateway Fail → Network problem → WiFi reset (Red 🔴)
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
│ Logo (90x36)     DD/MM HH:MM:SS │ ← Clock with color indicator
│                                 │
│                                 │
│         WebView Content         │
│                                 │
│                                 │
│ ● Error Message        v1.0.0   │ ← Error widget + Version
│                        IT Team  │
└─────────────────────────────────┘
```

### Components
- **Logo**: Top-left corner, 90x36px
- **Digital Clock**: Top-right corner, DD/MM HH:MM:SS format với color indicator
- **WebView**: Full screen dashboard content
- **Announcement**: Full-screen overlay when active
- **Error Display**: Bottom-left corner, colored dot + error message
- **Version Info**: Bottom-right, small text

## 🎯 Clock Color Indicator

### Colors & Meanings (Priority Order)
- 🔴 **Red (Highest Priority)**: Ping server failed
  - Cannot reach ERPNext server
  - Network connectivity completely down
  - DNS resolution failed
  - **Action**: WiFi auto-reset (off→on→wait 10s)

- 🟡 **Yellow**: HTTP request failed (but ping OK)
  - Server reachable but HTTP error (4xx, 5xx)
  - API authentication issues
  - ERPNext service problems
  - **Action**: Retry HTTP without wifi reset

- 🟠 **Orange**: Config/Content error
  - Invalid dashboard URL (about:blank)
  - Config parsing failed
  - WebView initialization error
  - **Action**: Use fallback/mock config

- ⚫ **Black (Normal)**: All systems operational
  - Ping successful + HTTP successful
  - Config loaded + WebView working
  - All timers active

## 📋 Error Display Widget

### Features
- **Location**: Bottom-left corner của màn hình
- **Components**: Colored dot + detailed error message
- **Auto-hide**: Tự động ẩn khi không có lỗi
- **Color coding**: Tương ứng với clock color indicator

### Error Message Types
- **Config Error**: "Config Error: [chi tiết lỗi]"
  - Invalid dashboard URL
  - Server không trả về config
  - Config parsing failed
- **Network Error**: "Network Error: Cannot reach server - WiFi reset in progress"
  - Gateway không reachable (10.0.0.1)
  - Server không ping được
  - WiFi reset đang diễn ra
- **HTTP Error**: "HTTP Error: Server reachable but HTTP failed"
  - Server ping OK nhưng HTTP request thất bại
  - API authentication issues
  - Server trả về 4xx/5xx codes
- **URL Error**: "URL Error: Dashboard URL check failed"
  - Dashboard URL không load được
  - WebView validation failed

### Visual Design
```
┌────────────────────────────────┐
│ ● Config Error: Invalid URL   │
└────────────────────────────────┘
```
- **Colored dot**: Red/Yellow/Orange tương ứng với loại lỗi
- **Text style**: Small, readable font
- **Max width**: 400px để tránh overflow
- **Position**: Fixed bottom-left (2px từ cạnh)

## 🔍 Debug & Logging

### Console Output Examples
```
I/flutter: Smart reload started
I/flutter: App initialized, checking for config changes
I/flutter: URL valid, reloading WebView
I/flutter: Ping successful - network OK, loading config
I/flutter: Ping failed - attempting wifi reset
I/flutter: Toggle WiFi: OFF
I/flutter: Toggle WiFi: ON
I/flutter: Waiting 10s for wifi reconnection...
I/flutter: Retrying config load after wifi reset
I/flutter: Exit timer set for 23:00:00
I/flutter: Announcement timer set: 09:00 for 30min
```

### Error Messages
```
I/flutter: Post-init config error: Connection refused - trying network recovery
I/flutter: Handling network failure - checking with ping
I/flutter: Pinging server: erp-sonnt.tiqn.local
I/flutter: Ping failed: erp-sonnt.tiqn.local - SocketException
I/flutter: Ping failed - resetting wifi
I/flutter: WiFi toggle successful: disabled
I/flutter: WiFi toggle successful: enabled
I/flutter: URL error - trying network recovery
I/flutter: Ignoring connection timeout error - ping will handle network detection
```

## 🛠 Troubleshooting

### Common Issues

#### Clock Always Red 🔴
**Symptoms**: Ping server thất bại, wifi được reset liên tục
**Causes**:
- Network hoàn toàn down
- DNS server không hoạt động
- ERPNext server IP không reachable
- Firewall block ping packets

**Solutions**:
1. Check physical network connection
2. Test ping manually: `ping erp-sonnt.tiqn.local`
3. Verify DNS resolution
4. Check firewall/router settings
5. Verify ERPNext server is running
6. Check IP address trong getServerHost()

#### Clock Always Yellow 🟡
**Symptoms**: Ping OK nhưng HTTP requests thất bại
**Causes**:
- ERPNext service down (server running nhưng app down)
- HTTP authentication failed
- API endpoint không exist
- Server trả về 4xx/5xx errors

**Solutions**:
1. Check ERPNext service status
2. Test API manually: `curl http://erp-sonnt.tiqn.local/api/resource/TV Config/config`
3. Verify API permissions
4. Check ERPNext logs
5. Verify authentication headers

#### Clock Always Orange 🟠
**Symptoms**: Config parsing failed, sử dụng mock data
**Causes**:
- Dashboard URL = 'about:blank'
- Config format không đúng
- WebView initialization error

**Solutions**:
1. Check dashboard_link trong ERPNext config
2. Verify config data structure
3. Test dashboard URL in browser
4. Check ERPNext TV Config DocType

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

#### Test Ping Functionality
```bash
# Test ping manually
ping erp-sonnt.tiqn.local  # Debug mode
ping erp.tiqn.local        # Production mode

# Test DNS resolution
nslookup erp-sonnt.tiqn.local
```

#### Check Network Connectivity
```dart
// Test ping functionality
final serverHost = getServerHost();
final pingSuccess = await pingServer(serverHost);
if (kDebugMode) print('Ping result: $pingSuccess');

// Test WiFi control
final wifiOff = await toggleWifi(enable: false);
final wifiOn = await toggleWifi(enable: true);
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
static const Duration _timeout = Duration(seconds: 30);

// Ping settings
static const int _pingTimeout = 5; // seconds

// WiFi reset delays
static const Duration _wifiOffDelay = Duration(seconds: 2);
static const Duration _wifiReconnectWait = Duration(seconds: 10);
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
  static const bool enablePingBasedReload = true;
  static const bool enableWifiAutoRecovery = true;
  static const bool enableClockColorIndicator = true;
  static const bool enableSmartReload = true;
  static const bool enableNetworkDiagnostics = true;
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
  
  static void trackPingLatency(String host, Duration duration) {
    if (kDebugMode) print('Ping $host: ${duration.inMilliseconds}ms');
  }
  
  static void trackWifiResetCycle(Duration totalTime) {
    if (kDebugMode) print('WiFi reset cycle: ${totalTime.inSeconds}s');
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

### Network Functions
```dart
// Ping server to check network connectivity
Future<bool> pingServer(String host, {int timeout = 5});

// Get server host from API URL
String getServerHost();

// WiFi IOT control for turning wifi off/on
Future<bool> toggleWifi({required bool enable});
```

## 🔄 Version History

### v1.0.0 - Enhanced Version with Ping-Based Recovery
- ✅ Ping-based smart reload system
- ✅ WiFi auto-recovery (off→on→wait 10s)
- ✅ Clock color indicators (4 states)
- ✅ HTTP-first approach (only ping on errors) 
- ✅ Intelligent error handling (ping vs HTTP vs config)
- ✅ Unified 30s timeout
- ✅ Intelligent timer management
- ✅ Enhanced network diagnostics
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