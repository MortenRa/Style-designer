namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;

permissionset 50100 "REPORT STYLE DESIGN"
{
    Caption = 'Theme Designer';
    Assignable = true;

    // The designer stores generated themes and assigns themes and header/footers to reports,
    // which are platform tables.
    Permissions =
        tabledata "Report Style Config" = RIMD,
        tabledata "Report Style Preview Data" = RIMD,
        tabledata "Report Style Gallery Job" = RIMD,
        tabledata "Report Style Suggestion" = RIMD,
        table "Report Style Suggestion" = X,
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
        codeunit "Report Style Directions" = X,
        // Designers send designs for approval; changing a request (approve, reject, activate) needs THEME APPROVE.
        tabledata "Report Style Approval" = RI,
        table "Report Style Approval" = X,
        codeunit "Report Style Approvals" = X,
        page "Report Style Approvals" = X,
        page "Report Style Copilot" = X,
        table "Report Style Proposal" = X;
}
