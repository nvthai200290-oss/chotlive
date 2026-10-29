@echo off
setlocal
title CHOTLIVE Relay v2.1
cd /d "%~dp0"
where node >nul 2>&1
if errorlevel 1 (
  echo [LOI] Chua co Node.js 20 tro len.
  echo Cai Node.js LTS tai https://nodejs.org/en/download
  start "" "https://nodejs.org/en/download"
  pause
  exit /b 1
)
echo =======================================
echo CHOTLIVE v2.1 - MAY CHU BINH LUAN
echo =======================================
echo Dang cai/cap nhat thu vien TikTok...
call npm install --omit=dev
if errorlevel 1 (
  echo [LOI] Cai thu vien that bai. Kiem tra mang Internet.
  pause
  exit /b 1
)
echo.
echo Bat dau nhan binh luan TikTok LIVE...
echo De giu ket noi, KHONG DONG cua so nay.
node relay.js
echo May chu da dung.
pause
