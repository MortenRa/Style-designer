namespace Abakion.ReportStyleDesigner;

/// One document of a "Your documents" gallery refresh, rendered by a background session so no progress
/// dialog pops up in the user's session. Rows live only until the designer has picked up the result.
table 50103 "Report Style Gallery Job"
{
    Caption = 'Report Style Gallery Job';
    Access = Internal;
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; AutoIncrement = true; }
        field(2; "User Security ID"; Guid) { Caption = 'User'; DataClassification = EndUserPseudonymousIdentifiers; }
        field(3; "Batch ID"; Guid) { Caption = 'Batch'; }
        field(4; Seq; Integer) { Caption = 'Sequence (add-in)'; }
        field(5; "Report ID"; Integer) { Caption = 'Report'; }
        field(6; "Layout Name"; Text[250]) { Caption = 'Layout'; }
        field(7; "Layout App ID"; Text[50]) { Caption = 'Layout app'; }
        field(8; Status; Option) { Caption = 'Status'; OptionMembers = Pending,Running,Done,Failed; }
        field(9; State; Blob) { Caption = 'Designer state'; }
        field(10; Pdf; Blob) { Caption = 'PDF'; }
        field(11; "Error Text"; Text[2048]) { Caption = 'Error'; }
        field(12; Created; DateTime) { Caption = 'Created'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Batch; "User Security ID", "Batch ID") { }
    }
}
