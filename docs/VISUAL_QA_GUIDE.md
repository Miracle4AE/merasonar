# MeraSonar — Visual QA Guide

Golden test zorunlu değil; release öncesi manuel screenshot QA rehberi.

## Hedef ekranlar

1. Dashboard (Home) — desktop + mobile
2. Live Area
3. Marine Intelligence (koordinat analizi)
4. Map — World mode
5. Map — Chart overlay
6. Captain Atlas komuta merkezi
7. Compare
8. AI Assistant sheet (Captain)
9. Saved spots panel
10. Empty states (dashboard, marine, live)

## Hedef çözünürlükler

| Profil | Boyut | Platform |
|--------|-------|----------|
| Desktop geniş | 1600×900 | Windows |
| Desktop laptop | 1366×768 | Windows |
| Mobile | 390×844 | Android |

## Kabul kriterleri

- [ ] Metin taşması / overflow yok (`RenderFlex overflowed` yok)
- [ ] Dark theme kontrast okunabilir
- [ ] Sidebar Captain Atlas etiketi kırık değil
- [ ] Mobil sticky dock görünür; desktop’ta dock yok
- [ ] “Mission Control” metni görünmüyor
- [ ] Boş state premium (dekoratif desen, CTA)
- [ ] Battery saver: ambient/blur azaltılmış, işlevsel
- [ ] Reduce motion: geçişler sade, crash yok

## Screenshot dosya adlandırma (öneri)

```
docs/screenshots/rc1/dashboard_1600x900.png
docs/screenshots/rc1/live_area_390x844.png
...
```

## Flutter golden test (TODO — Phase 4+)

- `golden_toolkit` veya `flutter_test` `matchesGoldenFile`
- CI’da `--update-goldens` yalnızca manual onaylı PR
- İlk hedef: Dashboard V2 + empty state kartları

---

**Son güncelleme:** RC Phase 3
