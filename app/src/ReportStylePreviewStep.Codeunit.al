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
        if Step = 'render' then begin
            Rendered := false;
            UsedPreviewLogo := UsePreviewLogo(Rec);
        end;
        case Step of
            'setup':
                DesignerMgt.PreviewSetup(Rec, PreviewName, Previous, HadPrevious);
            'render':
                begin
                    if not FormatSet then
                        OutputFormat := ReportFormat::Pdf;
                    DesignerMgt.PreviewRender(Rec, OutputFormat, Pdf);
                    Rendered := true;
                    // A trial logo was put in Company Information for this render only: undo it with the transaction.
                    if UsedPreviewLogo then
                        Error(RollBackTok);
                end;
            'cleanup':
                DesignerMgt.PreviewCleanup(Rec."Target Report ID", PreviewName, Previous, HadPrevious);
        end;
    end;

    var
        Previous: Record "Tenant Report Layout Selection" temporary;
        Pdf: Codeunit "Temp Blob";
        Step: Text;
        OutputFormat: ReportFormat;
        FormatSet: Boolean;
        PreviewName: Text[250];
        HadPrevious: Boolean;
        UsedPreviewLogo: Boolean;
        Rendered: Boolean;
        RollBackTok: Label 'Preview logo rolled back.', Locked = true;
        CompanyInformationTableTok: Label '79', Locked = true;

    procedure SetStep(NewStep: Text)
    begin
        Step := NewStep;
    end;

    /// The format the render step produces. PDF when not set.
    procedure SetFormat(NewFormat: ReportFormat)
    begin
        OutputFormat := NewFormat;
        FormatSet := true;
    end;

    /// True when the render used a trial logo and was rolled back on purpose: the PDF is still there.
    procedure RenderedWithPreviewLogo(): Boolean
    begin
        exit(UsedPreviewLogo and Rendered);
    end;

    // Puts the trial logo in Company Information (Picture) without committing; the render then reads it.
    local procedure UsePreviewLogo(var Config: Record "Report Style Config"): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        CompanyInformation: RecordRef;
        TableNo: Integer;
    begin
        Config.CalcFields("Preview Logo");
        if not Config."Preview Logo".HasValue() then
            exit(false);
        Evaluate(TableNo, CompanyInformationTableTok);
        CompanyInformation.Open(TableNo);
        if not CompanyInformation.WritePermission() then
            exit(false);
        if not CompanyInformation.FindFirst() then
            exit(false);
        TempBlob.FromRecord(Config, Config.FieldNo("Preview Logo"));
        TempBlob.ToRecordRef(CompanyInformation, 29);
        CompanyInformation.Modify();
        exit(true);
    end;

    procedure GetPdf(var Result: Codeunit "Temp Blob")
    begin
        Result := Pdf;
    end;
}
