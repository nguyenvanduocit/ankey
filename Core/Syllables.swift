import Foundation

/// Vietnamese syllables that appear in real words. Engine.render accepts a conversion only
/// while it stays a prefix of one of these, so `test` stays English instead of becoming `tét`
/// when the rules alone would allow `pót` or `doé`.
///
/// Source: single syllables of Viet74K (github.com/duyetdev/vietnamese-wordlist) and
/// hunspell-vi (github.com/1ec5/hunspell-vi), kept when the rule-based engine can type them,
/// plus the spoken forms `ờm ừm ừa ẻm`. Both tone placements of oa, oe, uy are listed; lookup ignores the placement.
private let source = """
a ai am an ang anh ao au ay b ba bai bam ban bang banh bao bau bay be bem ben beng beo bi bia bic
bin binh biên biêng biêt biêu biếc biếm biến biếng biết biếu biền biều biển biểu biện biệt bo boa
bom bon bong bu bua bui bum bun bung buy buôi buôn buông buýp buýt buốt buồi buồm buồn buồng buổi
buộc buộm buột bà bài bàm bàn bàng bành bào bàu bày bá bác bách bái bám bán báng bánh báo báp bát
báu báy bân bâng bâu bây bã bãi bão bè bèm bèn bèo bé béc bén béng béo bép bét bê bên bênh bêu bì
bìa bìm bình bìu bí bích bím bín bính bíp bít bíu bò bòi bòm bòn bòng bó bóc bói bón bóng bóp bót bô
bôi bôm bôn bông bõ bõm bõng bù bùa bùi bùm bùn bùng bú búa búi bún búng búp bút băm băn băng bĩ
bĩnh bĩu bũm bơ bơi bơm bơn bư bưa bưng bưu bươi bươm bươn bương bươu bước bướm bướng bướp bướu bưởi
bượt bạ bạc bạch bại bạm bạn bạng bạnh bạo bạp bạt bạu bả bải bản bảng bảnh bảo bảu bảy bấc bấm bấn
bấng bấp bất bấu bấy bầm bần bầng bầu bầy bẩm bẩn bẩu bẩy bẫm bẫy bậc bậm bận bậng bập bật bậu bậy
bắc bắn bắng bắp bắt bằm bằn bằng bẳm bẳn bẵm bẵng bặc bặm bặn bặng bặp bặt bẹ bẹn bẹo bẹp bẹt bẻ
bẻm bẻo bẽ bẽn bẽo bế bến bếnh bếp bết bề bền bềnh bều bể bển bểnh bễ bệ bệch bện bệnh bệp bệt bệu
bỉ bỉm bỉnh bỉu bị bịa bịch bịn bịnh bịp bịt bịu bọ bọc bọn bọng bọp bọt bỏ bỏi bỏm bỏn bỏng bố bốc
bối bốn bống bốp bốt bồ bồi bồm bồn bồng bổ bổi bổn bổng bỗ bỗm bỗng bộ bộc bội bộn bộng bộp bột bớ
bới bớn bớp bớt bờ bời bờm bờn bở bởi bỡ bỡn bợ bợm bợn bợp bợt bụ bụa bục bụi bụm bụng bụp bụt bủ
bủa bủm bủn bủng bứ bứa bức bứng bứt bừ bừa bừng bửa bửng bửu bữa bự bựa bực bựng bựt c ca cai cam
can cang canh cao cau cay cen ch cha chai cham chan chang chanh chao chau chay che chem chen cheng
cheo chi chia chim chin chinh chiu chiêm chiên chiêng chiêu chiếc chiếm chiến chiếng chiếp chiết
chiếu chiền chiềng chiều chiểu chiệc chiện cho choa choai choang choe choen choi chom chon chong
choài choàm choàng choá choác choái choán choáng choãi choè choèn choé choét choăn choạc choại
choạng choạp choảng choắt choẹ choẹt chu chua chui chum chun chung chuyên chuyến chuyền chuyển
chuyện chuôi chuôm chuông chuẩn chuế chuếch chuếnh chuểnh chuệch chuệnh chuốc chuối chuốt chuồi
chuồn chuồng chuỗi chuộc chuội chuộng chuột chuỳ chà chài chàm chàng chành chào chàu chày chá chác
chách chái chán cháng chánh cháo chát cháu cháy châm chân châng châu chây chã chãi chão chè chèm
chèn chèo ché chém chén chéng chéo chép chét chê chêm chênh chêu chì chìa chìm chình chìu chí chía
chích chím chín chính chíp chít chíu chò chòe chòi chòm chòng chó chóa chóc chóe chói chóng chóp
chót chô chôm chôn chông chõ chõm chõng chù chùa chùi chùm chùn chùng chùy chú chúa chúc chúi chúm
chúng chút chăm chăn chăng chĩa chĩn chĩnh chũi chũm chũn chơ chơi chơm chơn chư chưa chưn chưng
chương chước chướng chườm chường chưởi chưởng chưỡng chược chượp chạ chạc chạch chạm chạn chạng
chạnh chạo chạp chạt chạy chả chải chảm chảng chảnh chảo chảu chảy chấm chấn chấp chất chấu chấy
chầm chần chầu chầy chẩm chẩn chẩu chẫm chẫn chẫu chậc chậm chận chập chật chậu chậy chắc chắm chắn
chắp chắt chằm chằn chằng chẳng chẵn chặc chặm chặn chặng chặp chặt chẹn chẹo chẹp chẹt chẻ chẻm
chẻn chẻng chẻo chẽ chẽm chẽn chế chếch chếnh chếp chết chề chềm chềnh chểnh chễm chễnh chệ chệch
chệm chện chệnh chệp chệt chỉ chỉa chỉn chỉnh chị chịa chịn chịt chịu chọ chọc chọe chọi chọn chọp
chọt chỏ chỏi chỏm chỏn chỏng chốc chối chốn chống chốp chốt chồ chồi chồm chồn chồng chổi chổm
chổng chỗ chỗi chỗm chộ chội chộn chộp chột chớ chới chớm chớn chớp chớt chờ chờm chờn chở chởm chợ
chợn chợp chợt chục chụm chụp chụt chủ chủa chủm chủn chủng chứ chứa chức chứng chứt chừ chừa chừng
chửa chửi chửng chữ chữa chững chực chựng co coi com con cong cot cu cua cui cum cun cung cuông cuốc
cuối cuốn cuống cuồn cuồng cuỗm cuộc cuội cuộn cuộng cy cà cài càm càn càng cành cào càu cày cá các
cách cái cám cán cáng cánh cáo cáp cát cáu cáy câm cân câng câu cây cãi cò còi còm còn còng có cóc
cói cóm cón cóng cóp cót cô côi côm côn công cõi cõm cõng cù cùa cùi cùm cùn cùng cú cúa cúc cúi cúm
cún cúng cúp cút căm căn căng cũ cũi cũn cũng cơ cơi cơm cơn cư cưa cưng cưu cương cước cưới cướp
cười cườm cường cưỡi cưỡng cược cạ cạc cạch cạm cạn cạnh cạo cạp cạu cạy cả cải cảm cản cảng cảnh
cảo cảu cảy cấc cấm cấn cấp cất cấu cấy cầm cần cầu cầy cẩm cẩn cẩu cẩy cẫm cẫn cẫng cậm cận cập cật
cậu cậy cắc cắm cắn cắng cắp cắt cằm cằn cẳn cẳng cẵng cặc cặm cặn cặp cặt cọ cọc cọi cọm cọn cọng
cọp cọt cỏ cỏi cỏm cỏn cỏng cố cốc cối cốm cốn cống cốp cốt cồ cồm cồn cồng cổ cổi cổn cổng cỗ cỗi
cộ cộc cội cộm cộn cộng cộp cột cớ cớm cớn cớt cờ cời cờn cởi cỡ cỡi cỡm cỡn cợm cợn cợp cợt cụ cục
cụi cụm cụng cụp cụt củ của củi củm củn củng cứ cứa cức cứng cứt cứu cừ cừu cử cửa cửi cửng cửu cữ
cữu cự cựa cực cựu d da dai dam dan dang danh dao day de den deo di dim din dinh diu diêm diên diêu
diếc diếp diết diếu diềm diềng diều diễm diễn diễu diệc diệm diện diệp diệt diệu do doa doan doanh
doi dom don dong doàng doành doá doãi doãn doãng doạ doạng du dua dun dung duy duyên duyệt duôi duật
duềnh duệ duốc duối duồn duỗi duộc dy dyn dà dài dàm dàn dàng dành dào dàu dày dá dác dách dái dám
dán dáng dáo dát dáu dáy dâm dân dâng dâu dây dã dãi dãn dãy dè dèn dé dém déo dép dét dê dên dênh
dì dìa dìm dìu dí dích dím dính díp dít díu dò dòi dòm dòng dó dóa dóc dói dóm dón dóng dót dô dôi
dôn dông dõi dõng dù dùa dùi dùn dùng dúa dúi dúm dún dúng dút dýn dăm dăn dăng dĩ dĩa dĩn dĩnh dũ
dũa dũi dũng dơ dơi dơn dư dưa dưng dương dưới dướn dướng dường dưỡng dược dượi dượng dượt dạ dạc
dại dạm dạn dạng dạo dạt dạy dả dải dảnh dảy dấm dấn dấp dấu dấy dầm dần dầu dầy dẩm dẩn dẩu dẩy dẫm
dẫn dẫu dẫy dậm dận dập dật dậu dậy dắc dắm dắng dắt dằm dằn dằng dẳn dẳng dặc dặm dặn dặng dặt dẹm
dẹo dẹp dẹt dẻ dẻo dẽ dế dếch dết dề dền dềnh dể dễ dệ dệch dện dệnh dệt dệu dỉ dị dịch dịp dịt dịu
dọ dọa dọc dọi dọn dọng dọp dỏ dỏm dỏng dốc dối dống dốp dốt dồ dồi dồn dồng dổi dổm dỗ dỗi dộc dội
dộng dộp dột dớ dớn dớp dờ dời dờn dở dởm dỡ dợ dợm dợn dụ dục dụi dụm dụng dụt dủi dứ dứa dức dứng
dứt dừ dừa dừng dử dửng dữ dự dựa dực dựng dựt e em en eng eo g ga gai gam gan gang ganh gao gau gay
ge gen ghe ghen ghi ghim ghin ghiếc ghiền ghè ghèn ghé ghém ghép ghét ghê ghì ghìm ghình ghín ghính
ghít ghẹ ghẹn ghẹo ghẻ ghẽ ghế ghếch ghề ghềnh ghểnh ghễnh ghệch ghệt ghịt gi gia giai giam gian
giang gianh giao giau gic gie gien gieo gin gio gioi gion giong gioàng gioăng gip giu giua giun
giuộc già giàm giàn giàng giành giào giàu giày giá giác giám gián giáng giáo giáp giát giáy giâm
giâu giây giã giãi giãn giãy gièm gié giéo giê giêng giò giòi giòn gió gióc giói gión gióng giô giôn
giông giùi giùm giú giúi giúp giăm giăng giũ giũa giơ giương giướng giường giượng giạ giạc giại giạm
giạng giạp giạt giả giải giảm giản giảng giảnh giảo giảu giấc giấm giấn giấp giấu giấy giầm giần
giầu giầy giẫm giẫy giậm giận giập giật giậu giắc giắm giắn giắng giắt giằm giằn giằng giẳn giẵm
giặc giặm giặn giặt giẹo giẹp giẻ giếc giếm giếng giết giề giền giềng giễu giọ giọc giọi giọng giọt
giỏ giỏi giỏn giỏng giốc giối giống giốt giồ giồi giồng giổi giỗ giỗi giộ giội giộp giới giờ giời
giờn giở giỡn giụa giục giụi giủi giừ giữ giữa giựt go gom gon goá gu guốc guồi guồng guổng guộc
guộn guột gà gài gàn gàng gành gào gàu gày gá gác gách gái gán gánh gáo gáp gát gáu gáy gâm gân gâu
gây gã gãi gãy gì gìm gìn gí gích gíp gò gòn góa góc gói góp gót gô gôm gôn gông gõ gù gùa gùi gùn
gùng gúa gút găm găn găng gũi gơ gơn gươm gương gườm gường gưởi gưỡng gượm gượng gạ gạc gạch gại gạn
gạnh gạo gạt gạy gả gảnh gảy gấc gấm gấp gấu gấy gầm gần gầu gầy gẩm gẩy gẫm gẫu gẫy gậm gận gập gật
gậy gắm gắn gắng gắp gắt gằm gằn gẵng gặc gặm gặn gặng gặp gặt gỉ gọ gọc gọi gọn gọng gọt gỏi gỏng
gốc gối gốm gồ gồi gồm gồng gổ gỗ gộ gộc gội gộp gột gớm gờ gờm gờn gở gởi gỡ gợi gợn gợt gụ gục gụi
gụt gủa gứng gừ gừng gửi h ha hai ham han hang hanh hao hau hay he hec hem hen heo hi hia him hin
hinh hiu hiên hiêng hiếc hiếm hiến hiếng hiếp hiếu hiềm hiền hiểm hiển hiểu hiện hiệp hiệt hiệu ho
hoa hoai hoan hoang hoay hoc hoe hoen hoi hom hon hong hoà hoài hoàn hoàng hoành hoá hoác hoán hoáng
hoánh hoáy hoãn hoãng hoè hoét hoăm hoăng hoạ hoạch hoại hoạn hoạnh hoạt hoả hoải hoảng hoảnh hoắc
hoắm hoắt hoằn hoẳn hoẵng hoặc hoặn hoẹ hoẹt hoẻn hu hua hui hum hun hung huy huynh huyên huyết
huyền huyễn huyện huyệt huân huê huênh huý huých huýt huơ huấn huầy huế huếch huề huệ huống huốt
huỳnh huỵch huỷ hy hà hài hàm hàn hàng hành hào hàu há hác hách hái hám hán háng hánh háo háp hát
háu háy hâm hân hâu hây hãi hãm hãn hãng hãnh hão hãy hè hèm hèn hèo hé héc hén héo hét hê hên hênh
hì hình hí hích híp hít hò hòa hòe hòi hòm hòn hòng hó hóa hóc hói hóm hón hóng hóp hót hô hôi hôm
hôn hông hõm hù hùa hùi hùm hùn hùng hú húc húi húm húng húp hút húy hý hăm hăng hĩ hĩm hĩnh hũ hũm
hơ hơi hơn hơng hư hưng hưu hươm hươn hương hươu hước hướm hướng hườm hường hưởng hượm hạ hạc hạch
hại hạm hạn hạng hạnh hạo hạp hạt hạy hả hải hảm hảng hảnh hảo hảy hấm hấn hấng hấp hất hấu hấy hầm
hầu hầy hẩm hẩng hẩu hẩy hẫng hẫu hậm hận hập hậu hắc hắn hắng hắt hằm hằn hằng hẳm hẳn hẵm hẵng hặc
hặm hẹ hẹm hẹn hẹp hẹt hẻ hẻm hẻn hẻo hẽm hếch hến hết hếu hề hềnh hều hể hển hểnh hểu hễ hệ hệch
hệt hỉ hỉnh hị hịch họ họa học họe họng họp hỏ hỏa hỏi hỏm hỏn hỏng hố hốc hối hống hốt hồ hồi hồn
hồng hổ hổi hổm hổn hổng hỗ hỗm hỗn hỗng hộ hộc hội hộn hộp hột hớ hớm hớn hớp hớt hờ hời hờm hờn hở
hởi hởn hỡ hỡi hỡm hợi hợm hợp hợt hụ hục hụi hụm hụp hụt hủ hủi hủm hủn hủng hủy hứ hứa hức hứng hừ
hừa hừm hừng hử hửng hữ hững hữu hự hực hựu hỷ i ic im in inh iu k ka kan kay ke kem ken keng keo
kha khai kham khan khang khanh khao khau khay khe khem khen kheo khi khin khinh khiu khiêm khiên
khiêng khiêu khiếm khiến khiếp khiết khiếu khiền khiển khiểng khiễng khiệng kho khoa khoai khoan
khoang khoanh khoe khoen khoeo khoi khom khoành khoá khoác khoái khoán khoáng khoát khoáy khoé khoén
khoét khoăm khoăn khoạng khoả khoải khoản khoảng khoảnh khoắm khoắn khoắng khoắt khoằm khoặm khoẻ
khu khua khui khum khung khuy khuya khuynh khuyên khuyến khuyết khuyển khuân khuâng khuây khuê khuôn
khuông khuýp khuơ khuất khuấy khuẩn khuếch khuều khuờ khuỳnh khuỵ khuỵu khuỷnh khuỷu khyển khà khàn
khàng khành khá khác khách khái khám khán kháng khánh kháo kháp khát kháu kháy khâm khân khâng khâu
khè khèn khèng khèo khé khén khéo khép khét khê khênh khêu khì khìn khí khía khích khín khít khíu
khò khòe khòm khòn khòng khó khóa khóc khóe khói khóm khô khôi khôn không khù khùa khùng khú khúc
khúm khúng khăm khăn khăng khĩnh khơ khơi khư khươi khươm khươn khương khước khướt khướu khưởng
khưỡng khượt khạ khạc khạch khạng khạo khạp khả khải khảm khản khảng khảnh khảo khảy khấc khấm khấn
khấp khất khấu khầng khẩn khẩu khẩy khậc khậm khập khật khắc khắm khắn khắng khắp khắt khằn khằng
khẳm khẳn khẳng khặc khẹc khẻ khẻo khẽ khế khề khềnh khều khểnh khễnh khệ khệch khệnh khỉ khỉnh khị
khịa khịt khịu khọm khọt khỏ khỏa khỏe khỏi khỏng khố khốc khối khốn khống khổ khổn khổng khớ khới
khớp khờ khởi khụ khục khụng khụt khụy khủ khủa khủng khứ khứa khứng khứu khừ khừa khừng khử khự
khựng ki kia kim kin kinh kip kiêm kiên kiêng kiêu kiếm kiến kiếng kiếp kiết kiếu kiềm kiền kiềng
kiều kiểm kiểng kiểu kiễng kiệm kiện kiệt kiệu ku kuênh kuýp ky káp kè kèm kèn kèo ké kéc kém kén
kéo kép két kê kên kêng kênh kêu kì kìa kìm kìn kình kí kích kín kính kíp kít kíu kót kôn ký kĩ kĩn
kĩu kơi kạn kẹ kẹn kẹo kẹp kẹt kẻ kẻm kẻng kẻo kẽ kẽm kẽo kế kếch kếp kết kếu kề kềm kền kềnh kều kể
kễnh kệ kệch kệnh kỉ kỉnh kị kịa kịch kịp kịt kốc kỳ kỵ kỷ kỹ l la lai lam lan lang lanh lao lat lau
lay le lem len leng leo li lia lic lie lim lin linh lit liu liêm liên liêng liêu liếc liếm liến
liếng liếp liếu liềm liền liềng liều liểng liễm liễn liễu liệc liệm liệng liệp liệt liệu lo loa loai
loan loang loanh loay loe loen loi lom lon long loà loài loàn loàng loá loác loán loáng loát loáy
loã loãng loè loé loét loăn loăng loạc loạch loại loạn loạng loạt loả loảng loắn loắt loằn loằng
loẹt loẻng lu lua lui lum lung luy luya luyn luyên luyến luyện luân luôm luôn luông luý luých luýnh
luýt luấn luẩn luận luật luốc luống luốt luồi luồn luồng luỗng luộc luộm luột luỵ luỹ ly là lài làm
làn làng lành lào làu lày lá lác lách lái lán láng lánh láo láp lát láu láy lâm lân lâng lâp lâu lây
lã lãi lãm lãn lãng lãnh lão lè lèm lèn lèng lèo lé léc lém lén léng léo lép lét lê lêc lên lênh lêu
lì lìa lìm lìn lình lìu lí lía líc lích lính líp lít líu lò lòa lòe lòi lòm lòn lòng ló lóc lóe lói
lóm lóng lóp lót lô lôi lôm lôn lông lõ lõa lõi lõm lõng lù lùa lùi lùm lùn lùng lú lúa lúc lúi lúm
lún lúng lúp lút lúy lý lăm lăn lăng lĩ lĩnh lũ lũa lũi lũm lũn lũng lũy lơ lơi lơn lơng lư lưa lưng
lưu lươm lươn lương lưới lướng lướp lướt lướu lười lườm lườn lường lưởi lưởng lưỡi lưỡng lược lượm
lượn lượng lượt lạ lạc lạch lại lạm lạn lạng lạnh lạo lạp lạt lạu lạy lả lải lảm lảng lảnh lảo lảu
lảy lấc lấm lấn lấp lất lấu lấy lầm lần lầu lầy lẩm lẩn lẩu lẩy lẫm lẫn lẫy lận lập lật lậu lậy lắc
lắm lắng lắp lắt lằm lằn lằng lẳm lẳn lẳng lẵng lặc lặm lặn lặng lặp lặt lẹ lẹm lẹn lẹo lẹp lẹt lẻ
lẻm lẻn lẻng lẻo lẽ lẽn lẽo lếc lếch lếp lết lếu lề lềnh lều lể lểu lễ lễu lệ lệch lệnh lệt lỉm lỉnh
lỉu lị lịa lịch lịm lịnh lịu lọ lọc lọi lọm lọn lọng lọp lọt lỏa lỏi lỏm lỏn lỏng lố lốc lối lốm lốn
lốp lốt lồ lồi lồm lồn lồng lổ lổm lổn lổng lỗ lỗi lỗm lộ lộc lội lộm lộn lộng lộp lột lớ lới lớn
lớp lớt lờ lời lờm lờn lở lởi lởm lởn lỡ lỡi lỡm lợ lợi lợm lợn lợp lợt lụ lụa lục lụi lụm lụn lụng
lụp lụt lụy lủ lủa lủi lủm lủn lủng lứa lức lứt lừ lừa lừng lử lửa lửng lữ lữa lững lự lựa lực lựng
lựu lỵ lỹ m ma mai mam man mang manh mao mau may me mem men meo mi mia mim min minh miu miên miêu
miến miếng miết miếu miền miều miểng miễn miễu miện miệng miệt mo moa moan moay moi mom mon mong mu
mua mui mum mun mung muy muya muôi muôn muông muối muốn muống muốt muồi muồm muồng muỗi muỗm muỗng
muội muộn my mà mài màn màng mành mào màu mày má mác mách mái mám mán máng mánh máo mát máu máy mâm
mân mâng mâp mâu mây mã mãi mãn mãng mãnh mão mè mèm mèn mèng mèo mé méc mém mén méo mép mét mê mên
mênh mì mìn mình mí mía mích mím míp mít míu mò mòi mòm mòn mòng mó móc mói móm món móng móp mót mô
môi môm môn mông môt mõ mõm mù mùa mùi mùn mùng mú múa múc múi múm mún múp mút măm măn măng mĩ mĩm
mũ mũi mũm mơ mơi mơn mưa mưng mưu mươi mươn mương mướn mướp mướt mười mườn mường mưởi mưỡu mược
mượn mượt mạ mạc mạch mại mạn mạng mạnh mạo mạp mạt mạy mả mải mảng mảnh mảy mấm mấn mấp mất mấu mấy
mầm mần mầng mầu mầy mẩm mẩn mẩu mẩy mẫm mẫn mẫu mậm mận mập mật mậu mậy mắc mắm mắn mắng mắt mằn
mẳn mẵm mặc mặn mặt mẹ mẹc mẹo mẹp mẹt mẻ mẻo mẽ mế mếch mến mết mếu mề mềm mền mể mễ mệ mệnh mệt mỉ
mỉa mỉm mỉu mị mịch mịn mịnh mịt mọ mọc mọi mọn mọng mọp mọt mỏ mỏi mỏm mỏng mố mốc mối mống mốt mồ
mồi mồm mồn mồng mổ mổng mỗ mỗi mộ mộc mội mộng một mớ mới mớm mớn mớp mờ mời mờm mở mởn mỡ mợ mụ
mục mụi mụn mụp mụt mủ mủi mủm mủn mủng mứa mức mứn mứt mứu mừng mửa mửng mự mựa mực mỹ n na nai nam
nan nang nanh nao nat nau nay ne nem nen neo neon nga ngai ngam ngan ngang nganh ngao ngau ngay nghe
nghen ngheo nghi nghim nghinh nghiu nghiêm nghiên nghiêng nghiêu nghiến nghiền nghiễm nghiệm nghiện
nghiệp nghiệt nghè nghèn nghèo nghé nghén nghét nghê nghênh nghêu nghì nghìn nghí nghía nghít nghĩ
nghĩa nghĩnh nghẹ nghẹn nghẹo nghẹt nghẻn nghẻo nghẽn nghẽo nghếch nghến nghề nghền nghềnh nghều
nghể nghển nghểnh nghểu nghễ nghễnh nghễu nghệ nghệch nghện nghệt nghệu nghỉ nghỉm nghỉn nghỉnh
nghỉu nghị nghịch nghịt nghịu ngo ngoa ngoai ngoam ngoan ngoang ngoao ngoay ngoe ngoem ngoen ngoeo
ngoi ngon ngong ngoài ngoàm ngoác ngoách ngoái ngoáp ngoáy ngoã ngoãn ngoé ngoém ngoén ngoét ngoăn
ngoăng ngoạ ngoạc ngoạch ngoại ngoạm ngoạn ngoạp ngoạy ngoải ngoảm ngoảng ngoảnh ngoảy ngoẩy ngoắc
ngoắt ngoằn ngoằng ngoẳn ngoẳng ngoẵng ngoặc ngoặt ngoẻm ngoẻn ngu ngun nguy nguyên nguyền nguyễn
nguyện nguyệt nguây nguôi nguých nguýt nguầy nguẩy nguậy nguếch nguệch nguồi nguồn nguội nguỳ nguỵ
nguỷu ngà ngài ngàm ngàn ngàng ngành ngào ngàu ngày ngác ngách ngái ngám ngán ngáng ngánh ngáo ngáp
ngát ngáu ngáy ngâm ngân ngâu ngây ngã ngãi ngãng ngão ngía ngò ngòi ngòm ngòn ngòng ngó ngóc ngóe
ngóeo ngói ngóm ngón ngóng ngóp ngót ngô ngôi ngôn ngông ngõ ngõa ngõi ngõng ngù ngùi ngùn ngùng ngú
ngúc ngún ngúng ngút ngăm ngăn ngũ ngũn ngũng ngơ ngơi ngơm ngơn ngư ngưa ngưng ngưu ngươi ngươn
ngước người ngường ngưởng ngưỡng ngược ngượng ngạc ngạch ngại ngạn ngạnh ngạo ngạt ngả ngải ngảng
ngảnh ngảo ngấc ngấm ngấn ngấp ngất ngấu ngấy ngầm ngần ngầu ngầy ngẩm ngẩn ngẩng ngẫm ngẫn ngẫu
ngậm ngận ngập ngật ngậu ngậy ngắc ngắm ngắn ngắt ngằn ngẳn ngẳng ngẵng ngặt ngẹt ngịu ngọ ngọc ngọn
ngọng ngọt ngỏ ngỏm ngỏn ngỏng ngố ngốc ngốn ngốt ngồ ngồi ngồm ngồn ngồng ngổ ngổm ngổn ngổng ngỗ
ngỗi ngỗng ngộ ngộc ngộn ngộp ngột ngớ ngớn ngớp ngớt ngờ ngời ngờm ngởn ngỡ ngỡi ngỡn ngợ ngợi ngợm
ngợp ngụ ngụa ngục ngụm ngụp ngụt ngụy ngủ ngủi ngủm ngủn ngủng ngứ ngứa ngứng ngứt ngừ ngừa ngừng
ngửa ngửi ngửng ngữ ngự ngựa ngực nha nhai nham nhan nhang nhanh nhao nhau nhay nhe nhem nhen nheo
nhi nhinh nhiu nhiên nhiêu nhiếc nhiếp nhiều nhiễm nhiễn nhiễu nhiệm nhiệt nho nhoai nhoang nhoay
nhoe nhoen nhoi nhom nhon nhong nhoà nhoài nhoàm nhoàng nhoá nhoáng nhoáy nhoè nhoèn nhoé nhoét
nhoạng nhoằng nhoẹt nhoẻn nhu nhui nhum nhun nhung nhuyễn nhuôm nhuần nhuận nhuế nhuệ nhuốc nhuốm
nhuồn nhuộm nhuỵ nhà nhài nhàm nhàn nhàng nhành nhào nhàu nhày nhá nhác nhách nhái nhám nháng nhánh
nháo nháp nhát nháu nháy nhâm nhân nhâng nhâu nhây nhã nhãi nhãn nhãng nhão nhè nhèm nhèn nhèo nhé
nhém nhén nhéo nhép nhét nhê nhênh nhì nhìn nhìu nhí nhía nhích nhím nhín nhính nhíp nhít nhíu nhò
nhòa nhòe nhòm nhòng nhó nhóa nhóc nhóe nhói nhóm nhón nhóng nhóp nhót nhô nhôi nhôm nhôn nhông nhõ
nhõi nhõm nhõn nhõng nhù nhùi nhùn nhùng nhú nhúa nhúc nhúi nhúm nhún nhúng nhút nhăm nhăn nhăng nhĩ
nhũ nhũn nhũng nhơ nhơi nhơm nhơn như nhưng nhương nhướn nhướng nhường nhưỡng nhược nhượng nhạc nhại
nhạn nhạng nhạnh nhạo nhạp nhạt nhạy nhả nhải nhảm nhản nhảnh nhảo nhảu nhảy nhấc nhấm nhấn nhấp
nhất nhấy nhầm nhần nhầu nhầy nhẩm nhẩn nhẩu nhẩy nhẫm nhẫn nhẫy nhậm nhận nhập nhật nhậu nhậy nhắc
nhắm nhắn nhắng nhắp nhắt nhằm nhằn nhằng nhẳn nhẳng nhẵn nhẵng nhặm nhặn nhặng nhặt nhẹ nhẹm nhẹn
nhẹo nhẹp nhẹt nhẻ nhẻm nhẻo nhẽ nhẽo nhếch nhếu nhều nhể nhểu nhễ nhệch nhện nhệu nhỉ nhỉnh nhỉu
nhị nhịn nhịp nhịt nhịu nhọ nhọc nhọn nhọt nhỏ nhỏm nhỏn nhỏng nhố nhốc nhối nhốn nhốp nhốt nhồi
nhồm nhồn nhồng nhổ nhổm nhổn nhổng nhội nhộn nhộng nhột nhớ nhớm nhớn nhớp nhớt nhờ nhời nhờm nhờn
nhở nhởi nhởn nhỡ nhỡn nhợ nhợn nhợp nhợt nhụ nhụa nhục nhụi nhụng nhụt nhụy nhủ nhủi nhủn nhủng nhứ
nhức nhứt nhừ nhử nhửng nhữ những nhự nhựa nhựt ni nia nic nin ninh nit niu niêm niên niêu niết niềm
niền niềng niễng niệm niệt niệu no noa noi nom non nong noãn nu nua nui num nung nuy nuôi nuông nuốc
nuối nuốm nuốt nuộc nuột nà nài nàn nàng nành nào này ná nác nách nái nám nán náng nánh náo náp nát
náu náy nâm nân nâng nâu nây nã não nãy nè nèo né ném nén néo nép nét nê nêm nên nênh nêu nì nình ní
níc ních nín nính níp nít níu nò nòi nòm nòng nó nóc nói nón nóng nóp nót nô nôi nôm nôn nông nõ nõn
nùi nùn nùng nú núa núc núi núm núng núp nút năm năn năng nĩa nũng nơ nơi nơm nư nưa nưng nương nước
nướng nườm nường nược nượp nạ nạc nại nạm nạn nạng nạnh nạo nạp nạt nạy nả nải nản nảo nảy nấc nấm
nấn nấng nấp nấu nấy nầm nần nầy nẩy nẫm nẫn nẫng nẫu nẫy nậm nậng nập nậu nậy nắc nắm nắn nắng nắp
nằm nằn nằng nẵng nặc nặn nặng nẹ nẹp nẹt nẻ nẻo nếm nến nếp nết nếu nề nền nể nệ nệm nện nệp nỉ nị
nịch nịnh nịt nịu nọ nọc nọi nọn nọng nọt nỏ nỏi nỏm nố nốc nối nống nốp nốt nồ nồi nồm nồng nổ nổi
nổng nỗ nỗi nỗng nộ nội nộm nộn nộp nột nớ nới nớp nớt nờ nờm nở nỡ nỡm nợ nợp nụ nục nủa nứa nức
nứng nứt nừng nử nửa nữ nữa nự nực nựng o oa oai oan oang oanh oe oeng oeo oi om on ong oà oài oàm
oàng oành oác oách oái oán oánh oáp oát oé oéc oăm oăn oăng oạc oạch oại oạp oải oản oắt oằn oẳn
oẳng oặt oẹ oẻ p pa pai pan pang panh pao pe pen ph pha phai phan phang phanh phao phau phay phe
phen pheo phi phia phim phin phinh phiu phiên phiêu phiếm phiến phiết phiếu phiền phiện phiệt phiệu
pho phoi phom phon phong phu phua phui phun phung phuy phà phài phàm phàn phàng phành phào phá phác
phách phái phán pháo pháp phát pháy phân phây phè phèn phèng phèo phé phéc phéng phép phét phê phên
phênh phêu phì phìa phìn phình phí phía phích phím phính phít phò phòi phòm phòng phó phóc phón
phóng phót phô phôi phôm phôn phông phù phùa phùn phùng phú phúc phún phúng phút phăm phăn phăng
phĩnh phũ phơ phơi phơn phưng phương phước phướn phướng phường phưỡn phược phượng phượu phạ phạc
phạch phạm phạn phạng phạo phạt phả phải phản phảng phảy phấn phấp phất phầm phần phẩm phẩn phẩy
phẫn phẫu phận phập phật phắc phắn phắp phắt phẳng phặng phẹc phẹt phế phếch phết phề phềnh phều
phễn phễu phệ phệnh phệt phệu phỉ phỉnh phị phịa phịch phịt phịu phọc phọng phọp phọt phỏng phố phốc
phối phốp phốt phồ phồm phồn phồng phổ phổi phổng phỗng phộng phớ phới phớn phớt phờ phời phở phởn
phỡn phụ phục phụng phụp phụt phủ phủi phủng phứa phức phứt phừn phừng phựa phực phựt pi pin ping
pinh piêu po poa pom pong pop pu pua pui pun puy puốc puộc pà pài pàng pác pán páp pát pâu péc péo
pét pê píc pích píp pít pô pông păng pơ pơng pươi pạ pả pấc pắc pằn pẹc pẻ pếch pết pốt pờ pụa q qua
quai quan quang quanh quao quau quay que quen queng queo qui quoàng quoạng quoắt quuyết quy quyên
quyến quyết quyền quyển quyện quyệt quà quài quàn quàng quành quào quàu quày quá quác quách quái
quán quáng quánh quáo quát quáu quáy quân quây quãng què quèn quèo qué quéc quén quéo quét quê quên
quì quình quí quích quít quý quých quýnh quýt quăm quăn quăng quĩ quơ quạ quạc quạch quại quạng
quạnh quạo quạt quạu quạy quả quải quản quảng quảy quấc quấn quất quấy quần quầng quầy quẩn quẩng
quẩy quẫn quẫy quận quật quậy quắc quắm quắn quắp quắt quằm quằn quẳm quẳng quặc quặm quặn quặng
quặp quặt quẹn quẹo quẹt quẻ quẽ quế quếch quến quếnh quết quếu quề quềnh quều quệ quệch quện quệnh
quệt quỉ quị quịt quọ quốc quớ quới quờ quờn quở quởn quỳ quỳnh quỵ quỵp quỵt quỷ quỷnh quỹ r ra rai
ram ran rang ranh rao rat rau ray re rem ren reng reo ri ria ric rim rin ring rinh rit riu riên
riêng riêu riết riếu riềm riềng riễu riệt ro roa roi rom ron rong roàng roá roạt ru rua rui rum run
rung ruy ruê ruôn ruýp ruốc ruối ruốt ruồi ruồng ruổi ruỗng ruộm ruộng ruột rà rài ràn ràng rành rào
rày rá rác rách rái rám rán ráng ráo ráp rát ráu ráy râm rân râu rây rã rãi rãnh rão rãy rè rèm rèn
rèo ré rén réo rét rê rêm rên rêu rì rìa rình rìu rí rích rím ríp rít ríu rò ròi ròm ròn ròng ró róc
rói róm rón róng rót rô rôm rôn rông rõ rõi rù rùa rùm rùn rùng rú rúc rúi rúm rún rúng rúp rút răm
răn răng rĩ rĩn rũ rũa rơ rơi rơm rơn rư rưa rưng rươi rươm rương rước rưới rướm rướn rười rườm rườn
rường rưởi rưỡi rượi rượn rượng rượt rượu rạ rạc rạch rạm rạn rạng rạo rạp rạt rạy rả rải rảng rảnh
rảo rảu rảy rấm rấn rấp rất rầm rần rầu rầy rẩm rẩy rẫm rẫy rậm rận rập rật rậu rắc rắm rắn rắp rắt
rằm rằn rằng rặc rặm rặn rặng rặt rẹo rẹt rẻ rẻng rẻo rẽ rế rếch rến rếp rết rề rền rềnh rều rể rểnh
rễ rệ rệch rện rệp rệt rệu rỉ rỉa rỉn rỉnh rị rịa rịch rịn rịp rịt rọ rọc rọi rọm rọn rọt rỏ rỏi rỏm
rỏn rỏng rốc rối rốn rống rốp rốt rồ rồi rồm rồn rồng rổ rổi rổn rổng rỗ rỗi rỗng rộ rộc rộm rộn
rộng rộp rột rớ rớm rớp rớt rờ rời rờm rờn rở rởm rởn rỡ rỡn rợ rợi rợm rợn rợp rợt rụ rụa rục rụi
rụm rụng rụp rụt rủ rủa rủi rủn rủng rứa rức rứt rừ rừng rửa rửng rữa rựa rực rựng rỵn s sa sai sam
san sang sanh sao sau say se sen seo si sia sic sim sin sinh siu siêng siêu siếc siết siểm siểng
siễn so soa soi som son song soà soài soàm soàn soái soán soát soạn soạng soạp soạt soải soảng soẹt
su sua sui sum sun sung suy suyển suyễn suê suôn suông suý suýt suất suối suốt suồng suỵt sà sài sàm
sàn sàng sành sào sá sác sách sái sám sán sáng sánh sáo sáp sát sáu sâm sân sâng sâu sây sã sãi sè
sèo séc sém séo sét sê sên sênh sêu sì sìn sình síc sích sín sính sít sò sòa sòi sòm sòn sòng sóc
sói sóm són sóng sót sô sôi sông sõi sõng sù sùi sùm sùng sú súc sún súng súp sút súy săm săn săng
sĩ sũng sơ sơm sơn sư sưa sưng sưu sươi sương sướng sướt sườn sường sưởi sượng sượt sạ sạc sạch sại
sạm sạn sạo sạp sạt sả sải sản sảng sảnh sảo sảy sấm sấn sấp sất sấu sấy sầm sần sầu sầy sẩm sẩn sẩy
sẫm sậm sập sật sậu sậy sắc sắm sắn sắng sắp sắt sằng sẵn sặc sặm sặt sẹ sẹm sẹo sẹp sẹt sẻ sẻn sẽ
sến sếp sếu sề sền sềnh sều sể sểnh sễ sệ sệch sệp sệt sỉ sỉa sỉnh sị sịa sịch sịt sọ sọc sọm sọt sỏ
sỏi số sốc sống sốp sốt sồ sồi sồn sồng sổ sổi sổng sỗ sộ sộc sộp sột sớ sới sớm sớn sớt sờ sờm sờn
sở sởi sởn sỡ sợ sợi sụ sụa sục sụm sụn sụp sụt sủ sủa sủi sủng sứ sứa sức sứt sừn sừng sử sửa sửng
sửu sữa sững sự sực sựng sựt sỹ t ta tai tam tan tang tanh tao tau tay te tem ten teng teo tha thai
tham than thang thanh thao thau thay the then theo thi thia thin thinh thiu thiêm thiên thiêng thiêu
thiếc thiến thiếp thiết thiếu thiềm thiền thiềng thiều thiểm thiển thiểu thiện thiệp thiệt thiệu tho
thoa thoai thoang thoi thom thon thong thoà thoàn thoá thoái thoán thoáng thoát thoã thoăn thoại
thoạt thoả thoải thoảng thoắng thoắt thu thua thui thum thun thung thuyên thuyết thuyền thuê thuôn
thuông thuý thuấn thuần thuẫn thuận thuật thuế thuể thuốc thuốn thuồi thuồn thuồng thuổng thuỗn
thuộc thuội thuộm thuột thuở thuỳ thuỵ thuỷ thà thài thàm thàng thành thào thày thá thác thách thái
thám thán tháng thánh tháo tháp thát tháu tháy thâm thân thâu thây thãi thè thèm thèn thèo thé thép
thét thê thêm thênh thêu thì thìa thìn thình thìu thí thía thích thím thín thính thíp thít thò thòa
thòi thòm thòng thó thóa thóc thói thóm thóp thót thô thôi thôn thông thõa thõm thõng thù thùa thùi
thùm thùn thùng thùy thú thúc thúi thúng thút thúy thăm thăn thăng thĩ thũng thơ thơi thơm thơn thư
thưa thưng thương thước thướng thướt thười thườn thường thưởng thưỡi thưỡn thược thượng thượt thạc
thạch thạnh thạo thạp thả thải thảm thản thảng thảnh thảo thảy thấm thấp thất thấu thấy thầm thần
thầu thầy thẩm thẩn thẩu thẩy thẫm thẫn thậm thận thập thật thắc thắm thắn thắng thắp thắt thằn
thằng thẳm thẳng thặng thẹn thẹo thẹp thẻ thẻn thẻo thẽ thế thếch thếp thết thề thềm thều thể thểu
thệ thện thỉ thỉnh thỉu thị thịch thịnh thịt thịu thọ thọc thọt thỏ thỏa thỏi thỏm thố thốc thối
thốn thống thốt thồ thồi thồm thồn thổ thổi thổn thỗn thộc thộn thộp thột thớ thới thớm thớt thờ
thời thờm thờn thở thợ thợt thụ thục thụi thụng thụp thụt thụy thủ thủa thủi thủm thủng thủy thứ
thức thừ thừa thừng thử thửa thửng thững thự thực ti tia tic tim tin ting tinh tit tiu tiêm tiên
tiêng tiêu tiếc tiếm tiến tiếng tiếp tiết tiếu tiềm tiền tiều tiểu tiễn tiễu tiệc tiệm tiện tiệp
tiệt to toa toan toang toanh toe toen toi tom ton tong top toà toài toàn toàng toá toác toái toán
toáng toát toáy toè toèn toé toét toạ toạc toại toạng toả toản toẹt toẻ toẽ tr tra trai tram tran
trang tranh trao trat trau tre treng treo tri trinh triêng triêu triến triết triền triềng triều
triển triện triệng triệt triệu tro troi trom tron trong troẹt tru trui trun trung truy truyền truyện
truân truông truất truật truồi truồng truột truỵ trà trài tràm tràn tràng trành trào tràu trày trá
trác trách trái trám trán tráng tránh tráo tráp trát trâm trân trâng trâu trây trã trãi trè trèm
trèn trèo tréc trém tréo trét trê trên trêu trì trình trìu trí tría trích trính trít tríu trò tròi
tròm tròn tròng tróc trói tróm tróng trót trô trôi trôm trôn trông trõm trõn trù trùi trùm trùn
trùng trú trúc trúm trúng trút trăm trăn trăng trĩ trĩnh trĩu trũi trũng trơ trơi trơn trưa trưng
trương trước trướng trườn trường trưởng trưỡng trượng trượt trạc trạch trại trạm trạn trạng trạnh
trạo trạt trạy trả trải trảm trản trảng trảnh trảo trảu trảy trấn trấp trất trấu trầm trần trầu trầy
trẩm trẩn trẩu trẩy trẫm trậm trận trập trật trắc trắm trắng trắt trằm trằn trằng trẳng trặc trặn
trẹ trẹo trẹt trẻ trẻo trẽ trẽn trẽo trếch trếnh trết trếu trề trển trễ trệ trệch trệt trệu trỉa trị
trịa trịch trịnh trịt trọ trọc trọi trọn trọng trọt trỏ trỏi trỏng trố trốc trối trốn trống trốt trồ
trồi trồng trổ trổi trổng trỗ trỗi trộ trộc trội trộm trộn trộng trớ trới trớn trớp trớt trờ trời
trờm trờn trở trợ trợn trợt trụ trụa trục trụi trụm trụn trụng trụp trụt trụy trủ trủng trứ trứng
trừ trừa trừng trừu trửng trữ trự trực tu tua tui tum tun tung tuy tuya tuyn tuyên tuyếc tuyến tuyết
tuyền tuyển tuyệt tuân tuôn tuông tuý tuýp tuýt tuấn tuất tuần tuẫn tuế tuếch tuềnh tuệ tuệch tuốc
tuốn tuốt tuồi tuồn tuồng tuổi tuộc tuột tuỳ tuỵ tuỷ ty tà tài tàm tàn tàng tành tào tàu tày tá tác
tách tái tám tán táng tánh táo táp tát táu táy tâm tân tâng tâu tây tã tãi tè tèm tèn tèng tèo té
téc tém tén téo tép tét tê têm tên tênh têt têu tì tìm tình tí tía tíc tích tím tín tính típ tít tíu
tò tòa tòe tòi tòm tòn tòng tó tóc tóe tói tóm tóp tót tô tôi tôm tôn tông tõe tõm tù tùm tùng tùy
tú túa túc túi túm túng túp tút túy tý tăm tăn tăng tĩ tĩn tĩnh tĩu tũm tũn tơ tơi tơn tư tưa tưng
tươi tươm tương tước tưới tướn tướng tướp tướt tườm tường tườu tưởi tưởng tược tượng tượp tượt tạ
tạc tạch tại tạm tạng tạnh tạo tạp tạt tả tải tản tảng tảo tấc tấm tấn tấp tất tấu tấy tầm tần tầng
tầu tầy tẩm tẩn tẩu tẩy tậm tận tập tật tậu tắc tắm tắn tắp tắt tằm tằn tằng tẳn tặc tặn tặng tẹc
tẹo tẹp tẹt tẻ tẻm tẻo tẽ tẽn tế tếch tết tếu tề tềnh tể tểnh tễ tễnh tệ tệp tỉ tỉa tỉm tỉnh tỉu tị
tịch tịnh tịt tịu tọ tọa tọc tọng tọp tọt tỏ tỏa tỏe tỏi tỏm tỏng tố tốc tối tốn tống tốp tốt tồ tồi
tồm tồn tồng tổ tổn tổng tỗng tộ tộc tội tộp tột tớ tới tớn tớp tớt tờ tời tở tởm tởn tợ tợn tợp tụ
tục tụi tụm tụng tụt tụy tủ tủa tủi tủm tủn tủng tủy tứ tứa tức từ từa từng tử tửa tửng tửu tự tựa
tựu tỳ tỵ tỷ u ui um un ung uy uyn uyên uyển uôm uông uý uýt uất uầy uẩn uẩy uế uể uốn uống uổng uột
uỳnh uỵch uỷ v va vac vai vam van vang vanh vao vat vay ve ven veo vi via vin vinh viêm viên viêng
viếng viết viền viển viễn việc viện việt vo voa voan voi vom von vong vu vua vui vun vung vuông vuốt
vuột vy và vài vàm vàn vàng vành vào vày vá vác vách vái ván váng vánh váo váp vát váy vâm vân vâng
vây vã vãi vãn vãng vãnh vè vèo vé véc vén véo vét vê vên vênh vêu vì ví vía vích vính vít víu vò
vòi vòm vòn vòng vó vóc vói vón vóng vót vô vôi vôn vông võ võng vù vùa vùi vùn vùng vú vúc vút văn
văng vĩ vĩnh vũ vũm vũng vơ vơi vưng vưu vươn vương vướng vườn vưởng vược vượn vượng vượt vạ vạc
vạch vại vạm vạn vạng vạnh vạp vạt vạy vả vải vảng vảnh vảy vấn vấp vất vấu vấy vần vầng vầu vầy vẩn
vẩu vẩy vẫn vẫy vậm vận vập vật vậy vắc vắn vắng vắt vằm vằn vằng vẳng vặc vặn vặt vẹc vẹm vẹn vẹo
vẹt vẻ vẻn vẻo vẽ vế vếch vết vếu về vền vều vểnh vệ vện vệt vỉ vỉa vị vịm vịn vịnh vịt vọ vọc vọi
vọng vọp vọt vỏ vỏn vỏng vố vốc vối vốn vống vồ vồi vồn vồng vổ vổng vỗ vội vớ với vớt vờ vời vờn vở
vởn vỡ vợ vợi vợt vụ vục vụn vụng vụt vủn vức vứt vừa vừng vửng vữa vững vựa vực vựng x xa xam xan
xang xanh xao xay xe xem xen xeng xeo xi xia xim xin xing xinh xit xiêm xiên xiêu xiếc xiết xiếu
xiềng xiểm xiển xiểng xo xoa xoai xoan xoang xoay xoe xoen xoi xom xon xong xoà xoài xoàm xoàn xoàng
xoành xoá xoác xoát xoáy xoã xoè xoèn xoét xoăn xoạc xoạch xoạng xoạt xoả xoải xoảng xoắn xoẳn xoẹ
xoẹt xoẻng xu xua xui xum xun xung xuy xuya xuynh xuyên xuyến xuyết xuân xuây xuê xuôi xuý xuýt xuất
xuẩn xuề xuềnh xuể xuệch xuống xuồng xuổng xuộm xuỳ xuỵt xy xà xài xàm xàng xành xào xàu xá xác xách
xái xám xán xáng xáo xáp xát xáu xáy xâm xâu xây xã xè xèn xèng xèo xé xéc xém xén xéo xép xét xê
xên xênh xêu xì xìa xình xìu xí xía xích xín xính xít xíu xòa xòe xòm xòng xó xóa xóc xói xóm xón
xóng xóp xót xô xôi xôm xôn xông xõa xõm xõng xù xùa xùi xùm xùng xùy xú xúa xúc xúi xúm xúng xúp
xút xúy xýt xăm xăn xăng xĩnh xũ xơ xơi xơm xơn xưa xưng xương xước xướng xười xường xưởng xược xượi
xượt xạ xạc xạch xạm xạo xạp xạu xả xải xảm xảnh xảo xảu xảy xấc xấp xấu xầm xầu xẩm xẩn xẩu xẩy xậm
xập xắc xắm xắn xắng xắp xắt xằng xẵng xẹ xẹc xẹo xẹp xẹt xẻ xẻn xẻng xẻo xẽo xế xếch xếp xề xềm
xềnh xều xể xểnh xệ xệch xệp xệt xệu xỉ xỉa xỉn xỉnh xỉu xị xịch xịn xịt xịu xọ xọc xọe xọp xỏ xỏa
xỏng xố xốc xối xốn xống xốp xốt xồ xồm xồn xồng xổ xổi xổm xổn xổng xộc xộn xộp xớ xới xớn xớp xớt
xờ xờm xở xởi xởn xỡ xợp xợt xụ xục xụi xụng xụp xụt xủ xủng xứ xức xứng xừ xừng xử xửa xửng xự xực
y yen yêm yên yêng yêu yếm yến yết yếu yểm yểng yểu à ành ào á ác ách ái ám án áng ánh áo áp át áy â
âm ân âu ã è èng èo é éc ém én éo ép ét ê êm êu ì ìn ình í ích ín ít ò òa òi òm òn òng ó óc óe ói
óng óp ót ô ôi ôm ôn ông õng ù ùa ùm ùn ùng ú úa úc úi úm úng úp út úy ý ă ăm ăn ăng đ đa đai đam
đan đang đanh đao đau đay đe đem đen đeng đeo đi đia đin đinh đip điu điên điêng điêu điếc điếm điến
điếng điếu điềm điền điều điểm điển điểu điệm điện điệp điệu đo đoan đoi đom đon đong đoài đoàn
đoàng đoành đoá đoác đoái đoán đoãng đoạ đoạn đoạt đoản đoảng đu đua đui đum đun đung đup đuy đuya
đuôi đuôn đuông đuềnh đuểnh đuễnh đuốc đuối đuống đuồn đuổi đuỗn đuột đà đài đàm đàn đàng đành đào
đày đá đác đách đái đám đán đáng đánh đáo đáp đát đáu đáy đâm đâng đâu đây đã đãi đãng đãy đè đèm
đèn đèo đé đéc đém đéo đét đê đêm đên đênh đêu đì đìa đìn đình đìu đí đía đích đính đíp đít đò đòi
đòm đòn đòng đó đóa đóc đói đóm đón đóng đóp đót đô đôi đôm đôn đông đõ đù đùa đùi đùm đùn đùng đú
đúa đúc đúm đún đúng đúp đút đăm đăng đĩ đĩa đĩnh đũa đũi đũng đơ đơm đơn đưa đưng đương đước đướu
đười đườn đường đưỡn được đượi đượm đạc đạch đại đạm đạn đạo đạp đạt đả đảm đản đảng đảnh đảo đảy
đấm đấng đất đấu đấy đầm đần đầu đầy đẩu đẩy đẫm đẫn đẫy đậm đận đập đật đậu đậy đắc đắm đắn đắng
đắp đắt đằm đằn đằng đẳng đẵm đẵn đẵng đặc đặm đặn đặng đặt đẹn đẹp đẹt đẻ đẽ đẽo đế đếch đếm đến đề
đềm đền đềnh đều để đểm đểnh đểu đễ đễnh đệ đệm đệp đỉa đỉnh địa địch định địt địu đọ đọa đọc đọi
đọn đọng đọp đọt đỏ đỏi đỏm đỏng đố đốc đối đốm đốn đống đốp đốt đồ đồi đồm đồn đồng đổ đổi đổng đỗ
đỗi độ độc đội độn động độp đột đớ đới đớn đớp đớt đờ đời đờm đờn đởm đởn đỡ đợ đợi đợp đợt đụ đục
đụi đụn đụng đụp đụt đủ đủi đủng đứ đứa đức đứng đứt đừ đừa đừng đử đực đựng ĩ ĩnh ơ ơi ơn ư ưa ưng
ưu ươi ươm ươn ương ước ướm ướp ướt ườn ưỡn ạ ạch ạnh ạo ạt ả ải ảm ảng ảnh ảo ấm ấn ấp ất ấu ấy ầm
ầng ầu ầy ẩm ẩn ẩng ẩu ẩy ẫm ậc ậm ập ậu ắc ắng ắp ắt ằng ẳng ẵm ặc ặp ẹ ẹc ẹo ẹp ẹt ẻm ẻn ẻo ẽo ế ếch
ếm ếp ề ềnh ễng ễnh ệ ệch ện ệnh ệp ệt ỉ ỉa ỉm ỉn ỉu ị ịch ịn ịt ọ ọc ọe ọi ọp ọt ỏe ỏi ỏm ỏn ỏng ố
ốc ối ốm ống ốp ốt ồ ồi ồm ồn ồng ổ ổi ổm ổn ổng ộ ộc ộn ộp ớ ới ớm ớn ớt ờ ời ờm ờn ở ởn ỡm ợ ợi ợt
ụ ụa ục ụp ụt ủ ủa ủi ủn ủng ủy ứ ứa ức ứng ừ ừa ừm ừng ử ửng ựa ực ỳ ỷ
"""

enum Syllables {
    static let all: [String] = source.split(whereSeparator: \.isWhitespace).map(String.init)

    /// For every leading part of every toneless syllable, the tones the syllables beginning
    /// with it carry. A word typed halfway still counts, and a tone must fit some real word.
    private static let tones: [String: Set<Tone>] = {
        var table: [String: Set<Tone>] = [:]
        for syllable in all {
            var tone = Tone.none
            var scalars = String.UnicodeScalarView()
            for scalar in syllable.decomposedStringWithCanonicalMapping.unicodeScalars {
                switch scalar.value {
                case 0x0301: tone = .sac
                case 0x0300: tone = .huyen
                case 0x0309: tone = .hoi
                case 0x0303: tone = .nga
                case 0x0323: tone = .nang
                default: scalars.append(scalar)
                }
            }
            var prefix = ""
            for ch in String(scalars).precomposedStringWithCanonicalMapping {
                prefix.append(ch)
                table[prefix, default: []].insert(tone)
            }
        }
        return table
    }()

    /// `toneless` is lowercase.
    static func accepts(_ toneless: String, tone: Tone) -> Bool {
        guard let known = tones[toneless] else { return false }
        return tone == .none || known.contains(tone)
    }
}
