; Windows 安装包（Inno Setup 6）。
; 版本号从环境变量 APP_VERSION 读（CI 里就是 tag 名）；路径是相对本文件的默认值，
; 本地 `flutter build windows` 之后直接 ISCC 这个文件也能出包。

#define MyAppName "Tencent Cloud Chat"
#define MyAppPublisher "Tencent Cloud"
#define MyAppExeName "im_flutter_uikit_full_platform.exe"
#define MyAppVersion GetEnv("APP_VERSION")

#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\.."
#endif

[Setup]
; 换 AppId 会让老版本认不出这是同一款应用，升级时并存两份。
AppId={{8F4B2A6D-9C1E-4B7A-8E5F-3D0A7C6B1942}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallFilesDir={app}
OutputDir={#OutputDir}
OutputBaseFilename=chat-timflutter-windows-x64-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; 不设这条，{autopf} 在 64 位系统上落到 Program Files (x86)。
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
SetupIconFile=..\..\windows\runner\resources\app_icon.ico

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
