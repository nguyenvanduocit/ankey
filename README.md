# Ankey

![Ankey: bộ gõ Telex cho macOS](.github/social-preview.png)

Ankey là bộ gõ Telex cho macOS.

Chạy trên Apple silicon, macOS 13 trở lên. Không dùng thư viện bên ngoài. Phần lõi khoảng 1.300 dòng Swift.

## Cài đặt

```
curl -fsSL https://raw.githubusercontent.com/nguyenvanduocit/ankey/main/install.sh | sh
```

Đăng xuất rồi đăng nhập lại, sau đó thêm **Ankey** ở System Settings → Keyboard → Input Sources → Edit… → **+** → Vietnamese.

Lần đầu mở, Ankey hiện cửa sổ **Hướng dẫn** gồm ba bước: bật Ankey, gõ thử, và các mẹo. Sau đó, menu bộ gõ → **Trợ giúp…** mở danh sách mã gõ nhanh và phần hỏi đáp. Cũng trong menu đó, **Gửi góp ý…** mở khung góp ý.

## Mã gõ nhanh

Gõ một mã ở đầu từ, mã chạy ngay ở chữ cuối, không cần phím kết thúc:

| Mã | Việc |
|---|---|
| `///feedback` | Mở khung gõ góp ý (hoặc menu bộ gõ → Gửi góp ý…). Enter để gửi, Esc để bỏ. |
| `///bug` | Như trên, đánh dấu là báo lỗi. |
| `///ankey` | Mở Cài đặt. |

Gõ sai một chữ thì chữ đã gõ giữ nguyên như bình thường, nên `//`, `http://` và `và/hoặc` không bị ảnh hưởng. Trong khung góp ý, Telex vẫn hoạt động, tối đa 1000 ký tự. Cmd, Ctrl, bấm chuột hoặc chuyển ứng dụng thì huỷ.

Gõ góp ý là lúc duy nhất Ankey gửi chữ bạn gõ, và chỉ khi bạn bấm Enter. Nội dung gửi gồm đoạn bạn gõ, phiên bản macOS, loại chip, bảng mã và chế độ gõ, không có tên ứng dụng. Datadog còn nhận IP và user agent, và giữ 15 ngày.

## Phân biệt tiếng Anh và tiếng Việt

Chỉ có luật Telex thì chưa đủ. Theo luật, `test` thành `tét` và `does` thành `doé` đều hợp lệ. Nên mình thêm bốn lớp kiểm tra.

**1. Một từ phải là tiền tố của một âm tiết có thật trong tiếng Việt.** [`Syllables.swift`](Core/Syllables.swift) giữ các âm tiết đơn lấy từ Viet74K và hunspell-vi. Kết quả chuyển đổi chỉ được nhận khi nó còn là tiền tố của một âm tiết trong danh sách. `doé` qua được luật nhưng không có trong danh sách, nên từ đó giữ nguyên.

**2. Từ tiếng Anh vẫn lọt qua lớp 1 thì có danh sách riêng.** Có những từ tiếng Anh sau khi Telex thêm dấu lại thành âm tiết hợp lệ (`reset` → `rết`, `test` → `tét`). [`English.swift`](Core/English.swift) tìm chúng bằng máy: lấy 20.000 từ tiếng Anh phổ biến nhất, giữ những từ engine sẽ chuyển đổi, rồi xếp hạng dạng đã chuyển theo độ phổ biến trong tiếng Việt (FrequencyWords, vi).

| Hạng của dạng đã chuyển trong tiếng Việt | Kết quả |
|---|---|
| Dưới 500 | Bỏ khỏi danh sách, tiếng Việt thắng: `cos` là `có`, `nos` là `nó`. |
| 500 đến 8000 | Giữ tiếng Anh chỉ khi đứng ngay sau một từ tiếng Anh: `git commit as` giữ nguyên, `cảm own` chuyển thành `cảm ơn`. |
| Từ 8000 trở lên, hoặc không có hạng | Luôn giữ tiếng Anh: `reset`, `boot`, `list`. |

**3. Từ đứng trước quyết định ngôn ngữ cho các từ nhập nhằng.** Ankey nhớ từ gần nhất là tiếng Anh hay tiếng Việt. Trí nhớ này bị xoá khi gặp dấu chấm, `!`, `?`, Return, Tab, khi chuyển app, và khi con trỏ nhảy chỗ khác, vì lúc đó các từ gõ trước không còn liên quan tới từ sắp gõ. Từ dính liền với dấu câu của code (`my_var`, `user@host`, `foo.bar(x)`) giữ nguyên, trừ khi đứng sau một từ tiếng Việt, nên `ừm...tôi` vẫn chuyển bình thường.

**4. Xoá cả từ rồi gõ lại đúng phím đó là lời sửa.** `sex` ra `sẽ`, bạn xoá cả từ rồi gõ lại `sex`: Ankey hiểu là chọn nhầm, hiện `sex` ngay và nhớ từ đó khi bạn chốt từ. Chiều ngược lại cũng vậy, `test` ép thành `tét`. Chỉ tính khi xoá hết từ và gõ lại đúng chuỗi phím, từ có từ ba chữ trở lên, và chỉ với từ nằm trong danh sách tiếng Anh có sẵn: `banj` hay `tooi` không phải từ tiếng Anh nên không bao giờ bị giữ nguyên chữ. Sửa lỗi gõ (`sex` thành `sez`), gõ tiếp thành từ dài hơn (`sexy`) hay xoá nửa chừng không đổi gì. Từ đã học hiện ở thẻ Chung, bấm xoá là quên.

Ba lớp sau cùng là một điểm số cho mỗi từ: hạng có sẵn (0, 1, 2), cộng một khi từ trước là tiếng Anh, cộng điểm đã học từ lời sửa. Từ đạt 2 trở lên thì giữ nguyên chữ đã gõ. Lời sửa đẩy điểm tới đầu bên kia (+2 hoặc −2), nên từ đổi chiều sau mọi từ đứng trước.

Gõ phím dấu hai lần (`coss`) không huỷ dấu để ra `cos`: tiếng Anh có nhiều từ kết thúc bằng hai chữ như vậy (`boss`, `pass`, `harass`) và Ankey giữ nguyên chúng. Muốn `cos`, bấm Esc khi đang hiện `có`, hoặc xoá cả từ rồi gõ lại. Phím mũ (`oo`, `ee`, `w`) gõ thêm một lần thì huỷ mũ (`tooo` ra `too`).

Các danh sách có sẵn nằm trong code, không nằm trong settings đã lưu, để mỗi lần cập nhật đều tới được cả những người đã chỉnh settings riêng.

## Render từ phím thô

Engine không sửa chữ đang hiện trên màn hình. Nó giữ **các phím thô đã gõ từ lần ngắt từ gần nhất** và render lại cả từ sau mỗi phím. Undo, backspace và việc trả về tiếng Anh đều suy ra từ cách làm này:

- Backspace bỏ phím thô cuối rồi render lại.
- `noww` ra `now` vì engine thấy đủ bốn phím, không phải một chữ `nô` đã chuyển dở.
- Esc trả về phím thô. Nếu Ankey đã đổi `test` thành `tét`, một lần Esc cho lại `test`.
- Shift+Esc đảo cách đọc của từ đang gõ và giữ từ mở: `test` giữ nguyên thì ra `tét`, `có` thì ra `cos`, bấm lần nữa để quay lại. Gõ thêm hoặc xoá một phím thì từ đọc lại từ đầu. Từ chỉ có một cách đọc (`hello`) không đổi. Shift+Esc không dạy Ankey gì; muốn Ankey nhớ thì xoá cả từ rồi gõ lại.

Vì thấy cả từ nên phím dấu không cần đúng thứ tự. `vieetj` và `vietej` đều ra `việt`. `duwocj` và `duocwj` đều ra `dược`. Phím mũ có thể đến sau các nguyên âm theo sau (`vayaj` → `vậy`, `toio` → `tôi`) hoặc sau phụ âm cuối. Phím dấu thanh nằm ngay trước phím mũ thì phá cặp, nên `verse` và `reference` giữ nguyên mọi chữ.

## Thống kê

Ankey không gửi gì đi, trừ khi bạn tự gửi góp ý (mục trên) hoặc bật trong Cài đặt → Thống kê. Thống kê có hai công tắc, cả hai mặc định tắt.

- **Ghi thống kê trên máy.** Ankey đếm số lần: từ được đổi dấu, từ giữ nguyên, Esc trả lại chữ đã gõ, lần Shift+Esc đảo cách đọc (hai chiều), lần Ankey học lại một từ từ lời sửa (hai chiều), chèn trực tiếp bị lệch. Chỉ lưu trên máy, giữ 30 ngày. Tắt là xoá hết.
- **Gửi thống kê tới Datadog.** Mỗi ngày gửi tối đa một lần, chỉ các ngày đã qua. Nút Sao chép trong tab Thống kê đưa đúng dữ liệu sẽ gửi vào clipboard.

Không bao giờ lưu hay gửi chữ bạn gõ, phím bấm hay tên ứng dụng. Các trường được gửi nằm trong danh sách cố định ở `Tests/TestMain.swift`, thêm một trường mới thì test đỏ cho tới khi danh sách đổi theo.

Khi bạn bật gửi, Datadog nhận:

- số liệu đã đếm (nút Sao chép trong tab Thống kê cho xem đúng nội dung), cùng phiên bản Ankey, phiên bản macOS, kiểu đặt dấu, bảng mã và số luật theo ứng dụng (chỉ số lượng, không có tên);
- một ID ngẫu nhiên của bản cài này, tạo khi bật gửi và bỏ khi tắt;
- địa chỉ IP và user agent (`Ankey/<phiên bản> (macOS <phiên bản>)`) của máy bạn, vì mọi kết nối mạng đều gửi hai thứ đó.

Datadog Logs không xoá được dữ liệu theo từng ID. Số liệu đã gửi nằm ở đó tới khi hết hạn lưu giữ của Datadog.

## Cảm ơn

Cảm ơn **FireGroup** đã tài trợ tài khoản Apple Developer dùng để ký và notarize Ankey.
