#!/bin/bash

# Settings -- these need to use 0/1 for Boolean values for compatibility with the macOS defaults system
dontAskAgain=0
keepAllLanguages=1
keepFiles=0
languageCodes=""
removeCMv4=0
useSystemTools=0

# Paths
targetDir=$PWD # Default to current directory
doviToolPath=""
mkvextractPath=""
mkvmergePath=""

# Functions

# Read settings using `defaults` without overwriting current values that have not been set
getSettings() {
    local defaultValue

    defaultValue=$(defaults read org.nekno.DV7toDV8 dontAskAgain 2> /dev/null)
    if [[ $? == 0 ]]
    then
        dontAskAgain=$defaultValue
    fi

    defaultValue=$(defaults read org.nekno.DV7toDV8 keepAllLanguages 2> /dev/null)
    if [[ $? == 0 ]]
    then
        keepAllLanguages=$defaultValue
    fi

    defaultValue=$(defaults read org.nekno.DV7toDV8 keepFiles 2> /dev/null)
    if [[ $? == 0 ]]
    then
        keepFiles=$defaultValue
    fi

    defaultValue=$(defaults read org.nekno.DV7toDV8 languageCodes 2> /dev/null)
    if [[ $? == 0 ]]
    then
        languageCodes=$defaultValue
    fi

    defaultValue=$(defaults read org.nekno.DV7toDV8 removeCMv4 2> /dev/null)
    if [[ $? == 0 ]]
    then
        removeCMv4=$defaultValue
    fi

    defaultValue=$(defaults read org.nekno.DV7toDV8 useSystemTools 2> /dev/null)
    if [[ $? == 0 ]]
    then
        useSystemTools=$defaultValue
    fi
}

printHelp () {
    echo ""
    echo "Usage: $0 [OPTIONS] [PATH]"
    echo ""
    echo "Options:"
    echo ""
    echo "  -h|--help              Display this help message"
    echo "  -k|--keep-files        Keep working files"
    echo "  -l|--languages LANGS   Specify comma-separated ISO 639-1 (en,es,de) or ISO 639-2"
    echo "                         language codes (eng,spa,ger) for audio and subtitle tracks to keep (default: keep all tracks)"
    echo "  -r|--remove-cmv4       Remove DV CMv4.0 metadata and leave CMv2.9"
    echo "  -s|--show-settings     Show the settings app to configure the script for use on macOS (this option must be specified last)"
    echo "                         (default: enabled on macOS; unsupported on other platforms)"
    echo "  -u|--use-system-tools  Use tools installed on the local system"
    echo ""
    echo "Arguments:"
    echo ""
    echo "  PATH                   Specify the target directory path (default: current directory)"
    echo ""
    echo "Example:"
    echo ""
    echo "  $0 -k -l eng,spa -r /path/to/folder/containing/mkvs"
    echo ""
    exit 1
}

# Get the script's directory path; do this before pushing the targetDir
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Set the subdirectory paths
configPath=$scriptDir/config
toolsPath=$scriptDir/tools
settingsAppPath="$toolsPath/DV7 to DV8 Settings.app"

# If we're running on macOS, read the settings
if [[ $(uname) == "Darwin" ]]
then
    getSettings
fi

# Get the command-line arguments to override the defaults
# If any args are specified, assume all options were set as desired, so don't prompt for settings
while (( "$#" )); do
    case "$1" in
    -h|--help)
        printHelp;;
    -k|--keep-files)
        keepFiles=1
        dontAskAgain=1
        echo "Option enabled to keep working files..."
        shift;;
    -l|--languages)
        languageCodes=$2
        keepAllLanguages=0
        dontAskAgain=1
        echo "Language codes set: '$languageCodes'..."
        shift 2;;
    -r|--remove-cmv4)
        removeCMv4=1
        dontAskAgain=1
        echo "Option enabled to remove CMv4.0..."
        shift;;
    -s|--show-settings)
        dontAskAgain=0
        echo "Option enabled to show the settings app on macOS..."
        shift;;
    -u|--use-system-tools)
        useSystemTools=1
        dontAskAgain=1
        echo "Option enabled to use system tools..."
        shift;;
    -*|--*=) # unsupported flags
        echo "Error: Unsupported flag '$1'. Quitting." >&2
        exit 1;;
    *)
        targetDir=$1
        echo "Setting target directory: '$targetDir'..."
        shift;;
    esac
done

# If we're running on macOS, get settings if allowed
if [[ $(uname) == "Darwin" ]] && [[ $dontAskAgain == 0 ]]
then
    echo "Prompting for settings..."
    open -W -a "$settingsAppPath" 2> /dev/null
    getSettings
fi

# Set the JSON config file based on the CMv4.0 setting
if [[ $removeCMv4 == 1 ]]
then
    echo "Using CMv2.9 config file..."
    jsonFilePath=$configPath/DV7toDV8-CMv29.json
else
    echo "Using CMv4.0 config file..."
    jsonFilePath=$configPath/DV7toDV8-CMv40.json
fi

# Use the binaries installed on the local system; otherwise, use the binaries in the tools directory
if [[ $useSystemTools == 1 ]]
then
    which dovi_tool >/dev/null
    if [[ $? == 1 ]]
    then
        echo "dovi_tool not found in the system path. Quitting."
        exit 1
    fi

    which mkvextract >/dev/null
    if [[ $? == 1 ]]
    then
        echo "mkvextract not found in the system path. Quitting."
        exit 1
    fi

    which mkvmerge >/dev/null
    if [[ $? == 1 ]]
    then
        echo "mkvmerge not found in the system path. Quitting."
        exit 1
    fi

    echo "Using local system tools..."
    doviToolPath=dovi_tool
    mkvextractPath=mkvextract
    mkvmergePath=mkvmerge
else
    echo "Using bundled tools..."
    doviToolPath=$toolsPath/dovi_tool
    mkvextractPath=$toolsPath/mkvextract
    mkvmergePath=$toolsPath/mkvmerge
fi

if [[ ! -d $targetDir ]]
then
    echo "Directory not found: '$targetDir'. Quitting."
    exit 1
fi

echo "Processing directory: '$targetDir'..."

pushd "$targetDir" > /dev/null

for mkvFile in "$targetDir"/*.mkv
do
    mkvBase=$(basename "$mkvFile" .mkv)
    BL_EL_RPU_HEVC=$mkvBase.BL_EL_RPU.hevc
    DV7_EL_RPU_HEVC=$mkvBase.DV7.EL_RPU.hevc
    DV8_BL_RPU_HEVC=$mkvBase.DV8.BL_RPU.hevc
    DV8_RPU_BIN=$mkvBase.DV8.RPU.bin

    echo "Demuxing BL+EL+RPU HEVC from MKV..."
    "$mkvextractPath" "$mkvFile" tracks 0:"$BL_EL_RPU_HEVC"

    if [[ $? != 0 ]] || [[ ! -f "$BL_EL_RPU_HEVC" ]]
    then
        echo "Failed to extract HEVC track from MKV. Quitting."
        exit 1
    fi

    echo "Demuxing DV7 EL+RPU HEVC for you to archive for future use..."
    "$doviToolPath" demux --el-only "$BL_EL_RPU_HEVC" -e "$DV7_EL_RPU_HEVC"

    if [[ $? != 0 ]] || [[ ! -f "$DV7_EL_RPU_HEVC" ]]
    then
        echo "Failed to demux EL+RPU HEVC file. Quitting."
        exit 1
    fi

    # If the EL is less than ~10MB, then the input was likely DV8 rather than DV7
    # Extract and plot the RPU for archiving purposes, as it may be CMv4.0
    if [[ $(wc -c < "$DV7_EL_RPU_HEVC") -lt 10000000 ]]
    then
        echo "Extracting original RPU for you to archive for future use..."
        "$doviToolPath" extract-rpu "$BL_EL_RPU_HEVC" -o "$mkvBase.RPU.bin"
        "$doviToolPath" plot "$mkvBase.RPU.bin" -o "$mkvBase.L1_plot.png"
    fi

    echo "Converting BL+EL+RPU to DV8 BL+RPU..."
    "$doviToolPath" --edit-config "$jsonFilePath" convert --discard "$BL_EL_RPU_HEVC" -o "$DV8_BL_RPU_HEVC"

    if [[ $? != 0 ]] || [[ ! -f "$DV8_BL_RPU_HEVC" ]]
    then
        echo "Failed to convert BL+RPU. Quitting."
        exit 1
    fi

    echo "Deleting BL+EL+RPU HEVC..."
    if [[ $keepFiles == 0 ]]
    then
        rm "$BL_EL_RPU_HEVC"
    fi

    echo "Extracting DV8 RPU..."
    "$doviToolPath" extract-rpu "$DV8_BL_RPU_HEVC" -o "$DV8_RPU_BIN"

    echo "Plotting L1..."
    "$doviToolPath" plot "$DV8_RPU_BIN" -o "$mkvBase.DV8.L1_plot.png"

    echo "Remuxing DV8 MKV..."
    if [[ $keepAllLanguages == 0 ]] && [[ $languageCodes != "" ]]
    then
        echo "Remuxing audio and subtitle languages: '$languageCodes'..."
        "$mkvmergePath" -o "$mkvBase.DV8.mkv" -D -a $languageCodes -s $languageCodes "$mkvFile" "$DV8_BL_RPU_HEVC" --track-order 1:0
    else
        echo "Remuxing all audio and subtitle tracks..."
        "$mkvmergePath" -o "$mkvBase.DV8.mkv" -D "$mkvFile" "$DV8_BL_RPU_HEVC" --track-order 1:0
    fi

    if [[ $keepFiles == 0 ]]
    then
        echo "Cleaning up working files..."
        rm "$DV8_RPU_BIN" 
        rm "$DV8_BL_RPU_HEVC"
    fi
done

popd > /dev/null
echo "Done."
