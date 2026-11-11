# Qarzhy: Flutter жұмыс ортасын орнату (Windows)
# Іске қосу: файлды тінтуірдің оң жағымен басып -> "Выполнить с помощью PowerShell"
$ErrorActionPreference = "Continue"
function Step($t){ Write-Host "`n=== $t ===" -ForegroundColor Green }

Step "1/6 Git"
winget install -e --id Git.Git --accept-source-agreements --accept-package-agreements

Step "2/6 Android Studio (Android SDK + Java)"
winget install -e --id Google.AndroidStudio --accept-source-agreements --accept-package-agreements

Step "3/6 VS Code"
winget install -e --id Microsoft.VisualStudioCode --accept-source-agreements --accept-package-agreements

# Жаңа орнатылған бағдарламаларды PATH-тан көру үшін
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")

Step "4/6 Flutter SDK -> C:\flutter"
if (!(Test-Path "C:\flutter\bin\flutter.bat")) {
  git clone -b stable --depth 1 https://github.com/flutter/flutter.git C:\flutter
}
$userPath = [Environment]::GetEnvironmentVariable("Path","User")
if ($userPath -notlike "*C:\flutter\bin*") {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;C:\flutter\bin", "User")
}
$env:Path += ";C:\flutter\bin"
flutter config --no-analytics
flutter precache --android

Step "5/6 VS Code Flutter кеңейтімі"
code --install-extension Dart-Code.flutter

Step "6/6 Qarzhy кодын жүктеу -> $HOME\qarzhy-app"
if (!(Test-Path "$HOME\qarzhy-app\pubspec.yaml")) {
  if (Test-Path "$HOME\qarzhy-app") { Rename-Item "$HOME\qarzhy-app" "qarzhy-app-old" }
  git clone https://github.com/nn16nn/qarzhy-app "$HOME\qarzhy-app"
} else {
  git -C "$HOME\qarzhy-app" pull
}
Set-Location "$HOME\qarzhy-app"
flutter pub get

Write-Host "`nДАЙЫН. Енді:" -ForegroundColor Yellow
Write-Host " 1) Android Studio-ны бір рет ашып, Next -> Next -> Finish басыңыз (Android SDK жүктеледі)."
Write-Host " 2) Содан кейін жаңа терминалда:  flutter doctor --android-licenses   (барлығына y)"
Write-Host " 3) flutter doctor  — нәтижесінің скриншотын Claude-қа жіберіңіз."
Read-Host "`nЖабу үшін Enter басыңыз" | Out-Null
