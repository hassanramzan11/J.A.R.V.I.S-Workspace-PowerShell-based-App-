; =====================================================================
;   J.A.R.V.I.S  WORKSPACE  -  Inno Setup Installer
;   Compile with:  iscc setup.iss
; =====================================================================

#define MyAppName       "J.A.R.V.I.S Workspace"
#define MyAppVersion    "1.0.0"
#define MyAppPublisher  "Hassan Ahmed"
#define MyAppExeName    "Launch-Jarvis.vbs"

[Setup]
AppId={{B8E5F1A2-7C4D-4E9A-9B3F-2D6F4A1E8C77}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\JarvisWorkspace
DefaultGroupName=J.A.R.V.I.S Workspace
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=JarvisWorkspace-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=assets\jarvis.ico
UninstallDisplayIcon={app}\jarvis.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
; Main app files
Source: "..\Jarvis_Builder.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "launcher.vbs";          DestDir: "{app}"; DestName: "Launch-Jarvis.vbs"; Flags: ignoreversion
Source: "assets\jarvis.ico";     DestDir: "{app}"; Flags: ignoreversion

; VirtualDesktop.exe - exactly one will be installed based on Windows build.
; The file is renamed to "VirtualDesktop.exe" at the path the script expects.
Source: "vendor\VirtualDesktop11-24H2.exe"; DestDir: "{localappdata}\JarvisTools"; DestName: "VirtualDesktop.exe"; Flags: ignoreversion skipifsourcedoesntexist; Check: IsBuild24H2OrNewer
Source: "vendor\VirtualDesktop11-23H2.exe"; DestDir: "{localappdata}\JarvisTools"; DestName: "VirtualDesktop.exe"; Flags: ignoreversion skipifsourcedoesntexist; Check: IsBuild23H2
Source: "vendor\VirtualDesktop11-22H2.exe"; DestDir: "{localappdata}\JarvisTools"; DestName: "VirtualDesktop.exe"; Flags: ignoreversion skipifsourcedoesntexist; Check: IsBuild22H2
Source: "vendor\VirtualDesktop11.exe";      DestDir: "{localappdata}\JarvisTools"; DestName: "VirtualDesktop.exe"; Flags: ignoreversion skipifsourcedoesntexist; Check: IsBuild21H2
Source: "vendor\VirtualDesktop.exe";        DestDir: "{localappdata}\JarvisTools"; DestName: "VirtualDesktop.exe"; Flags: ignoreversion skipifsourcedoesntexist; Check: IsWin10

[Icons]
Name: "{group}\J.A.R.V.I.S Workspace";    Filename: "{app}\Launch-Jarvis.vbs"; WorkingDir: "{app}"; IconFilename: "{app}\jarvis.ico"
Name: "{group}\Open Profiles Folder";     Filename: "{userappdata}\JarvisWorkspace\profiles"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\J.A.R.V.I.S Workspace"; Filename: "{app}\Launch-Jarvis.vbs"; WorkingDir: "{app}"; IconFilename: "{app}\jarvis.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\Launch-Jarvis.vbs"; Description: "Launch J.A.R.V.I.S Workspace now"; Flags: postinstall nowait shellexec skipifsilent

[UninstallDelete]
; Remove the VirtualDesktop binary we placed (the JarvisTools folder is ours).
Type: filesandordirs; Name: "{localappdata}\JarvisTools"
; Profiles in {userappdata}\JarvisWorkspace are user data - leave them by default.
; Uncomment the next line if you want to nuke profiles too.
; Type: filesandordirs; Name: "{userappdata}\JarvisWorkspace"

[Code]
function GetBuildNumber(): Integer;
var
  V: TWindowsVersion;
begin
  GetWindowsVersionEx(V);
  Result := V.Build;
end;

function IsBuild24H2OrNewer(): Boolean;
begin
  Result := GetBuildNumber() >= 26100;
end;

function IsBuild23H2(): Boolean;
var
  B: Integer;
begin
  B := GetBuildNumber();
  Result := (B >= 22631) and (B < 26100);
end;

function IsBuild22H2(): Boolean;
var
  B: Integer;
begin
  B := GetBuildNumber();
  Result := (B >= 22621) and (B < 22631);
end;

function IsBuild21H2(): Boolean;
var
  B: Integer;
begin
  B := GetBuildNumber();
  Result := (B >= 22000) and (B < 22621);
end;

function IsWin10(): Boolean;
begin
  Result := GetBuildNumber() < 22000;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;
