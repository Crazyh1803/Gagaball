# Android release checklist

## Verified in this checkout

- Godot 4.7.2 imports and starts the project without script or resource errors.
- All six automated suites pass under Godot 4.7.2: profiles/tour, leagues/crowd/ball,
  gameplay, CPU free-for-all, fighter art, and controls/customization.
- The Android preset builds an AAB with package ID
  `com.appsbydan.gagapitshowdown`, version name `1.0.0`, and version code `1`.
- The merged manifest has minimum SDK 24, target SDK 36, one normal launcher entry,
  and no requested Android permissions.
- The bundle contains only the ARM 64-bit ABI, validates with Bundletool 1.18.3,
  requests 16 KB page alignment, and has 16 KB-aligned native load segments.
- The generated universal APK has an estimated compressed download size of about
  98.8 MB, below Google Play's 200 MB per-device limit.
- Internal tools, test scripts, the obsolete nested scaffold, and marketing-only
  files are excluded from the shipping bundle.

## Required before uploading

- Create or select the permanent release/upload keystore and keep at least two
  secure backups. Configure its path, alias, and passwords in Godot's Android
  export settings or the corresponding `GODOT_ANDROID_KEYSTORE_RELEASE_*`
  environment variables. Never commit the keystore or passwords.
- Export with **Export With Debug** disabled. Do not upload the debug AAB under
  `.godot/qa/`.
- Authorize USB debugging on a physical phone, install the QA APK, and complete
  a touch/audio/resume/save smoke test in landscape orientation.
- Host [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) at a public URL. Because the
  game's school presentation is likely to include children in its target
  audience, add that URL to the Play listing and expose it inside the app before
  submission.
- Complete Play Console declarations: ads, Data safety, target audience and
  content, content rating, app access, and Play App Signing.
- For every bundle exported with the official Godot 4.7.2 release template,
  upload `Godot_native_debug_symbols.4.7.2.stable.template_release.android.zip`
  as its **Native debug symbols** archive in Play Console. Keep symbol archives
  matched to the exact Godot version used for each release.
- The current Android build does not enable R8/ProGuard, so it intentionally has
  no deobfuscation mapping file. Do not upload a blank or unrelated mapping file.
- Add the required contact email, store description, screenshots, app icon, and
  feature graphic. Ensure every store image reflects the actual current build.

## Release build

Open the root `project.godot` in Godot 4.7.2, confirm the release keystore fields,
then export the `Android` preset. The configured output is
`GagaPitShowdown.aab`. Increment `version/code` for every later Play upload.
