namespace Abakion.ThemeDesigner.TestReports;

/// Run the four test reports (copies of BCApps PR #11205 Inventory reports with their new body layouts).
permissionset 50150 "TD TEST REPORTS"
{
    Assignable = true;
    Caption = 'Theme Designer test reports';
    Permissions = report "TD Inventory Order Details" = X,
        report "TD Inventory - Customer Sales" = X,
        report "TD Inv. - Sales Back Orders" = X,
        report "TD Inv. - Vendor Purchases" = X;
}