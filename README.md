# Ankey

![Ankey: bộ gõ Telex cho macOS](.github/social-preview.png)

Ankey là bộ gõ Telex cho macOS.

Chạy trên Apple silicon, macOS 13 trở lên. Không dùng thư viện bên ngoài. Phần lõi khoảng 1.300 dòng Swift.

## Cài đặt

```
curl -fsSL https://raw.githubusercontent.com/nguyenvanduocit/ankey/main/install.sh | sh
```

Đăng xuất rồi đăng nhập lại, sau đó thêm **Ankey** ở System Settings → Keyboard → Input Sources → Edit… → **+** → Vietnamese.

## Phân biệt tiếng Anh và tiếng Việt

Chỉ có luật Telex thì chưa đủ. Theo luật, `test` thành `tét` và `does` thành `doé` đều hợp lệ. Nên mình thêm ba lớp kiểm tra.

**1. Một từ phải là tiền tố của một âm tiết có thật trong tiếng Việt.** [`Syllables.swift`](Core/Syllables.swift) giữ các âm tiết đơn lấy từ Viet74K và hunspell-vi. Kết quả chuyển đổi chỉ được nhận khi nó còn là tiền tố của một âm tiết trong danh sách. `doé` qua được luật nhưng không có trong danh sách, nên từ đó giữ nguyên.

**2. Từ tiếng Anh vẫn lọt qua lớp 1 thì có danh sách riêng.** Có những từ tiếng Anh sau khi Telex thêm dấu lại thành âm tiết hợp lệ (`reset` → `rết`, `test` → `tét`). [`English.swift`](Core/English.swift) tìm chúng bằng máy: lấy 20.000 từ tiếng Anh phổ biến nhất, giữ những từ engine sẽ chuyển đổi, rồi xếp hạng dạng đã chuyển theo độ phổ biến trong tiếng Việt (FrequencyWords, vi).

| Hạng của dạng đã chuyển trong tiếng Việt | Kết quả |
|---|---|
| Dưới 500 | Bỏ khỏi danh sách, tiếng Việt thắng: `cos` là `có`, `nos` là `nó`. |
| 500 đến 8000 | Giữ tiếng Anh chỉ khi đứng ngay sau một từ tiếng Anh: `git commit as` giữ nguyên, `cảm own` chuyển thành `cảm ơn`. |
| Từ 8000 trở lên, hoặc không có hạng | Luôn giữ tiếng Anh: `reset`, `boot`, `list`. |

**3. Từ đứng trước quyết định ngôn ngữ cho các từ nhập nhằng.** Ankey nhớ từ gần nhất là tiếng Anh hay tiếng Việt. Trí nhớ này bị xoá khi gặp dấu chấm, `!`, `?`, Return, Tab, khi chuyển app, và khi con trỏ nhảy chỗ khác, vì lúc đó các từ gõ trước không còn liên quan tới từ sắp gõ. Từ dính liền với dấu câu của code (`my_var`, `user@host`, `foo.bar(x)`) giữ nguyên, trừ khi đứng sau một từ tiếng Việt, nên `ừm...tôi` vẫn chuyển bình thường.

Các danh sách có sẵn nằm trong code, không nằm trong settings đã lưu, để mỗi lần cập nhật đều tới được cả những người đã chỉnh settings riêng.

## Render từ phím thô

Engine không sửa chữ đang hiện trên màn hình. Nó giữ **các phím thô đã gõ từ lần ngắt từ gần nhất** và render lại cả từ sau mỗi phím. Undo, backspace và việc trả về tiếng Anh đều suy ra từ cách làm này:

- Backspace bỏ phím thô cuối rồi render lại.
- `noww` ra `now` vì engine thấy đủ bốn phím, không phải một chữ `nô` đã chuyển dở.
- Esc trả về phím thô. Nếu Ankey đã đổi `test` thành `tét`, một lần Esc cho lại `test`.

Vì thấy cả từ nên phím dấu không cần đúng thứ tự. `vieetj` và `vietej` đều ra `việt`. `duwocj` và `duocwj` đều ra `dược`. Phím mũ có thể đến sau các nguyên âm theo sau (`vayaj` → `vậy`, `toio` → `tôi`) hoặc sau phụ âm cuối. Phím dấu thanh nằm ngay trước phím mũ thì phá cặp, nên `verse` và `reference` giữ nguyên mọi chữ.

## Thống kê

Ankey không gửi gì đi, trừ khi bạn bật trong Cài đặt → Thống kê. Có hai công tắc, cả hai mặc định tắt.

- **Ghi thống kê trên máy.** Ankey đếm số lần: từ được đổi dấu, từ giữ nguyên, Esc trả lại chữ đã gõ, chèn trực tiếp bị lệch. Chỉ lưu trên máy, giữ 30 ngày. Tắt là xoá hết.
- **Gửi thống kê tới Datadog.** Mỗi ngày gửi tối đa một lần, chỉ các ngày đã qua. Tab Thống kê cho xem đúng dữ liệu sẽ gửi.

Không bao giờ lưu hay gửi chữ bạn gõ, phím bấm, tên ứng dụng hay nội dung gõ tắt. Các trường được gửi nằm trong danh sách cố định ở `Tests/TestMain.swift`, thêm một trường mới thì test đỏ cho tới khi danh sách đổi theo.

Khi bạn bật gửi, Datadog nhận:

- số liệu hiển thị trong tab Thống kê, cùng phiên bản Ankey, phiên bản macOS, kiểu đặt dấu, bảng mã và số luật theo ứng dụng (chỉ số lượng, không có tên);
- một ID ngẫu nhiên của bản cài này, tạo khi bật gửi và bỏ khi tắt;
- địa chỉ IP và user agent (`Ankey/<phiên bản> (macOS <phiên bản>)`) của máy bạn, vì mọi kết nối mạng đều gửi hai thứ đó.

Datadog Logs không xoá được dữ liệu theo từng ID. Số liệu đã gửi nằm ở đó tới khi hết hạn lưu giữ của Datadog.

## Cảm ơn

Cảm ơn **FireGroup** đã tài trợ tài khoản Apple Developer dùng để ký và notarize Ankey.
