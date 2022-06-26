# sidplay5
Sidplay for macOS

Since it seems that Sidplay 4.2 (http://www.sidmusic.org/sidplay/mac/) is no longer developed I decided to update the source and provide binaries for Intel and Apple Silicon. 

# implemented changes
* 64 Bit binary, runs on macOS 10.9 or higher
* supports Intel and Apple Silicon
* auto-update feature disabled (for now)
* code compiles now on latest Xcode

# still need to fix
* Xcode still complains about missing UI constraints and OpenGL
* starting with macOS 11, the toolbar height is smaller and the track info is cut off, stepping through subtunes is now a little bit tricky
