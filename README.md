# POS System

Bu proje, mobil (Flutter) ve backend (Node.js/TypeScript) kısımlarından oluşan bir POS (Nokta Satış) sistemidir.

## 🚀 Canlı Demo (Live Demo)

Projeyi bilgisayarınıza kurmadan denemek için aşağıdaki bağlantıları kullanabilirsiniz:

- **Web Canlı Demo (Tarayıcıda Çalıştır):** [Uygulamayı Tarayıcıda Test Et](https://appetize.io/app/b_2ywfkzjhpphsetxycfjwfn3wzu)
- **Backend API URL:** `https://pos-system-nd0u.onrender.com`

---

## 📦 Kurulum Dosyaları (APK & IPA)

Projeyi doğrudan kendi cihazınızda denemek isterseniz, derlenmiş dosyaları aşağıdaki bağlantılardan indirebilirsiniz:

- 📱 [Android APK İndir](https://github.com/affanccn/pos-system/releases/latest/download/ArtisanPOS.apk)
- 🍏 [iOS IPA İndir](https://github.com/affanccn/pos-system/releases/latest/download/app-unsigned.ipa)

*(Not: iOS uygulamasını yüklemek için TestFlight veya bir Apple Developer hesabına ihtiyacınız olabilir.)*

---

## 🛠️ Yerel Geliştirme (Local Development)

Projeyi kendi bilgisayarınızda çalıştırmak için:

### 1. Backend Kurulumu
```bash
cd backend
npm install
npm run start:dev
```

### 2. Mobil Uygulama Kurulumu (Flutter)
```bash
cd pos_mobile
flutter pub get
flutter run
```

## 📸 Ekran Görüntüleri

Aşağıda uygulamanın çeşitli modüllerine ait ekran görüntülerini bulabilirsiniz:

<table>
  <tr>
    <td align="center"><img src="screenshots/masayönetimi.png" width="200" /><br><b>Masa Yönetimi</b></td>
    <td align="center"><img src="screenshots/menüyönetimi.png" width="200" /><br><b>Menü Yönetimi</b></td>
    <td align="center"><img src="screenshots/menüüründüzenle.png" width="200" /><br><b>Ürün Düzenleme</b></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/rezervasyonekranı.png" width="200" /><br><b>Rezervasyon Ekranı</b></td>
    <td align="center"><img src="screenshots/kasayönetimi.png" width="200" /><br><b>Kasa Yönetimi</b></td>
    <td align="center"><img src="screenshots/personelyönetimi.png" width="200" /><br><b>Personel Yönetimi</b></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/personelbilgileri.png" width="200" /><br><b>Personel Bilgileri</b></td>
    <td align="center"><img src="screenshots/maliyet.png" width="200" /><br><b>Maliyet (1)</b></td>
    <td align="center"><img src="screenshots/maliyet2.png" width="200" /><br><b>Maliyet (2)</b></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/gelismisraporlar.png" width="200" /><br><b>Gelişmiş Raporlar (1)</b></td>
    <td align="center"><img src="screenshots/gelismisraporlar2.png" width="200" /><br><b>Gelişmiş Raporlar (2)</b></td>
    <td align="center"><img src="screenshots/logislemgecmisi.png" width="200" /><br><b>Log ve İşlem Geçmişi</b></td>
  </tr>
</table>
