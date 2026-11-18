namespace Abakion.ReportStyleDesigner;

/// Where a design is on its way to the customers: sent, approved, rejected, or active on the documents.
enum 50106 "Report Style Approval Status"
{
    Extensible = false;

    value(0; Pending) { Caption = 'Waiting for approval'; }
    value(1; Approved) { Caption = 'Approved'; }
    value(2; Rejected) { Caption = 'Rejected'; }
    value(3; Active) { Caption = 'Active'; }
}
