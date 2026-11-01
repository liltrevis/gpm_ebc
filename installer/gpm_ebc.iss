; ---------------------------------------------------------------------------
; Script d'installation Windows pour GPM-2EBC (Inno Setup 6+)
; Compilation : "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\gpm_ebc.iss
; Produit : dist\gpm_ebc_setup.exe
; ---------------------------------------------------------------------------

#define AppName "GPM-2EBC"
#define AppVersion "1.0.0"
#define AppPublisher "2e Escadron Blinde de Combat"
#define AppExeName "gpm_ebc.exe"
#define SourceDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{8F3C1D2A-5B7E-4C9A-9E21-7A6B4C5D8E01}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Installation sans droits administrateur (dans {localappdata}\Programs)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=gpm_ebc_setup
SetupIconFile=app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
VersionInfoVersion=1.0.0.0
DisableWelcomePage=no
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "app_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\app_icon.ico"
Name: "{group}\Desinstaller {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\app_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
