# MemoryMapDumper
Android MemoryMap Dumper
This is a Bash-based Memory Map Dump Tool (MMB) used for analyzing memory regions of processes running on Android devices through ADB. It allows you to dump, merge, and fix shared object files (.so) from a connected device. Below is a summary of the features and instructions for usage.


# Features
1. Memory Dump Task Run
- Select a device and dump memory regions based on specific processes.
- Extract /proc/\<pid\>/mem data from a target device.

2. Merge Task Run
- Merge binary dump files from a single memory task into one file.

3. SO Fix
- Use the SoFixer64 tool to repair .so files with custom page size settings.

4.Usage Menu
- Display the main menu and options available.

# Setup Requirements
1. ADB (Android Debug Bridge): Ensure ADB is installed and accessible from the terminal.
2. SoFixer Tool: Place the SoFixer64 binary in the correct path: https://github.com/Security-Development/SoFixer

# Usage Instructions
1. Run the script
```
./your_script_name.sh
```
2. Main Menu Options
```
    MMB(Memory Map Dump)      
|-------------------------------|
| 1) Memory Dump Task Run       |
| 2) Merge Task Run             |
| 3) SO FIX                     |
| 4) usage                      |
|-------------------------------|
```

# License
This script is released under an open-source license. Modify and distribute freely.

# Contributing
Feel free to submit issues or pull requests for improvements.
