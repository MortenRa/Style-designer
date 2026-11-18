namespace Abakion.ReportStyleDesigner;

/// Actions on the Theme Designer's notifications.
codeunit 50142 "Report Style Notifications"
{
    Access = Internal;

    /// "Compare in the designer" on the Quick Start notification after Copilot made themes.
    procedure OpenDesigner(Created: Notification)
    var
        Designer: Page "Report Style Designer";
    begin
        Designer.Run();
    end;
}