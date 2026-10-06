namespace Abakion.ReportStyleDesigner;

using System.Administration.Reports;

/// A header/footer design owned by an extension, as BaseApp's designs are in SaaS. Used by the mode test to check
/// that app-owned designs are referenced with their app ID (the platform rejects the empty GUID for them).
reportextension 50116 "RSD Test Parts" extends "Tenant Report Defaults"
{
    rendering
    {
        layout(RSDTestHFDesign)
        {
            Caption = 'RSD Test Header/Footer';
            LayoutFile = 'layouts\RSDTestHeaderFooter.docx';
            Type = Word;
            Subtype = HeaderFooter;
        }
    }
}
