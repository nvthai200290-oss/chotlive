# CHOTLIVE Relay v2.1 — cần chạy cùng với APP Android

## Cài và chạy trên Windows (mạng LAN)
1. Tải gói CHOTLIVE-Relay-v2.1-Windows trên GitHub Actions, giải nén toàn bộ.
2. Cài Node.js LTS 20+ một lần nếu máy chưa có (https://nodejs.org).
3. Nháy đúp **start-relay-windows.bat**. Cửa sổ máy chủ phải tiếp tục mở.
4. Đọc dòng **APP RELAY URL: ws://IP_MAY_TINH:8080**.
5. Trên CHOTLIVE Android mở Thiết lập nhanh, điền đúng URL trên, lưu.
6. Điện thoại và máy tính phải cùng Wi-Fi/LAN. Nhập **ID tài khoản phát LIVE**, nhấn KẾT NỐI.
7. Chỉ những bình luận mới sau lúc kết nối được chuyển xuống điện thoại. Chạm bình luận để in, không tự động chốt.

## Kiểm tra
- Bản Relay phải báo **v2.1.0**. APK v2.1.0 hiển thị cả ID `@username` và nội dung.
- Nếu màn hình báo **chưa kết nối Relay**, kiểm tra URL, Wi-Fi, tường lửa Windows, cổng 8080.
- Nếu Relay kết nối nhưng TikTok báo lỗi, kiểm tra tài khoản đang phát LIVE và quyền truy cập TikTok.
- Nếu hiển thị **bình luận rỗng**, có thể máy chủ vẫn đang chạy bản Relay cũ: dừng cửa sổ cũ và chạy bản này.
- Nếu TikTok chỉ cấp UID số thay vì @username, ứng dụng hiển thị **UID TikTok**; không tự tạo ID giả.
- Không thể xác nhận độ trễ 0 ms trên Internet/TikTok. Nên đo trực tiếp trong phiên LIVE.

## Triển khai khác LAN
Dùng WSS qua reverse proxy TLS có kiểm soát truy cập. Không mở relay WebSocket này công khai ra Internet khi chưa bổ sung xác thực và giới hạn kết nối.
