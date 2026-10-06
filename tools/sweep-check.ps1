# Verifies the PDFs written by codeunit 50110 "Studio Option Sweep":
#   - every render succeeded
#   - the chosen body font is embedded, and nothing fell back to Times New Roman
#   - for page-colour cases, the page corner has the chosen colour
param(
    [string]$Folder = 'C:\ProgramData\Microsoft\Microsoft Dynamics NAV\300\Server\MicrosoftDynamicsNavServer$PlatformCore\users\default\00000000-0000-0000-0000-000000000001\TEMP\sweep'
)
Add-Type -Path 'C:\depot\Platform-Core\out\platform\server\debug\Aspose.PDF.dll'
Add-Type -AssemblyName System.Drawing

$rows = Import-Csv -Path (Join-Path $Folder 'manifest.txt') -Delimiter '|'
$results = foreach ($r in $rows) {
    $problems = @()
    $warnings = @()
    $fonts = ''
    if ($r.result -ne 'OK') {
        $problems += "render failed: $($r.error)"
    } else {
        $pdfPath = Join-Path $Folder ('{0:000}.pdf' -f [int]$r.case)
        $doc = [Aspose.Pdf.Document]::new($pdfPath)
        $names = @($doc.FontUtilities.GetAllFonts() | ForEach-Object { $_.FontName } | Sort-Object -Unique)
        $fonts = $names -join ', '
        if ($names | Where-Object { $_ -match 'TimesNewRoman' }) {
            # A fallback on whitespace only is invisible (some header/footer designs do it with the base theme too).
            $absorber = [Aspose.Pdf.Text.TextFragmentAbsorber]::new()
            $doc.Pages.Accept($absorber)
            $visible = @($absorber.TextFragments | Where-Object { $_.TextState.Font.FontName -match 'TimesNewRoman' -and $_.Text.Trim() -ne '' })
            if ($visible.Count -gt 0) { $problems += "Times New Roman fallback on '$($visible[0].Text)'" } else { $warnings += 'Times New Roman on whitespace only' }
        }
        if ($r.bodyFont) {
            $want = ($r.bodyFont -replace ' ', '')
            if (-not ($names | Where-Object { ($_ -replace ' ', '') -like "*$want*" })) { $problems += "body font $($r.bodyFont) not embedded" }
        }
        if ($r.pageHex) {
            $png = Join-Path $Folder ('{0:000}.png' -f [int]$r.case)
            $fs = [IO.File]::Create($png)
            ([Aspose.Pdf.Devices.PngDevice]::new([Aspose.Pdf.Devices.Resolution]::new(40))).Process($doc.Pages[1], $fs)
            $fs.Close()
            $bmp = [System.Drawing.Bitmap]::new($png)
            $px = $bmp.GetPixel(3, $bmp.Height - 3)
            $bmp.Dispose()
            $got = '{0:X2}{1:X2}{2:X2}' -f $px.R, $px.G, $px.B
            $want = [Convert]::FromHexString($r.pageHex)
            if ([Math]::Abs($px.R - $want[0]) -gt 2 -or [Math]::Abs($px.G - $want[1]) -gt 2 -or [Math]::Abs($px.B - $want[2]) -gt 2) {
                $problems += "page colour $got, expected $($r.pageHex)"
            }
        }
        if ($r.scenario -like 'designed:*') {
            # what a designed header/footer must show on page 1 (CRONUS data)
            $expect = @{ page = $true; phone = $true; bank = $false }
            switch -Wildcard ($r.scenario) {
                '*no page number*' { $expect.page = $false }
                '*no footer*' { $expect.phone = $false }
                '*contact + bank*' { $expect.bank = $true }
                '*everything changed*' { $expect.bank = $true }
            }
            $absorber = [Aspose.Pdf.Text.TextAbsorber]::new()
            $doc.Pages[1].Accept($absorber)
            $text = $absorber.Text
            if (-not $text.Contains('Salesperson - Sales Statistics') -and -not $text.Contains('Customer - Order Summary') -and -not $text.Contains('Salesperson - Commission')) { $problems += 'report title (header) missing' }
            if (($text -match '\b1/\d+\b') -ne $expect.page) { $problems += "page number expected=$($expect.page)" }
            if (($text -match '0666-666-6666') -ne $expect.phone) { $problems += "contact footer expected=$($expect.phone)" }
            if (($text -match 'World Wide Bank') -ne $expect.bank) { $problems += "bank details expected=$($expect.bank)" }
        }
        $doc.Dispose()
    }
    [pscustomobject]@{
        Case     = [int]$r.case
        Report   = $r.report
        Layout   = $r.layout
        Scenario = $r.scenario
        Ms       = $r.ms
        Status   = if ($problems) { 'FAIL' } else { 'PASS' }
        Problems = $problems -join '; '
        Warnings = $warnings -join '; '
        Fonts    = $fonts
    }
}
$results | Export-Csv -Path (Join-Path $Folder 'sweep-results.csv') -NoTypeInformation -Delimiter ';'

'{0} renders: {1} PASS, {2} FAIL, {3} with warnings' -f $results.Count, @($results | Where-Object Status -eq 'PASS').Count, @($results | Where-Object Status -eq 'FAIL').Count, @($results | Where-Object Warnings).Count
$results | Group-Object Report, Layout | ForEach-Object {
    '{0,-22} {1,3} renders, {2,3} fail, avg {3,5} ms' -f $_.Name, $_.Count, @($_.Group | Where-Object Status -eq 'FAIL').Count, [int](($_.Group | Measure-Object Ms -Average).Average)
}
$results | Where-Object Status -eq 'FAIL' | Format-Table Case, Report, Layout, Scenario, Problems -AutoSize -Wrap | Out-String -Width 220
