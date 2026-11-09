namespace Abakion.ReportStyleDesigner;

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
            group(Look)
            {
                Caption = 'Look';
                field(Palette; Rec.Palette)
                {
                    ApplicationArea = All;
                    ToolTip = 'The main colours of the reports. "Keep base theme colours" leaves them as they are.';
                }
                field("Font Pair"; Rec."Font Pair")
                {
                    ApplicationArea = All;
                    ToolTip = 'The fonts for headings and text. Only fonts that print correctly are offered.';
                }
                field("Page Color"; Rec."Page Color")
                {
                    ApplicationArea = All;
                    ToolTip = 'The background of the page. White is the safest choice for printing.';
                }
                field("Table Style"; Rec."Table Style")
                {
                    ApplicationArea = All;
                    ToolTip = 'How lines with many rows, such as invoice lines, look.';
                }
            }
            group(Layout)
            {
                Caption = 'Header and footer';
                field(Composition; Composition)
                {
                    ApplicationArea = All;
                    Caption = 'Composition (draft)';
                    ToolTip = 'Sets the logo, page number and footer in one step. The designer can change each of them.';

                    trigger OnValidate()
                    begin
                        ApplyComposition();
                    end;
                }
                field("HF Show Date"; Rec."HF Show Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Show the date in the header.';
                }
                field("HF Accent Line"; Rec."HF Accent Line")
                {
                    ApplicationArea = All;
                    ToolTip = 'Draw a coloured line under the header.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
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
        Composition: Enum "Report Style Composition";

    trigger OnOpenPage()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        DesignerMgt.GetConfig(Rec);
    end;

    local procedure ApplyComposition()
    begin
        Rec."Header Mode" := 'design';
        Rec."HF Later Pages" := 'minimal';
        case Composition of
            Composition::Standard:
                begin
                    Rec."HF Logo" := 'right';
                    Rec."HF Page Number" := 'header';
                    Rec."HF Footer" := 'contact';
                    Rec."HF Show Date" := true;
                    Rec."HF Accent Line" := false;
                end;
            Composition::LogoLeft:
                begin
                    Rec."HF Logo" := 'left';
                    Rec."HF Page Number" := 'header';
                    Rec."HF Footer" := 'contact';
                    Rec."HF Show Date" := true;
                    Rec."HF Accent Line" := true;
                end;
            Composition::BankFooter:
                begin
                    Rec."HF Logo" := 'right';
                    Rec."HF Page Number" := 'footer';
                    Rec."HF Footer" := 'bank';
                    Rec."HF Show Date" := true;
                    Rec."HF Accent Line" := false;
                end;
            Composition::NoDate:
                begin
                    Rec."HF Logo" := 'right';
                    Rec."HF Page Number" := 'header';
                    Rec."HF Footer" := 'contact';
                    Rec."HF Show Date" := false;
                    Rec."HF Accent Line" := false;
                end;
            Composition::Minimal:
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
