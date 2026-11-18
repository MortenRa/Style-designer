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

    RequestedHeight = 600;
    MinimumHeight = 300;
    VerticalStretch = false;
    VerticalShrink = true;
    HorizontalStretch = true;
    HorizontalShrink = true;

    event Ready();
    // A click on the page when SetOpenOnClick(true) was called: open it full size.
    event FullViewRequested();
    // The arrows on the suggestion bar: -1 previous, 1 next.
    event SuggestionStep(Delta: Integer);
    // "Use my theme" on the bar: leave the suggestion.
    event UseMyThemeRequested();

    procedure ShowPdf(PdfBase64: Text; Tooltip: Text);
    procedure ShowMessage(Message: Text);
    procedure SetOpenOnClick(Open: Boolean);
    // Count 0 hides the bar; Index 0 means none of the suggestions is in the preview.
    procedure SetSuggestion(Name: Text; Index: Integer; Count: Integer; Reason: Text);
}
