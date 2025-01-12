//
//  ContentView.swift
//  DV7toDV8
//
//  Created by nekno on 1/10/25.
//

import SwiftUI

enum Settings: String {
    case dontAskAgain
    case keepAllLanguages
    case keepFiles
    case languageCodes
    case removeCMv4
    case useSystemTools
}

struct ContentView: View {
    @AppStorage(Settings.dontAskAgain.rawValue)
    private var dontAskAgain = false
    
    @AppStorage(Settings.keepAllLanguages.rawValue)
    private var keepAllLanguages = true
    
    @AppStorage(Settings.keepFiles.rawValue)
    private var keepFiles = false
    
    @AppStorage(Settings.languageCodes.rawValue)
    private var languageCodes = Locale.current.language.minimalIdentifier
    
    @AppStorage(Settings.removeCMv4.rawValue)
    private var removeCMv4 = false
    
    @AppStorage(Settings.useSystemTools.rawValue)
    private var useSystemTools = false
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        TabView {
            GroupBox {
                VStack(alignment: .leading) {
                    Toggle("Keep all languages", isOn: $keepAllLanguages)
                        .onChange(of: keepAllLanguages) { _ in
                            // Ensure a value is saved when the textfield is unedited
                            UserDefaults.standard.set(languageCodes, forKey: Settings.languageCodes.rawValue)
                        }
                    
                    LabeledContent {
                        TextField(
                            "Language codes",
                            text: $languageCodes,
                            prompt: Text(Locale.current.language.minimalIdentifier)
                        )
                        .textFieldStyle(.roundedBorder)
                        .disabled(keepAllLanguages)
                        
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                            Text("Language codes:")
                                .offset(x: -4)
                        }
                    }
                    
                    Text(
                    """
                    **Checked:** Keep all audio and subtitle languages from the original MKV file.
                    
                    **Unchecked**: Enter the languages you want included in the output MKV file and the rest will be omitted. Provide a comma-separated list of ISO 639-1 codes (`en,es,de`) or ISO 639-2 codes (`eng,spa,ger`).
                    
                    Click the **Help** button for a list of language codes.
                    """
                    )
                    .padding()
                    
                    HStack {
                        Spacer()
                        
                        Button("Help") {
                            openURL(
                                URL(string: "https://www.loc.gov/standards/iso639-2/php/English_list.php")!
                            )
                        }
                        .buttonStyle(.link)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
            } label: {
                Text("Audio & Subtitles")
                    .font(.title)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .tabItem {
                Text("Audio & Subtitles")
            }
            
            GroupBox {
                VStack(alignment: .leading) {
                    Toggle("Remove DV CMv4.0 metadata", isOn: $removeCMv4)
                    
                    Text(
                    """
                    **Checked**: Remove the Dolby Vision Content Mapping v4.0 (CMv4.0) dynamic metadata from the output video. This option is compatible with the Apple TV 4K (2021) and leaves the CMv2.9 metadata intact.
                    
                    **Unchecked**: Leave the CMv4.0 metadata intact (if present) in the output video. This option is compatible with the Apple TV 4K (2023).
                    """
                    )
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
            } label: {
                Text("Content Mapping")
                    .font(.title)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .tabItem {
                Text("Content Mapping")
            }

            GroupBox {
                VStack(alignment: .leading) {
                    Toggle("Keep working files", isOn: $keepFiles)
                    
                    Text(
                    """
                    **Checked**: Keep all intermediate working files demuxed from the input MKV file or generated during processing.
                    
                    **Unchecked**: Keep only files that are useful for archiving or analyzing the result of processing, including the Enhancement Layer (EL+RPU) from the DV7 input file, the DV8 RPU file after conversion, and a graph of the metadata plotted over the duration of the video.
                    """
                    )
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
            } label: {
                Text("Working Files")
                    .font(.title)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .tabItem {
                Text("Working Files")
            }
            
            GroupBox {
                VStack(alignment: .leading) {
                    Toggle("Use system tools", isOn: $useSystemTools)
                    
                    Text(
                    """
                    **Checked**: Use the `dovi_tool` and `mkvtoolnix` binaries installed on the local system.
                    
                    **Unchecked**: Use the binaries bundled with the app.
                    """
                    )
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding()
            } label: {
                Text("Tools")
                    .font(.title)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .tabItem {
                Text("Tools")
            }
        }
        
        Grid {
            GridRow {
                Color.clear
                    .frame(height: 0)
                    .frame(maxWidth: .infinity)
                
                Button {
                    exit(EXIT_SUCCESS)
                } label: {
                    Text("Go")
                        .frame(width: 88)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Toggle("Donʼt ask again", isOn: $dontAskAgain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
