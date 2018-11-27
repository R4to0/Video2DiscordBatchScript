@echo off
rem R4to0's Video to Discord batch script
rem This script will calculate video bitrate based on input length and output target size
rem with a minimum/maximum bitrate defined (default 128k and 1024k) using VP9 and 
rem audio as 128K (default) opus (WebM contained).

rem How to use:
rem Make sure you have ffmpeg installed and added to the PATH environment
rem (Optionally you can define path manually in the variables below)
rem Save this as Video2Discord.cmd and drag drop your video files over Video2Discord.cmd

rem Updates: https://gist.github.com/R4to0/29dd1762e4535dcbfe2be514631e656f

rem Didn't wanted to use this but i had to do
rem Use set function !variables! inside if/else
setlocal enabledelayedexpansion

title Video to Discord batch script by Rafael "R4to0" Alves (WebM)

rem Settings:
rem ENCODER Path to ffmpeg.exe
rem PROBER Path to ffprobe.exe
rem THREADS Amount of CPU cores/threads to use
rem RESOLUTION Video screen size to use https://ffmpeg.org/ffmpeg-utils.html#Video-size
rem MAXVIDEOBITRATE Maximum target bitrate
rem MINVIDEOBITRATE Minimum bitrate (below that script will quit)
rem AUDIOBITRATE Audio bitrate
rem FILEPREFIX Optional prefix to append to the output filename (ex.: 20180501_PREFIX.)webm
rem PRIORITY Windows process priority (low normal high realtime abovenormal  belownormal) https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-xp/bb491005(v=technet.10)
rem VIDEOCODEC Video encoder https://www.ffmpeg.org/ffmpeg-codecs.html#Video-Encoders
rem AUDIOCODEC Audio encoder https://www.ffmpeg.org/ffmpeg-codecs.html#Audio-Encoders
set ENCODER=ffmpeg.exe
set PROBER=ffprobe.exe
set THREADS=%NUMBER_OF_PROCESSORS%
set RESOLUTION=hd720
set MAXVIDEOBITRATE=1024
set MINVIDEOBITRATE=128
set AUDIOBITRATE=128
set FILEPREFIX=_r4v2d
set PRIORITY=low
set VIDEOCODEC=libvpx-vp9
set AUDIOCODEC=libopus

rem Use single input dir/file at time
pushd %~pd1

rem If input is empty, go to end of file (ends script)
if [%1==[ goto :EOF

rem Discord profile type
echo Select profile type:
echo 1. Normal (up to 8MB)
echo 2. Nitro (up to 50MB)
echo.
:proftype
set /p "acctype=Your choice? "
if %acctype% EQU 1 set BASECALC=64000
if %acctype% EQU 2 set BASECALC=384000
if %acctype% LEQ 0 (
    echo Invalid option specified. Try again...
    goto :proftype
)
if %acctype% GEQ 3 (
    echo Invalid option specified. Try again...
    goto :proftype
)
echo.

rem Shitty crop feature
rem Setting startposition to -1 will skip this completely and use total video time
rem Setting endposition to -1 will use up to the end of file
rem Total final time in seconds will be calculated
rem Time to seconds source:
rem https://stackoverflow.com/questions/42603119/arithmetic-operations-with-hhmmss-times-in-batch-file
set /p "StartPosition=Start time in hh:mm:ss (-1 to use full length): "
echo.
if %StartPosition% GEQ 0 (
    set STARTTIME=-ss %StartPosition%

    set /p "EndPosition=End time in hh:mm:ss (-1 to up to the end): "
    echo.

    if !EndPosition! GEQ 0 (
        set ENDTIME=-to !EndPosition!
        set /a "VIDEOSECS=(((1!EndPosition::=-100)*60+1!-100)-(((1%StartPosition::=-100)*60+1%-100)"
    ) else (
        for /f "delims=" %%i in ('%PROBER% -i %1 -show_entries format^=duration -v quiet -of csv^="p=0"') do set "TOTALSECS=%%i"
        set /a "VIDEOSECS=TOTALSECS-(((1%StartPosition::=-100)*60+1%-100)"
        pause
    )

) else (
    echo Using full length
    for /f "delims=" %%i in ('%PROBER% -i %1 -show_entries format^=duration -v quiet -of csv^="p=0"') do set "VIDEOSECS=%%i"
)

rem Calculate bitrate based on length and profile type
rem If result is higher than default, it will use defaultbitrate
rem https://www.etdofresh.com/ffmpeg-your-videos-to-8mb-in-windows-for-discord-use/
set /a "totalBitrate=%BASECALC%/VIDEOSECS"
set overheadBitrate=0
set /a "VIDEOBITRATE=totalBitrate-AUDIOBITRATE-overheadBitrate"
if %VIDEOBITRATE% LSS %MINVIDEOBITRATE% (
    echo POTATO QUALITY ERROR: Video length too long for specified type or invalid! %VIDEOBITRATE%
    goto :exitthis
)
if %VIDEOBITRATE% gtr %MAXVIDEOBITRATE% set VIDEOBITRATE=%MAXVIDEOBITRATE%

rem Do file size estimation
set /a "ESTFILESIZE=((VIDEOBITRATE*VIDEOSECS)/8)+((AUDIOBITRATE*VIDEOSECS)/8)"

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
start /b /wait /%PRIORITY% "" %ENCODER% -y -hwaccel d3d11va %STARTTIME% -i %1 %ENDTIME% -c:v %VIDEOCODEC% -b:v %VIDEOBITRATE%k -pass 1 -deadline good -an -threads %THREADS% -s %RESOLUTION% -strict -2  -f webm NUL && ^
start /b /wait /%PRIORITY% "" %ENCODER% -n -hwaccel d3d11va %STARTTIME% -i %1 %ENDTIME% -c:v %VIDEOCODEC% -b:v %VIDEOBITRATE%k -pass 2 -deadline good -c:a %AUDIOCODEC% -threads %THREADS% -s %RESOLUTION% -b:a %AUDIOBITRATE%k -strict -2  "%~d1%~p1%~n1"%FILEPREFIX%.webm
del "%~d1%~p1%ffmpeg2pass-0.log"

rem Switch to next file input if exists
shift
popd

:exitthis
pause
