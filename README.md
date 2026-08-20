# biconcept

Interior estimate app for Windows and Android. Estimates, CRM, calendar, and project accounts sync to Appwrite.

## Versioning

`pubspec.yaml` holds the marketing version (`1.0.0+1` is name `1.0.0`, build `1`). Settings shows that value from the installed binary, plus the CI channel and git SHA baked in at build time.

To ship an update:

1. Bump `version:` in `pubspec.yaml` (raise the `+build` if you only need a new Android `versionCode`).
2. Tag and push: `git tag v1.0.1 && git push origin v1.0.1`
3. GitHub Actions **Release** builds the Android APK and Windows zip, then publishes a GitHub Release with `latest.json`.
4. In the app, Settings → **Check for update** / **Update app**.

You can also run **Release** by hand from the Actions tab. The workflow run number becomes the Android `versionCode`.

If the GitHub repo is private, save a token with Contents read (the same GitHub token already used for data sync works). Public repos do not need a token.

## CI/CD

GitHub Actions:

- **CI** — `flutter analyze` and `flutter test` on pull requests and `main`
- **Release** — on `v*.*.*` tags (or workflow dispatch), publishes Android APK + Windows zip to GitHub Releases
- **Appwrite** — pushes table schema from `appwrite.config.json` when that file changes on `main`, or when you run the workflow by hand

Add a repository secret named `APPWRITE_API_KEY` (server key with tables read/write). Project ID and endpoint stay in `appwrite.config.json`; never commit the key.

```bash
gh secret set APPWRITE_API_KEY
```

Local schema deploy:

```bash
appwrite client --key "$APPWRITE_API_KEY"
appwrite push tables --all --force
```
