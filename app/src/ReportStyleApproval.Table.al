namespace Abakion.ReportStyleDesigner;

/// A design sent for approval. The theme and header/footer are already saved as parts; nothing is assigned to any
/// document until an approver activates the request. State holds the designer's choices, so activation applies
/// exactly what was approved, also if the designer is changed in the meantime.
table 50105 "Report Style Approval"
{
    Caption = 'Theme Designer Approval';
    Access = Internal;
    DataClassification = CustomerContent;
    LookupPageId = "Report Style Approvals";
    DrillDownPageId = "Report Style Approvals";

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'No.'; AutoIncrement = true; }
        field(2; Status; Enum "Report Style Approval Status") { Caption = 'Status'; }
        field(3; "Theme Name"; Text[250]) { Caption = 'Theme'; }
        field(4; "Header/Footer Name"; Text[250]) { Caption = 'Header/footer'; }
        field(5; Target; Text[250]) { Caption = 'Documents'; }
        field(6; Change; Text[250]) { Caption = 'What changes'; }
        field(7; "Sent By"; Code[50]) { Caption = 'Sent by'; DataClassification = EndUserIdentifiableInformation; }
        field(8; "Sent At"; DateTime) { Caption = 'Sent at'; }
        field(9; "Decided By"; Code[50]) { Caption = 'Approved or rejected by'; DataClassification = EndUserIdentifiableInformation; }
        field(10; "Decided At"; DateTime) { Caption = 'Approved or rejected at'; }
        field(11; "Activated By"; Code[50]) { Caption = 'Activated by'; DataClassification = EndUserIdentifiableInformation; }
        field(12; "Activated At"; DateTime) { Caption = 'Activated at'; }
        field(13; Comment; Text[250]) { Caption = 'Comment'; }
        field(14; State; Blob) { Caption = 'Design'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Status; Status, "Sent At") { }
    }
}
