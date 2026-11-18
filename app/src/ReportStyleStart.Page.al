namespace Abakion.ReportStyleDesigner;

using System.Text;
using System.Utilities;

/// The simple entry point (phase 1): a few plain choices for the look, then the full designer for more detail.
/// A standard page, not the designer add-in; only the preview uses a small image box (Report Style Page Preview).
page 50105 "Report Style Start"
{
    Caption = 'Theme Designer - Quick Start';
    PageType = Card;
    SourceTable = "Report Style Config";
    UsageCategory = Administration;
    ApplicationArea = All;
    AdditionalSearchTerms = 'report style, report theme, report design, document design, colours, fonts, start';

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
            group(DirectionGroup)
            {
                Caption = 'Design direction';
                field(Direction; Rec.Direction)
                {
                    ApplicationArea = All;
                    Caption = 'Direction';
                    ToolTip = 'A finished look to start from. It sets the colours, fonts, tables, header and footer in one step. You can change every detail below.';

                    trigger OnValidate()
                    var
                        Directions: Codeunit "Report Style Directions";
                    begin
                        Directions.Apply(Rec);
                        RefreshAdvice();
                    end;
                }
                field(DirectionDescription; DirectionText)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                    Style = Subordinate;
                    ToolTip = 'What the chosen direction looks like.';
                }
            }
            group(Look)
            {
                Caption = 'Look';
                field("Base Theme"; Rec."Base Theme")
                {
                    ApplicationArea = All;
                    Caption = 'Theme';
                    ToolTip = 'A theme that already exists in Business Central. Choosing one shows it as it is; the choices below then change it.';

                    trigger OnValidate()
                    begin
                        // Shown as it is: the choices below go back to "keep the base theme".
                        Rec."Theme Mode" := 'custom';
                        Rec.Palette := Rec.Palette::KeepBase;
                        Rec."Font Pair" := Rec."Font Pair"::KeepBase;
                        Rec."Page Color" := Rec."Page Color"::KeepBase;
                        Rec."Table Style" := Rec."Table Style"::KeepBase;
                        RefreshAdvice();
                    end;
                }
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
                // A small image box of our own: a Media field is a thumbnail outside a factbox, and the
                // Web Page Viewer stays 320 px high on a Card page, too low for a whole page.
                usercontrol(PreviewViewer; "Report Style Page Preview")
                {
                    ApplicationArea = All;

                    trigger Ready()
                    begin
                        ViewerReady := true;
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
        DirectionText: Text;
        DocumentText: Text;
        PreviewCaptionTxt: Label '%1 · page 1 · not applied yet', Comment = '%1 = report name';
        DocumentTxt: Label '%1 (%2) · layout %3', Comment = '%1 = report name, %2 = report ID, %3 = layout name';
        NoDocumentTxt: Label 'No document chosen yet. Choose one to see the preview.';
        PreviewStatusText: Text;
        ViewerReady: Boolean;
        StartTxt: Label 'Change a choice, or choose Update preview, to see the first page of the document here.';
        ZoomTipTxt: Label 'Click to zoom: whole page, full width, larger.';

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
        Base64Convert: Codeunit "Base64 Convert";
        Pdf: Codeunit "Temp Blob";
    begin
        if not ViewerReady then
            exit;
        if not Runner.Preview(Rec) then begin
            PreviewStatusText := Runner.GetErrorText();
            ShowMessage(PreviewStatusText);
            exit;
        end;
        Runner.GetPdf(Pdf);
        PreviewStatusText := StrSubstNo(PreviewCaptionTxt, DesignerMgt.GetReportCaption(Rec));
        CurrPage.PreviewViewer.ShowPdf(Base64Convert.ToBase64(Pdf.CreateInStream()), ZoomTipTxt);
    end;

    local procedure ShowMessage(Message: Text)
    begin
        if ViewerReady then
            CurrPage.PreviewViewer.ShowMessage(Message);
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
        ComputeDirectionText();
    end;

    local procedure ComputeDirectionText()
    var
        Directions: Codeunit "Report Style Directions";
    begin
        DirectionText := Directions.Describe(Rec.Direction);
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
}
