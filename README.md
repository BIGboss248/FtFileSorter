# FtFileSorter

Desktop app and companion command-line tool for indexing document folders,
extracting the 18-character document code, copying duplicates by code, and
moving unwanted file types into a `trash` folder.

## Building for Windows

Build the GUI together with the CLI so both ship side by side:

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
```

This produces:

```text
build\windows\x64\runner\Release\
├─ ft_file_sorter.exe   <- desktop app
├─ index_folder.exe     <- command-line tool (self-contained)
├─ flutter_windows.dll
└─ data\
```

To also build the installer:

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -Installer -Version 1.2.3
```

The installer places both executables in the same folder and optionally adds
that folder to the user `PATH`.

### Why bundle them

The app and the CLI share one configuration file,
`%APPDATA%\FtFileSorter\allowed_types.json`, which stores the
document-type → allowed-extension rules. Both resolve that path the same way
regardless of the working directory, so the rules edited in the app's **File
Type Rules** dialog are exactly the ones the CLI applies. Shipping them together
keeps the two in sync.

See [tool/README.md](tool/README.md) for the full CLI reference.
