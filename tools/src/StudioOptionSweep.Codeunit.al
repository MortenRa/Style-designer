namespace Abakion.ReportStyleDesigner;

using System.IO;
using System.Reflection;
using System.Utilities;

/// Renders every studio option on every Body layout through the same preview path the studio uses, and writes
/// sweep\NNN.pdf plus sweep\manifest.txt (one line per render, with what the PDF should contain) to the session
/// temp folder. sweep-check.ps1 then verifies fonts and page colour in the PDFs.
codeunit 50110 "Studio Option Sweep"
{
    var
        ConfiguratorMgt: Codeunit "Report Style Configurator Mgt.";
        ManifestOutStream: OutStream;
        Folder: Text;
        CaseNo: Integer;
        Designing: Boolean;
        DesignLogo: Text;
        DesignPageNumber: Text;
        DesignShowDate: Boolean;
        DesignLaterPages: Text;
        DesignFooter: Text;
        DesignAccentLine: Boolean;
        Failed: Integer;

    trigger OnRun()
    var
        BodyLayouts: Record "Report Layout List";
        ManifestFile: File;
    begin
        Folder := TemporaryPath + 'sweep\';
        ManifestFile.Create(Folder + 'manifest.txt');
        ManifestFile.CreateOutStream(ManifestOutStream);
        ManifestOutStream.WriteText('case|report|layout|scenario|result|ms|bodyFont|headingFont|pageHex|error');
        ManifestOutStream.WriteText();

        BodyLayouts.SetRange("Layout Subtype", BodyLayouts."Layout Subtype"::Body);
        BodyLayouts.SetFilter(Name, '<>Preview*');
        if BodyLayouts.FindSet() then
            repeat
                SweepLayout(BodyLayouts);
            until BodyLayouts.Next() = 0;

        ManifestFile.Close();
        Message('SWEEP DONE: %1 renders, %2 failed', CaseNo, Failed);
    end;

    local procedure SweepLayout(BodyLayout: Record "Report Layout List")
    var
        Themes: Record "Report Layout List";
        Headers: Record "Report Layout List";
        Ordinal: Integer;
        TableOrdinal: Integer;
    begin
        Themes.SetRange("Report ID", 2000000001);
        Themes.SetRange("Layout Subtype", Themes."Layout Subtype"::Theme);
        Themes.SetFilter(Name, '<>Preview*');
        if Themes.FindSet() then
            repeat
                if HasThemePart(Themes) then
                    foreach TableOrdinal in Enum::"Report Theme Table Style".Ordinals() do
                        RunCase(BodyLayout, Themes.Name, 0, 0, 0, 0, TableOrdinal, '',
                            StrSubstNo('theme %1 + table %2', Themes.Name, Format(Enum::"Report Theme Table Style".FromInteger(TableOrdinal))));
            until Themes.Next() = 0;

        foreach Ordinal in Enum::"Report Style Palette".Ordinals() do
            if Ordinal <> Enum::"Report Style Palette"::Custom.AsInteger() then
                RunCase(BodyLayout, 'DefaultTheme', Ordinal, 0, 0, 0, 4, '', 'palette ' + Format(Enum::"Report Style Palette".FromInteger(Ordinal)) + ' + bold header');
        foreach Ordinal in Enum::"Report Style Font Pair".Ordinals() do
            RunCase(BodyLayout, 'DefaultTheme', 0, Ordinal, 0, 0, 0, '', 'fonts ' + Format(Enum::"Report Style Font Pair".FromInteger(Ordinal)));
        foreach Ordinal in Enum::"Report Style Page Color".Ordinals() do
            if Ordinal <> Enum::"Report Style Page Color"::Custom.AsInteger() then
                RunCase(BodyLayout, 'DefaultTheme', 0, 0, 0, Ordinal, 0, '', 'page ' + Format(Enum::"Report Style Page Color".FromInteger(Ordinal)));
        RunCase(BodyLayout, 'DefaultTheme', 0, 0, 7, 0, 0, '', 'size 7 pt');
        RunCase(BodyLayout, 'DefaultTheme', 0, 0, 10, 0, 0, '', 'size 10 pt');
        RunCase(BodyLayout, 'DefaultTheme', 0, 0, 12, 0, 0, '', 'size 12 pt');

        RunDesign(BodyLayout, 'right', 'header', true, 'minimal', 'contact', false, 'designed: as base');
        RunDesign(BodyLayout, 'left', 'header', true, 'minimal', 'contact', false, 'designed: logo left');
        RunDesign(BodyLayout, 'none', 'header', true, 'minimal', 'contact', false, 'designed: no logo');
        RunDesign(BodyLayout, 'right', 'footer', true, 'minimal', 'contact', false, 'designed: page number in footer');
        RunDesign(BodyLayout, 'right', 'none', false, 'minimal', 'contact', false, 'designed: no page number, no date');
        RunDesign(BodyLayout, 'right', 'header', true, 'same', 'bank', false, 'designed: same header, contact + bank');
        RunDesign(BodyLayout, 'right', 'footer', true, 'minimal', 'none', false, 'designed: no footer, page number in footer');
        RunDesign(BodyLayout, 'left', 'footer', false, 'same', 'bank', true, 'designed: everything changed + accent line');

        Headers.SetRange("Report ID", 2000000001);
        Headers.SetRange("Layout Subtype", Headers."Layout Subtype"::HeaderFooter);
        Headers.SetFilter(Name, '<>Preview*');
        if Headers.FindSet() then
            repeat
                RunCase(BodyLayout, 'DefaultTheme', 1, 2, 0, 2, 4, Headers.Name, 'header ' + Headers.Name + ' + Nature/Georgia/green/bold');
            until Headers.Next() = 0;
    end;

    // Designed header/footer with Nature palette and Georgia/Verdana, so "match theme" shows in the fonts check.
    local procedure RunDesign(BodyLayout: Record "Report Layout List"; Logo: Text; PageNumber: Text; ShowDate: Boolean; LaterPages: Text; Footer: Text; AccentLine: Boolean; Scenario: Text)
    begin
        DesignLogo := Logo;
        DesignPageNumber := PageNumber;
        DesignShowDate := ShowDate;
        DesignLaterPages := LaterPages;
        DesignFooter := Footer;
        DesignAccentLine := AccentLine;
        Designing := true;
        RunCase(BodyLayout, 'DefaultTheme', 1, 2, 0, 0, 4, '', Scenario);
        Designing := false;
    end;

    local procedure RunCase(BodyLayout: Record "Report Layout List"; BaseTheme: Text; Palette: Integer; FontPair: Integer; Size: Decimal; PageColor: Integer; TableStyle: Integer; HeaderPart: Text; Scenario: Text)
    var
        Config: Record "Report Style Config" temporary;
        Runner: Codeunit "Report Style Designer Runner";
        Pdf: Codeunit "Temp Blob";
        PdfFile: File;
        PdfOutStream: OutStream;
        HeadingFont: Text;
        BodyFont: Text;
        PageHex: Text;
        Started: DateTime;
        Result: Text;
        ErrorText: Text;
    begin
        CaseNo += 1;
        Config.Init();
        Config."Target Report ID" := BodyLayout."Report ID";
        Config."Target Layout Name" := BodyLayout.Name;
        Config."Target Layout App ID" := BodyLayout."Application ID";
        Config."Base Theme" := CopyStr(BaseTheme, 1, MaxStrLen(Config."Base Theme"));
        Config.Palette := Enum::"Report Style Palette".FromInteger(Palette);
        Config."Font Pair" := Enum::"Report Style Font Pair".FromInteger(FontPair);
        Config."Base Font Size" := Size;
        Config."Page Color" := Enum::"Report Style Page Color".FromInteger(PageColor);
        Config."Table Style" := Enum::"Report Theme Table Style".FromInteger(TableStyle);
        Config."Header Part" := CopyStr(HeaderPart, 1, MaxStrLen(Config."Header Part"));
        if HeaderPart <> '' then
            Config."Header Mode" := 'custom';
        if Designing then begin
            Config."Header Mode" := 'design';
            Config."HF Logo" := CopyStr(DesignLogo, 1, 10);
            Config."HF Page Number" := CopyStr(DesignPageNumber, 1, 10);
            Config."HF Show Date" := DesignShowDate;
            Config."HF Later Pages" := CopyStr(DesignLaterPages, 1, 10);
            Config."HF Footer" := CopyStr(DesignFooter, 1, 10);
            Config."HF Accent Line" := DesignAccentLine;
        end;
        Config.Insert();

        ConfiguratorMgt.GetFontPair(Config."Font Pair", HeadingFont, BodyFont);
        if Config."Page Color" = Config."Page Color"::White then
            PageHex := 'FFFFFF'
        else
            PageHex := ConfiguratorMgt.GetPageColorHex(Config."Page Color");

        Commit();
        Started := CurrentDateTime();
        if Runner.Preview(Config) then begin
            Runner.GetPdf(Pdf);
            PdfFile.Create(Folder + Format(CaseNo, 0, '<Integer,3><Filler Character,0>') + '.pdf');
            PdfFile.CreateOutStream(PdfOutStream);
            CopyStream(PdfOutStream, Pdf.CreateInStream());
            PdfFile.Close();
            Result := 'OK';
        end else begin
            Result := 'FAIL';
            ErrorText := Runner.GetErrorText().Replace('|', '/');
            Failed += 1;
        end;

        ManifestOutStream.WriteText(StrSubstNo('%1|%2|%3|%4|%5|%6|%7|%8|%9|', CaseNo, BodyLayout."Report ID", BodyLayout.Name, Scenario, Result,
            Round((CurrentDateTime() - Started) / 1, 1), BodyFont, HeadingFont, PageHex) + ErrorText);
        ManifestOutStream.WriteText();
    end;

    local procedure HasThemePart(var ReportLayoutList: Record "Report Layout List"): Boolean
    var
        DataCompression: Codeunit "Data Compression";
        Layout: Codeunit "Temp Blob";
        LayoutOutStream: OutStream;
        Entries: List of [Text];
    begin
        Layout.CreateOutStream(LayoutOutStream);
        ReportLayoutList.Layout.ExportStream(LayoutOutStream);
        if not DataCompression.IsZip(Layout.CreateInStream()) then
            exit(false);
        DataCompression.OpenZipArchive(Layout, false);
        DataCompression.GetEntryList(Entries);
        DataCompression.CloseZipArchive();
        exit(Entries.Contains('word/theme/theme1.xml'));
    end;
}
