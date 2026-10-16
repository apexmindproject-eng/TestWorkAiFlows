; Fly in a Box for Windows: one setup file. Built by .github/workflows/pc.yml:
;   iscc /DSrc=<the assembled folder> /DOut=<output folder> installer.iss
; Installs for the current user (no administrator rights), into %LOCALAPPDATA%\Programs\Fly in a Box.

#ifndef Src
  #define Src "..\..\dist\FlyInABox"
#endif
#ifndef Out
  #define Out "..\..\dist"
#endif

[Setup]
AppName=Fly in a Box
AppVersion=1.0
AppPublisher=Fly in a Box
DefaultDirName={localappdata}\Programs\Fly in a Box
DefaultGroupName=Fly in a Box
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#Out}
OutputBaseFilename=FlyInABox-Setup
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMADictionarySize=262144
LZMANumBlockThreads=2
WizardStyle=modern
UninstallDisplayName=Fly in a Box

[Tasks]
Name: "desktopicon"; Description: "Put Fly in a Box on the desktop"; GroupDescription: "Shortcuts:"

[Files]
Source: "{#Src}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Fly in a Box"; Filename: "{app}\python\pythonw.exe"; Parameters: """{app}\launcher.pyw"""; WorkingDir: "{app}"; Comment: "A FlyWire brain in a NeuroMechFly body, live"
Name: "{autoprograms}\Fly in a Box (full physics)"; Filename: "{app}\python\pythonw.exe"; Parameters: """{app}\launcher.pyw"" --full"; WorkingDir: "{app}"; Comment: "Every physics step at 0.1 ms, as in the videos (slower)"
Name: "{autodesktop}\Fly in a Box"; Filename: "{app}\python\pythonw.exe"; Parameters: """{app}\launcher.pyw"""; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\python\pythonw.exe"; Parameters: """{app}\launcher.pyw"""; WorkingDir: "{app}"; Description: "Start Fly in a Box now"; Flags: postinstall nowait skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\app\out"
Type: filesandordirs; Name: "{app}\app\__pycache__"
