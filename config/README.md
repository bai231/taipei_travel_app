# Local API credentials

Copy `config/secrets.example.json` to `config/secrets.json`, then replace the
placeholder values with your TDX Client ID and Client Secret.

Run the Flutter web app with:

```powershell
flutter run -d chrome --dart-define-from-file=config/secrets.json
```

`config/secrets.json` is ignored by Git and must be shared with teammates using
a private channel.
