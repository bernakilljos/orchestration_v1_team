@echo off
rem =====================================================
rem Module 07: Git 초기화 + (선택) GitHub 저장소 생성
rem Usage: 07-github.bat [TARGET]
rem
rem TEAM 배포 버전:
rem   - 하드코딩 토큰 없음
rem   - 환경변수 GITHUB_PERSONAL_ACCESS_TOKEN 있으면 사용
rem   - 없으면 prompt (Enter 치면 skip)
rem   - 어떤 경우에도 git init 은 됨
rem =====================================================
setlocal enabledelayedexpansion

set "TARGET=%~1"
if "%TARGET%"=="" echo [ERROR] TARGET required & exit /b 1

echo.
echo [+] Git / GitHub setup...

where git >nul 2>&1
if errorlevel 1 (
  echo       [WARN] git not found - skipping all
  goto DONE
)

rem --- Git init (항상 수행) ---
if exist "%TARGET%\.git" (
  echo       [OK] Git already initialized
) else (
  cd /d "%TARGET%"
  git init >nul 2>&1
  if not errorlevel 1 echo       [OK] git init done
)

rem --- GitHub PAT 확인 ---
set "GITHUB_PAT="
powershell -NoProfile -Command "[System.Environment]::GetEnvironmentVariable('GITHUB_PERSONAL_ACCESS_TOKEN','User')" > "%TEMP%\_ghpat.txt" 2>nul
set /p "GITHUB_PAT=" < "%TEMP%\_ghpat.txt"
del "%TEMP%\_ghpat.txt" >nul 2>&1

rem --- 환경변수에 없으면 prompt ---
if "!GITHUB_PAT!"=="" (
  echo.
  echo       --------------------------------------------------------
  echo       [선택] GitHub Personal Access Token 입력
  echo       --------------------------------------------------------
  echo       토큰을 입력하면 GitHub 저장소를 자동 생성합니다.
  echo       Enter 만 치면 GitHub 단계를 SKIP 하고 git init 까지만 합니다.
  echo.
  echo       토큰 발급: https://github.com/settings/tokens (repo 권한)
  echo.
  set /p "GITHUB_PAT=      Token (없으면 Enter): "
  if not "!GITHUB_PAT!"=="" (
    powershell -NoProfile -Command "[System.Environment]::SetEnvironmentVariable('GITHUB_PERSONAL_ACCESS_TOKEN','!GITHUB_PAT!','User')" >nul 2>&1
    echo       [OK] Token 저장됨 (User 환경변수)
  )
)

rem --- 토큰 없으면 여기서 종료 ---
if "!GITHUB_PAT!"=="" (
  echo       [SKIP] GitHub 저장소 생성 단계 — 토큰 미입력
  echo              나중에 직접 만들려면:
  echo                set GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...
  echo                gh repo create  또는  git remote add origin ...
  goto DONE
)

rem --- GitHub repo 생성 ---
for %%P in ("%TARGET%") do set "PROJ_BASE=%%~nxP"
set "PROJ_BASE=!PROJ_BASE: =-!"
echo       Creating GitHub repo: !PROJ_BASE!...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$pat='!GITHUB_PAT!';$base='!PROJ_BASE!'; ^
   $headers=@{Authorization=('token '+$pat);Accept='application/vnd.github.v3+json'}; ^
   $url=''; ^
   for($i=0;$i-le10;$i++){$name=if($i-eq0){$base}else{$base+'-'+$i}; ^
     try{$b=@{name=$name;private=$false;auto_init=$false}|ConvertTo-Json; ^
       $r=Invoke-RestMethod -Uri 'https://api.github.com/user/repos' -Method Post -Headers $headers -Body $b -ContentType 'application/json' -ErrorAction Stop -TimeoutSec 15; ^
       $url=$r.clone_url;break ^
     }catch{if($_.Exception.Response.StatusCode.value__ -eq 422){continue}else{break}}}; ^
   if($url){$url|Set-Content('%TARGET%\.github-repo-url.txt') -Encoding UTF8; Write-Host('      [OK] '+$url)}else{Write-Host '      [WARN] GitHub repo creation failed - 토큰/권한 확인 필요'}"

rem --- remote add + 초기 commit ---
cd /d "%TARGET%"
if exist "%TARGET%\.github-repo-url.txt" (
  for /f "usebackq tokens=*" %%U in ("%TARGET%\.github-repo-url.txt") do set "GH_URL=%%U"
  if not "!GH_URL!"=="" git remote add origin "!GH_URL!" >nul 2>&1
)

git add . >nul 2>&1
git commit -m "Initial commit from orchestration setup" >nul 2>&1
if not errorlevel 1 echo       [OK] Initial commit done

:DONE
echo [Module 07] Git/GitHub OK
endlocal
exit /b 0
