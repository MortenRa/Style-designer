# Build and publish Report Style Designer (cloud app) + Report Style Designer Tools (on-prem tests) to the local
# PlatformCore server, then run the generator checks. The generator is copied from BCApps (single source).
param([switch]$SkipChecks)
$ErrorActionPreference = 'Stop'
$R = 'C:\depot\report-style-designer'
$B = 'C:\depot\BCApps\src\Layers\W1\BaseApp\Foundation\Reporting'
$alc = 'C:\Users\v-mortenr\.vscode\extensions\ms-dynamics-smb.al-18.0.2653898\bin\alc.exe'
$dev = 'http://localhost:7049/Navision_PlatformCore/dev/apps?SchemaUpdateMode=forcesync'

(Get-Content "$B\ReportThemeGenerator.Codeunit.al" -Raw) -replace '(?m)^codeunit 9667 ', 'codeunit 50100 ' -replace 'namespace Microsoft\.Foundation\.Reporting;', 'namespace Abakion.ReportStyleDesigner;' | Set-Content "$R\app\src\ReportThemeGenerator.Codeunit.al" -NoNewline
(Get-Content "$B\ReportThemeColorSlot.Enum.al" -Raw) -replace '(?m)^enum 9667 ', 'enum 50100 ' -replace 'namespace Microsoft\.Foundation\.Reporting;', 'namespace Abakion.ReportStyleDesigner;' | Set-Content "$R\app\src\ReportThemeColorSlot.Enum.al" -NoNewline
(Get-Content "$B\ReportThemeTableStyle.Enum.al" -Raw) -replace '(?m)^enum 9668 ', 'enum 50108 ' -replace 'namespace Microsoft\.Foundation\.Reporting;', 'namespace Abakion.ReportStyleDesigner;' | Set-Content "$R\app\src\ReportThemeTableStyle.Enum.al" -NoNewline

function Build($project, $out) {
    & $alc "/project:$project" "/packagecachepath:$project\.alpackages" "/out:$out" | Select-String -Pattern 'error|warning' | ForEach-Object { $_.Line }
    if ($LASTEXITCODE -ne 0) { throw "compile failed: $project" }
}
function Publish($file) {
    $null = Invoke-WebRequest -Uri $dev -Method Post -UseDefaultCredentials -AllowUnencryptedAuthentication -Form @{ file = Get-Item $file } -TimeoutSec 300
}

New-Item -ItemType Directory "$R\out" -Force | Out-Null
Build "$R\app" "$R\out\ReportStyleDesigner.app"
Copy-Item "$R\out\ReportStyleDesigner.app" "$R\tools\.alpackages\" -Force
Build "$R\tools" "$R\out\ReportStyleDesignerTools.app"
Publish "$R\out\ReportStyleDesigner.app"
Publish "$R\out\ReportStyleDesignerTools.app"
'published'

if (-not $SkipChecks) {
    Import-Module 'C:\depot\Platform-Core\out\platform\libMgmt\Debug\Microsoft.Dynamics.Nav.Management.psm1' -WarningAction SilentlyContinue
    try { Invoke-NAVCodeunit -ServerInstance PlatformCore -CompanyName 'CRONUS International Ltd.' -CodeunitId 50101 -ErrorAction Stop } catch { 'ERR: ' + ($_.Exception.Message -split "`n")[0] }
}
