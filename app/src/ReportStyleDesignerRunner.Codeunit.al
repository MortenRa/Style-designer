namespace Abakion.ReportStyleDesigner;

using System.Utilities;

/// Runs a save through Codeunit.Run, and a preview as three protected steps (setup, render, cleanup), so a failure
/// rolls back and comes back as text instead of breaking the page (try functions may not write to the database).
codeunit 50105 "Report Style Designer Runner"
{
    Access = Internal;
    TableNo = "Report Style Config";

    trigger OnRun()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        ResultText := DesignerMgt.Save(Rec, SaveMode);
    end;

    var
        Pdf: Codeunit "Temp Blob";
        SaveMode: Text;
        ResultText: Text;
        ErrorText: Text;
        CleanupErrorText: Text;
        BusyErr: Label 'This report is being previewed in another window. Try again in a moment.';

    procedure SetSaveMode(NewSaveMode: Text)
    begin
        SaveMode := NewSaveMode;
    end;

    /// Renders a per-user preview. Cleanup always runs, also when rendering fails hard (for example a deadlock).
    /// Call without an open write transaction.
    procedure Preview(var Config: Record "Report Style Config"): Boolean
    var
        PreviewStep: Codeunit "Report Style Preview Step";
        Attempt: Integer;
        Succeeded: Boolean;
        CleanedUp: Boolean;
    begin
        Clear(Pdf);
        ErrorText := '';
        CleanupErrorText := '';
        // Setup is retried once: two previews running at the same time can deadlock on the layout tables.
        for Attempt := 1 to 2 do
            if not Succeeded then begin
                PreviewStep.SetStep('setup');
                Succeeded := PreviewStep.Run(Config);
                if not Succeeded then begin
                    ErrorText := GetLastErrorText();
                    if not ErrorText.Contains('deadlock') then
                        Attempt := 2
                    else
                        Sleep(200 + Random(300));
                end;
            end;
        if Succeeded then begin
            PreviewStep.SetStep('render');
            Succeeded := PreviewStep.Run(Config);
            if not Succeeded then
                ErrorText := GetLastErrorText();
        end;

        // Cleanup must not be skipped, so it is retried; what still fails is removed as stale after 10 minutes.
        PreviewStep.SetStep('cleanup');
        for Attempt := 1 to 3 do
            if not CleanedUp then begin
                CleanedUp := PreviewStep.Run(Config);
                if not CleanedUp then begin
                    CleanupErrorText := GetLastErrorText();
                    Sleep(200 + Random(300));
                end;
            end;

        if Succeeded then
            PreviewStep.GetPdf(Pdf)
        else
            if ErrorText.Contains('deadlock') then
                ErrorText := BusyErr;
        exit(Succeeded);
    end;

    procedure GetPdf(var Result: Codeunit "Temp Blob")
    begin
        Result := Pdf;
    end;

    procedure GetResultText(): Text
    begin
        exit(ResultText);
    end;

    procedure GetCleanupErrorText(): Text
    begin
        exit(CleanupErrorText);
    end;

    procedure GetErrorText(): Text
    begin
        exit(ErrorText);
    end;
}
