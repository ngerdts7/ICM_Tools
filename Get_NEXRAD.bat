@echo off
rem ----------------------------------------------------------
rem - Script for pulling the latest radar data from an FTP site
rem - Requires local install of WinSCP
rem -      https://winscp.net/eng/index.php
rem - NEXRAD site codes:
rem - https://www.roc.noaa.gov/wsr88d/Images/WSR-88DCONUSCoverage1000.jpg
rem ----------------------------------------------------------

rem - Define local paths and desired window for pulling files.
set "localpath=C:\temp\NEXRAD\"
set "sitecode=khgx"    :: NEXRAD station site code
set "window=2h"        :: files added in this time period will be imported
set "ftp_UN=anonymous" :: user name login for FTP - (anonymous for public sites)
set "ftp_PW=pw"        :: password for FTP - (arbitrary string for public sites)

rem - Assemble FTP site path
set "ftpsite=ftp://%ftp_UN%:%ftp_PW%@tgftp.nws.noaa.gov"
set "ftploc=/SL.us008001/DF.of/DC.radar/DS.176pr/SI.%sitecode%/"

rem - Call WinSCP to pull requested window of files from FTP to local folder
"C:\Program Files (x86)\WinSCP\WinSCP.com" log="%localpath%log\WinSCP.log" ^
	/ini=nul /command ^
	"open %ftpsite%%ftploc%" ^
	"get *>%window% %localpath%*" ^
	"exit"
	
rem ftp://anonymous:pw@tgftp.nws.noaa.gov