#! /usr/bin/env bash

set -euo pipefail
IFS=$(printf "\n\t")

if [ -z "${1:-}" ]; then
    printf 'Usage: dithercbz [Folder or archive]'
    exit
fi

if ! command -v magick >/dev/null 2>&1; then
    printf 'magick dependency missing.'
    exit
fi

if ! command -v parallel >/dev/null 2>&1; then
    printf 'parallel dependency missing.'
    exit
fi

if ! command -v 7z >/dev/null 2>&1; then
    printf '7z dependency missing.'
    exit
fi

if [ -z "${DITHERCBZ_COLOR_MAP_LOCATION:-}" ]; then
    printf "The DITHERCBZ_COLOR_MAP_LOCATION environment variable is not set"
    exit
fi

if ! [ -f "$DITHERCBZ_COLOR_MAP_LOCATION" ] || ! [ -r "$DITHERCBZ_COLOR_MAP_LOCATION" ]; then
    printf "The file at DITHERCBZ_COLOR_MAP_LOCATION(%s) is not a regular, readable file" "$DITHERCBZ_COLOR_MAP_LOCATION"
    exit
fi

archiveFileName="$1"
# FIXME: if the directory ends with a / it breaks

# directory or archive or nothing
if [ -d "$archiveFileName" ]; then
    archiveFolder="$archiveFileName"
elif [ -e "$archiveFileName" ]; then
    #get rid of file extension
    archiveFolder="${archiveFileName%.*}"

    if [ -e "$archiveFolder" ]; then
        printf 'ERROR1: "%s" already exists\n' "$archiveFolder"
        exit
    fi

    printf "Extracting archive...\r"
    7z x -y -o"$archiveFolder" "$archiveFileName" > /dev/null
    ret="$?"
    if [ "$ret" -ne "0" ]; then
        printf 'ERROR3: Problem extracting archive to "%s"\n' "$archiveFolder"
        exit
    fi
    printf "Finished extracting archive!"

    zipped="1"
else
    printf 'ERROR4: "%s" does not exist\n' "$archiveFileName"
    exit
fi

outputFolder="new$archiveFolder"

mkdir "$outputFolder" 2> /dev/null
ret=$?
if [ "$ret" -ne "0" ]; then
    printf "ERROR5: %s already exists\n" "$outputFolder"
    exit
fi

convertimage() {
    deviceresw=1404
    deviceresh=1872
    colorMapLocation="$DITHERCBZ_COLOR_MAP_LOCATION"

    file="$1"
    outputFolder="$2"
    # get rid of everything past the first '/'
    foldername="${file%/*}"
    # get rid of everything before the last '/'
    filenamewithsuffix="${file##*/}"
    # get rid of the file extension
    filename="${filenamewithsuffix%.*}"

    newfolder="${outputFolder}/${foldername}"
    newfile="${newfolder}/${filename}.png"
    echo "newfile: $newfile"

    mkdir -p "$newfolder" 2> /dev/null

    imgdim="$(magick identify -quiet -format '%[fx:w] %[fx:h]' "$file" 2> /dev/null)"
    ret="$?"
    if [ "$ret" != 0 ]; then
        return
    fi

    imgw="$(printf "%s" "$imgdim" | awk '{print $1}')"
    imgh="$(printf "%s" "$imgdim" | awk '{print $2}')"

    resw="$deviceresw"
    resh="$deviceresh"

    rotation=0

    if [ "$imgw" -gt "$imgh" ]; then
        resw="$deviceresh"
        resh="$deviceresw"
        rotation="-90"
    fi

    # FIXME: if the file path becomes too long it won't be able to read(?) or write the file
    magick convert "$file" \
        -filter LanczosSharp \
        -resize "${resw}x${resh}" \
        -colorspace Gray \
        -dither FloydSteinberg \
        -remap "$colorMapLocation" \
        -rotate "$rotation" \
        -quality 75 \
        "$newfile"
        # -define png:color-type=0 \ # 0 means grayscale
        # -define png:bit-depth=8 \
}

export -f convertimage
find "$archiveFolder" -type f | parallel -q convertimage {} "$outputFolder"

zipFileName="${archiveFolder}.zip"

mkdir -p output

7z a "output/$zipFileName" "${outputFolder}/."

rename .zip .cbz "output/$zipFileName"

rm -r "$outputFolder"

if [ "${zipped:-}" ]; then
    rm -r "$archiveFolder"
fi
