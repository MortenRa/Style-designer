namespace Abakion.ReportStyleDesigner;

using System.IO;
using System.Utilities;

/// <summary>
/// Produces a header/footer part by rearranging a copy of an existing design: blocks (logo, date, page number,
/// footers) are moved or removed, never built from scratch, so every data binding stays valid.
/// </summary>
/// <remarks>
/// Built for BaseApp's "External Default Detailed" design: a first-page header with the report title and page number
/// over the logo and date, a minimal header for later pages, and footers with contact (and bank) details.
/// Fixed fonts and colours are always turned into theme references, so the header/footer follows the theme.
/// </remarks>
codeunit 50117 "Report Header Footer Generator"
{
    Access = Internal;

    var
        PartXml: Dictionary of [Text, Text];
        EntryNames: List of [Text];
        CopyCount: Integer;
        Logo: Text;
        PageNumber: Text;
        LaterPages: Text;
        FooterContent: Text;
        ShowDate: Boolean;
        AccentLine: Boolean;
        Configured: Boolean;
        WordNamespaceTxt: Label 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', Locked = true;
        RelNamespaceTxt: Label 'http://schemas.openxmlformats.org/officeDocument/2006/relationships', Locked = true;
        PackageRelNamespaceTxt: Label 'http://schemas.openxmlformats.org/package/2006/relationships', Locked = true;
        DocumentEntryTxt: Label 'word/document.xml', Locked = true;
        DocumentRelsEntryTxt: Label 'word/_rels/document.xml.rels', Locked = true;
        ContentTypesEntryTxt: Label '[Content_Types].xml', Locked = true;
        ContentTypesNamespaceTxt: Label 'http://schemas.openxmlformats.org/package/2006/content-types', Locked = true;
        NotADesignErr: Label 'The header/footer design cannot be used as a base: %1', Comment = '%1 = what is missing';

    procedure SetLogo(NewLogo: Text)
    begin
        Logo := NewLogo; // right, left, none
    end;

    procedure SetPageNumber(NewPageNumber: Text)
    begin
        PageNumber := NewPageNumber; // header, footer, none
    end;

    procedure SetShowDate(NewShowDate: Boolean)
    begin
        ShowDate := NewShowDate;
        Configured := true;
    end;

    procedure SetLaterPages(NewLaterPages: Text)
    begin
        LaterPages := NewLaterPages; // minimal, same
    end;

    procedure SetFooter(NewFooter: Text)
    begin
        FooterContent := NewFooter; // contact, bank, none
    end;

    procedure SetAccentLine(NewAccentLine: Boolean)
    begin
        AccentLine := NewAccentLine;
    end;

    procedure Generate(BaseDesign: InStream; var GeneratedDesign: Codeunit "Temp Blob")
    var
        Source: Codeunit "Data Compression";
        Target: Codeunit "Data Compression";
        EntryBlob: Codeunit "Temp Blob";
        EntryName: Text;
    begin
        if not Configured then
            ShowDate := true;
        Source.OpenZipArchive(BaseDesign, false);
        Clear(EntryNames);
        Source.GetEntryList(EntryNames);
        if not EntryNames.Contains(DocumentEntryTxt) or not EntryNames.Contains(DocumentRelsEntryTxt) or not EntryNames.Contains(ContentTypesEntryTxt) then
            Error(NotADesignErr, DocumentEntryTxt);

        Clear(PartXml);
        CopyCount := 0;
        foreach EntryName in EntryNames do
            if (EntryName in [DocumentEntryTxt, DocumentRelsEntryTxt, ContentTypesEntryTxt]) or IsHeaderFooterPart(EntryName) or IsHeaderFooterRels(EntryName) then begin
                Source.ExtractEntry(EntryName, EntryBlob);
                PartXml.Set(EntryName, ReadText(EntryBlob));
            end;

        Transform();

        Target.CreateZipArchive();
        foreach EntryName in EntryNames do
            if not EntryName.EndsWith('/') then begin
                if PartXml.ContainsKey(EntryName) then
                    WriteText(EntryBlob, PartXml.Get(EntryName))
                else
                    Source.ExtractEntry(EntryName, EntryBlob);
                Target.AddEntry(EntryBlob.CreateInStream(), EntryName);
            end;
        // parts created as copies
        foreach EntryName in PartXml.Keys() do
            if not EntryNames.Contains(EntryName) then begin
                WriteText(EntryBlob, PartXml.Get(EntryName));
                Target.AddEntry(EntryBlob.CreateInStream(), EntryName);
            end;
        Source.CloseZipArchive();
        Target.SaveZipArchive(GeneratedDesign);
        Target.CloseZipArchive();
    end;

    local procedure Transform()
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        SectionProperties: XmlElement;
        Node: XmlNode;
        FirstHeader: Text;
        DefaultHeader: Text;
        FirstFooter: Text;
        DefaultFooter: Text;
        EvenFooter: Text;
        TargetFooter: Text;
        PageParagraph: Text;
        Part: Text;
    begin
        Load(DocumentEntryTxt, Document, NamespaceManager);
        if not Document.SelectSingleNode('/w:document/w:body/w:sectPr', NamespaceManager, Node) then
            Error(NotADesignErr, 'section properties');
        SectionProperties := Node.AsXmlElement();
        FirstHeader := ReferenceId(SectionProperties, NamespaceManager, 'header', 'first');
        DefaultHeader := ReferenceId(SectionProperties, NamespaceManager, 'header', 'default');
        FirstFooter := ReferenceId(SectionProperties, NamespaceManager, 'footer', 'first');
        DefaultFooter := ReferenceId(SectionProperties, NamespaceManager, 'footer', 'default');
        EvenFooter := ReferenceId(SectionProperties, NamespaceManager, 'footer', 'even');
        if (FirstHeader = '') or (DefaultHeader = '') then
            Error(NotADesignErr, 'a first-page and a default header');

        // Footer: contact details (default footer), contact + bank (first-page footer), or none (the empty even footer).
        case FooterContent of
            'bank':
                TargetFooter := FirstFooter;
            'none':
                TargetFooter := EvenFooter;
            else
                TargetFooter := DefaultFooter;
        end;

        // 1. Content: logo and date live in the first-page header; the date also in the minimal header.
        PatchLogo(PartFor(FirstHeader));
        if not ShowDate then begin
            RemoveBound(PartFor(FirstHeader), 'DateAndTime');
            RemoveBound(PartFor(DefaultHeader), 'DateAndTime');
        end;
        if PageNumber in ['footer', 'none'] then begin
            PageParagraph := TakePageNumber(PartFor(FirstHeader));
            TakePageNumber(PartFor(DefaultHeader));
            if (PageNumber = 'footer') and (PageParagraph <> '') and (TargetFooter <> '') then
                AppendParagraph(PartFor(TargetFooter), PageParagraph);
        end;
        if AccentLine then begin
            AddAccentLine(PartFor(FirstHeader));
            AddAccentLine(PartFor(DefaultHeader));
        end;
        foreach Part in PartXml.Keys() do
            if IsHeaderFooterPart(Part) then
                MatchTheme(Part);

        // 2. Wiring. Each header/footer slot gets its own part: the report merge handles a part once per slot, so a
        //    part shared by two slots would be lost. Where two slots show the same content, the part is copied.
        if TargetFooter <> '' then begin
            SetReferenceId(SectionProperties, NamespaceManager, 'footer', 'default', TargetFooter);
            SetReferenceId(SectionProperties, NamespaceManager, 'footer', 'first', TargetFooter);
        end;
        if LaterPages = 'same' then
            SetReferenceId(SectionProperties, NamespaceManager, 'header', 'default', FirstHeader);
        MakeSlotsDistinct(SectionProperties, NamespaceManager);
        Save(DocumentEntryTxt, Document);
    end;

    // Any slot whose part is already used by another slot gets its own copy of that part.
    local procedure MakeSlotsDistinct(SectionProperties: XmlElement; NamespaceManager: XmlNamespaceManager)
    var
        References: XmlNodeList;
        Reference: XmlNode;
        Attribute: XmlAttribute;
        Seen: List of [Text];
        Id: Text;
    begin
        SectionProperties.SelectNodes('w:headerReference|w:footerReference', NamespaceManager, References);
        foreach Reference in References do
            if Reference.AsXmlElement().Attributes().Get('id', RelNamespaceTxt, Attribute) then begin
                Id := Attribute.Value();
                if Seen.Contains(Id) then
                    Reference.AsXmlElement().SetAttribute('id', RelNamespaceTxt, CopyPart(Id))
                else
                    Seen.Add(Id);
            end;
    end;

    // Copies a header/footer part (with its own relationships, such as the logo picture) as a new part, registers it in
    // the package and returns the new relationship ID.
    local procedure CopyPart(RelationshipId: Text) NewRelationshipId: Text
    var
        Document: XmlDocument;
        Root: XmlElement;
        Element: XmlElement;
        SourcePart: Text;
        SourceFile: Text;
        Kind: Text;
        NewFile: Text;
        Number: Integer;
    begin
        SourcePart := PartFor(RelationshipId);
        SourceFile := SourcePart.Substring(StrLen('word/') + 1);
        if SourceFile.StartsWith('header') then
            Kind := 'header'
        else
            Kind := 'footer';
        Number := 1;
        while PartXml.ContainsKey(StrSubstNo('word/%1%2.xml', Kind, Number)) or EntryNames.Contains(StrSubstNo('word/%1%2.xml', Kind, Number)) do
            Number += 1;
        NewFile := StrSubstNo('%1%2.xml', Kind, Number);
        CopyCount += 1;
        NewRelationshipId := StrSubstNo('rIdRsd%1', CopyCount);

        PartXml.Set('word/' + NewFile, PartXml.Get(SourcePart));
        if PartXml.ContainsKey('word/_rels/' + SourceFile + '.rels') then
            PartXml.Set('word/_rels/' + NewFile + '.rels', PartXml.Get('word/_rels/' + SourceFile + '.rels'));

        XmlDocument.ReadFrom(PartXml.Get(ContentTypesEntryTxt), Document);
        Document.GetRoot(Root);
        Element := XmlElement.Create('Override', ContentTypesNamespaceTxt);
        Element.SetAttribute('PartName', '/word/' + NewFile);
        Element.SetAttribute('ContentType', StrSubstNo('application/vnd.openxmlformats-officedocument.wordprocessingml.%1+xml', Kind));
        Root.Add(Element);
        Save(ContentTypesEntryTxt, Document);

        XmlDocument.ReadFrom(PartXml.Get(DocumentRelsEntryTxt), Document);
        Document.GetRoot(Root);
        Element := XmlElement.Create('Relationship', PackageRelNamespaceTxt);
        Element.SetAttribute('Id', NewRelationshipId);
        Element.SetAttribute('Type', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/' + Kind);
        Element.SetAttribute('Target', NewFile);
        Root.Add(Element);
        Save(DocumentRelsEntryTxt, Document);
    end;

    local procedure IsHeaderFooterRels(EntryName: Text): Boolean
    begin
        exit((EntryName.StartsWith('word/_rels/header') or EntryName.StartsWith('word/_rels/footer')) and EntryName.EndsWith('.xml.rels'));
    end;
    // Moves the logo to the first column of its row (left), or removes it (none).
    local procedure PatchLogo(Part: Text)
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        LogoNode: XmlNode;
        LogoCell: XmlNode;
        FirstCell: XmlNode;
        Paragraphs: XmlNodeList;
        Paragraph: XmlNode;
    begin
        if Logo in ['', 'right'] then
            exit;
        Load(Part, Document, NamespaceManager);
        if not Document.SelectSingleNode('//w:sdt[w:sdtPr/w:tag[contains(@w:val, ''CompanyLogo'')]]', NamespaceManager, LogoNode) then
            exit;
        if Logo = 'none' then begin
            LogoNode.Remove();
            Save(Part, Document);
            exit;
        end;

        // left: swap the content of the logo's cell with the first cell of the same row
        if not LogoNode.SelectSingleNode('ancestor::w:tc[1]', NamespaceManager, LogoCell) then
            exit;
        if not LogoCell.SelectSingleNode('../w:tc[1]', NamespaceManager, FirstCell) then
            exit;
        if FirstCell.AsXmlElement().InnerXml() = LogoCell.AsXmlElement().InnerXml() then
            exit;
        SwapCellParagraphs(FirstCell.AsXmlElement(), LogoCell.AsXmlElement(), NamespaceManager);
        // the logo paragraph was right-aligned; align it left in its new place, and the other content right
        FirstCell.SelectNodes('w:p', NamespaceManager, Paragraphs);
        foreach Paragraph in Paragraphs do
            SetJustification(Paragraph.AsXmlElement(), NamespaceManager, 'left');
        LogoCell.SelectNodes('w:p', NamespaceManager, Paragraphs);
        foreach Paragraph in Paragraphs do
            SetJustification(Paragraph.AsXmlElement(), NamespaceManager, 'right');
        Save(Part, Document);
    end;

    local procedure SwapCellParagraphs(CellA: XmlElement; CellB: XmlElement; NamespaceManager: XmlNamespaceManager)
    var
        ParagraphsA: XmlNodeList;
        ParagraphsB: XmlNodeList;
        Paragraph: XmlNode;
    begin
        CellA.SelectNodes('w:p|w:tbl|w:sdt', NamespaceManager, ParagraphsA);
        CellB.SelectNodes('w:p|w:tbl|w:sdt', NamespaceManager, ParagraphsB);
        foreach Paragraph in ParagraphsA do
            Paragraph.Remove();
        foreach Paragraph in ParagraphsB do
            Paragraph.Remove();
        foreach Paragraph in ParagraphsB do
            CellA.Add(Paragraph);
        foreach Paragraph in ParagraphsA do
            CellB.Add(Paragraph);
    end;

    local procedure SetJustification(Paragraph: XmlElement; NamespaceManager: XmlNamespaceManager; Value: Text)
    var
        Node: XmlNode;
        ParagraphProperties: XmlElement;
        Justification: XmlElement;
    begin
        if Paragraph.SelectSingleNode('w:pPr', NamespaceManager, Node) then
            ParagraphProperties := Node.AsXmlElement()
        else begin
            ParagraphProperties := XmlElement.Create('pPr', WordNamespaceTxt);
            Paragraph.AddFirst(ParagraphProperties);
        end;
        if ParagraphProperties.SelectSingleNode('w:jc', NamespaceManager, Node) then
            Justification := Node.AsXmlElement()
        else begin
            Justification := XmlElement.Create('jc', WordNamespaceTxt);
            // CT_PPr: jc comes before textDirection, textAlignment, ..., rPr, sectPr, pPrChange
            InsertBeforeFirst(ParagraphProperties, NamespaceManager, Justification,
                'w:textDirection,w:textAlignment,w:textboxTightWrap,w:outlineLvl,w:divId,w:cnfStyle,w:rPr,w:sectPr,w:pPrChange');
        end;
        Justification.SetAttribute('val', WordNamespaceTxt, Value);
    end;

    local procedure RemoveBound(Part: Text; FieldName: Text)
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Nodes: XmlNodeList;
        Node: XmlNode;
    begin
        if Part = '' then
            exit;
        Load(Part, Document, NamespaceManager);
        Document.SelectNodes(StrSubstNo('//w:sdt[w:sdtPr/w:tag[contains(@w:val, ''%1'')] or w:sdtPr/w:dataBinding[contains(@w:xpath, ''%1'')]]', FieldName), NamespaceManager, Nodes);
        foreach Node in Nodes do
            Node.Remove();
        Save(Part, Document);
    end;

    // Empties the paragraph with the PAGE field and returns its original XML, so it can be placed elsewhere.
    local procedure TakePageNumber(Part: Text) PageParagraph: Text
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Paragraphs: XmlNodeList;
        Paragraph: XmlNode;
        Children: XmlNodeList;
        Child: XmlNode;
    begin
        if Part = '' then
            exit('');
        Load(Part, Document, NamespaceManager);
        Document.SelectNodes('//w:p[.//w:instrText[contains(., ''PAGE'')] or .//w:fldSimple[contains(@w:instr, ''PAGE'')]]', NamespaceManager, Paragraphs);
        foreach Paragraph in Paragraphs do begin
            if PageParagraph = '' then
                Paragraph.WriteTo(PageParagraph);
            Paragraph.SelectNodes('*[not(self::w:pPr)]', NamespaceManager, Children);
            foreach Child in Children do
                Child.Remove();
        end;
        Save(Part, Document);
    end;

    local procedure AppendParagraph(Part: Text; ParagraphXml: Text)
    var
        Document: XmlDocument;
        Fragment: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Root: XmlElement;
        Node: XmlNode;
    begin
        if Part = '' then
            exit;
        Load(Part, Document, NamespaceManager);
        XmlDocument.ReadFrom(ParagraphXml, Fragment);
        Fragment.GetRoot(Root);
        SetJustification(Root, NamespaceManager, 'right');
        if Document.SelectSingleNode('/*', NamespaceManager, Node) then
            Node.AsXmlElement().Add(Root);
        Save(Part, Document);
    end;

    // A bottom border on the last row of each header table, in the theme's Accent 3.
    local procedure AddAccentLine(Part: Text)
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Cells: XmlNodeList;
        Cell: XmlNode;
        Node: XmlNode;
        CellProperties: XmlElement;
        Borders: XmlElement;
        Bottom: XmlElement;
    begin
        if Part = '' then
            exit;
        Load(Part, Document, NamespaceManager);
        Document.SelectNodes('/*/w:tbl/w:tr[last()]/w:tc', NamespaceManager, Cells);
        foreach Cell in Cells do begin
            if Cell.SelectSingleNode('w:tcPr', NamespaceManager, Node) then
                CellProperties := Node.AsXmlElement()
            else begin
                CellProperties := XmlElement.Create('tcPr', WordNamespaceTxt);
                Cell.AsXmlElement().AddFirst(CellProperties);
            end;
            if CellProperties.SelectSingleNode('w:tcBorders', NamespaceManager, Node) then
                Borders := Node.AsXmlElement()
            else begin
                Borders := XmlElement.Create('tcBorders', WordNamespaceTxt);
                InsertBeforeFirst(CellProperties, NamespaceManager, Borders, 'w:shd,w:noWrap,w:tcMar,w:textDirection,w:tcFitText,w:vAlign,w:hideMark');
            end;
            if Borders.SelectSingleNode('w:bottom', NamespaceManager, Node) then
                Node.Remove();
            Bottom := XmlElement.Create('bottom', WordNamespaceTxt);
            Bottom.SetAttribute('val', WordNamespaceTxt, 'single');
            Bottom.SetAttribute('sz', WordNamespaceTxt, '12');
            Bottom.SetAttribute('space', WordNamespaceTxt, '0');
            Bottom.SetAttribute('color', WordNamespaceTxt, 'auto');
            Bottom.SetAttribute('themeColor', WordNamespaceTxt, 'accent3');
            InsertBeforeFirst(Borders, NamespaceManager, Bottom, 'w:end,w:right,w:insideH,w:insideV,w:tl2br,w:tr2bl');
        end;
        Save(Part, Document);
    end;

    // Fixed fonts and text colours become theme references, so the header/footer follows the theme.
    local procedure MatchTheme(Part: Text)
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Nodes: XmlNodeList;
        Node: XmlNode;
        Element: XmlElement;
        Attribute: XmlAttribute;
        FontName: Text;
        ThemeFont: Text;
        ThemeColor: Text;
    begin
        Load(Part, Document, NamespaceManager);
        Document.SelectNodes('//w:rFonts[@w:ascii or @w:hAnsi]', NamespaceManager, Nodes);
        foreach Node in Nodes do begin
            Element := Node.AsXmlElement();
            if Element.Attributes().Get('ascii', WordNamespaceTxt, Attribute) then
                FontName := Attribute.Value()
            else
                if Element.Attributes().Get('hAnsi', WordNamespaceTxt, Attribute) then
                    FontName := Attribute.Value();
            ThemeFont := ThemeFontFor(FontName);
            if ThemeFont <> '' then begin
                Element.RemoveAttribute('ascii', WordNamespaceTxt);
                Element.RemoveAttribute('hAnsi', WordNamespaceTxt);
                Element.SetAttribute('asciiTheme', WordNamespaceTxt, ThemeFont);
                Element.SetAttribute('hAnsiTheme', WordNamespaceTxt, ThemeFont);
            end;
        end;

        Document.SelectNodes('//w:color[not(@w:themeColor)]', NamespaceManager, Nodes);
        foreach Node in Nodes do begin
            Element := Node.AsXmlElement();
            if Element.Attributes().Get('val', WordNamespaceTxt, Attribute) then begin
                ThemeColor := ThemeColorFor(Attribute.Value());
                if ThemeColor <> '' then
                    Element.SetAttribute('themeColor', WordNamespaceTxt, ThemeColor);
            end;
        end;
        Save(Part, Document);
    end;

    local procedure ThemeFontFor(FontName: Text): Text
    begin
        // Only the fonts the shipped designs use; symbol or brand fonts stay as they are.
        case FontName of
            'Segoe UI Semibold', 'Segoe UI Bold', 'Sitka Display Semibold', 'Sitka Text Semibold', 'Aptos Display', 'Calibri Light', 'Bahnschrift SemiBold':
                exit('majorHAnsi');
            'Segoe UI', 'Sitka Text', 'Aptos', 'Aptos Narrow', 'Calibri', 'Bahnschrift':
                exit('minorHAnsi');
        end;
        exit('');
    end;

    local procedure ThemeColorFor(HexColor: Text): Text
    begin
        // Neutral text colours only; any other colour (e.g. a brand colour) stays fixed.
        case UpperCase(HexColor) of
            '242424', '000000':
                exit('text1');
            '44546A':
                exit('text2');
        end;
        exit('');
    end;

    local procedure ReferenceId(SectionProperties: XmlElement; NamespaceManager: XmlNamespaceManager; Kind: Text; ReferenceType: Text): Text
    var
        Node: XmlNode;
        Attribute: XmlAttribute;
    begin
        if not SectionProperties.SelectSingleNode(StrSubstNo('w:%1Reference[@w:type=''%2'']', Kind, ReferenceType), NamespaceManager, Node) then
            exit('');
        if Node.AsXmlElement().Attributes().Get('id', RelNamespaceTxt, Attribute) then
            exit(Attribute.Value());
    end;

    local procedure SetReferenceId(SectionProperties: XmlElement; NamespaceManager: XmlNamespaceManager; Kind: Text; ReferenceType: Text; RelationshipId: Text)
    var
        Node: XmlNode;
    begin
        if SectionProperties.SelectSingleNode(StrSubstNo('w:%1Reference[@w:type=''%2'']', Kind, ReferenceType), NamespaceManager, Node) then
            Node.AsXmlElement().SetAttribute('id', RelNamespaceTxt, RelationshipId);
    end;

    // Entry name ("word/header3.xml") of the part behind a relationship ID of document.xml.
    local procedure PartFor(RelationshipId: Text): Text
    var
        Relationships: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Node: XmlNode;
        Attribute: XmlAttribute;
    begin
        if RelationshipId = '' then
            exit('');
        XmlDocument.ReadFrom(PartXml.Get(DocumentRelsEntryTxt), Relationships);
        NamespaceManager.NameTable(Relationships.NameTable());
        NamespaceManager.AddNamespace('r', PackageRelNamespaceTxt);
        if not Relationships.SelectSingleNode(StrSubstNo('/r:Relationships/r:Relationship[@Id=''%1'']', RelationshipId), NamespaceManager, Node) then
            exit('');
        if Node.AsXmlElement().Attributes().Get('Target', Attribute) then
            exit('word/' + Attribute.Value().TrimStart('/').Replace('word/', ''));
    end;

    local procedure IsHeaderFooterPart(EntryName: Text): Boolean
    begin
        exit((EntryName.StartsWith('word/header') or EntryName.StartsWith('word/footer')) and EntryName.EndsWith('.xml'));
    end;

    local procedure Load(Part: Text; var Document: XmlDocument; var NamespaceManager: XmlNamespaceManager)
    var
        ReadOptions: XmlReadOptions;
    begin
        ReadOptions.PreserveWhitespace := true;
        if not XmlDocument.ReadFrom(PartXml.Get(Part), ReadOptions, Document) then
            Error(NotADesignErr, Part);
        Clear(NamespaceManager);
        NamespaceManager.NameTable(Document.NameTable());
        NamespaceManager.AddNamespace('w', WordNamespaceTxt);
        NamespaceManager.AddNamespace('r', RelNamespaceTxt);
    end;

    // Written through a UTF-8 stream: writing to Text would declare utf-16, which does not match the UTF-8 bytes.
    local procedure Save(Part: Text; Document: XmlDocument)
    var
        Blob: Codeunit "Temp Blob";
    begin
        Document.WriteTo(Blob.CreateOutStream(TextEncoding::UTF8));
        PartXml.Set(Part, ReadText(Blob));
    end;

    local procedure InsertBeforeFirst(Parent: XmlElement; NamespaceManager: XmlNamespaceManager; NewElement: XmlElement; FollowingNames: Text)
    var
        Node: XmlNode;
        FollowingName: Text;
    begin
        foreach FollowingName in FollowingNames.Split(',') do
            if Parent.SelectSingleNode(FollowingName, NamespaceManager, Node) then begin
                Node.AddBeforeSelf(NewElement);
                exit;
            end;
        Parent.Add(NewElement);
    end;

    local procedure ReadText(Blob: Codeunit "Temp Blob") Result: Text
    var
        BlobInStream: InStream;
        Line: Text;
    begin
        BlobInStream := Blob.CreateInStream(TextEncoding::UTF8);
        while not BlobInStream.EOS() do begin
            BlobInStream.Read(Line);
            Result += Line;
        end;
    end;

    local procedure WriteText(var Blob: Codeunit "Temp Blob"; Xml: Text)
    var
        BlobOutStream: OutStream;
    begin
        Clear(Blob);
        BlobOutStream := Blob.CreateOutStream(TextEncoding::UTF8);
        BlobOutStream.WriteText(Xml);
    end;
}
