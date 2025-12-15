; Simple Eiffel Package Manager Installer
; Inno Setup Script

#define MyAppName "Simple Eiffel Package Manager"
#define MyAppShortName "simple"
#define MyAppVersion "1.0.3"
#define MyAppPublisher "Simple Eiffel"
#define MyAppURL "https://github.com/simple-eiffel"
#define MyAppExeName "simple.exe"

[Setup]
AppId={{8E4D2B3A-F5C1-4D7E-9B2A-3C6E8F1D4A5B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\SimpleEiffel\simple
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=LICENSE
OutputDir=installer
OutputBaseFilename=simple-setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
ChangesEnvironment=yes
PrivilegesRequired=admin
WizardImageFile=..\reference_docs\artwork\logo-tall-164x314.png
WizardSmallImageFile=..\reference_docs\artwork\logo-small-55x58.png

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "addtopath"; Description: "Add to PATH environment variable"; GroupDescription: "Additional options:"; Flags: checkedonce

[Files]
; Main executable (renamed from simple_pkg.exe to simple.exe) - Using finalized build
Source: "EIFGENs\simple_pkg_exe\F_code\simple_pkg.exe"; DestDir: "{app}"; DestName: "simple.exe"; Flags: ignoreversion

[Icons]
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

[Registry]
; Add to PATH
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; \
    Tasks: addtopath; Check: NeedsAddPath('{app}')

[Run]
Filename: "{cmd}"; Parameters: "/c echo Simple Eiffel Package Manager installed! && echo Run 'simple --help' for usage."; \
    Description: "Show installation complete message"; Flags: postinstall shellexec runhidden

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c echo Simple uninstalled. Run 'refreshenv' or restart your terminal."; \
    Flags: runhidden

[Code]
function NeedsAddPath(Param: string): Boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', OrigPath) then
  begin
    Result := True;
    Exit;
  end;
  { Look for the path with leading and trailing semicolons }
  Result := Pos(';' + Uppercase(Param) + ';', ';' + Uppercase(OrigPath) + ';') = 0;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  OrigPath, NewPath: string;
  P: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    { Remove from PATH }
    if RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', OrigPath) then
    begin
      P := Pos(';' + ExpandConstant('{app}'), OrigPath);
      if P > 0 then
      begin
        NewPath := Copy(OrigPath, 1, P - 1) + Copy(OrigPath, P + Length(';' + ExpandConstant('{app}')), MaxInt);
        RegWriteStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 'Path', NewPath);
      end;
    end;
  end;
end;
