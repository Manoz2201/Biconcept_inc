# biconcept

Interior estimate app for Windows and Android. Estimates, CRM, calendar, and project accounts sync to Appwrite.

## CI/CD

GitHub Actions:

- **CI** — `flutter analyze` and `flutter test` on pull requests and `main`
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
