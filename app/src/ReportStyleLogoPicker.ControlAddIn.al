namespace Abakion.ReportStyleDesigner;

/// The logo as the starting point on the Quick Start page: the company logo on small pages, on the left,
/// centred and on the right, so the user picks a placement by looking at it. No external scripts.
controladdin "Report Style Logo Picker"
{
    Scripts = 'addin/logopicker.js';
    StartupScript = 'addin/logopicker-startup.js';
    StyleSheets = 'addin/logopicker.css';

    RequestedHeight = 210;
    MinimumHeight = 150;
    VerticalStretch = false;
    VerticalShrink = true;
    HorizontalStretch = true;
    HorizontalShrink = true;

    event Ready();
    event PlacementChosen(Placement: Text);
    event UploadRequested();

    procedure ShowLogo(LogoBase64: Text; Placement: Text);
    procedure ShowNoLogo(Message: Text);
}
