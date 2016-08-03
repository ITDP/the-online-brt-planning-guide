@echo off
cd bin
SET DEBUG=1
SET DRAFT=1
neko obrt.n generate ..\..\guide\the-guide.src ..\..\.generated
pause
