namespace Abakion.ReportStyleDesigner;

using System.Reflection;

page 50101 "Report Style Body Layouts"
{
    Caption = 'Body Layouts';
    PageType = List;
    SourceTable = "Report Layout List";
    SourceTableView = where("Layout Subtype" = const(Body));
    Editable = false;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Layouts)
            {
                field("Report ID"; Rec."Report ID") { }
                field("Report Name"; Rec."Report Name") { }
                field(Name; Rec.Name) { Caption = 'Layout'; }
                field(Description; Rec.Description) { }
                field("Layout Status"; Rec."Layout Status") { }
                field("Layout Publisher"; Rec."Layout Publisher") { }
            }
        }
    }
}
