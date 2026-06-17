<#
.SYNOPSIS
  Adds the x86_64 PDFium native library to pdfrx so the app's PDF annotation
  screen renders on Android **emulators** (which are x86_64).

.WHY
  pdfrx bundles libpdfium.so per ABI, but its build only ships arm64-v8a and
  armeabi-v7a, and its CMake only seeds `.lib/latest` when that folder does not
  yet exist — so x86_64 never lands there. Without it, the emulator loads the
  wrong libpdfium and crashes with:
      Failed to lookup symbol 'FPDF_InitLibraryWithConfig'

  This script downloads the matching x86_64 build (same chromium release pdfrx
  pins) and drops it where pdfrx links and bundles from. Real arm devices are
  unaffected (their libs already ship).

.WHEN TO RUN
  Once after a fresh `flutter pub get` / `flutter clean` that re-extracted pdfrx
  (which removes the placed lib). Run from anywhere:
      pwsh isla_app/tool/setup_pdfium_x86_64.ps1
#>

$ErrorActionPreference = 'Stop'

# pdfrx pins this PDFium release (see android/CMakeLists.txt: PDFIUM_RELEASE).
$Release      = 'chromium%2F7202'
$ArchiveName  = 'pdfium-android-x64'           # x86_64 build
$ExpectedSha  = 'eb54f96d9e519e05823420892399c7b0500d1c4465d4408884c1ee478792b133'
$DownloadUrl  = "https://github.com/bblanchon/pdfium-binaries/releases/download/$Release/$ArchiveName.tgz"

# 1. Locate the pub cache and the pdfrx package directory.
$pubCache = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { Join-Path $env:LOCALAPPDATA 'Pub\Cache' }
$hosted   = Join-Path $pubCache 'hosted\pub.dev'
$pdfrxDir = Get-ChildItem -Path $hosted -Directory -Filter 'pdfrx-*' |
            Sort-Object Name -Descending | Select-Object -First 1
if (-not $pdfrxDir) { throw "pdfrx package not found under $hosted. Run 'flutter pub get' first." }

$libRoot   = Join-Path $pdfrxDir.FullName 'android\.lib'
$latestDir = Join-Path $libRoot 'latest\x86_64'
$relDir    = Join-Path $libRoot "$Release\x86_64"
$target    = Join-Path $latestDir 'libpdfium.so'

if (Test-Path $target) {
    Write-Host "x86_64 libpdfium.so already present at:`n  $target" -ForegroundColor Green
    Write-Host "Nothing to do." -ForegroundColor Green
    return
}

# 2. Download + extract the archive to a temp folder.
$tmp = Join-Path $env:TEMP "pdfium_x64_$(Get-Random)"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$tgz = Join-Path $tmp 'x64.tgz'

Write-Host "Downloading $ArchiveName ($Release)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $DownloadUrl -OutFile $tgz

Write-Host "Extracting..." -ForegroundColor Cyan
tar -xzf $tgz -C $tmp
$so = Join-Path $tmp 'lib\libpdfium.so'
if (-not (Test-Path $so)) { throw "libpdfium.so not found in archive." }

# 3. Verify integrity against the known-good hash.
$sha = (Get-FileHash -Algorithm SHA256 -Path $so).Hash.ToLower()
if ($sha -ne $ExpectedSha) {
    throw "SHA256 mismatch.`n expected: $ExpectedSha`n got:      $sha"
}
Write-Host "SHA256 verified." -ForegroundColor Green

# 4. Place it where pdfrx links (latest) and where its download check looks (release).
New-Item -ItemType Directory -Path $latestDir -Force | Out-Null
New-Item -ItemType Directory -Path $relDir    -Force | Out-Null
Copy-Item $so $target -Force
Copy-Item $so (Join-Path $relDir 'libpdfium.so') -Force

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

# 5. Patch pdfrx's android/build.gradle so its CMake compiles the libpdfrx.so
#    shim for x86_64 too (otherwise `pdfrx_file_access_create` is missing).
$buildGradle = Join-Path $pdfrxDir.FullName 'android\build.gradle'
$bg = Get-Content $buildGradle -Raw
if ($bg -notmatch '"x86_64"') {
    $bg = $bg -replace 'abiFilters "arm64-v8a", "armeabi-v7a"',
                       'abiFilters "arm64-v8a", "armeabi-v7a", "x86_64"'
    Set-Content -Path $buildGradle -Value $bg -Encoding utf8
    Write-Host "Patched build.gradle abiFilters (+x86_64)." -ForegroundColor Green
} else {
    Write-Host "build.gradle already includes x86_64." -ForegroundColor Green
}

# 6. Patch CMakeLists so the PDFium download step is skipped when the lib is
#    already present (offline-robust; avoids a FATAL on a flaky download).
$cmake = Join-Path $pdfrxDir.FullName 'android\CMakeLists.txt'
$cm = Get-Content $cmake -Raw
if ($cm -match 'if\(NOT EXISTS \$\{PDFIUM_SRC_LIB_FILENAME\}\)\s*\r?\n\s*message') {
    $cm = $cm -replace 'if\(NOT EXISTS \$\{PDFIUM_SRC_LIB_FILENAME\}\)(\s*\r?\n\s*message)',
                       'if(NOT EXISTS ${PDFIUM_DEST_LIB_FILENAME} AND NOT EXISTS ${PDFIUM_SRC_LIB_FILENAME})$1'
    Set-Content -Path $cmake -Value $cm -Encoding utf8
    Write-Host "Patched CMakeLists download guard." -ForegroundColor Green
} else {
    Write-Host "CMakeLists already patched (or layout changed)." -ForegroundColor Green
}

Write-Host "`nDone. x86_64 PDFium + libpdfrx shim enabled:" -ForegroundColor Green
Write-Host "  $target"
Write-Host "`nNow run:  flutter clean; flutter pub get; flutter run" -ForegroundColor Yellow
