@echo off
cd bin
::SET DEBUG=1
node manu.js generate ..\..\guide\index.manu ..\..\.generated
cd ..
pause

