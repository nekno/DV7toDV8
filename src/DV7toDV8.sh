#!/bin/bash

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

targetDir=$1

if [[ $# == 0 ]]
then
    echo "Please provide a directory: "
    read targetDir
fi

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
doviToolPath=$toolsPath/dovi_tool
mkvextractPath=$toolsPath/mkvextract
mkvmergePath=$toolsPath/mkvmerge
jsonFilePath=$configPath/DV7toDV8.json

languageCodes=$(osascript "$languageCodesPath")

for mkvFile in "$targetDir"/*.mkv
do
    mkvBase=$(basename "$mkvFile" .mkv)

	echo "Demuxing DV7 BL+EL+RPU HEVC from MKV..."
    "$mkvextractPath" "$mkvFile" tracks 0:"$mkvBase.DV7.BL_EL_RPU.hevc"

    if [[ $? != 0 ]] || [[ ! -f "$mkvBase.DV7.BL_EL_RPU.hevc" ]]
    then
        echo "Failed to extract HEVC track from MKV. Quitting."
        exit 1
    fi
	
	echo "Demuxing DV7 EL+RPU HEVC..."
	"$doviToolPath" demux --el-only "$mkvBase.DV7.BL_EL_RPU.hevc" -e "$mkvBase.DV7.EL_RPU.hevc"

    if [[ $? != 0 ]] || [[ ! -f "$mkvBase.DV7.EL_RPU.hevc" ]]
    then
        echo "Failed to demux EL+RPU HEVC file. Quitting."
        exit 1
    fi
	
	echo "Converting DV7 BL+EL+RPU to DV8 BL+RPU..."
    "$doviToolPath" --edit-config "$jsonFilePath" convert --discard "$mkvBase.DV7.BL_EL_RPU.hevc" -o "$mkvBase.DV8.BL_RPU.hevc"

    if [[ $? != 0 ]] || [[ ! -f "$mkvBase.DV8.BL_RPU.hevc" ]]
    then
        echo "File to convert BL+RPU. Quitting."
        exit 1
    fi
	
	echo "Deleting DV7 BL+EL+RPU HEVC..."
	rm "$mkvBase.DV7.BL_EL_RPU.hevc"
	
	echo "Extracting DV8 RPU..."
    "$doviToolPath" extract-rpu "$mkvBase.DV8.BL_RPU.hevc" -o "$mkvBase.DV8.RPU.bin"
	
	echo "Plotting L1..."
    "$doviToolPath" plot "$mkvBase.DV8.RPU.bin" -o "$mkvBase.DV8.L1_plot.png"
	
	echo "Remuxing DV8 MKV..."
    if [[ $languageCodes != "" ]]
    then
        echo "Remuxing audio and subtitle languages: $languageCodes"
        "$mkvmergePath" -o "$mkvBase.DV8.mkv" -D -a $languageCodes -s $languageCodes "$mkvFile" "$mkvBase.DV8.BL_RPU.hevc" --track-order 1:0
    else
        "$mkvmergePath" -o "$mkvBase.DV8.mkv" -D "$mkvFile" "$mkvBase.DV8.BL_RPU.hevc" --track-order 1:0
    fi
	
	echo "Cleaning up..."
    rm "$mkvBase.DV8.RPU.bin"
    rm "$mkvBase.DV8.BL_RPU.hevc"
done

popd > /dev/null
echo "Done."
