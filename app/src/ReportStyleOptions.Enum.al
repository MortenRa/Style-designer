namespace Abakion.ReportStyleDesigner;

enum 50101 "Report Style Palette"
{
    Extensible = false;

    value(0; KeepBase) { Caption = 'Keep base theme colours'; }
    value(1; Nature) { Caption = 'Nature'; }
    value(2; Ocean) { Caption = 'Ocean'; }
    value(3; Sunset) { Caption = 'Sunset'; }
    value(4; Graphite) { Caption = 'Graphite'; }
    // Colours chosen one by one (Copilot proposals); stored in "Custom Colors".
    value(5; Custom) { Caption = 'Custom'; }
}

enum 50102 "Report Style Font Pair"
{
    Extensible = false;

    value(0; KeepBase) { Caption = 'Keep base theme fonts'; }
    value(1; SegoeUI) { Caption = 'Segoe UI Semibold / Segoe UI'; }
    value(2; GeorgiaVerdana) { Caption = 'Georgia / Verdana'; }
    value(3; CambriaCalibri) { Caption = 'Cambria / Calibri'; }
    value(4; Bahnschrift) { Caption = 'Bahnschrift SemiBold / Bahnschrift'; }
    value(5; Sitka) { Caption = 'Sitka Display Semibold / Sitka Text'; }
}

enum 50103 "Report Style Page Color"
{
    Extensible = false;

    value(0; KeepBase) { Caption = 'Keep base theme page colour'; }
    value(1; White) { Caption = 'White (no page colour)'; }
    value(2; SoftGreen) { Caption = 'Soft green'; }
    value(3; SoftBlue) { Caption = 'Soft blue'; }
    value(4; WarmPaper) { Caption = 'Warm paper'; }
    value(5; LightGrey) { Caption = 'Light grey'; }
    // Any light colour (a tint of the theme colour, or picked by the user); stored in "Custom Page Color".
    value(6; Custom) { Caption = 'Custom'; }
}

enum 50104 "Report Style Assign To"
{
    Extensible = false;

    value(0; Layout) { Caption = 'This Body layout'; }
    value(1; CompanyDefault) { Caption = 'Company default (all reports)'; }
}
