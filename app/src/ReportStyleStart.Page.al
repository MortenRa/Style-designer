namespace Abakion.ReportStyleDesigner;

using System.Integration;
using System.IO;
using System.Text;
using System.Utilities;

/// The simple entry point (phase 1): a few plain choices for the look, then the full designer for more detail.
/// A standard page, not the add-in, so it does not add control add-in maintenance.
page 50105 "Report Style Start"
{
    Caption = 'Report style';
    PageType = Card;
    SourceTable = "Report Style Config";
    UsageCategory = Administration;
    ApplicationArea = All;
    AdditionalSearchTerms = 'report theme, report design, document design, colours, fonts, start';

    layout
    {
        area(Content)
        {
            // One FastTab with two columns: the choices on the left, the preview on the right (wider than a factbox).
            group(Main)
            {
                ShowCaption = false;
            group(Choices)
            {
                ShowCaption = false;
            group(Look)
            {
                Caption = 'Look';
                field(Palette; Rec.Palette)
                {
                    ApplicationArea = All;
                    ToolTip = 'The main colours of the reports. "Keep base theme colours" leaves them as they are.';

                    trigger OnValidate()
                    begin
                        RefreshAdvice();
                    end;
                }
                field("Font Pair"; Rec."Font Pair")
                {
                    ApplicationArea = All;
                    ToolTip = 'The fonts for headings and text. Only fonts that print correctly are offered.';

                    trigger OnValidate()
                    begin
                        RefreshAdvice();
                    end;
                }
                field("Page Color"; Rec."Page Color")
                {
                    ApplicationArea = All;
                    ToolTip = 'The background of the page. White is the safest choice for printing.';

                    trigger OnValidate()
                    begin
                        RefreshAdvice();
                    end;
                }
                field("Table Style"; Rec."Table Style")
                {
                    ApplicationArea = All;
                    ToolTip = 'How lines with many rows, such as invoice lines, look.';

                    trigger OnValidate()
                    begin
                        RefreshAdvice();
                    end;
                }
            }
            group(Layout)
            {
                Caption = 'Header and footer';
                field(Composition; Rec.Composition)
                {
                    ApplicationArea = All;
                    Caption = 'Composition (draft)';
                    ToolTip = 'Sets the logo, page number and footer in one step. The designer can change each of them.';

                    trigger OnValidate()
                    begin
                        ApplyComposition();
                        RefreshAdvice();
                    end;
                }
                field("HF Show Date"; Rec."HF Show Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Show the date in the header.';

                    trigger OnValidate()
                    begin
                        RefreshAdvice();
                    end;
                }
                field("HF Accent Line"; Rec."HF Accent Line")
                {
                    ApplicationArea = All;
                    ToolTip = 'Draw a coloured line under the header.';

                    trigger OnValidate()
                    begin
                        RefreshAdvice();
                    end;
                }
            }
            group(Advice)
            {
                Caption = 'Recommendations';
                field(AdviceText; AdviceText)
                {
                    ApplicationArea = All;
                    Caption = 'Advice';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Soft recommendations based on the settings. They explain a likely problem; you can still apply the style.';
                }
            }
            }
            group(PreviewGroup)
            {
                Caption = 'Preview';
                field(DocumentName; DocumentText)
                {
                    ApplicationArea = All;
                    Caption = 'Document';
                    Editable = false;
                    ToolTip = 'The document the preview shows. Choose another report layout to see the style on it.';

                    trigger OnAssistEdit()
                    var
                        ConfiguratorMgt: Codeunit "Report Style Configurator Mgt.";
                    begin
                        Rec.Modify(true);
                        Commit();
                        if not ConfiguratorMgt.LookupBodyLayout(Rec) then
                            exit;
                        Rec.Modify(true);
                        Commit();
                        ComputeDocumentText();
                        UpdatePreview();
                        CurrPage.Update(false);
                    end;
                }
                // Microsoft's Web Page Viewer (System Application) shows the page as a picture at the column's width;
                // a Media field is limited to a small thumbnail outside a factbox. No add-in of our own.
                usercontrol(PreviewViewer; WebPageViewer)
                {
                    ApplicationArea = All;

                    trigger ControlAddInReady(CallbackUrl: Text)
                    begin
                        ViewerReady := true;
                        CurrPage.PreviewViewer.InitializeFullIFrame();
                        ShowMessage(StartTxt);
                    end;
                }
                field(PreviewStatus; PreviewStatusText)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    Style = Subordinate;
                    ToolTip = 'What the preview shows, or why it could not be shown.';
                }
            }
            }
        }
    }

    actions
    {
        area(Promoted)
        {
            actionref(UpdatePreview_Promoted; UpdatePreviewAction) { }
            actionref(OpenDesigner_Promoted; OpenDesigner) { }
        }
        area(Processing)
        {
            // Not rendered while the page opens: the report's progress dialog cannot be shown before the page is there.
            action(UpdatePreviewAction)
            {
                ApplicationArea = All;
                Caption = 'Update preview';
                ToolTip = 'Show the first page of the chosen document with these choices. The preview also updates after each change.';
                Image = Refresh;

                trigger OnAction()
                begin
                    Rec.Modify(true);
                    Commit();
                    UpdatePreview();
                end;
            }
            action(OpenDesigner)
            {
                ApplicationArea = All;
                Caption = 'Preview and apply';
                ToolTip = 'See the reports with these choices and apply them. More options are in the designer.';

                trigger OnAction()
                var
                    Designer: Page "Report Style Designer";
                begin
                    Rec.Modify(true);
                    Commit();
                    Designer.Run();
                end;
            }
        }
    }

    var
        AdviceText: Text;
        DocumentText: Text;
        PreviewCaptionTxt: Label '%1 · page 1 · not applied yet', Comment = '%1 = report name';
        DocumentTxt: Label '%1 (%2) · layout %3', Comment = '%1 = report name, %2 = report ID, %3 = layout name';
        NoDocumentTxt: Label 'No document chosen yet. Choose one to see the preview.';
        PreviewStatusText: Text;
        ViewerReady: Boolean;
        StartTxt: Label 'Change a choice, or choose Update preview, to see the first page of the document here.';
        NoPictureErr: Label 'The preview could not be turned into a picture.';
        ZoomTipTxt: Label 'Click to switch between the whole page and the full width.';
        MessageHtmlTxt: Label '<div style="font:13px Segoe UI,sans-serif;color:#605e5c;padding:24px">%1</div>', Locked = true;

    trigger OnOpenPage()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        DesignerMgt.GetConfig(Rec);
    end;

    local procedure ComputeDocumentText()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        if Rec."Target Report ID" = 0 then
            DocumentText := NoDocumentTxt
        else
            DocumentText := StrSubstNo(DocumentTxt, DesignerMgt.GetReportCaption(Rec), Rec."Target Report ID", Rec."Target Layout Name");
    end;

    // Renders the chosen document with the current choices and shows page 1 as a picture (turned into PNG on the server).
    // The preview writes per-user layout settings and restores them, so it runs outside the page's write transaction.
    local procedure UpdatePreview()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Runner: Codeunit "Report Style Designer Runner";
        PdfDocument: Codeunit "PDF Document";
        Base64Convert: Codeunit "Base64 Convert";
        Pdf: Codeunit "Temp Blob";
        Image: Codeunit "Temp Blob";
        ImageStream: InStream;
    begin
        if not ViewerReady then
            exit;
        if not Runner.Preview(Rec) then begin
            PreviewStatusText := Runner.GetErrorText();
            ShowMessage(PreviewStatusText);
            exit;
        end;
        Runner.GetPdf(Pdf);
        Image.CreateInStream(ImageStream);
        if PdfDocument.Load(Pdf.CreateInStream()) then
            if PdfDocument.ConvertPdfToImage(ImageStream, Enum::"Image Format"::Png, 1) then begin
                PreviewStatusText := StrSubstNo(PreviewCaptionTxt, DesignerMgt.GetReportCaption(Rec));
                ShowImage(Base64Convert.ToBase64(ImageStream));
                exit;
            end;
        PreviewStatusText := NoPictureErr;
        ShowMessage(PreviewStatusText);
    end;

    local procedure ShowMessage(Message: Text)
    begin
        ShowHtml(StrSubstNo(MessageHtmlTxt, Message.Replace('&', '&amp;').Replace('<', '&lt;')));
    end;

    // The whole page fits the frame; a click switches to the full width (scrolling) and back.
    local procedure ShowImage(PngBase64: Text)
    var
        Html: TextBuilder;
    begin
        if not ViewerReady then
            exit;
        Html.Append('<style>html,body{margin:0;height:100%;background:#f3f2f1}');
        Html.Append('.p{height:100%;box-sizing:border-box;padding:8px;display:flex;align-items:center;justify-content:center}');
        Html.Append('.p img{max-width:100%;max-height:100%;background:#fff;box-shadow:0 1px 4px rgba(0,0,0,.25);cursor:zoom-in}');
        Html.Append('.p.w{display:block;height:auto}.p.w img{display:block;width:100%;max-height:none;cursor:zoom-out}</style>');
        Html.Append('<div class="p" id="p" title="' + ZoomTipTxt + '"><img alt="" src="data:image/png;base64,' + PngBase64 + '"></div>');
        CurrPage.PreviewViewer.SetContent(Html.ToText(), 'document.getElementById("p").addEventListener("click",function(){this.classList.toggle("w");});');
    end;

    local procedure ShowHtml(Html: Text)
    begin
        if ViewerReady then
            CurrPage.PreviewViewer.SetContent(Html);
    end;

    // A Card page fills its non-source fields here, not in OnAfterGetCurrRecord (that is for list pages).
    trigger OnAfterGetRecord()
    begin
        ComputeAdvice();
        ComputeDocumentText();
    end;

    local procedure ComputeAdvice()
    var
        Advice: Codeunit "Report Style Advice";
    begin
        AdviceText := Advice.GetAdviceText(Rec);
    end;

    // After a change the page must be redrawn, or a non-source field keeps its old text.
    local procedure RefreshAdvice()
    begin
        ComputeAdvice();
        Rec.Modify(true);
        Commit();
        UpdatePreview();
        CurrPage.Update(false);
    end;

    local procedure ApplyComposition()
    begin
        if Rec.Composition = Rec.Composition::NotChosen then
            exit;
        Rec."Header Mode" := 'design';
        Rec."HF Later Pages" := 'minimal';
        case Rec.Composition of
            Rec.Composition::Standard:
                begin
                    Rec."HF Logo" := 'right';
                    Rec."HF Page Number" := 'header';
                    Rec."HF Footer" := 'contact';
                    Rec."HF Show Date" := true;
                    Rec."HF Accent Line" := false;
                end;
            Rec.Composition::LogoLeft:
                begin
                    Rec."HF Logo" := 'left';
                    Rec."HF Page Number" := 'header';
                    Rec."HF Footer" := 'contact';
                    Rec."HF Show Date" := true;
                    Rec."HF Accent Line" := true;
                end;
            Rec.Composition::BankFooter:
                begin
                    Rec."HF Logo" := 'right';
                    Rec."HF Page Number" := 'footer';
                    Rec."HF Footer" := 'bank';
                    Rec."HF Show Date" := true;
                    Rec."HF Accent Line" := false;
                end;
            Rec.Composition::NoDate:
                begin
                    Rec."HF Logo" := 'right';
                    Rec."HF Page Number" := 'header';
                    Rec."HF Footer" := 'contact';
                    Rec."HF Show Date" := false;
                    Rec."HF Accent Line" := false;
                end;
            Rec.Composition::Minimal:
                begin
                    Rec."HF Logo" := 'right';
                    Rec."HF Page Number" := 'header';
                    Rec."HF Footer" := 'none';
                    Rec."HF Show Date" := true;
                    Rec."HF Accent Line" := true;
                end;
        end;
        Rec.Modify(true);
    end;
}
