@echo off
echo ============================================================
echo   ISLA App - Development Runner
echo   Secrets are loaded from: lib/config/secrets.dart
echo ============================================================
echo.

:: Check if flutter is available
where flutter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Flutter not found in PATH.
    echo Please install Flutter and add it to your PATH.
    pause
    exit /b 1
)

echo Running: flutter pub get
call flutter pub get

echo.
echo Starting ISLA App...
echo.
call flutter run --web-renderer html

pause
