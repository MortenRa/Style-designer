namespace Abakion.ReportStyleDesigner;

using System.Utilities;

/// Control renders for the sweep's Times New Roman findings: the same header/footer designs with the base theme
/// unchanged, versus with Georgia/Verdana. Writes control\N.pdf to the session temp folder.
codeunit 50111 "Sweep Control"
{
    trigger OnRun()
    begin
        Render(1, 107, 'InternalMinimalisticCenteredHFDesign', 0);
        Render(2, 107, 'InternalMinimalisticCenteredHFDesign', 2);
        Render(3, 115, 'ExternalModernHFDesign', 0);
        Render(4, 115, 'ExternalModernHFDesign', 2);
        Render(5, 115, 'InternalModernMaxiHFDesign', 0);
        Render(6, 115, 'InternalModernMaxiHFDesign', 1);
    end;

    local procedure Render(No: Integer; ReportID: Integer; HeaderPart: Text; FontPair: Integer)
    var
        Config: Record "Report Style Config" temporary;
        Runner: Codeunit "Report Style Designer Runner";
        Pdf: Codeunit "Temp Blob";
        PdfFile: File;
        PdfOutStream: OutStream;
    begin
        Config.Init();
        Config."Target Report ID" := ReportID;
        Config."Target Layout Name" := 'WordBody';
        Config."Base Theme" := 'DefaultTheme';
        Config."Font Pair" := Enum::"Report Style Font Pair".FromInteger(FontPair);
        Config."Header Part" := CopyStr(HeaderPart, 1, MaxStrLen(Config."Header Part"));
        if HeaderPart <> '' then
            Config."Header Mode" := 'custom';
        Config.Insert();
        Commit();
        if not Runner.Preview(Config) then
            Error('control %1 failed: %2', No, Runner.GetErrorText());
        Runner.GetPdf(Pdf);
        PdfFile.Create(TemporaryPath + 'control\' + Format(No) + '.pdf');
        PdfFile.CreateOutStream(PdfOutStream);
        CopyStream(PdfOutStream, Pdf.CreateInStream());
        PdfFile.Close();
    end;
}
