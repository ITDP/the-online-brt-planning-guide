@echo off
cd bin
::SET DEBUG=1
node manu.js generate ..\..\guide\the-guide.manu ..\..\.generated
cd ..
pause

