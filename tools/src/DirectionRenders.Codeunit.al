namespace Abakion.ReportStyleDesigner;

using System.IO;
using System.Reflection;
using System.Utilities;

/// Renders the first Body layout of report 1306 (Sales Invoice), or else the first Body layout, once per design direction, to
/// direction-<n>-<name>.pdf in the session's temp folder, so the directions can be looked at side by side.
codeunit 50136 "Direction Renders"
{
    trigger OnRun()
    var
        BodyLayout: Record "Report Layout List";
        Ordinal: Integer;
        Rendered: Integer;
        Failed: Text;
    begin
        BodyLayout.SetRange("Report ID", 1306);
        BodyLayout.SetRange("Layout Subtype", BodyLayout."Layout Subtype"::Body);
        BodyLayout.SetFilter(Name, '<>Preview*');
        if BodyLayout.IsEmpty() then
            BodyLayout.SetRange("Report ID");
        BodyLayout.FindFirst();
        foreach Ordinal in Enum::"Report Style Direction".Ordinals() do
            if Ordinal <> 0 then
                if Render(BodyLayout, Enum::"Report Style Direction".FromInteger(Ordinal)) then
                    Rendered += 1
                else
                    Failed += Format(Enum::"Report Style Direction".FromInteger(Ordinal)) + ' ';
        Message('DIRECTION RENDERS: %1 to %2 (layout %3) %4', Rendered, TemporaryPath, BodyLayout.Name, Failed);
    end;

    local procedure Render(BodyLayout: Record "Report Layout List"; Direction: Enum "Report Style Direction"): Boolean
    var
        Config: Record "Report Style Config" temporary;
        Directions: Codeunit "Report Style Directions";
        Runner: Codeunit "Report Style Designer Runner";
        Pdf: Codeunit "Temp Blob";
        PdfFile: File;
        PdfOutStream: OutStream;
    begin
        Config.Init();
        Config."Target Report ID" := BodyLayout."Report ID";
        Config."Target Layout Name" := BodyLayout.Name;
        Config."Target Layout App ID" := BodyLayout."Application ID";
        Config."Base Theme" := 'DefaultTheme';
        Config.Direction := Direction;
        Directions.Apply(Config);
        Config.Insert();
        Commit();
        if not Runner.Preview(Config) then
            Error('%1: %2', Direction, Runner.GetErrorText());
        Runner.GetPdf(Pdf);
        PdfFile.Create(TemporaryPath + StrSubstNo('direction-%1-%2.pdf', Direction.AsInteger(), Format(Direction)));
        PdfFile.CreateOutStream(PdfOutStream);
        CopyStream(PdfOutStream, Pdf.CreateInStream());
        PdfFile.Close();
        WritePng(Pdf, TemporaryPath + StrSubstNo('direction-%1-%2.png', Direction.AsInteger(), Format(Direction)));
        exit(true);
    end;

    // Page 1 as a PNG (72 dpi), for a quick look without a PDF viewer.
    local procedure WritePng(Pdf: Codeunit "Temp Blob"; FileName: Text)
    var
        PdfDocument: Codeunit "PDF Document";
        Image: Codeunit "Temp Blob";
        ImageStream: InStream;
        PngFile: File;
        PngOutStream: OutStream;
    begin
        Image.CreateInStream(ImageStream);
        if not PdfDocument.Load(Pdf.CreateInStream()) then
            exit;
        if not PdfDocument.ConvertPdfToImage(ImageStream, Enum::"Image Format"::Png, 1) then
            exit;
        PngFile.Create(FileName);
        PngFile.CreateOutStream(PngOutStream);
        CopyStream(PngOutStream, ImageStream);
        PngFile.Close();
    end;
}
