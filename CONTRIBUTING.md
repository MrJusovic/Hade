# Katkı Rehberi

Hade'ye katkıda bulunmak istediğin için teşekkürler! 🎉

## Başlarken
1. Depoyu **fork** edin ve klonlayın:
   ```bash
   git clone https://github.com/<kullanıcı-adın>/Hade.git
   cd Hade
   open Hade.xcodeproj
   ```
2. Gereksinimler: **macOS 26+** ve **Xcode 26+**.
3. Yeni bir dal açın: `git checkout -b feature/kısa-açıklama`

## Geliştirme
- **Mimari**: SwiftUI + Observation (`@Observable`), Core Data, `async/await`. Combine kullanmaktan kaçınıyoruz.
- **Kod stili**:
  - Tipler `PascalCase`, özellik/metotlar `camelCase`
  - 4 boşluk girinti
  - Zorlama unwrap'ten (`!`) kaçının
  - Karmaşık mantık için açıklayıcı yorumlar
- Değişikliklerinizi küçük ve odaklı tutun; alakasız düzenlemelerden kaçının.

## Commit & PR
- Anlamlı commit mesajları yazın (ne + neden).
- PR açıklamasında neyi değiştirdiğinizi ve nasıl test ettiğinizi belirtin.
- Mümkünse ekran görüntüsü/GIF ekleyin.
- PR'ı `main` dalına açın.

## Hata bildirimi & öneriler
- **Issue** açarken: beklenen davranış, gerçekleşen davranış, tekrar üretme adımları ve (varsa) örnek OpenAPI dokümanı/istek ekleyin.
- Özellik önerileri için kullanım senaryosunu kısaca anlatın.

## Lisans
Katkılarınız, projenin [MIT lisansı](LICENSE) altında yayınlanacaktır.
