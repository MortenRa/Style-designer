namespace Abakion.ReportStyleDesigner;

/// Holds the preview picture for "Report Style Preview Part" (the app has no Base Application dependency for Media Repository).
table 50105 "Report Style Preview Image"
{
    Caption = 'Report Style Preview Image';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'Entry No.'; }
        field(2; Image; Media) { Caption = 'Image'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
    }
}
