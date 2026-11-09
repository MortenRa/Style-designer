namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;

permissionset 50100 "REPORT STYLE DESIGN"
{
    Caption = 'Report Style Designer';
    Assignable = true;

    // The designer stores generated themes and assigns themes and header/footers to reports,
    // which are platform tables.
    Permissions =
        tabledata "Report Style Config" = RIMD,
        tabledata "Report Style Preview Data" = RIMD,
        tabledata "Report Style Gallery Job" = RIMD,
        table "Report Style Gallery Job" = X,
        codeunit "Report Style Gallery Jobs" = X,
        table "Report Style Preview Data" = X,
        tabledata "Tenant Report Layout" = RIMD,
        tabledata "Tenant Report Layout Cfg" = RIMD,
        tabledata "Tenant Report Layout Selection" = RIMD,
        table "Report Style Config" = X,
        page "Report Style Designer" = X,
        page "Report Style Start" = X,
        page "Report Style Body Layouts" = X,
        codeunit "Report Theme Generator" = X,
        codeunit "Report Header Footer Generator" = X,
        codeunit "Report Style Configurator Mgt." = X,
        codeunit "Report Style Designer Mgt." = X,
        codeunit "Report Style Designer Runner" = X,
        codeunit "Report Style Preview Step" = X,
        codeunit "Report Style Copilot" = X,
        codeunit "Report Style Propose Themes" = X,
        codeunit "Report Style Theme Rules" = X,
        page "Report Style Copilot" = X,
        table "Report Style Proposal" = X;
}
