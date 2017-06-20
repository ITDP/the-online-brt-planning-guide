@echo off
cd bin
::SET DEBUG=1
SET PULL_REQUEST=146
SET BASE_BRANCH=commit_ts
SET GH_USER=lehonma
node manu.js generate ..\..\guide\index.manu ..\..\.generated
cd ..
pause

