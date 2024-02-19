# DV7 to DV8

Dolby Vision profile 7 to Dolby Vision profile 8.1 conversion utility for macOS

# Installation

- Download the latest [release](https://github.com/nekno/DV7toDV8/releases)
- Extract the `.zip` file
- Drag & drop the `DV7 to DV8` app to your `Applications` folder
- The included `mkvtoolnix` utilities aren't available in Universal binaries, so that means if you're using an Apple silicon Mac, you'll need to install [Rosetta 2](https://en.wikipedia.org/wiki/Rosetta_(software)#Rosetta_2) directly from Apple:
  - Launch the **Terminal** app
  - Type `softwareupdate --install-rosetta` and hit `return`
  - Accept the license agreement
- The app has not been digitally signed by an Apple Developer ID, so you will need to approve the app for the first run
  - Do one of the following:
    - Right-click on the app icon with your mouse and select **Open**
    - Ctrl-click on the app icon with your mouse and select **Open**
    - Two-finger tap on the app icon with your trackpad and select **Open**
  - Approve the security prompt to allow the app to run

# App Usage

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
  - Remux the DV8 BL+RPU HEVC stream into a new MKV file with the non-video tracks from the original MKV file
  - Delete the DV8 BL+RPU HEVC and RPU working files

# Script Usage

If you prefer to use a plaintext Bash script over an app, you can also run `DV7toDV8.sh` directly.

The upside is that you can see and read exactly what you're running; the downside is that macOS doesn't want you to run downloaded tools, so you'll have to approve each utility in the System Settings app.

- Download and extract the repo
- Run `DV7toDV8.sh` in Terminal, passing one argument for the folder location of the MKV files you want to convert
- On first run of each utility, you'll need to approve the app to run and then re-run the script
- The bundled tools are unmodified versions of those publicly available, so if you're uncomfortable running the utilities downloaded in the `tools` folder, you can download and use your own copies of `dovi_tool` and `mkvtoolnix` (both can be installed via Homebrew); you'll just need to update the paths to the tools appropriately in the script
- To approve the tools to run, you can run each tool in the `tools` folder in Terminal, or just run the script repeatedly (passing a folder containing MKV files as an argument)
  - Run the script once
  - Open the **System Settings** app
  - In the sidebar, select **Privacy & Security**
  - Scroll down to the **Security** section
  - Approve the `mkvextract` utility to run
  - Run the script a second time
  - Approve the `dovi_tool` utility to run
  - Run the script a third time
  - Approve the `mkvmerge` utility to run
- All utilities should now be approved and the script can be run normally

# Building

This project leverages [Platypus](https://sveinbjorn.org/platypus) to create a macOS app bundle from a simple Bash script.

- Clone the **DV7toDV8** repo in the `~/Documents/Xcode/DV7toDV8` folder
- Install Platypus 5.4.1 or greater via [download](https://sveinbjorn.org/files/software/platypus.zip) or Homebrew
  ```bash
  $ brew install --cask platypus 
  ```
- In macOS Ventura 13 or greater (substitute similar steps for macOS <13):
  - Open the **System Settings** app
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
