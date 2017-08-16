@echo off
cd bin
::SET DEBUG=1
SET hostname=127.0.0.1:8080/
node manu.js generate ..\..\guide\index.manu ..\..\.generated
cd ..
pause

