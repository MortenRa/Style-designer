namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;
using System.Reflection;
using System.Utilities;

/// Turns a "Report Style Config" into a theme part, stores it under the Tenant Report Defaults report,
/// assigns it, and previews the target Body layout with it.
codeunit 50102 "Report Style Configurator Mgt."
{
    Access = Internal;
    var
        TenantReportDefaultsTok: Label '2000000001', Locked = true;
        NotBodyErr: Label 'Themes only apply to Body layouts. Layout %1 of report %2 is not a Body layout.', Comment = '%1 = layout name, %2 = report ID';
        SameNameErr: Label 'Save the theme under a different name than the base theme, so the base theme is not overwritten.';
        NoBaseErr: Label 'Base theme %1 was not found.', Comment = '%1 = theme name';
        NoNameErr: Label 'Specify a name to save the theme as.';
        AppliedMsg: Label 'Theme %1 was saved and assigned to %2.', Comment = '%1 = theme name, %2 = what it was assigned to';
        CompanyDefaultTxt: Label 'the company default';
        OtherKindErr: Label 'A theme or header/footer named %1 already exists. Choose another name.', Comment = '%1 = name';
        LayoutTargetTxt: Label 'layout %1 of report %2', Comment = '%1 = layout name, %2 = report ID';

    procedure LookupBodyLayout(var Config: Record "Report Style Config"): Boolean
    var
        ReportLayoutList: Record "Report Layout List";
        BodyLayouts: Page "Report Style Body Layouts";
    begin
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Body);
        BodyLayouts.SetTableView(ReportLayoutList);
        // Open on the layout that is selected now.
        ReportLayoutList.SetRange("Report ID", Config."Target Report ID");
        ReportLayoutList.SetRange(Name, Config."Target Layout Name");
        if ReportLayoutList.FindFirst() then
            BodyLayouts.SetRecord(ReportLayoutList);
        ReportLayoutList.SetRange("Report ID");
        ReportLayoutList.SetRange(Name);
        BodyLayouts.LookupMode(true);
        if BodyLayouts.RunModal() <> Action::LookupOK then
            exit(false);
        BodyLayouts.GetRecord(ReportLayoutList);
        Config."Target Report ID" := ReportLayoutList."Report ID";
        Config."Target Layout Name" := ReportLayoutList.Name;
        Config."Target Layout App ID" := ReportLayoutList."Application ID";
        exit(true);
    end;

    procedure ValidateBodyLayout(var Config: Record "Report Style Config")
    var
        ReportLayoutList: Record "Report Layout List";
    begin
        ReportLayoutList.SetRange("Report ID", Config."Target Report ID");
        ReportLayoutList.SetRange(Name, Config."Target Layout Name");
        if not ReportLayoutList.FindFirst() then
            Error(NotBodyErr, Config."Target Layout Name", Config."Target Report ID");
        if ReportLayoutList."Layout Subtype" <> ReportLayoutList."Layout Subtype"::Body then
            Error(NotBodyErr, Config."Target Layout Name", Config."Target Report ID");
        Config."Target Layout App ID" := ReportLayoutList."Application ID";
    end;

    procedure Apply(var Config: Record "Report Style Config"; ShowMessage: Boolean)
    var
        Generated: Codeunit "Temp Blob";
        Target: Text;
    begin
        if Config."Theme Name".Trim() = '' then
            Error(NoNameErr);
        if Config."Theme Name" = Config."Base Theme" then
            Error(SameNameErr);
        if Config."Assign To" = Config."Assign To"::Layout then
            ValidateBodyLayout(Config);

        GenerateTheme(Config, Generated);
        StorePart(Config."Theme Name", Generated);

        if Config."Assign To" = Config."Assign To"::CompanyDefault then begin
            AssignTheme(0, '', CopyStr(CompanyName(), 1, 30), Config."Theme Name");
            Target := CompanyDefaultTxt;
        end else begin
            AssignTheme(Config."Target Report ID", EncodePartName(Config."Target Layout App ID", Config."Target Layout Name"), '', Config."Theme Name");
            Target := StrSubstNo(LayoutTargetTxt, Config."Target Layout Name", Config."Target Report ID");
        end;

        if ShowMessage then
            Message(AppliedMsg, Config."Theme Name", Target);
    end;

    procedure ApplyAndPreview(var Config: Record "Report Style Config")
    var
        Pdf: Codeunit "Temp Blob";
    begin
        ApplyAndRenderPdf(Config, Pdf);
        File.ViewFromStream(Pdf.CreateInStream(), StrSubstNo('%1 - %2.pdf', Config."Target Layout Name", Config."Theme Name"), true);
    end;

    procedure ApplyAndRenderPdf(var Config: Record "Report Style Config"; var Pdf: Codeunit "Temp Blob")
    var
        Previous: Record "Tenant Report Layout Selection" temporary;
        PdfOutStream: OutStream;
        HadPrevious: Boolean;
    begin
        ValidateBodyLayout(Config);
        Apply(Config, false);
        SelectBodyLayout(Config, Previous, HadPrevious);
        Commit();

        Pdf.CreateOutStream(PdfOutStream);
        if not TrySaveAsPdf(Config."Target Report ID", PdfOutStream) then begin
            RestoreSelection(Config, Previous, HadPrevious);
            Commit();
            Error(GetLastErrorText());
        end;
        RestoreSelection(Config, Previous, HadPrevious);
        Commit();
    end;

    procedure ApplyAndRunReport(var Config: Record "Report Style Config")
    var
        Previous: Record "Tenant Report Layout Selection" temporary;
        HadPrevious: Boolean;
    begin
        ValidateBodyLayout(Config);
        Apply(Config, false);
        SelectBodyLayout(Config, Previous, HadPrevious);
        Commit();

        Report.RunModal(Config."Target Report ID");
        RestoreSelection(Config, Previous, HadPrevious);
        Commit();
    end;

    [TryFunction]
    local procedure TrySaveAsPdf(ReportID: Integer; PdfOutStream: OutStream)
    begin
        Report.SaveAs(ReportID, '', ReportFormat::Pdf, PdfOutStream);
    end;

    // Makes the Body layout the company's selected layout for the report, keeping the old selection to restore.
    // The selection's own part fields are left empty so the theme assignment decides the theme.
    local procedure SelectBodyLayout(Config: Record "Report Style Config"; var Previous: Record "Tenant Report Layout Selection" temporary; var HadPrevious: Boolean)
    var
        Selection: Record "Tenant Report Layout Selection";
        EmptyGuid: Guid;
    begin
        HadPrevious := Selection.Get(Config."Target Report ID", CompanyName(), EmptyGuid);
        if HadPrevious then begin
            Previous := Selection;
            Previous.Insert();
            Selection.Delete();
        end;
        Selection.Init();
        Selection."Report ID" := Config."Target Report ID";
        Selection."Company Name" := CopyStr(CompanyName(), 1, MaxStrLen(Selection."Company Name"));
        Selection."User ID" := EmptyGuid;
        Selection."Layout Name" := Config."Target Layout Name";
        Selection."App ID" := Config."Target Layout App ID";
        Selection.Insert();
    end;

    local procedure RestoreSelection(Config: Record "Report Style Config"; var Previous: Record "Tenant Report Layout Selection" temporary; HadPrevious: Boolean)
    var
        Selection: Record "Tenant Report Layout Selection";
        EmptyGuid: Guid;
    begin
        if Selection.Get(Config."Target Report ID", CompanyName(), EmptyGuid) then
            Selection.Delete();
        if HadPrevious then begin
            Selection := Previous;
            Selection.Insert();
        end;
    end;

    procedure GenerateTheme(Config: Record "Report Style Config"; var Generated: Codeunit "Temp Blob")
    var
        Generator: Codeunit "Report Theme Generator";
        Base: Codeunit "Temp Blob";
    begin
        GetBaseTheme(Config."Base Theme", Base);
        Generator.SetThemeName(Config."Theme Name");
        if Config.Palette = Config.Palette::Custom then
            SetColors(Generator, Config."Custom Colors".Split(','))
        else
            SetPalette(Generator, Config.Palette);
        SetFonts(Generator, Config."Font Pair");
        if Config."Base Font Size" <> 0 then
            Generator.SetBaseFontSize(Config."Base Font Size");
        if Config."Page Color" = Config."Page Color"::Custom then begin
            if Config."Custom Page Color" <> '' then
                Generator.SetPageColor(Config."Custom Page Color");
        end else
            SetPageColor(Generator, Config."Page Color");
        Generator.SetTableStyle(Config."Table Style");
        Generator.Generate(Base.CreateInStream(), Generated);
    end;

    procedure GetBaseTheme(ThemeName: Text; var Theme: Codeunit "Temp Blob")
    var
        ReportLayoutList: Record "Report Layout List";
        LayoutOutStream: OutStream;
    begin
        ReportLayoutList.SetRange("Report ID", TenantReportDefaultsId());
        ReportLayoutList.SetRange(Name, ThemeName);
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Theme);
        if not ReportLayoutList.FindFirst() then
            Error(NoBaseErr, ThemeName);
        Theme.CreateOutStream(LayoutOutStream);
        ReportLayoutList.Layout.ExportStream(LayoutOutStream);
    end;

    procedure StorePart(ThemeName: Text[250]; Generated: Codeunit "Temp Blob")
    begin
        StorePartOfKind(ThemeName, Generated, false);
    end;

    /// Stores a generated theme (IsHeaderFooter = false) or header/footer part under Tenant Report Defaults.
    procedure StorePartOfKind(ThemeName: Text[250]; Generated: Codeunit "Temp Blob"; IsHeaderFooter: Boolean)
    var
        TenantReportLayout: Record "Tenant Report Layout";
        Prepared: Codeunit "Temp Blob";
        PreparedInStream: InStream;
        EmptyGuid: Guid;
    begin
        // Run the same validation/preparation the insert trigger does, so an update in place gets it too.
        PreparedInStream := Prepared.CreateInStream(TextEncoding::UTF8);
        if not Report.ValidateAndPrepareLayout(TenantReportDefaultsId(), Generated.CreateInStream(TextEncoding::UTF8), PreparedInStream, ReportLayoutType::Word) then
            Error(GetLastErrorText());

        if TenantReportLayout.Get(TenantReportDefaultsId(), ThemeName, EmptyGuid) then begin
            if (TenantReportLayout."Layout Subtype" = TenantReportLayout."Layout Subtype"::HeaderFooter) <> IsHeaderFooter then
                Error(OtherKindErr, ThemeName);
            TenantReportLayout.Layout.ImportStream(PreparedInStream, ThemeName);
            TenantReportLayout."Layout Status" := TenantReportLayout."Layout Status"::Approved;
            TenantReportLayout.Modify(true);
            exit;
        end;

        TenantReportLayout.Init();
        TenantReportLayout."Report ID" := TenantReportDefaultsId();
        TenantReportLayout.Name := ThemeName;
        TenantReportLayout.Description := ThemeName;
        TenantReportLayout."Company Name" := '';
        TenantReportLayout."Layout Format" := TenantReportLayout."Layout Format"::Word;
        if IsHeaderFooter then begin
            TenantReportLayout."Layout Subtype" := TenantReportLayout."Layout Subtype"::HeaderFooter;
            TenantReportLayout."MIME Type" := 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        end else begin
            TenantReportLayout."Layout Subtype" := TenantReportLayout."Layout Subtype"::Theme;
            TenantReportLayout."MIME Type" := 'application/vnd.openxmlformats-officedocument.wordprocessingml.template';
        end;
        TenantReportLayout."Layout Status" := TenantReportLayout."Layout Status"::Approved;
        TenantReportLayout.Layout.ImportStream(PreparedInStream, ThemeName);
        TenantReportLayout.Insert(true);
    end;

    procedure AssignTheme(ReportID: Integer; LayoutName: Text; ForCompany: Text[30]; ThemeName: Text)
    var
        TenantReportLayoutCfg: Record "Tenant Report Layout Cfg";
        EmptyGuid: Guid;
    begin
        if TenantReportLayoutCfg.Get(ReportID, LayoutName, ForCompany) then begin
            TenantReportLayoutCfg."Theme Part Name" := CopyStr(EncodePartName(EmptyGuid, ThemeName), 1, MaxStrLen(TenantReportLayoutCfg."Theme Part Name"));
            TenantReportLayoutCfg.Modify(true);
            exit;
        end;
        TenantReportLayoutCfg.Init();
        TenantReportLayoutCfg."Report ID" := ReportID;
        TenantReportLayoutCfg."Layout Name" := CopyStr(LayoutName, 1, MaxStrLen(TenantReportLayoutCfg."Layout Name"));
        TenantReportLayoutCfg."Company Name" := ForCompany;
        TenantReportLayoutCfg."Theme Part Name" := CopyStr(EncodePartName(EmptyGuid, ThemeName), 1, MaxStrLen(TenantReportLayoutCfg."Theme Part Name"));
        TenantReportLayoutCfg.Insert(true);
    end;

    procedure EncodePartName(AppID: Guid; Name: Text): Text
    begin
        // Same shape as CompositeLayoutLookupHelper.EncodeCompositeName: <lowercase guid>::<name>.
        exit(LowerCase(Format(AppID, 0, 4)) + '::' + Name);
    end;

    procedure TenantReportDefaultsId() ReportID: Integer
    begin
        Evaluate(ReportID, TenantReportDefaultsTok);
    end;

    local procedure SetPalette(var Generator: Codeunit "Report Theme Generator"; Palette: Enum "Report Style Palette")
    begin
        SetColors(Generator, GetPaletteColors(Palette));
    end;

    local procedure SetColors(var Generator: Codeunit "Report Theme Generator"; Colors: List of [Text])
    var
        Slot: Integer;
    begin
        if Colors.Count() <> 12 then
            exit;
        for Slot := 1 to Colors.Count() do
            Generator.SetColor(Enum::"Report Theme Color Slot".FromInteger(Slot - 1), Colors.Get(Slot));
    end;

    /// The 12 colours in clrScheme order (dk1, lt1, dk2, lt2, accent1-6, hlink, folHlink); empty for KeepBase.
    /// Slot roles follow the shipped Default theme: Accent 1 = table banding, Accent 2 = rules, Accent 3 = emphasis.
    procedure GetPaletteColors(Palette: Enum "Report Style Palette") Colors: List of [Text]
    begin
        case Palette of
            Palette::Nature:
                Colors.AddRange('2F3E2E', 'FFFFFF', '2F3E2E', 'EEF3E8', 'EEF3E8', 'C9D8BD', '4F7A3A', '8AA668', 'B5651D', '5A7D8C', '4F7A3A', '2F3E2E');
            Palette::Ocean:
                Colors.AddRange('1F2A37', 'FFFFFF', '1F2A37', 'EEF4F9', 'EEF4F9', 'D3E2EE', '1F6FA8', '4F9AC9', 'E0A100', '7A5BA8', '1F6FA8', '3B4A5C');
            Palette::Sunset:
                Colors.AddRange('3A2A25', 'FFFFFF', '3A2A25', 'FBF1EA', 'FBF1EA', 'F0D9C8', 'C2502A', 'E08E45', '8A6F2A', '6B4E71', 'C2502A', '7A4A3A');
            Palette::Graphite:
                Colors.AddRange('202020', 'FFFFFF', '202020', 'F2F2F2', 'F2F2F2', 'D9D9D9', '404040', '7F7F7F', 'A6A6A6', '595959', '404040', '202020');
        end;
    end;

    local procedure SetFonts(var Generator: Codeunit "Report Theme Generator"; FontPair: Enum "Report Style Font Pair")
    var
        HeadingFont: Text;
        BodyFont: Text;
    begin
        if GetFontPair(FontPair, HeadingFont, BodyFont) then
            Generator.SetFonts(HeadingFont, BodyFont);
    end;

    procedure GetFontPair(FontPair: Enum "Report Style Font Pair"; var HeadingFont: Text; var BodyFont: Text): Boolean
    begin
        case FontPair of
            FontPair::SegoeUI:
                SetPair(HeadingFont, BodyFont, 'Segoe UI Semibold', 'Segoe UI');
            FontPair::GeorgiaVerdana:
                SetPair(HeadingFont, BodyFont, 'Georgia', 'Verdana');
            FontPair::CambriaCalibri:
                SetPair(HeadingFont, BodyFont, 'Cambria', 'Calibri');
            FontPair::Bahnschrift:
                SetPair(HeadingFont, BodyFont, 'Bahnschrift SemiBold', 'Bahnschrift');
            FontPair::Sitka:
                SetPair(HeadingFont, BodyFont, 'Sitka Display Semibold', 'Sitka Text');
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure SetPair(var HeadingFont: Text; var BodyFont: Text; NewHeading: Text; NewBody: Text)
    begin
        HeadingFont := NewHeading;
        BodyFont := NewBody;
    end;

    local procedure SetPageColor(var Generator: Codeunit "Report Theme Generator"; PageColor: Enum "Report Style Page Color")
    begin
        if PageColor <> PageColor::KeepBase then
            Generator.SetPageColor(GetPageColorHex(PageColor));
    end;

    /// Hex for the page colour; empty for White (removes the colour) and KeepBase.
    procedure GetPageColorHex(PageColor: Enum "Report Style Page Color"): Text
    begin
        case PageColor of
            PageColor::SoftGreen:
                exit('F4F8EF');
            PageColor::SoftBlue:
                exit('F2F7FB');
            PageColor::WarmPaper:
                exit('FBF7F0');
            PageColor::LightGrey:
                exit('F5F5F5');
        end;
        exit('');
    end;
}