# Outpost Control

**Yazar**: Monsterfish
**Sürüm**: 1.0.16

Harita düzenleyicide yerleştirdiğiniz Avrupalı ve Arap karakolları üzerinde daha fazla kontrol sağlar. Her özellik ayarlardan kapatılabilir.

## Karakol paneli

Harita düzenleyicide bir karakol seçin. Panelin üstündeki düğme artık iki sayfa arasında geçiş yapar. Her kaydırıcı kendi değerini sağ tarafında gösterir.

- **Saldıranlar** – oyundaki gibi karakolun hangi birlikleri göndereceğini belirler, üç kaydırıcı içerir:
  - **Boyut:** her dalgada tam olarak kaç birlik bulunacağını 0'dan (hiç dalga yok) oyunun en büyük boyutunda gönderdiği azami sayıya kadar ayarlar. ("Dalga başına kesin birlik sayısını ayarla" kapalıysa oyunun kendi kaydırıcısı geri gelir: rastgele grup boyutlarından oluşan 6 kademe.) Bu modül olmadan harita, oyunun kendi boyutlarından en yakın olanını korur.
  - **Başlangıç Gecikmesi:** ilk dalgadan önce ne kadar bekleneceğini (oyunun kendi ayarı) normal hızda saniye cinsinden gösterir.
  - **Büyüme:** her dalganın bir öncekinden ilk dalganın yüzdesi olarak ne kadar büyüyeceğini belirler. 0 (başlangıç) tüm dalgaları oyundaki gibi ilk dalgayla aynı boyutta tutar; 50 her seferinde ilk dalganın yarısını ekler; 100 her seferinde tam bir ilk dalga ekler. Dalgalar 999 birlikte büyümeyi durdurur. Dalgaların geliş hızı oyundaki gibi kalır: her dalgadan sonra biraz daha erken gelirler.
- **Savunucular** – aynı sekiz birlik düğmesi yeni bir anlam kazanır, ayrıca bir kaydırıcı eklenir:
  - **Birlik düğmeleri:** karakolu hangi birliklerin koruyacağını belirler. Birden fazla seçerseniz sırayla üretilirler. Avrupalı bir karakol okçular, arbaletçiler, mızrakçılar, kargıcılar, gürzcüler, kılıçlılar, şövalyeler ve kara keşişler sunar; Arap bir karakol ise Arap okçular, sapancılar, atlı okçular, Arap kılıçlılar, köleler, suikastçılar, ateş atıcılar ve arbaletçiler sunar. Hiçbir şey seçilmezse karakol oyundaki gibi okçuları kullanır.
  - **Miktar:** karakolun çevresinde kaç muhafız duracağını 0 ile 50 arasında ayarlar. Ölen muhafızlar tek tek geri gelir; sayı ne kadar yüksekse o kadar hızlı yenilenirler, böylece tam bir ekip oyunun 8 muhafızıyla yaklaşık aynı sürede tamamlanır (normal hızda 8 için her 30 saniyede bir, 50 için her 5 saniyede bir muhafız).
  - **Duruşlar:** göğüs göğüse savaşan yaya askerler (mızrakçılar, kargıcılar, gürzcüler, kılıçlılar, kara keşişler, suikastçılar) savunma duruşunda nöbet tutar ve yaklaşan düşmanlara saldırır; köleler saldırgan duruşta daha uzaktaki düşmanlara hücum eder; şövalyeler saldırgan duruşta karakolun çevresinde devriye gezer, düşman birliklere ve 10 kare mesafeye giren her düşman binasına saldırır; atlı okçular da saldırgan duruşta karakolun çevresinde devriye gezer: her yönde bir tane olmak üzere 7 ila 15 kare dışarıdaki rastgele altı nokta boyunca dolaşır, yolda bir bina, sur veya su varsa nokta yakındaki boş bir yere kaydırılır. Okçular, arbaletçiler, sapancılar ve ateş atıcılar oyunun kendi karakol okçuları gibi durup ateş eder.
  - **Surların üzerinde:** yaya muhafızlar, yürüyerek ulaşabiliyorsa karakolun 16 kare yakınındaki sahibine ait surlara, taş kulelere ve taş kapı binalarına çıkar; her biri çevresinde en az muhafız bulunan boş noktaya yerleşir, böylece yayılır ve ölen muhafızların yerini doldururlar. Şövalyeler ve atlı okçular aşağıda kalır. Bu özellik ayar yapılmamış olanlar dâhil tüm karakollar için çalışır (ayarlardan değiştirilebilir).

## Saldıranların görevleri

Normalde tüm dalga aynı şeyi yapar: ilerleyip bir binaya saldırır, arada bir hendeği kazar. Bu modülle her dalga karakoldan ayrıldığında birlik türüne göre bölünür ve her grup kendine uygun bir görev alır:

| Birlik | İlk görev (varsayılan pay) | Kalanlar |
| --- | --- | --- |
| Köleler | hendeği doldur (%50) | binaları yakıp yık |
| Mızrakçılar | hendeği doldur (%50) | surlara ve kapılara saldır |
| Gürzcüler | hendeği doldur (%30) | binaları yık |
| Kılıçlılar | surlara ve kapılara saldır (%60) | binaları yık |
| Arap kılıçlılar | surlara ve kapılara saldır (%50) | binaları yık |
| Şövalyeler | lordu avla (%40) | kalenin etrafında at sür |
| Okçular, Arap okçular | hendeği doldur (%30) | ilerleyip karşılaştığı birliklere ateş et |
| Sapancılar | kalenin etrafında yürü (%30) | ilerleyip karşılaştığı birliklere ateş et |
| Atlı okçular | kalenin etrafında at sür (%100) | ilerleyip karşılaştığı birliklere ateş et |
| Ateş atıcılar | binaları yak (%60) | ilerleyip karşılaştığı birlikleri yak |

Kalenin etrafında dolaşmak, kaleyi güvenli bir mesafeden çevreleyip surların dışındaki işçileri ve birlikleri biçmek anlamına gelir. Şövalyeler lorda yalnızca ulaşabiliyorlarsa saldırır; aksi hâlde onlar da kalenin etrafında at sürer. Yapacak işi kalmayan bir birlik (hendek dolmuşsa, yolda sur yoksa) tüm dalganın normalde yapacağı gibi saldırır. Her pay ayarlardan değiştirilebilir.

## Yoldaki kuşatma araçları

Karakoldan çıkan mancınıklar ve ateş balistaları saldırdıkları kaleye doğru ilerler ve menzile düşmana ait bir şey girer girmez durup ateş eder — tıpkı hedef verdiğiniz kendi kuşatma araçlarınız gibi:

- **Mancınıklar** (ve haritanın karakolları gönderiyorsa trebuşeler veya mangoneller) menzildeki en yakın düşman binasına, ardından bir sonrakine ateş eder.
- **Ateş balistaları** önce menzildeki düşman birliklerine ve işçilerine, ardından binalara ateş eder.

Bir hedefin menzilde olup olmadığına, her aracın kendi menziliyle (kullanıyorsanız Rebalancer'ın belirlediği menzille) tıpkı bir oyuncunun aracında olduğu gibi oyunun kendisi karar verir. Yalnızca düşmanları hedef alırlar: karakol sahibinden farklı takımdaki oyuncular; müttefiklere, sahipsiz binalara veya hayvanlara asla ateş etmezler. Bir kuşatma birliği, araçlarından herhangi birinin menzilinde hedef kaldığı sürece olduğu yerde durur, böylece hiçbir hedefin yanından geçip gitmez; menzilde hiçbir şey kalmadığında yürümeye devam eder.

## Sonraki rakip

Karakolun gönderdiği her birlik bir düşman oyuncuyu hedef alır. O oyuncu yenildiğinde (lordu öldüğünde) birlik boş boş beklemek yerine, oyunun ilk hedefi seçtiği yolla — lordu hâlâ hayatta olan en yakın düşman — sonraki rakibi seçer. Kuşatma araçları menzillerindeki herhangi bir düşmana ateş etmeyi sürdürür ve bir hedef yok edildiğinde menzildeki bir sonrakine geçer.

## Karakollar yapay zekâyı desteklesin (varsayılan olarak kapalı)

Bu ayar açıkken bir yapay zekânın karakolundan ayrılan dalga tek başına saldırmak yerine o yapay zekânın kendi saldırı ordusuna katılır. Her birlik, oyunun onun için kullanacağı gruba girer: okçular, arbaletçiler, sapancılar, atlı okçular ve ateş atıcılar destek birliklerine, diğer herkes ana orduya. Yapay zekânın sonraki saldırısını bekler, o saldırıda savaşır ve yapay zekânın saldırmadan önce beklediği ordu sayısına dâhil olurlar. Kuşatma araçları karakolda kalıp erişebildikleri hedeflere ateş eder.

## Kayıt dosyaları ve haritalar

Her karakol için yaptığınız ayarlar haritada ve kayıt dosyalarında (Map Extensions modülü aracılığıyla) saklanır. Bu modül olmadan oynandığında harita yine çalışır: karakol ayarladığınız muhafız sayısını korur (en az bir adet, okçu olarak) ve dalgaları oyunun kendi boyutunda kalıp büyümez.
