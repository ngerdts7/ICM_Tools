@echo off
set "localpath=%~dp0"
set "icmversion=2021.2"
set "script=Automated_CIP.rb"

echo Running IExchange script %script%
echo Running IExchange version %icmversion%
"C:\Program Files\Innovyze Workgroup Client %icmversion%\iexchange.exe" "%localpath%%script%" /ICM

PAUSE