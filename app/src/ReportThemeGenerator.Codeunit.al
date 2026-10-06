// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Abakion.ReportStyleDesigner;

using System.IO;
using System.Utilities;

/// <summary>
/// Produces a report theme part (.dotx) by patching a base theme. Only the settings that were set are
/// changed; everything else in the base theme is kept as is.
/// </summary>
/// <remarks>
/// Composite compose takes colours, fonts, docDefaults and the page background from the theme part, so
/// these are the values the generator writes. Font size travels via styles.xml only, never the theme.
/// </remarks>
codeunit 50100 "Report Theme Generator"
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        Colors: Dictionary of [Integer, Text];
        HeadingFont: Text;
        BodyFont: Text;
        PageColor: Text;
        ThemeName: Text;
        BaseColors: Dictionary of [Text, Text];
        TableStyle: Enum "Report Theme Table Style";
        BaseFontSizeHalfPoints: Integer;
        FontsSet: Boolean;
        PageColorSet: Boolean;
        WordNamespaceTxt: Label 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', Locked = true;
        DrawingNamespaceTxt: Label 'http://schemas.openxmlformats.org/drawingml/2006/main', Locked = true;
        ThemeEntryTxt: Label 'word/theme/theme1.xml', Locked = true;
        StylesEntryTxt: Label 'word/styles.xml', Locked = true;
        DocumentEntryTxt: Label 'word/document.xml', Locked = true;
        SettingsEntryTxt: Label 'word/settings.xml', Locked = true;
        InvalidColorErr: Label '%1 is not a valid colour. Use six hexadecimal digits, for example 4D614C.', Comment = '%1 = the colour value entered';
        InvalidFontSizeErr: Label 'The font size must be between 6 and 72 points.';
        MissingFontErr: Label 'Specify both a heading font and a body font.';
        NotAThemeErr: Label 'The base theme is not a valid Word theme. It must contain %1.', Comment = '%1 = path of the missing part inside the file, for example word/theme/theme1.xml';

    procedure SetColor(Slot: Enum "Report Theme Color Slot"; HexColor: Text)
    begin
        this.Colors.Set(Slot.AsInteger(), this.NormalizeColor(HexColor));
    end;

    procedure SetFonts(NewHeadingFont: Text; NewBodyFont: Text)
    begin
        if (NewHeadingFont.Trim() = '') or (NewBodyFont.Trim() = '') then
            Error(MissingFontErr);
        this.HeadingFont := NewHeadingFont.Trim();
        this.BodyFont := NewBodyFont.Trim();
        this.FontsSet := true;
    end;

    /// <summary>
    /// Sets the page colour. An empty value removes the base theme's page colour.
    /// </summary>
    procedure SetPageColor(HexColor: Text)
    begin
        if HexColor = '' then
            this.PageColor := ''
        else
            this.PageColor := this.NormalizeColor(HexColor);
        this.PageColorSet := true;
    end;

    procedure SetBaseFontSize(Points: Decimal)
    begin
        if (Points < 6) or (Points > 72) then
            Error(InvalidFontSizeErr);
        this.BaseFontSizeHalfPoints := Round(Points * 2, 1);
    end;

    procedure SetThemeName(NewThemeName: Text)
    begin
        this.ThemeName := NewThemeName.Trim();
    end;

    /// <summary>
    /// Restyles the BC table styles used by the Body layouts. Colours refer to the theme, so they follow the palette.
    /// </summary>
    procedure SetTableStyle(NewTableStyle: Enum "Report Theme Table Style")
    begin
        this.TableStyle := NewTableStyle;
    end;

    procedure Generate(BaseTheme: InStream; var GeneratedTheme: Codeunit "Temp Blob")
    var
        Source: Codeunit "Data Compression";
        Target: Codeunit "Data Compression";
        EntryBlob: Codeunit "Temp Blob";
        EntryList: List of [Text];
        EntryName: Text;
    begin
        // Copy into a new archive instead of updating in place: Data Compression cannot extract
        // entries from an archive opened for update.
        Source.OpenZipArchive(BaseTheme, false);
        Source.GetEntryList(EntryList);
        if not EntryList.Contains(ThemeEntryTxt) then
            Error(NotAThemeErr, ThemeEntryTxt);
        if this.StylesNeedPatching() and not EntryList.Contains(StylesEntryTxt) then
            Error(NotAThemeErr, StylesEntryTxt);
        if this.TableStyle <> this.TableStyle::KeepBase then begin
            Source.ExtractEntry(ThemeEntryTxt, EntryBlob);
            this.LoadBaseColors(EntryBlob);
        end;

        Target.CreateZipArchive();
        foreach EntryName in EntryList do
            if not EntryName.EndsWith('/') then begin
                Source.ExtractEntry(EntryName, EntryBlob);
                this.PatchPart(EntryName, EntryBlob);
                Target.AddEntry(EntryBlob.CreateInStream(), EntryName);
            end;
        Source.CloseZipArchive();

        Target.SaveZipArchive(GeneratedTheme);
        Target.CloseZipArchive();
    end;

    local procedure PatchPart(EntryName: Text; var EntryBlob: Codeunit "Temp Blob")
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        ReadOptions: XmlReadOptions;
    begin
        case EntryName of
            ThemeEntryTxt:
                if (this.Colors.Count() = 0) and not this.FontsSet and (this.ThemeName = '') then
                    exit;
            StylesEntryTxt:
                if not this.StylesNeedPatching() then
                    exit;
            DocumentEntryTxt:
                if not this.PageColorSet then
                    exit;
            SettingsEntryTxt:
                if this.PageColor = '' then
                    exit;
            else
                exit;
        end;

        ReadOptions.PreserveWhitespace := true;
        if not XmlDocument.ReadFrom(EntryBlob.CreateInStream(TextEncoding::UTF8), ReadOptions, Document) then
            Error(NotAThemeErr, EntryName);
        NamespaceManager.NameTable(Document.NameTable());
        NamespaceManager.AddNamespace('w', WordNamespaceTxt);
        NamespaceManager.AddNamespace('a', DrawingNamespaceTxt);

        case EntryName of
            ThemeEntryTxt:
                this.PatchTheme(Document, NamespaceManager);
            StylesEntryTxt:
                this.PatchStyles(Document, NamespaceManager);
            DocumentEntryTxt:
                this.PatchBackground(Document, NamespaceManager);
            SettingsEntryTxt:
                this.PatchSettings(Document, NamespaceManager);
        end;

        Clear(EntryBlob);
        Document.WriteTo(EntryBlob.CreateOutStream(TextEncoding::UTF8));
    end;

    local procedure PatchTheme(var Document: XmlDocument; NamespaceManager: XmlNamespaceManager)
    var
        Node: XmlNode;
        SlotElement: XmlElement;
        ColorElement: XmlElement;
        SlotKey: Integer;
    begin
        if this.ThemeName <> '' then begin
            if Document.SelectSingleNode('/a:theme', NamespaceManager, Node) then
                Node.AsXmlElement().SetAttribute('name', this.ThemeName);
            if Document.SelectSingleNode('//a:themeElements/a:clrScheme', NamespaceManager, Node) then
                Node.AsXmlElement().SetAttribute('name', this.ThemeName);
            if Document.SelectSingleNode('//a:themeElements/a:fontScheme', NamespaceManager, Node) then
                Node.AsXmlElement().SetAttribute('name', this.ThemeName);
        end;

        foreach SlotKey in this.Colors.Keys() do
            if Document.SelectSingleNode('//a:themeElements/a:clrScheme/a:' + this.SlotElementName(Enum::"Report Theme Color Slot".FromInteger(SlotKey)), NamespaceManager, Node) then begin
                // A slot holds either a:srgbClr or a:sysClr; replace whichever is there.
                SlotElement := Node.AsXmlElement();
                SlotElement.RemoveNodes();
                ColorElement := XmlElement.Create('srgbClr', DrawingNamespaceTxt);
                ColorElement.SetAttribute('val', this.Colors.Get(SlotKey));
                SlotElement.Add(ColorElement);
            end;

        if this.FontsSet then begin
            this.SetTypeface(Document, NamespaceManager, 'majorFont', this.HeadingFont);
            this.SetTypeface(Document, NamespaceManager, 'minorFont', this.BodyFont);
        end;
    end;

    local procedure SetTypeface(var Document: XmlDocument; NamespaceManager: XmlNamespaceManager; FontElementName: Text; Typeface: Text)
    var
        Node: XmlNode;
    begin
        if Document.SelectSingleNode('//a:themeElements/a:fontScheme/a:' + FontElementName + '/a:latin', NamespaceManager, Node) then
            Node.AsXmlElement().SetAttribute('typeface', Typeface);
    end;

    local procedure PatchStyles(var Document: XmlDocument; NamespaceManager: XmlNamespaceManager)
    var
        RunProperties: XmlElement;
        Node: XmlNode;
    begin
        if not Document.SelectSingleNode('/w:styles', NamespaceManager, Node) then
            exit;
        if this.BaseFontSizeHalfPoints <> 0 then begin
            // docDefaults is the first child of w:styles and rPrDefault the first child of docDefaults.
            RunProperties := this.GetOrAddFirstChild(Node.AsXmlElement(), NamespaceManager, 'docDefaults');
            RunProperties := this.GetOrAddFirstChild(RunProperties, NamespaceManager, 'rPrDefault');
            RunProperties := this.GetOrAddFirstChild(RunProperties, NamespaceManager, 'rPr');
            this.SetRunPropertyValue(RunProperties, NamespaceManager, 'sz');
            this.SetRunPropertyValue(RunProperties, NamespaceManager, 'szCs');
        end;
        this.PatchTableStyles(Document, NamespaceManager);
    end;

    local procedure StylesNeedPatching(): Boolean
    begin
        exit((this.BaseFontSizeHalfPoints <> 0) or (this.TableStyle <> this.TableStyle::KeepBase));
    end;

    local procedure PatchTableStyles(var Document: XmlDocument; NamespaceManager: XmlNamespaceManager)
    var
        Part: XmlElement;
    begin
        case this.TableStyle of
            this.TableStyle::Minimal:
                begin
                    if this.GetTableStylePart(Document, NamespaceManager, 'BCDataTable', 'band2Horz', Part) then
                        this.SetShading(Part, NamespaceManager, '', 0);
                    if this.GetTableStylePart(Document, NamespaceManager, 'BCBlockTable', 'band1Horz', Part) then
                        this.SetShading(Part, NamespaceManager, '', 0);
                end;
            this.TableStyle::Banded:
                if this.GetTableStylePart(Document, NamespaceManager, 'BCDataTable', 'band2Horz', Part) then
                    this.SetShading(Part, NamespaceManager, 'accent1', 0);
            this.TableStyle::AccentLines:
                begin
                    if this.GetTableStylePart(Document, NamespaceManager, 'BCDataTable', 'firstRow', Part) then
                        this.SetBorder(Part, NamespaceManager, 'bottom', 'accent3', 12);
                    this.SetAccentTotals(Document, NamespaceManager);
                end;
            this.TableStyle::BoldHeader:
                begin
                    // A tint keeps the default dark text readable: paragraph styles such as Normal set the text colour,
                    // and in Word they beat table-style formatting, so white header text cannot be forced from here.
                    if this.GetTableStylePart(Document, NamespaceManager, 'BCDataTable', 'firstRow', Part) then begin
                        this.SetShading(Part, NamespaceManager, 'accent3', 102);
                        this.SetBorder(Part, NamespaceManager, 'bottom', 'accent3', 12);
                    end;
                    if this.GetTableStylePart(Document, NamespaceManager, 'BCDataTable', 'band2Horz', Part) then
                        this.SetShading(Part, NamespaceManager, 'accent1', 0);
                    this.SetAccentTotals(Document, NamespaceManager);
                end;
        end;
    end;

    // Only borders and fills are restyled: text colour set in a table style loses to the paragraph style
    // (Normal sets text1 in the shipped themes), so it would not show.
    local procedure SetAccentTotals(var Document: XmlDocument; NamespaceManager: XmlNamespaceManager)
    var
        Part: XmlElement;
    begin
        if this.GetTableStylePart(Document, NamespaceManager, 'BCTotalsTable', 'lastRow', Part) then begin
            this.SetBorder(Part, NamespaceManager, 'top', 'accent3', 4);
            this.SetBorder(Part, NamespaceManager, 'bottom', 'accent3', 12);
        end;
    end;
    local procedure GetTableStylePart(var Document: XmlDocument; NamespaceManager: XmlNamespaceManager; StyleId: Text; PartType: Text; var Part: XmlElement): Boolean
    var
        Node: XmlNode;
        Style: XmlElement;
    begin
        if not Document.SelectSingleNode(StrSubstNo('/w:styles/w:style[@w:styleId=''%1'']', StyleId), NamespaceManager, Node) then
            exit(false);
        Style := Node.AsXmlElement();
        if Style.SelectSingleNode(StrSubstNo('w:tblStylePr[@w:type=''%1'']', PartType), NamespaceManager, Node) then begin
            Part := Node.AsXmlElement();
            exit(true);
        end;
        // tblStylePr elements are the last children of w:style.
        Part := XmlElement.Create('tblStylePr', WordNamespaceTxt);
        Part.SetAttribute('type', WordNamespaceTxt, PartType);
        Style.Add(Part);
        exit(true);
    end;

    // Tint is 0-255 as in w:themeFillTint (the share of the colour kept); 0 means the full colour.
    local procedure SetShading(Part: XmlElement; NamespaceManager: XmlNamespaceManager; ThemeColor: Text; Tint: Integer)
    var
        Shading: XmlElement;
    begin
        Shading := this.GetOrAddChild(this.GetCellProperties(Part, NamespaceManager), NamespaceManager, 'shd', 'noWrap,tcMar,textDirection,tcFitText,vAlign,hideMark');
        Shading.RemoveAttribute('themeFill', WordNamespaceTxt);
        Shading.RemoveAttribute('themeFillTint', WordNamespaceTxt);
        Shading.RemoveAttribute('themeFillShade', WordNamespaceTxt);
        Shading.SetAttribute('val', WordNamespaceTxt, 'clear');
        Shading.SetAttribute('color', WordNamespaceTxt, 'auto');
        if ThemeColor = '' then
            Shading.SetAttribute('fill', WordNamespaceTxt, 'auto')
        else begin
            Shading.SetAttribute('fill', WordNamespaceTxt, this.TintColor(this.EffectiveColor(ThemeColor), Tint));
            Shading.SetAttribute('themeFill', WordNamespaceTxt, ThemeColor);
            if Tint <> 0 then
                Shading.SetAttribute('themeFillTint', WordNamespaceTxt, this.ByteToHex(Tint));
        end;
    end;

    // An empty ThemeColor removes the border.
    local procedure SetBorder(Part: XmlElement; NamespaceManager: XmlNamespaceManager; Side: Text; ThemeColor: Text; EighthPoints: Integer)
    var
        Borders: XmlElement;
        Border: XmlElement;
        Following: Text;
    begin
        Borders := this.GetOrAddChild(this.GetCellProperties(Part, NamespaceManager), NamespaceManager, 'tcBorders', 'shd,noWrap,tcMar,textDirection,tcFitText,vAlign,hideMark');
        if Side = 'top' then
            Following := 'start,left,bottom,end,right,insideH,insideV,tl2br,tr2bl'
        else
            Following := 'end,right,insideH,insideV,tl2br,tr2bl';
        Border := this.GetOrAddChild(Borders, NamespaceManager, Side, Following);
        Border.RemoveAllAttributes();
        if ThemeColor = '' then begin
            Border.SetAttribute('val', WordNamespaceTxt, 'nil');
            exit;
        end;
        Border.SetAttribute('val', WordNamespaceTxt, 'single');
        Border.SetAttribute('sz', WordNamespaceTxt, Format(EighthPoints, 0, 9));
        Border.SetAttribute('space', WordNamespaceTxt, '0');
        Border.SetAttribute('color', WordNamespaceTxt, this.EffectiveColor(ThemeColor));
        Border.SetAttribute('themeColor', WordNamespaceTxt, ThemeColor);
    end;

    local procedure TintColor(HexColor: Text; Tint: Integer): Text
    var
        Channel: Integer;
        Result: Text;
    begin
        if Tint = 0 then
            exit(HexColor);
        for Channel := 0 to 2 do
            Result += this.ByteToHex(255 - Round((255 - this.HexToByte(CopyStr(HexColor, Channel * 2 + 1, 2))) * Tint / 255, 1));
        exit(Result);
    end;

    local procedure HexToByte(Hex: Text): Integer
    begin
        exit((StrPos('0123456789ABCDEF', Hex[1]) - 1) * 16 + StrPos('0123456789ABCDEF', Hex[2]) - 1);
    end;

    local procedure ByteToHex(Value: Integer): Text
    var
        Digits: Text;
    begin
        Digits := '0123456789ABCDEF';
        exit(Format(Digits[Value div 16 + 1]) + Format(Digits[Value mod 16 + 1]));
    end;

    local procedure GetCellProperties(Part: XmlElement; NamespaceManager: XmlNamespaceManager): XmlElement
    begin
        exit(this.GetOrAddChild(Part, NamespaceManager, 'tcPr', ''));
    end;

    local procedure GetOrAddChild(Parent: XmlElement; NamespaceManager: XmlNamespaceManager; ElementName: Text; FollowingNames: Text): XmlElement
    var
        Node: XmlNode;
        Child: XmlElement;
        FollowingList: List of [Text];
        FollowingName: Text;
    begin
        if Parent.SelectSingleNode('w:' + ElementName, NamespaceManager, Node) then
            exit(Node.AsXmlElement());
        Child := XmlElement.Create(ElementName, WordNamespaceTxt);
        if FollowingNames <> '' then
            foreach FollowingName in FollowingNames.Split(',') do
                FollowingList.Add('w:' + FollowingName);
        this.InsertBeforeFirst(Parent, NamespaceManager, Child, FollowingList);
        exit(Child);
    end;

    local procedure LoadBaseColors(ThemeBlob: Codeunit "Temp Blob")
    var
        Document: XmlDocument;
        NamespaceManager: XmlNamespaceManager;
        Node: XmlNode;
        Slot: Integer;
        SlotName: Text;
    begin
        Clear(this.BaseColors);
        if not XmlDocument.ReadFrom(ThemeBlob.CreateInStream(TextEncoding::UTF8), Document) then
            Error(NotAThemeErr, ThemeEntryTxt);
        NamespaceManager.NameTable(Document.NameTable());
        NamespaceManager.AddNamespace('a', DrawingNamespaceTxt);
        for Slot := 0 to 11 do begin
            SlotName := this.SlotElementName(Enum::"Report Theme Color Slot".FromInteger(Slot));
            if Document.SelectSingleNode('//a:clrScheme/a:' + SlotName + '/a:srgbClr/@val', NamespaceManager, Node) then
                this.BaseColors.Set(SlotName, Node.AsXmlAttribute().Value())
            else
                if Document.SelectSingleNode('//a:clrScheme/a:' + SlotName + '/a:sysClr/@lastClr', NamespaceManager, Node) then
                    this.BaseColors.Set(SlotName, Node.AsXmlAttribute().Value());
        end;
    end;

    // Hex of a WordprocessingML theme colour name in the generated theme, used as the fallback value next to w:themeColor.
    local procedure EffectiveColor(ThemeColor: Text): Text
    var
        SlotName: Text;
        Slot: Integer;
    begin
        case ThemeColor of
            'text1':
                SlotName := 'dk1';
            'background1':
                SlotName := 'lt1';
            'text2':
                SlotName := 'dk2';
            'background2':
                SlotName := 'lt2';
            else
                SlotName := ThemeColor;
        end;
        for Slot := 0 to 11 do
            if this.SlotElementName(Enum::"Report Theme Color Slot".FromInteger(Slot)) = SlotName then
                if this.Colors.ContainsKey(Slot) then
                    exit(this.Colors.Get(Slot));
        if this.BaseColors.ContainsKey(SlotName) then
            exit(this.BaseColors.Get(SlotName));
        exit('000000');
    end;

    local procedure SetRunPropertyValue(RunProperties: XmlElement; NamespaceManager: XmlNamespaceManager; ElementName: Text)
    var
        Node: XmlNode;
        SizeElement: XmlElement;
    begin
        if RunProperties.SelectSingleNode('w:' + ElementName, NamespaceManager, Node) then
            SizeElement := Node.AsXmlElement()
        else begin
            SizeElement := XmlElement.Create(ElementName, WordNamespaceTxt);
            this.InsertBeforeFirst(RunProperties, NamespaceManager, SizeElement, this.RunPropertiesAfterSize(ElementName));
        end;
        SizeElement.SetAttribute('val', WordNamespaceTxt, Format(this.BaseFontSizeHalfPoints, 0, 9));
    end;

    local procedure PatchBackground(var Document: XmlDocument; NamespaceManager: XmlNamespaceManager)
    var
        Node: XmlNode;
        Background: XmlElement;
    begin
        if Document.SelectSingleNode('/w:document/w:background', NamespaceManager, Node) then begin
            if this.PageColor = '' then begin
                Node.Remove();
                exit;
            end;
            Background := Node.AsXmlElement();
        end else begin
            if this.PageColor = '' then
                exit;
            if not Document.SelectSingleNode('/w:document', NamespaceManager, Node) then
                exit;
            // w:background must be the first child of w:document.
            Background := XmlElement.Create('background', WordNamespaceTxt);
            Node.AsXmlElement().AddFirst(Background);
        end;

        // Theme colour attributes take precedence over w:color, so drop them.
        Background.RemoveAttribute('themeColor', WordNamespaceTxt);
        Background.RemoveAttribute('themeTint', WordNamespaceTxt);
        Background.RemoveAttribute('themeShade', WordNamespaceTxt);
        Background.SetAttribute('color', WordNamespaceTxt, this.PageColor);
    end;

    local procedure PatchSettings(var Document: XmlDocument; NamespaceManager: XmlNamespaceManager)
    var
        Node: XmlNode;
        SettingsElement: XmlElement;
        PrecedingNames: List of [Text];
        PrecedingName: Text;
        Anchor: XmlNode;
        AnchorFound: Boolean;
    begin
        // Word only shows the page colour when editing if w:displayBackgroundShape is set.
        if not Document.SelectSingleNode('/w:settings', NamespaceManager, Node) then
            exit;
        SettingsElement := Node.AsXmlElement();
        if SettingsElement.SelectSingleNode('w:displayBackgroundShape', NamespaceManager, Node) then
            exit;

        PrecedingNames.AddRange('writeProtection', 'view', 'zoom', 'removePersonalInformation', 'removeDateAndTime', 'doNotDisplayPageBoundaries');
        foreach PrecedingName in PrecedingNames do
            if SettingsElement.SelectSingleNode('w:' + PrecedingName, NamespaceManager, Node) then begin
                Anchor := Node;
                AnchorFound := true;
            end;

        if AnchorFound then
            Anchor.AddAfterSelf(XmlElement.Create('displayBackgroundShape', WordNamespaceTxt))
        else
            SettingsElement.AddFirst(XmlElement.Create('displayBackgroundShape', WordNamespaceTxt));
    end;

    local procedure GetOrAddFirstChild(Parent: XmlElement; NamespaceManager: XmlNamespaceManager; ElementName: Text): XmlElement
    var
        Node: XmlNode;
        Child: XmlElement;
    begin
        if Parent.SelectSingleNode('w:' + ElementName, NamespaceManager, Node) then
            exit(Node.AsXmlElement());
        Child := XmlElement.Create(ElementName, WordNamespaceTxt);
        Parent.AddFirst(Child);
        exit(Child);
    end;

    local procedure InsertBeforeFirst(Parent: XmlElement; NamespaceManager: XmlNamespaceManager; NewElement: XmlElement; FollowingNames: List of [Text])
    var
        Node: XmlNode;
        FollowingName: Text;
    begin
        // Keeps CT_RPr schema order: insert before the first existing element that must follow.
        foreach FollowingName in FollowingNames do
            if Parent.SelectSingleNode(FollowingName, NamespaceManager, Node) then begin
                Node.AddBeforeSelf(NewElement);
                exit;
            end;
        Parent.Add(NewElement);
    end;

    local procedure RunPropertiesAfterSize(ElementName: Text) FollowingNames: List of [Text]
    begin
        if ElementName = 'sz' then
            FollowingNames.Add('w:szCs');
        FollowingNames.AddRange('w:highlight', 'w:u', 'w:effect', 'w:bdr', 'w:shd', 'w:fitText', 'w:vertAlign', 'w:rtl', 'w:cs', 'w:em', 'w:lang', 'w:eastAsianLayout', 'w:specVanish', 'w:oMath');
    end;

    local procedure SlotElementName(Slot: Enum "Report Theme Color Slot"): Text
    begin
        case Slot of
            Slot::Dark1:
                exit('dk1');
            Slot::Light1:
                exit('lt1');
            Slot::Dark2:
                exit('dk2');
            Slot::Light2:
                exit('lt2');
            Slot::Accent1:
                exit('accent1');
            Slot::Accent2:
                exit('accent2');
            Slot::Accent3:
                exit('accent3');
            Slot::Accent4:
                exit('accent4');
            Slot::Accent5:
                exit('accent5');
            Slot::Accent6:
                exit('accent6');
            Slot::Hyperlink:
                exit('hlink');
            Slot::FollowedHyperlink:
                exit('folHlink');
        end;
    end;

    local procedure NormalizeColor(HexColor: Text): Text
    var
        Normalized: Text;
        Position: Integer;
    begin
        Normalized := HexColor.Trim().TrimStart('#').ToUpper();
        if StrLen(Normalized) <> 6 then
            Error(InvalidColorErr, HexColor);
        for Position := 1 to 6 do
            if StrPos('0123456789ABCDEF', Normalized[Position]) = 0 then
                Error(InvalidColorErr, HexColor);
        exit(Normalized);
    end;
}
