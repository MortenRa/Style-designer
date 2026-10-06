namespace Abakion.ReportStyleDesigner;

using System.IO;
using System.Reflection;
using System.Utilities;

/// Mirrors codeunit 134620 "Report Theme Generator Tests" so it can run via Invoke-NAVCodeunit,
/// and writes the generated themes to disk for the compose + PDF harness.
codeunit 50101 "Theme Generator Runner"
{
    var
        ThemeEntryTok: Label 'word/theme/theme1.xml', Locked = true;
        StylesEntryTok: Label 'word/styles.xml', Locked = true;
        DocumentEntryTok: Label 'word/document.xml', Locked = true;
        SettingsEntryTok: Label 'word/settings.xml', Locked = true;
        Passed: Integer;

    trigger OnRun()
    begin
        ColorReplacesSystemColorWithRgb();
        UnsetColorsKeepBaseValues();
        FontsAreWrittenToFontScheme();
        ThemeNameIsWrittenToSchemes();
        PageColorIsAddedWithDisplayFlag();
        EmptyPageColorRemovesBackground();
        BaseFontSizeIsWrittenToDocDefaults();
        InvalidColorIsRejected();
        NonThemeFileIsRejected();
        GeneratedThemePassesLayoutValidation();
        BoldHeaderFillsHeaderRowWithAccent();
        WriteDemoThemes();
        Message('ALL %1 CHECKS PASSED', Passed);
    end;

    local procedure ColorReplacesSystemColorWithRgb()
    var
        Generator: Codeunit "Report Theme Generator";
        Generated: Codeunit "Temp Blob";
    begin
        Generator.SetColor("Report Theme Color Slot"::Light1, '#fff8e7');
        Generate(Generator, 'DefaultTheme', Generated);
        AreEqual('FFF8E7', GetValue(Generated, ThemeEntryTok, '//a:clrScheme/a:lt1/a:srgbClr/@val'), 'Light 1');
        IsFalse(HasNode(Generated, ThemeEntryTok, '//a:clrScheme/a:lt1/a:sysClr'), 'Light 1 still holds a system colour');
    end;

    local procedure UnsetColorsKeepBaseValues()
    var
        Generator: Codeunit "Report Theme Generator";
        Base: Codeunit "Temp Blob";
        Generated: Codeunit "Temp Blob";
    begin
        GetBaseTheme('DefaultTheme', Base);
        Generator.SetColor("Report Theme Color Slot"::Accent1, '4D614C');
        Generate(Generator, 'DefaultTheme', Generated);
        AreEqual('4D614C', GetValue(Generated, ThemeEntryTok, '//a:clrScheme/a:accent1/a:srgbClr/@val'), 'Accent 1');
        AreEqual(GetValue(Base, ThemeEntryTok, '//a:clrScheme/a:accent3/a:srgbClr/@val'), GetValue(Generated, ThemeEntryTok, '//a:clrScheme/a:accent3/a:srgbClr/@val'), 'Accent 3 kept');
    end;

    local procedure FontsAreWrittenToFontScheme()
    var
        Generator: Codeunit "Report Theme Generator";
        Generated: Codeunit "Temp Blob";
    begin
        Generator.SetFonts('Georgia', 'Verdana');
        Generate(Generator, 'DefaultTheme', Generated);
        AreEqual('Georgia', GetValue(Generated, ThemeEntryTok, '//a:fontScheme/a:majorFont/a:latin/@typeface'), 'Heading font');
        AreEqual('Verdana', GetValue(Generated, ThemeEntryTok, '//a:fontScheme/a:minorFont/a:latin/@typeface'), 'Body font');
    end;

    local procedure ThemeNameIsWrittenToSchemes()
    var
        Generator: Codeunit "Report Theme Generator";
        Generated: Codeunit "Temp Blob";
    begin
        Generator.SetThemeName('Nature');
        Generate(Generator, 'DefaultTheme', Generated);
        AreEqual('Nature', GetValue(Generated, ThemeEntryTok, '/a:theme/@name'), 'Theme name');
        AreEqual('Nature', GetValue(Generated, ThemeEntryTok, '//a:clrScheme/@name'), 'Colour scheme name');
        AreEqual('Nature', GetValue(Generated, ThemeEntryTok, '//a:fontScheme/@name'), 'Font scheme name');
    end;

    local procedure PageColorIsAddedWithDisplayFlag()
    var
        Generator: Codeunit "Report Theme Generator";
        Generated: Codeunit "Temp Blob";
    begin
        Generator.SetPageColor('EAEDE4');
        Generate(Generator, 'DefaultTheme', Generated);
        AreEqual('EAEDE4', GetValue(Generated, DocumentEntryTok, '/w:document/w:background/@w:color'), 'Page colour');
        IsTrue(HasNode(Generated, DocumentEntryTok, '/w:document/*[1][self::w:background]'), 'w:background must be first in w:document');
        IsTrue(HasNode(Generated, SettingsEntryTok, '/w:settings/w:displayBackgroundShape'), 'displayBackgroundShape');
    end;

    local procedure EmptyPageColorRemovesBackground()
    var
        Generator: Codeunit "Report Theme Generator";
        Generated: Codeunit "Temp Blob";
    begin
        Generator.SetPageColor('');
        Generate(Generator, 'CalmTheme', Generated);
        IsFalse(HasNode(Generated, DocumentEntryTok, '/w:document/w:background'), 'Page colour not removed');
    end;

    local procedure BaseFontSizeIsWrittenToDocDefaults()
    var
        Generator: Codeunit "Report Theme Generator";
        Generated: Codeunit "Temp Blob";
    begin
        Generator.SetBaseFontSize(10.5);
        Generate(Generator, 'DefaultTheme', Generated);
        AreEqual('21', GetValue(Generated, StylesEntryTok, '/w:styles/w:docDefaults/w:rPrDefault/w:rPr/w:sz/@w:val'), 'sz');
        AreEqual('21', GetValue(Generated, StylesEntryTok, '/w:styles/w:docDefaults/w:rPrDefault/w:rPr/w:szCs/@w:val'), 'szCs');
    end;

    local procedure InvalidColorIsRejected()
    begin
        IsFalse(TrySetColor('green'), 'green accepted');
        ExpectError('is not a valid colour');
        IsFalse(TrySetPageColor('12345G'), '12345G accepted');
        ExpectError('is not a valid colour');
    end;

    local procedure NonThemeFileIsRejected()
    var
        DataCompression: Codeunit "Data Compression";
        NotATheme: Codeunit "Temp Blob";
        ContentOutStream: OutStream;
    begin
        DataCompression.CreateZipArchive();
        NotATheme.CreateOutStream(ContentOutStream);
        ContentOutStream.WriteText('<w:document/>');
        DataCompression.AddEntry(NotATheme.CreateInStream(), DocumentEntryTok);
        DataCompression.SaveZipArchive(NotATheme);
        IsFalse(TryGenerate(NotATheme), 'non-theme accepted');
        ExpectError(ThemeEntryTok);
    end;

    local procedure GeneratedThemePassesLayoutValidation()
    var
        Generator: Codeunit "Report Theme Generator";
        Generated: Codeunit "Temp Blob";
        Prepared: Codeunit "Temp Blob";
        PreparedInStream: InStream;
    begin
        Generator.SetThemeName('Nature');
        Generator.SetColor("Report Theme Color Slot"::Accent1, '4D614C');
        Generator.SetFonts('Georgia', 'Verdana');
        Generator.SetBaseFontSize(9);
        Generator.SetPageColor('F7F7F2');
        Generate(Generator, 'DefaultTheme', Generated);
        DiagnoseValidation();
        PreparedInStream := Prepared.CreateInStream(TextEncoding::UTF8);
        ClearLastError();
        IsTrue(Report.ValidateAndPrepareLayout(2000000001, Generated.CreateInStream(TextEncoding::UTF8), PreparedInStream, ReportLayoutType::Word), 'rejected by layout validation: ' + GetLastErrorText());
    end;

    local procedure BoldHeaderFillsHeaderRowWithAccent()
    var
        Generator: Codeunit "Report Theme Generator";
        Generated: Codeunit "Temp Blob";
        Prepared: Codeunit "Temp Blob";
        PreparedInStream: InStream;
        HeaderRow: Text;
    begin
        Generator.SetColor("Report Theme Color Slot"::Accent3, 'C2502A');
        Generator.SetTableStyle("Report Theme Table Style"::BoldHeader);
        Generate(Generator, 'DefaultTheme', Generated);
        HeaderRow := '/w:styles/w:style[@w:styleId=''BCDataTable'']/w:tblStylePr[@w:type=''firstRow'']';
        AreEqual('accent3', GetValue(Generated, StylesEntryTok, HeaderRow + '/w:tcPr/w:shd/@w:themeFill'), 'header fill theme colour');
        AreEqual('E7B9AA', GetValue(Generated, StylesEntryTok, HeaderRow + '/w:tcPr/w:shd/@w:fill'), 'header fill 40% tint');
        AreEqual('66', GetValue(Generated, StylesEntryTok, HeaderRow + '/w:tcPr/w:shd/@w:themeFillTint'), 'header tint');
        AreEqual('accent3', GetValue(Generated, StylesEntryTok, HeaderRow + '/w:tcPr/w:tcBorders/w:bottom/@w:themeColor'), 'header rule');
        AreEqual('accent3', GetValue(Generated, StylesEntryTok, '/w:styles/w:style[@w:styleId=''BCTotalsTable'']/w:tblStylePr[@w:type=''lastRow'']/w:tcPr/w:tcBorders/w:bottom/@w:themeColor'), 'totals rule');
        PreparedInStream := Prepared.CreateInStream(TextEncoding::UTF8);
        IsTrue(Report.ValidateAndPrepareLayout(2000000001, Generated.CreateInStream(TextEncoding::UTF8), PreparedInStream, ReportLayoutType::Word), 'table-styled theme rejected: ' + GetLastErrorText());
    end;

    local procedure DiagnoseValidation()
    var
        Unchanged: Codeunit "Report Theme Generator";
        Base: Codeunit "Temp Blob";
        RoundTrip: Codeunit "Temp Blob";
        Prepared: Codeunit "Temp Blob";
        PreparedInStream: InStream;
        BaseOk: Boolean;
        RoundTripOk: Boolean;
        BaseError: Text;
    begin
        GetBaseTheme('DefaultTheme', Base);
        PreparedInStream := Prepared.CreateInStream(TextEncoding::UTF8);
        ClearLastError();
        BaseOk := Report.ValidateAndPrepareLayout(2000000001, Base.CreateInStream(TextEncoding::UTF8), PreparedInStream, ReportLayoutType::Word);
        BaseError := GetLastErrorText();

        Generate(Unchanged, 'DefaultTheme', RoundTrip);
        Clear(Prepared);
        PreparedInStream := Prepared.CreateInStream(TextEncoding::UTF8);
        ClearLastError();
        RoundTripOk := Report.ValidateAndPrepareLayout(2000000001, RoundTrip.CreateInStream(TextEncoding::UTF8), PreparedInStream, ReportLayoutType::Word);
        if not (BaseOk and RoundTripOk) then
            Error('DIAG: base valid=%1 (%2); round trip valid=%3 (%4)', BaseOk, BaseError, RoundTripOk, GetLastErrorText());
    end;

    local procedure WriteDemoThemes()
    var
        Generator: Codeunit "Report Theme Generator";
        Unchanged: Codeunit "Report Theme Generator";
        Generated: Codeunit "Temp Blob";
    begin
        // "Nature" from the mockup: green palette, Georgia/Verdana, light green page, 9 pt body.
        Generator.SetThemeName('Nature');
        Generator.SetColor("Report Theme Color Slot"::Dark1, '2F3E2E');
        Generator.SetColor("Report Theme Color Slot"::Dark2, '2F3E2E');
        Generator.SetColor("Report Theme Color Slot"::Light1, 'FFFFFF');
        Generator.SetColor("Report Theme Color Slot"::Light2, 'EEF3E8');
        Generator.SetColor("Report Theme Color Slot"::Accent1, 'EEF3E8');
        Generator.SetColor("Report Theme Color Slot"::Accent2, 'C9D8BD');
        Generator.SetColor("Report Theme Color Slot"::Accent3, '4F7A3A');
        Generator.SetColor("Report Theme Color Slot"::Accent4, '8AA668');
        Generator.SetColor("Report Theme Color Slot"::Accent5, 'B5651D');
        Generator.SetColor("Report Theme Color Slot"::Accent6, '5A7D8C');
        Generator.SetFonts('Georgia', 'Verdana');
        Generator.SetBaseFontSize(9);
        Generator.SetPageColor('F4F8EF');
        Generate(Generator, 'DefaultTheme', Generated);
        WriteFile(Generated, 'Nature.dotx');

        // Base unchanged through the generator: proves the round trip alone does not alter rendering.
        Generate(Unchanged, 'DefaultTheme', Generated);
        WriteFile(Generated, 'Default-roundtrip.dotx');
        Passed += 1;
    end;

    [TryFunction]
    local procedure TrySetColor(Value: Text)
    var
        Generator: Codeunit "Report Theme Generator";
    begin
        Generator.SetColor("Report Theme Color Slot"::Accent1, Value);
    end;

    [TryFunction]
    local procedure TrySetPageColor(Value: Text)
    var
        Generator: Codeunit "Report Theme Generator";
    begin
        Generator.SetPageColor(Value);
    end;

    [TryFunction]
    local procedure TryGenerate(Package: Codeunit "Temp Blob")
    var
        Generator: Codeunit "Report Theme Generator";
        Generated: Codeunit "Temp Blob";
    begin
        Generator.Generate(Package.CreateInStream(), Generated);
    end;

    local procedure Generate(var Generator: Codeunit "Report Theme Generator"; BaseName: Text; var Generated: Codeunit "Temp Blob")
    var
        Base: Codeunit "Temp Blob";
    begin
        GetBaseTheme(BaseName, Base);
        Generator.Generate(Base.CreateInStream(), Generated);
    end;

    local procedure GetBaseTheme(LayoutName: Text; var Theme: Codeunit "Temp Blob")
    var
        ReportLayoutList: Record "Report Layout List";
        LayoutOutStream: OutStream;
    begin
        ReportLayoutList.SetRange("Report ID", 2000000001);
        ReportLayoutList.SetRange(Name, LayoutName);
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Theme);
        ReportLayoutList.FindFirst();
        Theme.CreateOutStream(LayoutOutStream);
        ReportLayoutList.Layout.ExportStream(LayoutOutStream);
    end;

    local procedure LoadPart(Package: Codeunit "Temp Blob"; EntryName: Text; var Document: XmlDocument; var NamespaceManager: XmlNamespaceManager)
    var
        DataCompression: Codeunit "Data Compression";
        Entry: Codeunit "Temp Blob";
    begin
        DataCompression.OpenZipArchive(Package, false);
        DataCompression.ExtractEntry(EntryName, Entry);
        DataCompression.CloseZipArchive();
        XmlDocument.ReadFrom(Entry.CreateInStream(TextEncoding::UTF8), Document);
        NamespaceManager.NameTable(Document.NameTable());
        NamespaceManager.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        NamespaceManager.AddNamespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main');
    end;

    local procedure GetValue(Package: Codeunit "Temp Blob"; EntryName: Text; XPath: Text): Text
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Node: XmlNode;
    begin
        LoadPart(Package, EntryName, Document, NamespaceManager);
        if not Document.SelectSingleNode(XPath, NamespaceManager, Node) then
            Error('FAIL: %1 not found in %2', XPath, EntryName);
        exit(Node.AsXmlAttribute().Value());
    end;

    local procedure HasNode(Package: Codeunit "Temp Blob"; EntryName: Text; XPath: Text): Boolean
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Node: XmlNode;
    begin
        LoadPart(Package, EntryName, Document, NamespaceManager);
        exit(Document.SelectSingleNode(XPath, NamespaceManager, Node));
    end;

    local procedure WriteFile(Content: Codeunit "Temp Blob"; FileName: Text)
    var
        OutFile: File;
        FileOutStream: OutStream;
    begin
        OutFile.Create(TemporaryPath + 'themegen-' + FileName);
        OutFile.CreateOutStream(FileOutStream);
        CopyStream(FileOutStream, Content.CreateInStream());
        OutFile.Close();
    end;

    local procedure AreEqual(Expected: Text; Actual: Text; What: Text)
    begin
        if Expected <> Actual then
            Error('FAIL: %1 - expected <%2>, got <%3>', What, Expected, Actual);
        Passed += 1;
    end;

    local procedure IsTrue(Condition: Boolean; What: Text)
    begin
        if not Condition then
            Error('FAIL: %1', What);
        Passed += 1;
    end;

    local procedure IsFalse(Condition: Boolean; What: Text)
    begin
        IsTrue(not Condition, What);
    end;

    local procedure ExpectError(Fragment: Text)
    begin
        if StrPos(GetLastErrorText(), Fragment) = 0 then
            Error('FAIL: expected error containing <%1>, got <%2>', Fragment, GetLastErrorText());
        Passed += 1;
    end;
}
