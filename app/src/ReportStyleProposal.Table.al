namespace Abakion.ReportStyleDesigner;

/// A theme proposed by Copilot, already checked by "Report Style Theme Rules".
table 50101 "Report Style Proposal"
{
    Caption = 'Report Style Proposal';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer) { Caption = 'No.'; }
        field(2; Name; Text[100]) { Caption = 'Theme'; }
        field(3; Reason; Text[500]) { Caption = 'Why'; }
        field(4; Colors; Text[250]) { Caption = 'Colours'; }
        field(5; "Main Colour"; Text[10]) { Caption = 'Main colour'; }
        field(6; "Font Pair"; Enum "Report Style Font Pair") { Caption = 'Fonts'; }
        field(7; "Table Style"; Enum "Report Theme Table Style") { Caption = 'Table style'; }
        field(8; "Page Color"; Enum "Report Style Page Color") { Caption = 'Page colour'; }
        field(9; Adjustments; Text[250]) { Caption = 'Adjusted'; }
        field(10; "Custom Page Color"; Text[10]) { Caption = 'Custom page colour'; }
    }

    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
    }
}
