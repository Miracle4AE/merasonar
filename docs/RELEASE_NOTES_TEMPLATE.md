# MeraSonar — Release Notes Template

> Her yayın öncesi bu şablonu kopyalayıp `docs/releases/vX.Y.Z-rcN.md` olarak doldurun.

## Version

- **Sürüm:** X.Y.Z+build
- **Tarih:** YYYY-MM-DD
- **Kanal:** RC / Beta / Production

## Highlights

- (Kullanıcıya görünen 3–5 madde)

## Added

- 

## Improved

- 

## Fixed

- 

## Known limitations

- Image-space analiz GPS/kalibrasyon olmadan yalnızca görüntü piksellerinde çalışır.
- AI Assistant backend `OPENAI_API_KEY` gerektirir.
- Offline modda son önbellek gösterilir.

## Safety disclaimer

MeraSonar balık tespiti yapmaz; olasılık temelli planlama aracıdır. Av başarısı garanti edilmez. Resmi deniz ve hava uyarılarını takip edin.

## Upgrade notes

- Yerel `.env` dosyanızı koruyun; commit etmeyin.
- Backend ve istemci sürümünü birlikte güncelleyin.

## Test summary

| Gate | Sonuç |
|------|--------|
| `check_secrets.py` | |
| `check_release_config.py` | |
| `pytest` | |
| `flutter analyze` | |
| `flutter test` | |
| `release_verify.bat qa` | |
| Release build workflow | |
