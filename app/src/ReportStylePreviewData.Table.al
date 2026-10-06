namespace Abakion.ReportStyleDesigner;

/// The preview data (request page parameters) chosen for a report, so the "Your documents" gallery can show each
/// document with real data instead of everything the report would print by default.
table 50102 "Report Style Preview Data"
{
    Caption = 'Report Style Preview Data';
    Access = Internal;
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Report ID"; Integer) { Caption = 'Report'; }
        field(2; Parameters; Blob) { Caption = 'Request page parameters'; }
    }

    keys
    {
        key(PK; "Report ID") { Clustered = true; }
    }
}
