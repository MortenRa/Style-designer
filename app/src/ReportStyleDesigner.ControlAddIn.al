namespace Abakion.ReportStyleDesigner;

controladdin "Report Style Designer"
{
    Scripts =
        'https://cdn-bc.dynamics.com/common/js/pdfjs-4.10.38/pdf.min.mjs',
        'addin/studio.js';
    StartupScript = 'addin/startup.js';
    StyleSheets = 'addin/studio.css';

    HorizontalStretch = true;
    VerticalStretch = true;
    HorizontalShrink = true;
    VerticalShrink = true;
    RequestedHeight = 780;
    MinimumHeight = 560;

    event Ready();
    event PreviewRequested(State: Text; Seq: Integer);
    event SaveRequested(State: Text; Mode: Text);
    event ChooseDataRequested(State: Text);
    event ClearDataRequested(State: Text);
    // LogoColors: JSON array of hex colours the add-in read from the company logo.
    event CopilotRequested(State: Text; LogoColors: Text);
    // "Browse all…" in the document picker: choose a Body layout on a full list page.
    event BrowseLayoutsRequested(State: Text);
    // "Your documents" gallery: render the current style on another Body layout, and choose that report's preview data.
    // Docs: JSON array of {reportId, name, appId, seq}; rendered in a background session, picked up by GalleryPoll.
    event GalleryBatchRequested(State: Text; Docs: Text);
    event GalleryPoll();
    event GalleryChooseDataRequested(State: Text; ReportId: Integer);

    procedure Init(Data: Text);
    procedure ShowPreview(Seq: Integer; Base64Pdf: Text);
    procedure ShowPreviewError(Seq: Integer; Message: Text);
    procedure Notify(Message: Text; Kind: Text);
    procedure SetHasData(HasData: Boolean);
    procedure ShowGalleryPage(Seq: Integer; Base64Pdf: Text);
    procedure ShowGalleryError(Seq: Integer; Message: Text);
    procedure GalleryDataChanged(ReportId: Integer);
    procedure GalleryProgress(Pending: Integer);
}
