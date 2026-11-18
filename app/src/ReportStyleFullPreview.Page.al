namespace Abakion.ReportStyleDesigner;

/// Page 1 of the Quick Start preview at full size: the preview is the only content, so it gets the whole window.
/// A click zooms: whole page, full width, larger.
page 50108 "Report Style Full Preview"
{
    Caption = 'Preview';
    PageType = Card;
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            usercontrol(Viewer; "Report Style Full Preview")
            {
                ApplicationArea = All;

                trigger Ready()
                begin
                    if PdfBase64 = '' then
                        CurrPage.Viewer.ShowMessage(NothingTxt)
                    else
                        CurrPage.Viewer.ShowPdf(PdfBase64, ZoomTipTxt);
                end;
            }
        }
    }

    var
        PdfBase64: Text;
        ViewCaption: Text;
        NothingTxt: Label 'There is no preview yet. Change a choice on Quick Start, or choose Update preview.';
        ZoomTipTxt: Label 'Click to zoom: whole page, full width, larger.';

    trigger OnOpenPage()
    begin
        if ViewCaption <> '' then
            CurrPage.Caption(ViewCaption);
    end;

    procedure SetPreview(NewPdfBase64: Text; NewCaption: Text)
    begin
        PdfBase64 := NewPdfBase64;
        ViewCaption := NewCaption;
    end;
}