namespace Abakion.ReportStyleDesigner;

codeunit 50122 "Report Style Copilot Install"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerDatabase()
    var
        ReportStyleCopilot: Codeunit "Report Style Copilot";
    begin
        ReportStyleCopilot.RegisterCapability();
    end;
}

codeunit 50123 "Report Style Copilot Upgrade"
{
    Subtype = Upgrade;
    Access = Internal;

    trigger OnUpgradePerDatabase()
    var
        ReportStyleCopilot: Codeunit "Report Style Copilot";
    begin
        ReportStyleCopilot.RegisterCapability();
    end;
}
