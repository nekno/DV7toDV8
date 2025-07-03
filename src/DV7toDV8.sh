#!/bin/bash

# Settings -- these need to use 0/1 for Boolean values for compatibility with the macOS defaults system
dontAskAgain=0
keepAllLanguages=1
keepFiles=0
languageCodes=""
removeCMv4=0
useSystemTools=0
scanMode=0

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
    echo "  -S|--scan              Scan directory for DV7 files and optionally convert them"
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

# Simple scan function with table output
scanDirectory() {
    echo "Scanning for DV files in: $targetDir"
    echo ""
    
    which mediainfo >/dev/null 2>&1 || { echo "Error: mediainfo is required. Install with: brew install mediainfo"; exit 1; }
    
    local dv7Count=0
    local -a dv7Files=()
    local processedDV8s=""
    
    # Table header
    printf "%-65s %-6s %-10s %-10s\n" "Filename" "Type" "Size" "Status"
    printf "%s\n" "$(printf '%.0s-' {1..91})"
    
    # Find all MKV files
    while IFS= read -r -d '' mkvFile; do
        local mkvBase=$(basename "$mkvFile")
        local fileSize=$(ls -lh "$mkvFile" | awk '{print $5}')
        
        # Skip .DV8.mkv files for now (we'll handle them as children)
        [[ "$mkvFile" == *.DV8.mkv ]] && continue
        
        # Get DV profile
        local dvProfile=$(mediainfo --Inform="Video;%HDR_Format_Profile%" "$mkvFile" 2>/dev/null)
        [[ -z "$dvProfile" || "$dvProfile" != *"dv"* ]] && continue
        
        # Determine type
        local dvType="DV?"
        [[ "$dvProfile" == *"dvhe.07"* || "$dvProfile" == *"07"* ]] && dvType="DV7"
        [[ "$dvProfile" == *"dvhe.08"* || "$dvProfile" == *"08"* ]] && dvType="DV8"
        
        # Check conversion status and print parent
        if [[ "$dvType" == "DV7" ]]; then
            if [[ -f "${mkvFile%.mkv}.DV8.mkv" ]]; then
                # DV7 with converted DV8
                printf "%-65s %-6s %-10s %-10s\n" "${mkvBase:0:63}" "$dvType" "$fileSize" "✓"
                # Show the DV8 child
                local dv8File="${mkvFile%.mkv}.DV8.mkv"
                local dv8Base=$(basename "$dv8File")
                local dv8Size=$(ls -lh "$dv8File" | awk '{print $5}')
                printf "  └─ %-56s %-6s %-10s %-10s\n" "${dv8Base:0:60}" "DV8" "$dv8Size" "✓"
                processedDV8s="$processedDV8s|$dv8File|"
            else
                # DV7 without conversion
                ((dv7Count++))
                dv7Files+=("$mkvFile")
                printf "%-65s %-6s %-10s %-10s\n" "${mkvBase:0:63}" "$dvType" "$fileSize" "○"
            fi
        else
            # Original DV8
            printf "%-65s %-6s %-10s %-10s\n" "${mkvBase:0:63}" "$dvType" "$fileSize" "✓"
        fi
    done < <(find "$targetDir" -name "*.mkv" -type f -print0 2>/dev/null | sort -z 2>/dev/null || true)
    
    # Now handle any orphaned DV8 files (DV8s without corresponding DV7s)
    while IFS= read -r -d '' mkvFile; do
        [[ "$mkvFile" != *.DV8.mkv ]] && continue
        [[ "$processedDV8s" == *"|$mkvFile|"* ]] && continue
        
        local mkvBase=$(basename "$mkvFile")
        local fileSize=$(ls -lh "$mkvFile" | awk '{print $5}')
        printf "%-65s %-6s %-10s %-10s\n" "${mkvBase:0:63}" "DV8" "$fileSize" "Orphaned"
    done < <(find "$targetDir" -name "*.mkv" -type f -print0 2>/dev/null | sort -z 2>/dev/null || true)
    
    printf "%s\n" "$(printf '%.0s-' {1..91})"
    echo ""
    if [[ $dv7Count -eq 0 ]]; then
        echo "No DV7 files need conversion."
        exit 0
    fi
    
    echo "Found $dv7Count DV7 files that need conversion."
    echo -n "Convert them now? [y/N] "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    
    # User said yes - let the main loop handle it
    echo ""
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
    -S|--scan)
        scanMode=1
        dontAskAgain=1
        echo "Option enabled to scan for DV7 files..."
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

# If scan mode is enabled, scan first
if [[ $scanMode == 1 ]]
then
    scanDirectory
    # If we get here, user said yes to convert
fi

echo "Processing directory: '$targetDir'..."

pushd "$targetDir" > /dev/null

for mkvFile in *.mkv
do
    # Skip .DV8.mkv files
    [[ "$mkvFile" == *.DV8.mkv ]] && continue
    
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
