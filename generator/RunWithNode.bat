@echo off
cd bin
SET DEBUG=1
node obrt.js generate ..\..\guide\the-guide.src ..\..\.generated
pause

