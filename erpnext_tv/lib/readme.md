# TV Dashboard Flutter App - Thuật toán tổng quan (2024)

## 1. Lấy cấu hình từ ERPNext
- App lấy IP thiết bị (tự động hoặc nhập tay khi debug).
- Gọi API `/api/resource/TV Config/config` để lấy cấu hình tổng thể.
- Tìm bản ghi TV Config Detail có IP trùng với thiết bị, lấy dashboard_link, reload_interval, các thông tin thông báo, ...

## 2. Hiển thị dashboard
- Load dashboard_link vào WebView.
- Trước khi dashboard JS chạy, app inject một đoạn polyfill cho `Object.hasOwn` để đảm bảo dashboard hoạt động trên cả WebView Android cũ (không hỗ trợ hàm này).
- Không kiểm tra hoặc so sánh nội dung HTML dashboard sau khi load.

## 3. Tự động reload dashboard
- Đặt timer reload WebView theo reload_interval (giây).
- Mỗi lần reload, chỉ đơn giản gọi reload, không kiểm tra nội dung thay đổi.

## 4. Thông báo (announcement)
- Nếu cấu hình bật announcement, đặt timer hiển thị thông báo đúng thời điểm (announcement_begin, announcement_duration).
- Nếu app khởi động trong khoảng thời gian thông báo, hiển thị ngay.
- Thông báo tự động ẩn khi hết thời gian.

## 5. Tự động thoát app
- Nếu có cấu hình time_exit_app, đặt timer để tự động thoát app đúng giờ.

## 6. Hiển thị đồng hồ digital và logo
- Overlay đồng hồ digital ở góc phải trên màn hình, cập nhật mỗi giây, có thể tùy chỉnh giao diện (màu, kích thước, nền).
- Overlay logo ở góc trái trên màn hình, kích thước nhỏ, không che dashboard.

## 7. Lưu ý về tương thích WebView
- App tự động vá hàm `Object.hasOwn` bằng polyfill JS để dashboard luôn hiển thị trên các WebView Android cũ.
- Nếu dashboard vẫn không hiển thị, cần kiểm tra lại JS của dashboard hoặc cập nhật Android System WebView trên thiết bị.

## 8. Đảm bảo code rõ ràng, dễ bảo trì
- Tách riêng các hàm xử lý: lấy IP, lấy config, setup WebView, reload, thông báo, thoát app, inject polyfill.
- Sử dụng class TVConfig bất biến, có hàm so sánh nội dung.
- Tối ưu hóa setState, tránh update UI không cần thiết.
