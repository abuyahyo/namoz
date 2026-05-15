# Namoz — Windows desktop namoz vaqtlari vidjeti

Toza, doim ko'rinib turuvchi (always-on-top) Windows vidjeti — istalgan shahar uchun namoz vaqtlari, jonli countdown va Sajda uslubidagi dizayn bilan. PowerShell + WPF, hech qanday muhit o'rnatish kerak emas.

<p align="center">
  <img src="screenshot.png" alt="Namoz widget" width="280"/>
</p>

## Xususiyatlari

- **Istalgan shahar** — sozlamalar oynasidan shahar va davlatni o'zgartirib turish (Aladhan API, 5 mln+ joy)
- **Avto hisoblash usuli** — davlatga qarab method tanlanadi (Egyptian, Saudi Umm Al-Qura, Russia SAMR, Diyanet va h.k.)
- **Jonli countdown** — keyingi namozgacha qolgan vaqt har soniyada yangilanadi (HH:MM:SS)
- **Faol pill** — hozir ichida bo'lgan namoz vaqti ajratiladi
- **Singleton** — vidjet faqat bitta nusxada ishlaydi
- **Joylashuvni eslab qolish** — tortib qo'ygan joy `config.json` ga saqlanadi
- **Offline rejim** — internet yo'q bo'lsa, oxirgi keshlangan vaqtlar ko'rsatiladi
- **Avtomatik ishga tushish** — `shell:startup` shortcut bilan har gal Windows yoqilganda ochiladi
- **Toza dizayn** — Nunito shrifti, kirillcha o'zbek matn, chuqur yashil pastki bar, yumshoq aylanma burchaklar

## Bir qatorda o'rnatish

PowerShell ochib (Start menyuda **"Terminal"** yoki **"PowerShell"**) quyidagi qatorni yopishtiring va Enter bosing:

```powershell
irm https://raw.githubusercontent.com/abuyahyo/namoz/main/install.ps1 | iex
```

Shu zahoti vidjet yuklab olinadi, `%USERPROFILE%\PrayerWidget\` ga o'rnatiladi, Desktop va Startup'ga yorliqlar qo'shiladi va vidjet ishga tushadi. Hech narsa qo'lda qilish kerak emas.

**Olib tashlash:**
```powershell
irm https://raw.githubusercontent.com/abuyahyo/namoz/main/uninstall.ps1 | iex
```

## Talablar

- Windows 10 / 11
- PowerShell 5.1+ (Windows bilan birga keladi)
- Internet (boshlang'ich va kunlik yangilanish uchun; offline rejimda oxirgi kesh ko'rsatiladi)

## Qo'lda o'rnatish

Agar avtomatik installer ishlatmoqchi bo'lmasangiz:

1. [Release sahifasi](https://github.com/abuyahyo/namoz/releases/latest)dan **Source code (zip)** ni yuklang
2. ZIP ichidagi papkani `%USERPROFILE%\PrayerWidget\` ga ochib qo'ying
3. `start.vbs` ni ikki marta bosing

## Foydalanish

| Harakat | Natija |
|---|---|
| Sichqoncha bilan tortish | Vidjetni ko'chirish (joylashuv saqlanadi) |
| `⚙` tugmasi | Sozlamalar — shahar / davlatni o'zgartirish |
| `✕` tugmasi | Yopish |

## Texnik tafsilotlar

- **API:** [Aladhan](https://aladhan.com/prayer-times-api) `timingsByCity` endpoint
- **Shrift:** [Nunito](https://github.com/googlefonts/nunito) (SIL Open Font License) — `fonts/Nunito.ttf` ichida
- **Asosiy fayllar:**
  - `widget.ps1` — asosiy WPF skript
  - `start.vbs` — konsol ko'rinmaydigan launcher
  - `make-icon.ps1` — `Намоз` ikona generatori (Nunito Black bilan PNG → ICO)
  - `namoz.ico` — generatsiya qilingan dastur ikonasi
  - `fonts/Nunito.ttf` — bundled variable font

## Litsenziya

[MIT](LICENSE). Nunito shrifti uchun [SIL Open Font License](fonts/OFL.txt).

---

## English

A minimal always-on-top Windows widget showing Islamic prayer times for any city, with a live countdown to the next prayer and Sajda-inspired styling. Built with PowerShell + WPF — no runtime install required.

**Features:** city/country settings dialog with auto calculation method, live HH:MM:SS countdown, active-prayer pill, position persistence, offline fallback, optional auto-start on Windows logon.

**Setup:** clone to `%USERPROFILE%\PrayerWidget\`, run `start.vbs`. See above for the optional auto-start shortcut.

**Stack:** Windows PowerShell 5.1+, WPF, Aladhan API, Nunito font (bundled).
