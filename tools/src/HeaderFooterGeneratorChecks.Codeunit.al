namespace Abakion.ReportStyleDesigner;

using System.IO;
using System.Reflection;
using System.Utilities;

/// Checks of "Report Header Footer Generator" (Design your own header/footer), run via Invoke-NAVCodeunit.
codeunit 50118 "Header Footer Generator Checks"
{
    var
        Passed: Integer;
        BaseTok: Label 'ExternalDefaultDetailedHFDesign', Locked = true;
        W: Label 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', Locked = true;

    trigger OnRun()
    var
        Generated: Codeunit "Temp Blob";
        Base: Codeunit "Temp Blob";
        FirstHeader: Text;
        DefaultHeader: Text;
        FirstFooter: Text;
        DefaultFooter: Text;
        EvenFooter: Text;
    begin
        GetBase(Base);
        FirstHeader := PartOf(Base, 'header', 'first');
        DefaultHeader := PartOf(Base, 'header', 'default');
        FirstFooter := PartOf(Base, 'footer', 'first');
        DefaultFooter := PartOf(Base, 'footer', 'default');
        EvenFooter := PartOf(Base, 'footer', 'even');

        // defaults: layout as designed, but fonts and colours follow the theme, and the platform accepts it
        Generate('right', 'header', true, 'minimal', 'contact', false, Generated);
        IsTrue(Validates(Generated), 'default design rejected by layout validation: ' + GetLastErrorText());
        IsTrue(Count(Generated, FirstHeader, '//w:sdt[w:sdtPr/w:tag[contains(@w:val,''CompanyLogo'')]]') = 1, 'logo kept');
        IsTrue(CountInParts(Generated, '//w:rFonts[@w:ascii=''Segoe UI'' or @w:ascii=''Aptos'' or @w:ascii=''Aptos Narrow'']') = 0, 'fixed fonts left in header/footer');
        IsTrue(CountInParts(Generated, '//w:color[@w:val=''242424'' and not(@w:themeColor)]') = 0, 'fixed #242424 left in header/footer');
        IsTrue(CountInParts(Generated, '//w:color[@w:val=''242424'' and @w:themeColor=''text1'']') > 0, '#242424 mapped to text1');

        Generate('none', 'header', true, 'minimal', 'contact', false, Generated);
        IsTrue(Count(Generated, FirstHeader, '//w:sdt[w:sdtPr/w:tag[contains(@w:val,''CompanyLogo'')]]') = 0, 'logo none');
        IsTrue(Validates(Generated), 'logo none rejected');

        Generate('left', 'header', true, 'minimal', 'contact', false, Generated);
        IsTrue(Count(Generated, FirstHeader, '//w:tr/w:tc[1]//w:sdt[w:sdtPr/w:tag[contains(@w:val,''CompanyLogo'')]]') = 1, 'logo in the first column');
        IsTrue(Validates(Generated), 'logo left rejected');

        Generate('right', 'header', false, 'minimal', 'contact', false, Generated);
        IsTrue(CountInParts(Generated, '//w:sdt[w:sdtPr/w:tag[contains(@w:val,''DateAndTime'')]]') = 0, 'date hidden');

        Generate('right', 'footer', true, 'minimal', 'contact', false, Generated);
        IsTrue(Count(Generated, FirstHeader, '//w:instrText[contains(.,''PAGE'')]') = 0, 'page number removed from first header');
        IsTrue(Count(Generated, DefaultHeader, '//w:instrText[contains(.,''PAGE'')]') = 0, 'page number removed from later header');
        IsTrue(Count(Generated, PartOf(Generated, 'footer', 'first'), '//w:instrText[contains(.,''PAGE'')]') > 0, 'page number in first-page footer');
        IsTrue(Count(Generated, PartOf(Generated, 'footer', 'default'), '//w:instrText[contains(.,''PAGE'')]') > 0, 'page number in later footer');
        IsTrue(Validates(Generated), 'page number in footer rejected');

        Generate('right', 'none', true, 'minimal', 'contact', false, Generated);
        IsTrue(CountInParts(Generated, '//w:instrText[contains(.,''PAGE'')]') = 0, 'page number none');

        Generate('right', 'header', true, 'same', 'contact', false, Generated);
        IsTrue(Count(Generated, PartOf(Generated, 'header', 'default'), '//w:sdt[w:sdtPr/w:tag[contains(@w:val,''CompanyLogo'')]]') = 1, 'later pages get the first-page header (with logo)');

        Generate('right', 'header', true, 'minimal', 'bank', false, Generated);
        IsTrue(Count(Generated, PartOf(Generated, 'footer', 'default'), '//w:sdt[w:sdtPr/w:tag[contains(@w:val,''CompanyBankName'')]]') > 0, 'contact + bank footer on later pages');
        IsTrue(Count(Generated, PartOf(Generated, 'footer', 'first'), '//w:sdt[w:sdtPr/w:tag[contains(@w:val,''CompanyBankName'')]]') > 0, 'contact + bank footer on the first page');
        Generate('right', 'header', true, 'minimal', 'none', false, Generated);
        IsTrue(Count(Generated, PartOf(Generated, 'footer', 'first'), '//w:sdt') = 0, 'no footer details on the first page');
        IsTrue(Count(Generated, PartOf(Generated, 'footer', 'default'), '//w:sdt') = 0, 'no footer details on later pages');
        Generate('right', 'footer', true, 'minimal', 'none', false, Generated);
        IsTrue(Count(Generated, PartOf(Generated, 'footer', 'first'), '//w:instrText[contains(.,''PAGE'')]') > 0, 'no footer details, page number still in the footer');
        IsTrue(Validates(Generated), 'page number in empty footer rejected');

        Generate('right', 'header', true, 'minimal', 'contact', true, Generated);
        IsTrue(Count(Generated, FirstHeader, '/*/w:tbl/w:tr[last()]/w:tc/w:tcPr/w:tcBorders/w:bottom[@w:themeColor=''accent3'']') > 0, 'accent line');
        IsTrue(Validates(Generated), 'accent line rejected');

        Generate('left', 'footer', false, 'same', 'bank', true, Generated);
        IsTrue(Validates(Generated), 'all options at once rejected');

        Message('ALL %1 HEADER/FOOTER CHECKS PASSED', Passed);
    end;

    // Each header/footer slot must have its own part, and the part must exist: the report merge loses a part
    // that two slots share.
    local procedure SlotsAreDistinct(Package: Codeunit "Temp Blob")
    var
        DataCompression: Codeunit "Data Compression";
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Nodes: XmlNodeList;
        Node: XmlNode;
        Seen: List of [Text];
        Entries: List of [Text];
        Id: Text;
        Part: Text;
    begin
        DataCompression.OpenZipArchive(Package, false);
        DataCompression.GetEntryList(Entries);
        DataCompression.CloseZipArchive();
        Load(Package, 'word/document.xml', Document, NamespaceManager);
        Document.SelectNodes('/w:document/w:body/w:sectPr/*[self::w:headerReference or self::w:footerReference]/@r:id', NamespaceManager, Nodes);
        foreach Node in Nodes do begin
            Id := Node.AsXmlAttribute().Value();
            IsTrue(not Seen.Contains(Id), 'slots share part ' + Id);
            Seen.Add(Id);
            Part := PartForId(Package, Id);
            IsTrue(Entries.Contains(Part), 'referenced part missing: ' + Part);
        end;
    end;

    local procedure PartForId(Package: Codeunit "Temp Blob"; Id: Text): Text
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Node: XmlNode;
    begin
        Load(Package, 'word/_rels/document.xml.rels', Document, NamespaceManager);
        if Document.SelectSingleNode(StrSubstNo('/p:Relationships/p:Relationship[@Id=''%1'']/@Target', Id), NamespaceManager, Node) then
            exit('word/' + Node.AsXmlAttribute().Value());
    end;

    local procedure Generate(Logo: Text; PageNumber: Text; ShowDate: Boolean; LaterPages: Text; Footer: Text; AccentLine: Boolean; var Generated: Codeunit "Temp Blob")
    var
        Generator: Codeunit "Report Header Footer Generator";
        Base: Codeunit "Temp Blob";
    begin
        GetBase(Base);
        Generator.SetLogo(Logo);
        Generator.SetPageNumber(PageNumber);
        Generator.SetShowDate(ShowDate);
        Generator.SetLaterPages(LaterPages);
        Generator.SetFooter(Footer);
        Generator.SetAccentLine(AccentLine);
        Clear(Generated);
        Generator.Generate(Base.CreateInStream(), Generated);
        SlotsAreDistinct(Generated);
    end;

    local procedure GetBase(var Base: Codeunit "Temp Blob")
    var
        ReportLayoutList: Record "Report Layout List";
        BaseOutStream: OutStream;
    begin
        ReportLayoutList.SetRange("Report ID", 2000000001);
        ReportLayoutList.SetRange(Name, BaseTok);
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::HeaderFooter);
        ReportLayoutList.FindFirst();
        Clear(Base);
        Base.CreateOutStream(BaseOutStream);
        ReportLayoutList.Layout.ExportStream(BaseOutStream);
    end;

    local procedure Validates(Generated: Codeunit "Temp Blob"): Boolean
    var
        Prepared: Codeunit "Temp Blob";
        PreparedInStream: InStream;
    begin
        PreparedInStream := Prepared.CreateInStream(TextEncoding::UTF8);
        ClearLastError();
        exit(Report.ValidateAndPrepareLayout(2000000001, Generated.CreateInStream(TextEncoding::UTF8), PreparedInStream, ReportLayoutType::Word));
    end;

    local procedure RefId(Package: Codeunit "Temp Blob"; Kind: Text; ReferenceType: Text): Text
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Node: XmlNode;
    begin
        Load(Package, 'word/document.xml', Document, NamespaceManager);
        if Document.SelectSingleNode(StrSubstNo('/w:document/w:body/w:sectPr/w:%1Reference[@w:type=''%2'']/@r:id', Kind, ReferenceType), NamespaceManager, Node) then
            exit(Node.AsXmlAttribute().Value());
    end;

    local procedure PartOf(Package: Codeunit "Temp Blob"; Kind: Text; ReferenceType: Text): Text
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Node: XmlNode;
    begin
        Load(Package, 'word/_rels/document.xml.rels', Document, NamespaceManager);
        if Document.SelectSingleNode(StrSubstNo('/p:Relationships/p:Relationship[@Id=''%1'']/@Target', RefId(Package, Kind, ReferenceType)), NamespaceManager, Node) then
            exit('word/' + Node.AsXmlAttribute().Value());
    end;

    local procedure Count(Package: Codeunit "Temp Blob"; Part: Text; XPath: Text): Integer
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Nodes: XmlNodeList;
    begin
        Load(Package, Part, Document, NamespaceManager);
        Document.SelectNodes(XPath, NamespaceManager, Nodes);
        exit(Nodes.Count());
    end;

    local procedure CountInParts(Package: Codeunit "Temp Blob"; XPath: Text) Total: Integer
    var
        DataCompression: Codeunit "Data Compression";
        Entries: List of [Text];
        Entry: Text;
    begin
        DataCompression.OpenZipArchive(Package, false);
        DataCompression.GetEntryList(Entries);
        DataCompression.CloseZipArchive();
        foreach Entry in Entries do
            if (Entry.StartsWith('word/header') or Entry.StartsWith('word/footer')) and Entry.EndsWith('.xml') then
                Total += Count(Package, Entry, XPath);
    end;

    local procedure Load(Package: Codeunit "Temp Blob"; Part: Text; var Document: XmlDocument; var NamespaceManager: XmlNamespaceManager)
    var
        DataCompression: Codeunit "Data Compression";
        Entry: Codeunit "Temp Blob";
    begin
        DataCompression.OpenZipArchive(Package, false);
        DataCompression.ExtractEntry(Part, Entry);
        DataCompression.CloseZipArchive();
        XmlDocument.ReadFrom(Entry.CreateInStream(TextEncoding::UTF8), Document);
        Clear(NamespaceManager);
        NamespaceManager.NameTable(Document.NameTable());
        NamespaceManager.AddNamespace('w', W);
        NamespaceManager.AddNamespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships');
        NamespaceManager.AddNamespace('p', 'http://schemas.openxmlformats.org/package/2006/relationships');
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
}
