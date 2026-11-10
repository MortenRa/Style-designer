namespace Abakion.ReportStyleDesigner;

using System.IO;
using System.Utilities;

/// The first page of a report preview as a picture, without a control add-in: the PDF is turned into a PNG on the server.
page 50104 "Report Style Preview Part"
{
    Caption = 'Preview';
    PageType = CardPart;
    Editable = false;
    LinksAllowed = false;

    layout
    {
        area(Content)
        {
            field(Picture; TempImage.Image)
            {
                ApplicationArea = All;
                ShowCaption = false;
                ExtendedDatatype = Document;
                ToolTip = 'The first page of the chosen document with the current choices. Nothing is applied yet.';
            }
            field(Status; StatusText)
            {
                ApplicationArea = All;
                ShowCaption = false;
                MultiLine = true;
                Style = Subordinate;
                ToolTip = 'What the preview shows, or why it could not be shown.';
            }
        }
    }

    var
        TempImage: Record "Report Style Preview Image";
        StatusText: Text;
        NoPictureErr: Label 'The preview could not be turned into a picture.';
        StartTxt: Label 'Change a choice, or choose Update preview, to see the first page of the document here.';

    trigger OnOpenPage()
    begin
        StatusText := StartTxt;
    end;

    procedure ShowPdf(var Pdf: Codeunit "Temp Blob"; Caption: Text)
    var
        PdfDocument: Codeunit "PDF Document";
        Image: Codeunit "Temp Blob";
        PdfStream: InStream;
        ImageStream: InStream;
    begin
        Clear(TempImage);
        StatusText := Caption;
        PdfStream := Pdf.CreateInStream();
        Image.CreateInStream(ImageStream);
        if PdfDocument.Load(PdfStream) then
            if PdfDocument.ConvertPdfToImage(ImageStream, Enum::"Image Format"::Png, 1) then begin
                TempImage.Image.ImportStream(ImageStream, 'Report style preview', 'image/png');
                CurrPage.Update(false);
                exit;
            end;
        StatusText := NoPictureErr;
        CurrPage.Update(false);
    end;

    procedure ShowError(Message: Text)
    begin
        Clear(TempImage);
        StatusText := Message;
        CurrPage.Update(false);
    end;
}
