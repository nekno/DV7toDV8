#!/bin/bash
# Mac specific
# Only needed when relying on a local install of mkvtoolnix
# which mkvmerge >/dev/null
# if [[ $? == 1 ]]
# then
#     echo "Run 'brew install mkvtoolnix' to install mkvmerge"
#     exit 1
# fi
# which mkvextract >/dev/null
# if [[ $? == 1 ]]
# then
#     echo "Run 'brew install mkvtoolnix' to install mkvextract"
#     exit 1
# fi

# Keep working files generated during processing
keepFiles=false
targetDir=$PWD # Default to current directory
languageCodes=""
languageCodeSet=false
doviToolPath=""
mkvextractPath=""
mkvmergePath=""
useLocal=false


# Help function
function print_help {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "-k|--keep-files       Keep working files"
    echo "-t|--target PATH      Specify the target directory (default: current directory)"
    echo "-l LANG               Specify the language codes (comma-separated) for audio and subtitle tracks. If not specified, default to all tracks."
    echo "-u|--use-local        Use local system binaries if available"
    echo "-h|--help             Display this help message"
    echo ""
    exit 1
}

while (( "$#" )); do
  case "$1" in
  -k|--keep-files)
    echo "Option enabled to keep working files"
    keepFiles=true
    shift;;
  -h|--help)
    print_help;;
  -t|--target)
    targetDir=$2
    echo "Target directory set to '$targetDir'"
    shift 2;;
  -l)
    languageCodes=$2
    echo "Language codes set to '$languageCodes'"
    languageCodeSet=true
    shift 2;;
  -u|--use-local)
    useLocal=true
    echo "Option enabled to use local binaries"
    shift;;
  -*|--*=) # unsupported flags
    echo "Error: Unsupported flag $1" >&2
    exit 1;;
  *) # preserve positional arguments
    PARAMS="$PARAMS $1"
    shift;;
  esac
done

if [[ ! -d $targetDir ]]
then
    echo "Directory not found: '$targetDir'"
    exit 1
fi

echo "Processing directory: '$targetDir'"

# Get the script's directory path; do this before pushing the targetDir
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

pushd "$targetDir" > /dev/null

# Get the subdirectory paths
toolsPath=$scriptDir/tools
configPath=$scriptDir/config

# Reference the dovi_tool, mkvextract, and mkvmerge executables and the JSON file in their respective subdirectories
languageCodesPath=$toolsPath/language_codes.applescript
# If the --use-local flag is set, use the executables on the user's system; otherwise, use the executables in the tools directory
if [[ $useLocal == true ]]
then
    doviToolPath=dov_tool
    mkvextractPath=mkvextract
    mkvmergePath=mkvmerge
else
    doviToolPath=$toolsPath/dovi_tool
    mkvextractPath=$toolsPath/mkvextract
    mkvmergePath=$toolsPath/mkvmerge
fi
jsonFilePath=$configPath/DV7toDV8.json
# If we're running on a mac and the language code(s) are not provided, get them from the user
if [[ $(uname) == "Darwin" ]] && [[ $languageCodeSet == false ]]
then
    echo "Getting language codes..."
    languageCodes=$(osascript "$languageCodesPath")
fi
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
    if [[ $keepFiles == false ]]
    then
        rm "$BL_EL_RPU_HEVC"
    fi

    echo "Extracting DV8 RPU..."
    "$doviToolPath" extract-rpu "$DV8_BL_RPU_HEVC" -o "$DV8_RPU_BIN"

    echo "Plotting L1..."
    "$doviToolPath" plot "$DV8_RPU_BIN" -o "$mkvBase.DV8.L1_plot.png"

    echo "Remuxing DV8 MKV..."
    if [[ $languageCodes != "" ]]
    then
        echo "Remuxing audio and subtitle languages: $languageCodes"
        "$mkvmergePath" -o "$mkvBase.DV8.mkv" -D -a $languageCodes -s $languageCodes "$mkvFile" "$DV8_BL_RPU_HEVC" --track-order 1:0
    else
        echo "Remuxing all audio and subtitle tracks..."
        "$mkvmergePath" -o "$mkvBase.DV8.mkv" -D "$mkvFile" "$DV8_BL_RPU_HEVC" --track-order 1:0
    fi

    if [[ $keepFiles == false ]]
    then
        echo "Cleaning up working files..."
        rm "$DV8_RPU_BIN" 
        rm "$DV8_BL_RPU_HEVC"
    fi
done

popd > /dev/null
echo "Done."
