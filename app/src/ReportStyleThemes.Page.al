namespace Abakion.ReportStyleDesigner;

using System.Reflection;

/// The themes in Business Central, by name and description: the lookup of the Theme field on Quick Start.
page 50107 "Report Style Themes"
{
    Caption = 'Themes';
    PageType = List;
    SourceTable = "Report Layout List";
    SourceTableView = sorting(Name) where("Report ID" = const(2000000001), "Layout Subtype" = const(Theme), Name = filter('<>Preview *'));
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
}