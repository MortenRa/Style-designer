namespace Abakion.ReportStyleDesigner;

using System.Reflection;

table 50100 "Report Style Config"
{
    Caption = 'Report Style Configuration';
    Access = Internal;
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10]) { }
        field(2; "Base Theme"; Text[250])
        {
            Caption = 'Base theme';
            TableRelation = "Report Layout List".Name where("Report ID" = const(2000000001), "Layout Subtype" = const(Theme));
            ValidateTableRelation = false;
        }
        field(3; "Theme Name"; Text[250])
        {
            Caption = 'Save theme as';
            InitValue = 'Custom Theme';
        }
        field(4; Palette; Enum "Report Style Palette") { Caption = 'Colour palette'; }
        field(5; "Font Pair"; Enum "Report Style Font Pair") { Caption = 'Fonts (heading / body)'; }
        field(6; "Base Font Size"; Decimal)
        {
            Caption = 'Base font size (pt)';
            DecimalPlaces = 0 : 1;
            MinValue = 0;
            MaxValue = 72;
        }
        field(7; "Page Color"; Enum "Report Style Page Color") { Caption = 'Page colour'; }
        field(8; "Target Report ID"; Integer)
        {
            Caption = 'Report';
            InitValue = 114;
        }
        field(9; "Target Layout Name"; Text[250])
        {
            Caption = 'Body layout';
            InitValue = 'Approved';
        }
        field(10; "Target Layout App ID"; Guid) { Caption = 'Body layout app'; }
        field(11; "Assign To"; Enum "Report Style Assign To") { Caption = 'Assign theme to'; }
        field(12; "Report Parameters"; Blob) { Caption = 'Preview data (request page parameters)'; }
        field(13; "Table Style"; Enum "Report Theme Table Style") { Caption = 'Table style'; }
        field(14; "Header Part"; Text[250]) { Caption = 'Header/footer design'; }
        field(15; "Theme Mode"; Text[10]) { Caption = 'Theme: keep, default or custom'; InitValue = 'custom'; }
        field(16; "Header Mode"; Text[10]) { Caption = 'Header/footer: keep, default or custom'; InitValue = 'keep'; }
        field(17; "Apply To"; Text[10]) { Caption = 'Apply to: layout or company'; InitValue = 'layout'; }
        field(18; "Header Part App ID"; Guid) { Caption = 'Header/footer design app'; }
        // "Design your own" header/footer
        field(19; "HF Logo"; Text[10]) { Caption = 'Logo: right, left or none'; InitValue = 'right'; }
        field(20; "HF Page Number"; Text[10]) { Caption = 'Page number: header, footer or none'; InitValue = 'header'; }
        field(21; "HF Show Date"; Boolean) { Caption = 'Show date'; InitValue = true; }
        field(22; "HF Later Pages"; Text[10]) { Caption = 'Pages after the first: minimal or same'; InitValue = 'minimal'; }
        field(23; "HF Footer"; Text[10]) { Caption = 'Footer: contact, bank or none'; InitValue = 'contact'; }
        field(24; "HF Accent Line"; Boolean) { Caption = 'Accent line under the header'; }
        field(25; "HF Name"; Text[250]) { Caption = 'Save header/footer as'; InitValue = 'Custom Header/Footer'; }
        // The 12 theme colours (clrScheme order, comma-separated hex) when Palette = Custom.
        field(26; "Custom Colors"; Text[250]) { Caption = 'Custom colours'; }
        // The page colour (hex) when "Page Color" = Custom; always light, so it prints.
        field(27; "Custom Page Color"; Text[10]) { Caption = 'Custom page colour'; }
        // With Apply To = group: customer, vendor or internal (see "Report Style Doc Groups").
        field(28; "Apply Group"; Text[20]) { Caption = 'Apply to group'; }
        field(29; Composition; Enum "Report Style Composition") { Caption = 'Composition (draft)'; }
    }

    keys
    {
        key(PK; "Primary Key") { Clustered = true; }
    }
}
