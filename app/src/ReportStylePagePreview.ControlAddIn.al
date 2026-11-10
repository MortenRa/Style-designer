namespace Abakion.ReportStyleDesigner;

/// Shows one page of a report as a picture on the Report style page, taller than the Web Page Viewer allows.
/// Only an image box: the page is rendered and turned into a PNG on the server.
controladdin "Report Style Page Preview"
{
    Scripts = 'addin/pagepreview.js';
    StartupScript = 'addin/pagepreview-startup.js';
    StyleSheets = 'addin/pagepreview.css';

    RequestedHeight = 470;
    MinimumHeight = 300;
    VerticalStretch = false;
    VerticalShrink = true;
    HorizontalStretch = true;
    HorizontalShrink = true;

    event Ready();

    procedure ShowImage(PngBase64: Text; Tooltip: Text);
    procedure ShowMessage(Message: Text);
}
