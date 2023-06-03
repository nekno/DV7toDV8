# DV7 to DV8

Dolby Vision profile 7 to Dolby Vision profile 8.1 conversion utility for macOS

# Installation

- Download the latest [release](/nekno/DV7toDV8/releases)
- Extract the `.zip` file
- Drag & drop the `DV7 to DV8` app to your `Applications` folder
- The app has not been digitally signed by an Apple Developer ID, so you will need to approve the app for the first run
  - Do one of the following:
    - Right-click on the app icon with your mouse and select **Open**
    - Ctrl-click on the app icon with your mouse and select **Open**
    - Two-finger tap on the app icon with your trackpad and select **Open**
  - Approve the security prompt to allow the app to run

# Usage

- When you launch the app, you'll be prompted to select a folder
- Select a folder that contains Dolby Vision profile 7 `.mkv` files you want to convert to Dolby Vision profile 8.1
- To open folders in the future, do one of the following:
  - Double-click on the app icon to launch the app, then select a folder in the Open Folder window
  - Drag & drop a folder onto the app icon in the Finder or Dock
  - When the app is already running, drag & drop a folder onto the main window 
  - When the app is already running, use the **File** menu > **Open** option and select a folder
- The app will process each `.mkv` file in the folder, performing the following:
  - Demux the DV7 BL+EL+RPU HEVC video stream from the MKV container
  - Demux the DV7 EL+RPU enhancement layer from the HEVC stream for your archival purposes (delete this file if you don't care to be able to reconstruct the DV7 BL+EL+RPU in the future)
  - Convert the DV7 BL+EL+RPU to DV8 BL+RPU, removing tone mappings specific to profile 7 and any CM v4.0 mappings (leaving CM v2.9)
  - Delete the DV7 BL+EL+RPU HEVC file to conserve disk space
  - Extract the DV8 RPU from the DV8 BL+RPU HEVC stream
  - Plot a graph of the L1 metadata and render it into a PNG
  - Remux the DV8 BL+RPU HEVC stream into a new MKV file, muxing English audio and subtitle tracks from the original MKV file
  - Delete the DV8 BL+RPU HEVC and RPU working files

# Building

This project leverages Platypus to create a macOS app bundle from a simple Bash script.

- Clone the **DV7toDV8** repo in the `~/Documents/Xcode/DV7toDV8` folder
- Install Platypus 5.4.1 or greater
- In macOS Ventura 13 (substitute similar steps for macOS <13):
  - Open the **Settings** app
  - In the sidebar, select **Privacy & Security**
  - In the main window, select **Full Disk Access**
  - Click the **+** sign in the lower left
  - Select the **Platypus** app from the `Applications` folder and click **Open**
- Launch **Platypus**
  - Select **Profiles** menu > **Load Profile...**
  - Open the `~/Documents/Xcode/DV7toDV8/src/DV7 to DV8.platypus` file
  - If the location where you've stored the files on disk doesn't match `~/Documents/Xcode/DV7toDV8/src/`, set the following locations:
    - **Script Path**: `DV7toDV8.sh`
    - **Bundled Files**:
      - `tools` folder
      - `config` folder
