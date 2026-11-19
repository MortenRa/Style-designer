namespace Abakion.ReportStyleDesigner;

/// Shows page 1 of a report on the Report style page. The PDF is drawn with pdf.js, like the designer,
/// so the text stays sharp at every size (a picture from the server is only 72 dpi).
controladdin "Report Style Page Preview"
{
    Scripts =
        'https://cdn-bc.dynamics.com/common/js/pdfjs-4.10.38/pdf.min.mjs',
        'addin/pagepreview2.js';
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
    // After ShowBusy with RequestRender: the busy text is on screen, the page can render now.
    event RenderRequested();

    procedure ShowPdf(PdfBase64: Text; Tooltip: Text);
    procedure ShowMessage(Message: Text);
    // Shows that the preview is being made, over the last page if there is one.
    procedure ShowBusy(Message: Text; RequestRender: Boolean);
    procedure SetOpenOnClick(Open: Boolean);
    // A short line over the page, such as "Preview only". Empty hides it.
    procedure SetNote(Note: Text);
    // Count 0 hides the bar; Index 0 means none of the suggestions is in the preview.
    procedure SetSuggestion(Name: Text; Index: Integer; Count: Integer; Reason: Text);
}
