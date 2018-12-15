@echo off

set "BASETITLE=Video to Discord batch script by Rafael "R4to0" Alves"
title %BASETITLE%

rem R4to0's Video to Discord batch script
rem This script will calculate video bitrate based on input length and output target size
rem with a minimum/maximum bitrate defined (default 128k and 1024k) using VP9 and 
rem audio as 128K (default) opus (WebM contained).

rem How to use:
rem Make sure you have ffmpeg installed and added to the PATH environment
rem (Optionally you can define path manually in the variables below)
rem Save this as Video2Discord.cmd and drag drop your video files over Video2Discord.cmd

rem NOTE:
rem The EXACT file size allowed by Discord for free accounts is 8388213 bytes.
rem For some reason, Discord adds 395 bytes of metadata during upload.
rem You can check it in developer console by pressing CTRL+SHIFT+I
rem 8388608 - 395 = 8388213
rem Not tested with Nitro limits (52428800 for 50MB without subtracting extra metadata)

rem Updates: https://gist.github.com/R4to0/29dd1762e4535dcbfe2be514631e656f

rem Documentation source:
rem https://trac.ffmpeg.org/wiki/Encode/H.264
rem https://trac.ffmpeg.org/wiki/Encode/VP9

rem Didn't wanted to use this but I had to do
rem Use set function !variables! inside if/else
setlocal enabledelayedexpansion

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
rem set RESOLUTION=hd720
set MAXVIDEOBITRATE=1024
set MINVIDEOBITRATE=128
set AUDIOBITRATE=128
set FILEPREFIX=v2d
set PRIORITY=low
rem set VIDEOCODEC=libvpx-vp9
rem set AUDIOCODEC=libopus

rem Use single input dir/file at time
pushd %~pd1

rem If input is empty, go to end of file (ends script)
if [%1==[ goto :EOF

rem Size target
echo Target max size:
echo 1. Normal (up to 8MB)
echo 2. Nitro (up to 50MB)
echo.
:proftype
set /p "acctype=Your choice? "
if %acctype% EQU 1 (
    set BASECALC=8388213
    set PRL=Normal 8MB
)
if %acctype% EQU 2 (
    set BASECALC=52428800
    set PRL=Nitro 50MB
)
if %acctype% LEQ 0 (
    echo Invalid option specified. Try again...
    goto :proftype
)
if %acctype% GEQ 3 (
    echo Invalid option specified. Try again...
    goto :proftype
)
echo.

title %BASETITLE% (%PRL%)

rem Codec
rem TODO: Tweak x264 encoder due to overhead
echo Codec:
echo 1. WebM (VP9 + opus, recommended but slow encoding, CPU only)
echo 2. MP4 (x264 + aac, a bit faster but less efficient, CPU only)
rem echo 3. AMD GPU encoding MP4 (h264 + aac, VCE cards only, faster, inefficient)
rem echo 4. NVIDIA GPU encoding MP4 (NVENC cards only, not tested)
echo.
:codecsel
set /p "cdctyp=Your choice? "
if %cdctyp% EQU 1 (
    set "VIDEOCODEC=libvpx-vp9"
    set "AUDIOCODEC=libopus"
    set "EXTRAENCPARAMS=-deadline good"
    set "OUTPUTEXT=webm"
)
if %cdctyp% EQU 2 (
    set "VIDEOCODEC=libx264"
    set "AUDIOCODEC=aac"
    set "EXTRAENCPARAMS=-preset veryslow -movflags +faststart"
    set "OUTPUTEXT=mp4"
)
rem if %cdctyp% EQU 3 (
rem     set "VIDEOCODEC=h264_amf"
rem     set "AUDIOCODEC=aac"
rem     set "EXTRAENCPARAMS=-profile:v high -quality quality -coder cabac -rc cbr -movflags +faststart"
rem     set "OUTPUTEXT=mp4"
rem )
rem if %cdctyp% EQU 4 (
rem     set "VIDEOCODEC=h264_nvenc"
rem     set "AUDIOCODEC=aac"
rem     set "EXTRAENCPARAMS=-movflags +faststart"
rem     set "OUTPUTEXT=mp4"
rem )
if %cdctyp% LEQ 0 (
    echo Invalid option specified. Try again...
    goto :codecsel
)
if %cdctyp% GEQ 3 (
    echo Invalid option specified. Try again...
    goto :codecsel
)
echo.

title %BASETITLE% (%PRL% / %OUTPUTEXT%)

rem Resolution
echo Resolution:
echo -1. Same as origin file
echo 1. 240p (432x240)
echo 2. 360p (640x360)
echo 3. 480p (852x480)
echo 4. 720p (1280x720)
echo 5. 1080p (1920x1080)
:ressel
set /p "restyp=Your choice? "
if %restyp% LEQ 0 set "RESOLUTION="
if %restyp% EQU 1 set "RESOLUTION=-s fwqvga"
if %restyp% EQU 2 set "RESOLUTION=-s nhd"
if %restyp% EQU 3 set "RESOLUTION=-s hd480"
if %restyp% EQU 4 set "RESOLUTION=-s hd720"
if %restyp% EQU 5 set "RESOLUTION=-s hd1080"
if %restyp% GEQ 6 (
    echo Invalid option specified. Try again...
    goto :ressel
)

rem Shitty crop feature (NO USER INPUT VALIDATION!)
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
    )

) else (
    echo Using full length
    for /f "delims=" %%i in ('%PROBER% -i %1 -show_entries format^=duration -v quiet -of csv^="p=0"') do set "VIDEOSECS=%%i"
)

rem Calculate bitrate based on length and target file size
rem If result is higher than %MAXVIDEOBITRATE%, it will use it instead of result
rem Formula:
rem videobitrate = ( ( size in bytes / 128 ) / seconds ) - audiobitrate
set /a "VIDEOBITRATE=((BASECALC/128)/VIDEOSECS)-AUDIOBITRATE"
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

title %BASETITLE% (%PRL% / %OUTPUTEXT% / %VIDEOSECS% seconds %VIDEOBITRATE%kbps)

rem Compress Video:
rem -y Assume YES for overwriting (using NULL output for the first one)
rem -n Assume NO for overwriting
rem -hwaccel Uses GPU acceleration for decoding input video
rem -c:v Video output codec (VP9)
rem -b:v Video bitrate
rem -pass Two pass mode
rem -deadline Compression efficiency (VP9, https://trac.ffmpeg.org/wiki/Encode/VP9#speed)
rem -preset Compression efficiency (libx264, https://trac.ffmpeg.org/wiki/Encode/H.264#a2.Chooseapresetandtune)
rem -an Do not process audio (pass 1)
rem -threads Amount of CPU threads to use
rem -s Output resolution
rem -b:a Audio bitrate (Opus)
rem -strict Bypass encoding standards
rem -f Force format
rem %~d1 System Drive letter, %~p1 file path, %~n1 file name without extension
:start
start /b /wait /%PRIORITY% "" %ENCODER% -y -hwaccel d3d11va %STARTTIME% %ENDTIME% -i %1 -c:v %VIDEOCODEC% -b:v %VIDEOBITRATE%k %RESOLUTION% -pass 1 %EXTRAENCPARAMS% -an -threads %THREADS% -strict -2  -f %OUTPUTEXT% NUL && ^
start /b /wait /%PRIORITY% "" %ENCODER% -n -hwaccel d3d11va %STARTTIME% %ENDTIME% -i %1 -c:v %VIDEOCODEC% -b:v %VIDEOBITRATE%k %RESOLUTION% -pass 2 %EXTRAENCPARAMS% -c:a %AUDIOCODEC% -threads %THREADS% -b:a %AUDIOBITRATE%k -strict -2 "%~d1%~p1%~n1"%FILEPREFIX%.%OUTPUTEXT%
del "%~d1%~p1%ffmpeg2pass-0.log"
if "%VIDEOCODEC%" == "libx264" del "%~d1%~p1%ffmpeg2pass-0.log.mbtree"

rem Switch to next file input if exists
shift
popd

rem Quit this crappy script
:exitthis
pause
