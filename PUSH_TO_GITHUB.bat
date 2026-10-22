@echo off
cd /d "%~dp0"
echo.
echo === AG Farmer → GitHub push ===
echo Repo: https://github.com/devabhai-1/AG-Farmer.git
echo.
echo Pehle browser / Git Credential Manager se login ho sakta hai.
echo Secrets (.env, keys) gitignore me hain — push nahi honge.
echo.
git status -sb
echo.
set /p DO=Naye changes bhi add+commit karein? (y/N): 
if /I "%DO%"=="y" (
  git add -A
  git commit -m "Update AG Farmer" || echo (koi naya commit nahi)
)
git push -u origin main
echo.
if errorlevel 1 (
  echo FAIL: login / network check karo.
) else (
  echo OK: GitHub update ho gaya.
)
pause
