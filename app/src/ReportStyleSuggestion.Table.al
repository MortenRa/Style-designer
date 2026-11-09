namespace Abakion.ReportStyleDesigner;

/// The last Copilot proposals (JSON), kept in their own row so saving them never touches the style configuration.
table 50104 "Report Style Suggestion"
{
    Caption = 'Report Style Suggestion';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10]) { Caption = 'Primary key'; }
        field(2; Suggestions; Blob) { Caption = 'Copilot suggestions (last)'; }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
