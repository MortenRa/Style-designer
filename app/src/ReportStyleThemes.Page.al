namespace Abakion.ReportStyleDesigner;

using System.Reflection;

/// The themes in Business Central, by name only: the lookup of the Theme field on Quick Start.
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
            }
        }
    }
}