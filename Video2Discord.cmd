@echo off

TITLE Discord WebM script by Rafael "R4to0" Alves

rem Settings:
rem ENCODER Path to your ffmpeg
rem THREADS Amount of CPU cores/threads to use
rem RESOLUTION Video screen size to use https://ffmpeg.org/ffmpeg-utils.html#Video-size
rem VIDEOBITRATE Target bitrate
rem FILEPREFIX Optional prefix to append to the output filename (ex.: 20180501_PREFIX.)webm
rem PRIORITY Windows process priority (low normal high realtime abovenormal  belownormal) https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-xp/bb491005(v=technet.10)
rem VIDEOCODEC Video encoder https://www.ffmpeg.org/ffmpeg-codecs.html#Video-Encoders
rem AUDIOCODEC Audio encoder https://www.ffmpeg.org/ffmpeg-codecs.html#Audio-Encoders
set ENCODER=ffmpeg.exe
set PROBER=ffprobe.exe
set THREADS=2
set RESOLUTION=hd720
set MAXVIDEOBITRATE=1024
set MINVIDEOBITRATE=128
set AUDIOBITRATE=128
set FILEPREFIX=_720
set PRIORITY=low
set VIDEOCODEC=libvpx-vp9
set AUDIOCODEC=libopus

rem Use single input dir/file at time
pushd %~pd1

rem If input is empty, go to end of file (ends script)
if [%1==[ goto :EOF

echo Select account type:
echo 1. Normal (up to 8MB)
echo 2. Nitro (up to 50MB)
echo.
set /P acctype=Your choice? 
if %acctype% EQU 1 set BASECALC=64000
if %acctype% EQU 2 set BASECALC=384000
if %acctype% LEQ 0 (
    echo Invalid option specified.
    goto :exitthis
)
if %acctype% GEQ 3 (
    echo Invalid option specified.
    goto :exitthis
)
echo.

rem Calculate bitrate to hard limit 8MB
rem If result is higher than default, it will use defaultbitrate
for /F "delims=" %%i in ('%PROBER% -i %1 -show_entries format^=duration -v quiet -of csv^="p=0"') do set "VIDEOSECS=%%i"
rem 384000 for ~50MB, 64000 for ~8MB
SET /A "totalBitrate=%BASECALC%/VIDEOSECS"
SET overheadBitrate=0
SET /A "VIDEOBITRATE=totalBitrate-AUDIOBITRATE-overheadBitrate"
if %VIDEOBITRATE% LSS %MINVIDEOBITRATE% (
    echo POTATO QUALITY ERROR: Video lenght too long for specified type! %VIDEOBITRATE%
    goto :exitthis
)
if %VIDEOBITRATE% gtr %MAXVIDEOBITRATE% set VIDEOBITRATE=%MAXVIDEOBITRATE%

rem Do file size estimation
set /A "ESTFILESIZE=((VIDEOBITRATE*VIDEOSECS)/8)+((AUDIOBITRATE*VIDEOSECS)/8)"

echo Video bitrate will be %VIDEOBITRATE%kbps, audio bitrate %AUDIOBITRATE%kbps with %VIDEOSECS% seconds.
echo Estimated file size: %ESTFILESIZE%kBytes.
pause

rem Compress Video:
rem -y Assume YES for overwriting (using NULL output for the first one)
rem -n Assume NO for overwriting
rem -hwaccel Uses GPU acceleration for decoding input video
rem -c:v Video output codec (VP9)
rem -b:v Video bitrate
rem -pass Two pass mode
rem -deadline Compression efficiency (realtime, good, or best)
rem -an Do not process audio (pass 1)
rem -threads Amount of CPU threads to use
rem -s Output resolution
rem -b:a Audio bitrate (Opus)
rem -strict Bypass encoding standards
rem -f Force format
rem %~d1 System Drive letter, %~p1 file path, %~n1 file name without extension
:start
start /b /wait /%PRIORITY% "" %ENCODER% -y -hwaccel d3d11va -i %1 -c:v %VIDEOCODEC% -b:v %VIDEOBITRATE%k -pass 1 -deadline good -an -threads %THREADS% -s %RESOLUTION% -strict -2  -f webm NUL && ^
start /b /wait /%PRIORITY% "" %ENCODER% -n -hwaccel d3d11va -i %1 -c:v %VIDEOCODEC% -b:v %VIDEOBITRATE%k -pass 2 -deadline good -c:a %AUDIOCODEC% -threads %THREADS% -s %RESOLUTION% -b:a %AUDIOBITRATE%k -strict -2  "%~d1%~p1%~n1"%FILEPREFIX%.webm
del "%~d1%~p1%ffmpeg2pass-0.log"

rem Switch to next file input if exists
shift
popd

:exitthis
pause
