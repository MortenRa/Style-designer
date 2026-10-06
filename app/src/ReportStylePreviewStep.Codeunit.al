namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;
using System.Utilities;

/// One step of a preview (setup, render or cleanup), run through Codeunit.Run by "Report Style Designer Runner".
/// The instance keeps the state between the steps, so cleanup can always run, also after a failed render.
codeunit 50115 "Report Style Preview Step"
{
    Access = Internal;
    TableNo = "Report Style Config";

    trigger OnRun()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        case Step of
            'setup':
                DesignerMgt.PreviewSetup(Rec, PreviewName, Previous, HadPrevious);
            'render':
                DesignerMgt.PreviewRender(Rec, Pdf);
            'cleanup':
                DesignerMgt.PreviewCleanup(Rec."Target Report ID", PreviewName, Previous, HadPrevious);
        end;
    end;

    var
        Previous: Record "Tenant Report Layout Selection" temporary;
        Pdf: Codeunit "Temp Blob";
        Step: Text;
        PreviewName: Text[250];
        HadPrevious: Boolean;

    procedure SetStep(NewStep: Text)
    begin
        Step := NewStep;
    end;

    procedure GetPdf(var Result: Codeunit "Temp Blob")
    begin
        Result := Pdf;
    end;
}
