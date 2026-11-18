namespace Abakion.ReportStyleDesigner;

/// Approvers: everything a designer can do, plus approving, rejecting and activating designs.
permissionset 50101 "THEME APPROVE"
{
    Caption = 'Theme Designer - Approve';
    Assignable = true;
    IncludedPermissionSets = "REPORT STYLE DESIGN";

    Permissions =
        tabledata "Report Style Approval" = RIMD;
}