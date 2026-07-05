# MeraSonar — Git Release Tag Plan (v1.0.0-rc1)

**Durum (RC Phase 9):** Yerel git repository **yok**. `git init`, commit, tag veya push **kullanıcı onayı olmadan yapılmamalıdır**.

## Önerilen tag

```
v1.0.0-rc1
```

Bu tag `.github/workflows/release-build.yml` içindeki `v*` ve `*-rc*` pattern’lerini tetikler.

## Ön koşullar

1. `python scripts/check_secrets.py` — OK
2. `python scripts/check_release_config.py` — OK
3. `pytest` — geçmeli
4. `cd deniz_app && flutter analyze && flutter test` — geçmeli
5. `.env` tracked **olmamalı** (tracked ise BLOCKER)
6. `run_logs/`, `deniz_app/build/`, `.venv/` tracked olmamalı

## Kullanıcı onayından sonra — ilk kez repo oluşturma

```bash
cd "d:\Deniz uygulaması"
git init
git branch -M main
git remote add origin <GITHUB_REPO_URL>
git status
git add .
git commit -m "chore: prepare v1.0.0-rc1 release candidate"
git tag v1.0.0-rc1
git push -u origin main
git push origin v1.0.0-rc1
```

Branch adı `main` değilse:

```bash
git branch --show-current
git push -u origin HEAD
git push origin v1.0.0-rc1
```

## Tag push sonrası beklenen CI

GitHub Actions → **Release Build** workflow:

| Job | Çıktı |
|-----|--------|
| `qa` | check_secrets, check_release_config, pytest, flutter analyze/test |
| `build-android` | `MeraSonar-android-apk` artifact |
| `build-windows` | `MeraSonar-windows-release`, `MeraSonar-windows-release-zip` |

**Not:** CI tag validation bu ortamda **henüz Passed değil** — repo/tag push yapılmadı.

## CI başarısız olursa

| Belirti | Kontrol |
|---------|---------|
| `check_secrets` failure | `.env`, `sk-proj-`, tracked secrets |
| Flutter SDK mismatch | `release-build.yml` `channel: stable` |
| Android Gradle failure | JDK 17, `flutter build apk` log |
| Windows runner path | Non-ASCII path CI’da yok; yerelde `subst M:` |
| Artifact sanity | `check_release_artifacts.py` — zip içinde `.env`, `run_logs` |

## Tag silme / yeniden deneme (dikkatli)

```bash
git tag -d v1.0.0-rc1
git push origin :refs/tags/v1.0.0-rc1
```

Force push main/master **önerilmez**; yalnızca acil durumda ve ekip onayı ile.

## İlgili dokümanlar

- `docs/RC1_DISTRIBUTION_PACKAGE.md`
- `docs/releases/v1.0.0-rc1-artifacts.md`
- `docs/releases/v1.0.0-rc1.md`
