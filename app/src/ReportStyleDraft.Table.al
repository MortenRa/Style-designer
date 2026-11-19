namespace Abakion.ReportStyleDesigner;

/// A design saved to continue later. It is only a copy of the designer's choices: nothing is generated, assigned or
/// sent for approval until the designer opens it again or sends it.
table 50106 "Report Style Draft"
{
    Caption = 'Theme Designer Draft';
    Access = Internal;
    DataClassification = CustomerContent;
    LookupPageId = "Report Style Drafts";
    DrillDownPageId = "Report Style Drafts";

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'No.'; AutoIncrement = true; }
        field(2; Name; Text[100]) { Caption = 'Name'; }
        field(3; Document; Text[250]) { Caption = 'Document'; }
        field(4; Change; Text[250]) { Caption = 'What changes'; }
        field(5; "Theme Name"; Text[250]) { Caption = 'Theme'; }
        field(6; "Header/Footer Name"; Text[250]) { Caption = 'Header/footer'; }
        field(7; "Saved By"; Code[50]) { Caption = 'Saved by'; DataClassification = EndUserIdentifiableInformation; }
        field(8; "Saved At"; DateTime) { Caption = 'Saved at'; }
        field(9; State; Blob) { Caption = 'Design'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Name; Name, "Saved By") { }
    }
}
