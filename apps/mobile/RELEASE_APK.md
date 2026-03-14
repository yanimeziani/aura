# Release Pegasus APK

Current app version: **0.4.0** (versionCode 15).

## GitHub secrets required for signed release

- `ANDROID_KEYSTORE_BASE64`
- `PEGASUS_RELEASE_STORE_PASSWORD`
- `PEGASUS_RELEASE_KEY_ALIAS`
- `PEGASUS_RELEASE_KEY_PASSWORD`

The `Android Release` workflow fails if any secret is missing.

## Create a release

```bash
git add -A
git commit -m "release: prepare v0.4.0"
git tag v0.4.0
git push origin main
git push origin v0.4.0
```

The workflow runs these checks before publishing:

- `./gradlew verifyReleaseSigning`
- `./gradlew lint`
- `./gradlew testDebugUnitTest`
- `./gradlew assembleRelease`

## Output

Release asset name format:

`pegasus-vX.Y.Z-arm64.apk`
