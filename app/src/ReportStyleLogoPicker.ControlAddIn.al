namespace Abakion.ReportStyleDesigner;

/// The logo as the starting point on the Quick Start page: the company logo on small pages, on the left,
/// centred and on the right, so the user picks a placement by looking at it. No external scripts.
controladdin "Report Style Logo Picker"
{
    Scripts = 'addin/logopicker.js';
    StartupScript = 'addin/logopicker-startup.js';
    StyleSheets = 'addin/logopicker.css';

    RequestedHeight = 160;
    MinimumHeight = 110;
    VerticalStretch = false;
    VerticalShrink = true;
    HorizontalStretch = true;
    HorizontalShrink = true;

    event Ready();
    event PlacementChosen(Placement: Text);
    event UploadRequested();
    // A logo to try in the preview only, and back to the logo in Company Information.
    event TryLogoRequested();
    event CompanyLogoRequested();
    // The logo's main colours (JSON array of hex), for Draft with Copilot. Never the picture.
    event LogoColorsComputed(Colors: Text);

    procedure ShowLogo(LogoBase64: Text; Placement: Text);
    // True: the logo shown is a trial logo for the preview, not the one in Company Information. Call before ShowLogo.
    procedure SetTrialLogo(IsTrial: Boolean);
    procedure ShowNoLogo(Message: Text);
}
