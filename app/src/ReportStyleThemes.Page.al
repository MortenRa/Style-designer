namespace Abakion.ReportStyleDesigner;

using System.Reflection;

/// The themes in Business Central, by name and description: the lookup of the Theme field on Quick Start.
/// Only themes that can be a starting point: a theme built into the platform (StandardTheme) has no file to read.
page 50107 "Report Style Themes"
{
    Caption = 'Themes';
    PageType = List;
    SourceTable = "Report Layout List";
    SourceTableTemporary = true;
    SourceTableView = sorting(Name);
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Themes)
            {
                field(Name; Rec.Name) { Caption = 'Name'; ToolTip = 'The name of the theme.'; }
                field(Description; Rec.Description) { Caption = 'Description'; ToolTip = 'What the theme looks like.'; }
                field("Layout Status"; Rec."Layout Status") { Caption = 'Status'; ToolTip = 'Whether the theme is approved for use. Themes from Microsoft and apps are always approved; a theme saved in the designer is a draft until it is approved.'; }
            }
        }
    }

    trigger OnOpenPage()
    var
        ReportLayoutList: Record "Report Layout List";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        ReportLayoutList.SetRange("Report ID", 2000000001);
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Theme);
        ReportLayoutList.SetFilter(Name, '<>Preview *');
        if ReportLayoutList.FindSet() then
            repeat
                if DesignerMgt.IsUsableTheme(ReportLayoutList) then begin
                    Rec := ReportLayoutList;
                    Rec.Insert();
                end;
            until ReportLayoutList.Next() = 0;
        if Rec.FindFirst() then;
    end;
}
