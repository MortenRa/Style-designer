namespace Abakion.ReportStyleDesigner;

/// Shows page 1 of a report on the Report style page. The PDF is drawn with pdf.js, like the designer,
/// so the text stays sharp at every size (a picture from the server is only 72 dpi).
controladdin "Report Style Page Preview"
{
    Scripts =
        'https://cdn-bc.dynamics.com/common/js/pdfjs-4.10.38/pdf.min.mjs',
        'addin/pagepreview.js';
    StartupScript = 'addin/pagepreview-startup.js';
    StyleSheets = 'addin/pagepreview.css';

    RequestedHeight = 470;
    MinimumHeight = 300;
    VerticalStretch = false;
    VerticalShrink = true;
    HorizontalStretch = true;
    HorizontalShrink = true;

    event Ready();

    procedure ShowPdf(PdfBase64: Text; Tooltip: Text);
    procedure ShowMessage(Message: Text);
}
