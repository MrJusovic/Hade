# Hade

**API benzeri, açık kaynaklı ve tamamen ücretsiz bir macOS HTTP istemcisi.**

Hade; SwiftUI ile yazılmış, native bir macOS uygulamasıdır. İstek oluşturmak, koleksiyonlar halinde düzenlemek, ortam değişkenleri kullanmak ve OpenAPI/Swagger dokümanlarını içe aktarmak için tasarlanmıştır. Reklam yok, takip yok, ücret yok.

> API/API gibi araçlara sade, hızlı ve yerel bir alternatif.

---

## ✨ Özellikler

### İstek & Yanıt
- **HTTP metotları**: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
- **Query parametreleri** — URL ile **çift yönlü senkron** (birini düzenleyince diğeri güncellenir)
- **Header'lar** — standart header adları için öneri listeli, değer için bağlama duyarlı öneriler (ör. `Content-Type` → `application/json`)
- **Gövde**: JSON (sözdizimi renklendirmeli editör + biçimlendirme), düz metin, `x-www-form-urlencoded` (key-value tablosu)
- **Yanıt görüntüleyici**: durum kodu, süre, boyut; JSON renklendirme; header listesi; kopyalama

### Sekmeler (Tabs)
- Her istek ayrı sekmede açılır; birden fazla istek üzerinde aynı anda çalışın
- Koleksiyondan bir isteğe tıklayınca yeni sekmede açılır (zaten açıksa öne gelir)

### Koleksiyonlar
- İstekleri isimlendirip koleksiyonlar halinde saklayın (Core Data ile kalıcı)
- **Arama** — koleksiyon/istek/URL/metot/kategori üzerinde
- **Kategori gruplama** — OpenAPI `tag`'lerine göre koleksiyon içi gruplar
- **Koleksiyon ayarları** — ad, kaynak URL ve değişkenler

### Değişkenler & Ortamlar
- `{{değişken}}` sözdizimi; **koleksiyon < ortam < çalışma zamanı** öncelik sırasıyla çözümleme
- Ortamlar arası geçiş (dev/prod vb.)
- Değişken tipleri: **Metin**, **Gizli** (maskeli), **Authorization**
- `{{baseUrl}}` mantığı — içe aktarımda otomatik kurulur

### Otomatik Authorization
- OpenAPI `security` bilgisine göre kimlik doğrulama gerektiren uçlar işaretlenir
- Koleksiyonun **Authorization** tipli değişkeni, korumalı isteklere otomatik `Authorization` header'ı olarak eklenir (ör. `Bearer {{token}}`)

### Post-response Script (JavaScript)
- Yanıt sonrası çalışan JS; `response.status`, `response.body`, `response.headers`, `response.json()`, `setVar("k", v)`, `console.log(...)`
- Örnek: login yanıtından token'ı çıkarıp değişkene atayın, sonraki isteklerde otomatik kullanın:
  ```js
  setVar("token", response.json().access_token);
  ```

### OpenAPI / Swagger İçe Aktarma
- OpenAPI 3 ve Swagger 2 (JSON) dokümanlarını URL'den veya dosyadan içe aktarın
- `$ref` çözümü ve şemadan **örnek gövde üretimi**
- "Swagger'dan Güncelle" ile koleksiyonu kaynağından yenileyin

### Diğer
- İstek geçmişi (temizlenebilir)
- Güncelleme denetimi (GitHub Releases)
- Açık/koyu tema uyumu

---

## 📦 Kurulum

### DMG ile (önerilen)
1. [Releases](../../releases) sayfasından en son `Hade.dmg` dosyasını indirin.
2. DMG'yi açın ve **Hade**'yi `Applications` klasörüne sürükleyin.
3. İlk açılışta Gatekeeper uyarısı çıkarsa uygulamaya sağ tıklayıp **Aç** deyin.

### Kaynaktan derleme
```bash
git clone https://github.com/MrJusovic/Hade.git
cd Hade
open Hade.xcodeproj
```
Xcode'da **⌘R** ile çalıştırın. Gereksinim: macOS 26+, Xcode 26+.

> Uygulama ağ isteği yapabilmek için App Sandbox altında **Outgoing Connections (Client)** iznini kullanır (proje ayarlarında etkindir).

---

## 🚀 Hızlı Başlangıç

1. **Yeni İstek** (+) ile bir sekme açın, metot ve URL girin, **Gönder**.
2. Bir Swagger dokümanı içe aktarın: kenar çubuğu ▸ **Swagger İçe Aktar** ▸ URL veya dosya.
   - Deneme için: `https://petstore3.swagger.io/api/v3/openapi.json`
3. Koleksiyon ▸ sağ tık ▸ **Ayarlar…** ile `baseUrl` ve `Authorization` değişkenlerini tanımlayın.
4. Login isteğinin **Script** sekmesinde token'ı bir değişkene atayın; korumalı uçlar otomatik yetkilenir.

---

## 🛠️ Teknoloji
- SwiftUI + Observation (`@Observable`)
- Core Data (kalıcı depolama)
- URLSession (async/await)
- JavaScriptCore (script motoru)

---

## 🏷️ Sürüm çıkarma (bakımcılar için)
Sürümler **yerelde** imzalanıp notarize edilir; sertifika buluta yüklenmez.
```bash
# Bir kereye mahsus notarizasyon kimliği:
xcrun notarytool store-credentials "hade-notary" \
  --apple-id "APPLE_ID" --team-id "RH4R52HACH" --password "APP_SPECIFIC_PASSWORD"

# Sürüm:
scripts/release.sh 1.0.1
```
Script; archive → Developer ID imzalama → notarizasyon → DMG → GitHub release adımlarını yapar. (`.github/workflows/release.yml` yalnızca elle tetiklenen, **imzasız** bir yedektir.)

## 🤝 Katkı
Katkılar memnuniyetle karşılanır. Lütfen [CONTRIBUTING.md](CONTRIBUTING.md) dosyasına göz atın.

## 📄 Lisans
[MIT](LICENSE) — özgürce kullanın, değiştirin ve dağıtın.
