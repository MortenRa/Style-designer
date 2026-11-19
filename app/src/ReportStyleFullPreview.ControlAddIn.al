namespace Abakion.ReportStyleDesigner;

/// The same preview as on Quick Start, sized to fill a page of its own: the full-size view.
controladdin "Report Style Full Preview"
{
    Scripts =
        'https://cdn-bc.dynamics.com/common/js/pdfjs-4.10.38/pdf.min.mjs',
        'addin/pagepreview2.js';
    StartupScript = 'addin/pagepreview-startup.js';
    StyleSheets = 'addin/pagepreview.css';

    RequestedHeight = 900;
    MinimumHeight = 500;
    VerticalStretch = true;
    VerticalShrink = true;
    HorizontalStretch = true;
    HorizontalShrink = true;

    event Ready();
    event FullViewRequested();
    event SuggestionStep(Delta: Integer);
    // "Use my theme" on the bar: leave the suggestion.
    event UseMyThemeRequested();

    procedure ShowPdf(PdfBase64: Text; Tooltip: Text);
    procedure ShowMessage(Message: Text);
    procedure SetOpenOnClick(Open: Boolean);
    procedure SetSuggestion(Name: Text; Index: Integer; Count: Integer; Reason: Text);
}