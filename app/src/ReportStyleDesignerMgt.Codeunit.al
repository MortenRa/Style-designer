namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;
using System.IO;
using System.Reflection;
using System.Utilities;

/// Backend of the Report Style Designer add-in: builds its data, renders previews for the current user only,
/// and saves/assigns themes on request.
codeunit 50104 "Report Style Designer Mgt."
{
    Access = Internal;
    var
        ConfiguratorMgt: Codeunit "Report Style Configurator Mgt.";
        DocGroups: Codeunit "Report Style Doc Groups";
        PreviewPrefixTok: Label 'Preview ', Locked = true;
        HeaderFooterBaseTok: Label 'ExternalDefaultDetailedHFDesign', Locked = true;
        PreviewBusyErr: Label 'This report is being previewed in another window. Try again in a moment.';

    procedure GetConfig(var Config: Record "Report Style Config")
    begin
        if Config.Get() then begin
            // Settings saved before "Design your own" existed get its defaults once.
            if Config."HF Name" = '' then begin
                Config."HF Name" := 'Custom Header/Footer';
                Config."HF Show Date" := true;
                Config.Modify();
            end;
            exit;
        end;
        Config.Init();
        Config."Base Theme" := 'DefaultTheme';
        Config.Insert();
    end;

    procedure BuildStudioData(var Config: Record "Report Style Config"): Text
    begin
        exit(BuildStudioData(Config, ''));
    end;

    /// SuggestionsJson: the last Copilot proposals (JSON array), shown as a strip on the Theme tab.
    procedure BuildStudioData(var Config: Record "Report Style Config"; SuggestionsJson: Text): Text
    var
        ReportStyleCopilot: Codeunit "Report Style Copilot";
        Data: JsonObject;
        Copilot: JsonObject;
        Suggestions: JsonArray;
        BrandHex: Text;
        LogoBase64: Text;
        Result: Text;
        CopilotEnabled: Boolean;
    begin
        CopilotEnabled := ReportStyleCopilot.IsAvailable();
        Copilot.Add('enabled', CopilotEnabled);
        if CopilotEnabled then begin
            ReportStyleCopilot.GetCompanyBrand(BrandHex, LogoBase64);
            Copilot.Add('logo', LogoBase64);
        end;
        if Suggestions.ReadFrom(SuggestionsJson) then
            Copilot.Add('suggestions', Suggestions);
        Copilot.Add('customPalette', Enum::"Report Style Palette"::Custom.AsInteger());
        Data.Add('customPageId', Enum::"Report Style Page Color"::Custom.AsInteger());
        Data.Add('groups', DocGroups.GetGroups());
        Data.Add('copilot', Copilot);
        Data.Add('layouts', GetBodyLayouts());
        Data.Add('themes', GetThemes());
        Data.Add('palettes', GetPalettes());
        Data.Add('fonts', GetFonts());
        Data.Add('pageColors', GetPageColors());
        Data.Add('tableStyles', GetTableStyles());
        Data.Add('headers', GetHeaderParts());
        Data.Add('company', GetCompanyAssignment());
        Data.Add('state', StateFromConfig(Config));
        Data.WriteTo(Result);
        exit(Result);
    end;

    procedure ApplyState(var Config: Record "Report Style Config"; StateText: Text)
    var
        State: JsonObject;
        Token: JsonToken;
    begin
        State.ReadFrom(StateText);
        if State.Get('reportId', Token) then
            Config."Target Report ID" := Token.AsValue().AsInteger();
        if State.Get('layoutName', Token) then
            Config."Target Layout Name" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."Target Layout Name"));
        if State.Get('layoutAppId', Token) then
            Evaluate(Config."Target Layout App ID", Token.AsValue().AsText());
        if State.Get('baseTheme', Token) then
            Config."Base Theme" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."Base Theme"));
        if State.Get('palette', Token) then
            Config.Palette := Enum::"Report Style Palette".FromInteger(Token.AsValue().AsInteger());
        if State.Get('customColors', Token) then
            Config."Custom Colors" := CustomColorsFromJson(Token);
        if (Config.Palette = Config.Palette::Custom) and (Config."Custom Colors" = '') then
            Config.Palette := Config.Palette::KeepBase;
        if State.Get('fonts', Token) then
            Config."Font Pair" := Enum::"Report Style Font Pair".FromInteger(Token.AsValue().AsInteger());
        if State.Get('size', Token) then
            Config."Base Font Size" := Token.AsValue().AsDecimal();
        if State.Get('pageColor', Token) then
            Config."Page Color" := Enum::"Report Style Page Color".FromInteger(Token.AsValue().AsInteger());
        if State.Get('customPage', Token) then
            Config."Custom Page Color" := CustomPageFromJson(Token);
        if (Config."Page Color" = Config."Page Color"::Custom) and (Config."Custom Page Color" = '') then
            Config."Page Color" := Config."Page Color"::White;
        if State.Get('tableStyle', Token) then
            Config."Table Style" := Enum::"Report Theme Table Style".FromInteger(Token.AsValue().AsInteger());
        if State.Get('headerPart', Token) then
            Config."Header Part" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."Header Part"));
        if State.Get('headerAppId', Token) then
            if not Evaluate(Config."Header Part App ID", Token.AsValue().AsText()) then
                Clear(Config."Header Part App ID");
        if State.Get('themeMode', Token) then
            Config."Theme Mode" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."Theme Mode"));
        if State.Get('headerMode', Token) then
            Config."Header Mode" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."Header Mode"));
        if State.Get('applyTo', Token) then
            Config."Apply To" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."Apply To"));
        if State.Get('applyGroup', Token) then
            Config."Apply Group" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."Apply Group"));
        if State.Get('hfLogo', Token) then
            Config."HF Logo" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."HF Logo"));
        if State.Get('hfPageNumber', Token) then
            Config."HF Page Number" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."HF Page Number"));
        if State.Get('hfShowDate', Token) then
            Config."HF Show Date" := Token.AsValue().AsBoolean();
        if State.Get('hfLaterPages', Token) then
            Config."HF Later Pages" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."HF Later Pages"));
        if State.Get('hfFooter', Token) then
            Config."HF Footer" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."HF Footer"));
        if State.Get('hfAccentLine', Token) then
            Config."HF Accent Line" := Token.AsValue().AsBoolean();
        if State.Get('hfName', Token) then
            Config."HF Name" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."HF Name"));
        if State.Get('themeName', Token) then
            Config."Theme Name" := CopyStr(Token.AsValue().AsText(), 1, MaxStrLen(Config."Theme Name"));
        Config.Modify();
    end;

    /// Preview, step 1: prepares a render of the Body layout with the configured theme and header/footer for the
    /// current user only, without touching anything others use. A private copy of the Body layout gets the
    /// parts, and only the current user's layout selection points at that copy. Committed, so step 2 can render.
    /// (A theme on the selection row itself would be simpler, but the platform does not use it yet.)
    procedure PreviewSetup(var Config: Record "Report Style Config"; var PreviewName: Text[250]; var Previous: Record "Tenant Report Layout Selection" temporary; var HadPrevious: Boolean)
    var
        PreviewConfig: Record "Report Style Config";
        Generated: Codeunit "Temp Blob";
    begin
        ConfiguratorMgt.ValidateBodyLayout(Config);
        // A unique name per preview, so previews in two windows never touch each other's temporary parts.
        PreviewName := GetPreviewPartName();
        RemoveStalePreviewArtifacts();

        if ThemeMode(Config) = 'custom' then begin
            PreviewConfig := Config;
            PreviewConfig."Theme Name" := PreviewName;
            ConfiguratorMgt.GenerateTheme(PreviewConfig, Generated);
            ConfiguratorMgt.StorePart(PreviewName, Generated);
        end;
        if HeaderMode(Config) = 'design' then begin
            GenerateHeaderFooter(Config, Generated);
            ConfiguratorMgt.StorePartOfKind(PreviewHeaderName(PreviewName), Generated, true);
        end;
        CopyBodyLayout(Config, PreviewName);
        AssignPreviewTheme(Config, PreviewName);
        SelectForCurrentUser(Config."Target Report ID", PreviewName, Previous, HadPrevious);
        Commit();
    end;

    /// Preview, step 2: renders the report to PDF.
    procedure PreviewRender(var Config: Record "Report Style Config"; var Pdf: Codeunit "Temp Blob")
    var
        PdfOutStream: OutStream;
    begin
        Pdf.CreateOutStream(PdfOutStream);
        Report.SaveAs(Config."Target Report ID", GetParameters(Config), ReportFormat::Pdf, PdfOutStream);
    end;

    /// Preview, step 3: removes everything step 1 created and restores the user's own selection. Always runs.
    procedure PreviewCleanup(ReportID: Integer; PreviewName: Text[250]; var Previous: Record "Tenant Report Layout Selection" temporary; HadPrevious: Boolean)
    begin
        if PreviewName = '' then
            exit;
        RestoreUserSelection(ReportID, PreviewName, Previous, HadPrevious);
        RemovePreviewArtifacts(ReportID, PreviewName);
        Commit();
    end;
    local procedure CopyBodyLayout(Config: Record "Report Style Config"; PreviewName: Text[250])
    var
        ReportLayoutList: Record "Report Layout List";
        TenantReportLayout: Record "Tenant Report Layout";
        Body: Codeunit "Temp Blob";
        BodyOutStream: OutStream;
    begin
        ReportLayoutList.SetRange("Report ID", Config."Target Report ID");
        ReportLayoutList.SetRange(Name, Config."Target Layout Name");
        ReportLayoutList.SetRange("Application ID", Config."Target Layout App ID");
        ReportLayoutList.FindFirst();
        Body.CreateOutStream(BodyOutStream);
        ReportLayoutList.Layout.ExportStream(BodyOutStream);

        TenantReportLayout.Init();
        TenantReportLayout."Report ID" := Config."Target Report ID";
        TenantReportLayout.Name := PreviewName;
        TenantReportLayout.Description := PreviewName;
        TenantReportLayout."Layout Format" := TenantReportLayout."Layout Format"::Word;
        TenantReportLayout."Layout Subtype" := TenantReportLayout."Layout Subtype"::Body;
        TenantReportLayout."Layout Status" := TenantReportLayout."Layout Status"::Approved;
        TenantReportLayout."MIME Type" := ReportLayoutList."MIME Type";
        TenantReportLayout.Layout.ImportStream(Body.CreateInStream(TextEncoding::UTF8), PreviewName);
        TenantReportLayout.Insert(true);
    end;

    // The copy gets exactly the header and theme the original layout would get after saving: the parts are
    // resolved through the six assignment levels with this save applied at its level.
    local procedure AssignPreviewTheme(Config: Record "Report Style Config"; PreviewName: Text[250])
    var
        PreviewCfg: Record "Tenant Report Layout Cfg";
        LayoutKey: Text[250];
        EmptyGuid: Guid;
        Level: Integer;
    begin
        LayoutKey := CopyStr(ConfiguratorMgt.EncodePartName(Config."Target Layout App ID", Config."Target Layout Name"), 1, 250);
        PreviewCfg.Init();
        PreviewCfg."Report ID" := Config."Target Report ID";
        PreviewCfg."Layout Name" := CopyStr(ConfiguratorMgt.EncodePartName(EmptyGuid, PreviewName), 1, MaxStrLen(PreviewCfg."Layout Name"));
        PreviewCfg."Company Name" := '';
        PreviewCfg."Theme Part Name" := CopyStr(Effective(Config, LayoutKey, false, ConfiguratorMgt.EncodePartName(EmptyGuid, PreviewName), Level), 1, MaxStrLen(PreviewCfg."Theme Part Name"));
        PreviewCfg."Header Part Name" := CopyStr(Effective(Config, LayoutKey, true, PreviewHeaderRef(Config, PreviewName), Level), 1, MaxStrLen(PreviewCfg."Header Part Name"));
        if (PreviewCfg."Theme Part Name" <> '') or (PreviewCfg."Header Part Name" <> '') then
            PreviewCfg.Insert(true);
    end;

    // Part a layout resolves to, with this configuration's choice applied at its target level
    // (keep: as today, default: cleared at that level, custom: CustomRef at that level).
    local procedure Effective(Config: Record "Report Style Config"; LayoutKey: Text[250]; IsHeader: Boolean; CustomRef: Text; var FoundLevel: Integer): Text
    var
        Mode: Text;
        OverrideLevel: Integer;
        Level: Integer;
        Value: Text;
    begin
        if IsHeader then
            Mode := HeaderMode(Config)
        else
            Mode := ThemeMode(Config);
        if IsHeader and (Mode = 'custom') and (Config."Header Part" = '') then
            Mode := 'keep';
        if ModeOr(Config."Apply To", 'layout') = 'company' then
            OverrideLevel := 5
        else
            OverrideLevel := 2;
        for Level := 1 to 6 do begin
            if (Level = OverrideLevel) and (Mode in ['custom', 'design']) then
                Value := CustomRef
            else
                if (Level = OverrideLevel) and (Mode = 'default') then
                    Value := ''
                else
                    Value := PartAtLevel(Config."Target Report ID", LayoutKey, Level, IsHeader);
            if Value <> '' then begin
                FoundLevel := Level;
                exit(Value);
            end;
        end;
        FoundLevel := 0;
        exit('');
    end;

    // The six Tenant Report Layout Cfg levels the platform walks, most specific first.
    local procedure PartAtLevel(ReportID: Integer; LayoutKey: Text[250]; Level: Integer; IsHeader: Boolean): Text
    var
        Cfg: Record "Tenant Report Layout Cfg";
        Company: Text[30];
        Found: Boolean;
    begin
        Company := CopyStr(CompanyName(), 1, 30);
        case Level of
            1:
                Found := Cfg.Get(ReportID, LayoutKey, Company);
            2:
                Found := Cfg.Get(ReportID, LayoutKey, '');
            3:
                Found := Cfg.Get(ReportID, '', Company);
            4:
                Found := Cfg.Get(ReportID, '', '');
            5:
                Found := Cfg.Get(0, '', Company);
            6:
                Found := Cfg.Get(0, '', '');
        end;
        if not Found then
            exit('');
        if IsHeader then
            exit(Cfg."Header Part Name");
        exit(Cfg."Theme Part Name");
    end;

    local procedure AddCurrentParts(var Item: JsonObject; ReportID: Integer; LayoutKey: Text[250])
    var
        Level: Integer;
    begin
        Item.Add('currentTheme', PartName(FirstPart(ReportID, LayoutKey, false, Level)));
        Item.Add('currentThemeFrom', LevelCaption(Level));
        Item.Add('currentHeader', PartName(FirstPart(ReportID, LayoutKey, true, Level)));
        Item.Add('currentHeaderFrom', LevelCaption(Level));
    end;

    local procedure GetCompanyAssignment() Company: JsonObject
    begin
        Company.Add('theme', PartName(PartAtLevel(0, '', 5, false)));
        Company.Add('header', PartName(PartAtLevel(0, '', 5, true)));
        Company.Add('globalTheme', PartName(PartAtLevel(0, '', 6, false)));
        Company.Add('globalHeader', PartName(PartAtLevel(0, '', 6, true)));
    end;

    local procedure FirstPart(ReportID: Integer; LayoutKey: Text[250]; IsHeader: Boolean; var FoundLevel: Integer): Text
    var
        Level: Integer;
        Value: Text;
    begin
        for Level := 1 to 6 do begin
            Value := PartAtLevel(ReportID, LayoutKey, Level, IsHeader);
            if Value <> '' then begin
                FoundLevel := Level;
                exit(Value);
            end;
        end;
        FoundLevel := 0;
    end;

    local procedure LevelCaption(Level: Integer): Text
    begin
        case Level of
            1, 2:
                exit('this document');
            3, 4:
                exit('this report');
            5:
                exit('company default');
            6:
                exit('global default');
        end;
        exit('none');
    end;

    // "<guid>::Name" -> "Name"
    local procedure PartName(Ref: Text): Text
    begin
        if Ref.Contains('::') then
            exit(Ref.Substring(Ref.IndexOf('::') + 2));
        exit(Ref);
    end;

    local procedure ThemeMode(Config: Record "Report Style Config"): Text
    begin
        exit(ModeOr(Config."Theme Mode", 'custom'));
    end;

    local procedure HeaderMode(Config: Record "Report Style Config"): Text
    begin
        // Older configurations had only a design field: a chosen design meant "custom".
        if (Config."Header Mode" = '') and (Config."Header Part" <> '') then
            exit('custom');
        exit(ModeOr(Config."Header Mode", 'keep'));
    end;

    local procedure ModeOr(Value: Text; Fallback: Text): Text
    begin
        if Value = '' then
            exit(Fallback);
        exit(Value);
    end;
    local procedure RemovePreviewArtifacts(ReportID: Integer; PreviewName: Text[250])
    var
        PreviewCfg: Record "Tenant Report Layout Cfg";
        TenantReportLayout: Record "Tenant Report Layout";
        EmptyGuid: Guid;
    begin
        PreviewCfg.SetRange("Report ID", ReportID);
        PreviewCfg.SetRange("Layout Name", CopyStr(ConfiguratorMgt.EncodePartName(EmptyGuid, PreviewName), 1, MaxStrLen(PreviewCfg."Layout Name")));
        PreviewCfg.DeleteAll();
        if TenantReportLayout.Get(ReportID, PreviewName, EmptyGuid) then
            TenantReportLayout.Delete();
        DeletePart(PreviewName);
        DeletePart(PreviewHeaderName(PreviewName));
    end;

    /// Saves only what the user chose to change. Mode 'apply' assigns to the Apply To target; 'theme' only stores
    /// the custom theme as a part without assigning it.
    procedure Save(var Config: Record "Report Style Config"; Mode: Text): Text
    var
        Generated: Codeunit "Temp Blob";
        Result: TextBuilder;
        LayoutKey: Text[250];
        EmptyGuid: Guid;
        ForCompany: Boolean;
    begin
        if ThemeMode(Config) = 'custom' then begin
            if Config."Theme Name".Trim() = '' then
                Error('Give the theme a name first.');
            if Config."Theme Name".StartsWith(PreviewPrefixTok) then
                Error('Theme names starting with "%1" are reserved for previews.', PreviewPrefixTok.Trim());
            if Config."Theme Name" = Config."Base Theme" then
                Error('Save the theme under a different name than "%1", so the base theme is kept.', Config."Base Theme");
            ConfiguratorMgt.GenerateTheme(Config, Generated);
            ConfiguratorMgt.StorePart(Config."Theme Name", Generated);
            Result.Append(StrSubstNo('Theme "%1" saved. ', Config."Theme Name"));
        end;
        if Mode = 'theme' then begin
            if ThemeMode(Config) <> 'custom' then
                Error('Choose Customize for the theme to save one.');
            exit(Result.ToText() + 'It is not assigned to anything yet.');
        end;

        if (ThemeMode(Config) = 'keep') and (HeaderMode(Config) = 'keep') then
            Error('Nothing to apply: choose Use default or Customize for the theme or the header/footer.');
        if (HeaderMode(Config) = 'custom') and (Config."Header Part" = '') then
            Error('Choose a header/footer design first.');
        if HeaderMode(Config) = 'design' then begin
            if Config."HF Name".Trim() = '' then
                Error('Give the header/footer a name first.');
            if Config."HF Name".StartsWith(PreviewPrefixTok) then
                Error('Names starting with "%1" are reserved for previews.', PreviewPrefixTok.Trim());
            if Config."HF Name" = HeaderFooterBaseTok then
                Error('Save the header/footer under a different name than the design it starts from.');
            GenerateHeaderFooter(Config, Generated);
            ConfiguratorMgt.StorePartOfKind(Config."HF Name", Generated, true);
            Result.Append(StrSubstNo('Header/footer "%1" saved. ', Config."HF Name"));
        end;

        ForCompany := ModeOr(Config."Apply To", 'layout') = 'company';
        if Config."Apply To" = 'group' then begin
            // No group level exists in Business Central: assign every Body layout of the group's reports.
            Result.Append(StrSubstNo('%1 updated (%2 layouts): ', DocGroups.GroupCaption(Config."Apply Group"), ApplyToGroup(Config)));
            Result.Append(StrSubstNo('theme %1, header/footer %2.', ModeCaption(ThemeMode(Config)), ModeCaption(HeaderMode(Config))));
            exit(Result.ToText());
        end;
        if not ForCompany then begin
            ConfiguratorMgt.ValidateBodyLayout(Config);
            LayoutKey := CopyStr(ConfiguratorMgt.EncodePartName(Config."Target Layout App ID", Config."Target Layout Name"), 1, 250);
        end;
        ApplyParts(Config, ForCompany, Config."Target Report ID", LayoutKey);

        if ForCompany then
            Result.Append(StrSubstNo('Company default for %1 updated: ', CompanyName()))
        else
            Result.Append(StrSubstNo('%1 (%2) updated: ', GetReportName(Config."Target Report ID"), Config."Target Layout Name"));
        Result.Append(StrSubstNo('theme %1, header/footer %2.', ModeCaption(ThemeMode(Config)), ModeCaption(HeaderMode(Config))));
        exit(Result.ToText());
    end;

    // Writes one part at the target level (this layout for all companies, or this company's default) and leaves
    // the other part as it is. An empty value clears the assignment so lower levels apply again.
    /// Writes the chosen theme and header/footer to one assignment (one layout, or the company default).
    local procedure ApplyParts(Config: Record "Report Style Config"; ForCompany: Boolean; ReportID: Integer; LayoutKey: Text[250])
    var
        EmptyGuid: Guid;
    begin
        case ThemeMode(Config) of
            'custom':
                SetPart(ForCompany, ReportID, LayoutKey, false, ConfiguratorMgt.EncodePartName(EmptyGuid, Config."Theme Name"));
            'default':
                SetPart(ForCompany, ReportID, LayoutKey, false, '');
        end;
        case HeaderMode(Config) of
            'custom':
                SetPart(ForCompany, ReportID, LayoutKey, true, HeaderPartRef(Config));
            'design':
                SetPart(ForCompany, ReportID, LayoutKey, true, ConfiguratorMgt.EncodePartName(EmptyGuid, Config."HF Name"));
            'default':
                SetPart(ForCompany, ReportID, LayoutKey, true, '');
        end;
    end;

    /// "Apply to this group": the same assignment for every Body layout of every report in the group.
    local procedure ApplyToGroup(Config: Record "Report Style Config") Layouts: Integer
    var
        ReportLayoutList: Record "Report Layout List";
        ReportID: Integer;
    begin
        foreach ReportID in DocGroups.ReportsOf(Config."Apply Group") do begin
            ReportLayoutList.SetRange("Report ID", ReportID);
            ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Body);
            if ReportLayoutList.FindSet() then
                repeat
                    ApplyParts(Config, false, ReportID, CopyStr(ConfiguratorMgt.EncodePartName(ReportLayoutList."Application ID", ReportLayoutList.Name), 1, 250));
                    Layouts += 1;
                until ReportLayoutList.Next() = 0;
        end;
        if Layouts = 0 then
            Error('There are no documents with a Body layout in %1.', DocGroups.GroupCaption(Config."Apply Group"));
    end;

    local procedure SetPart(ForCompany: Boolean; ReportID: Integer; LayoutKey: Text[250]; IsHeader: Boolean; Value: Text)
    var
        Cfg: Record "Tenant Report Layout Cfg";
        Exists: Boolean;
    begin
        if ForCompany then
            Exists := Cfg.Get(0, '', CopyStr(CompanyName(), 1, 30))
        else
            Exists := Cfg.Get(ReportID, LayoutKey, '');
        if not Exists then begin
            if Value = '' then
                exit;
            Cfg.Init();
            if ForCompany then
                Cfg."Company Name" := CopyStr(CompanyName(), 1, 30)
            else begin
                Cfg."Report ID" := ReportID;
                Cfg."Layout Name" := LayoutKey;
            end;
        end;
        if IsHeader then
            Cfg."Header Part Name" := CopyStr(Value, 1, MaxStrLen(Cfg."Header Part Name"))
        else
            Cfg."Theme Part Name" := CopyStr(Value, 1, MaxStrLen(Cfg."Theme Part Name"));

        if not Exists then
            Cfg.Insert(true)
        else
            if (Cfg."Header Part Name" = '') and (Cfg."Theme Part Name" = '') then
                Cfg.Delete(true)
            else
                Cfg.Modify(true);
    end;

    local procedure ModeCaption(Mode: Text): Text
    begin
        case Mode of
            'keep':
                exit('unchanged');
            'default':
                exit('back to default');
        end;
        exit('customized');
    end;
    procedure ChooseData(var Config: Record "Report Style Config"): Boolean
    var
        Parameters: Text;
        NewParameters: Text;
    begin
        Parameters := GetParameters(Config);
        NewParameters := Report.RunRequestPage(Config."Target Report ID", Parameters);
        if NewParameters = '' then
            exit(false);
        SetParameters(Config, NewParameters);
        // The gallery shows this document with the same data.
        SetReportData(Config."Target Report ID", NewParameters);
        exit(true);
    end;

    procedure ClearData(var Config: Record "Report Style Config")
    var
        PreviewData: Record "Report Style Preview Data";
    begin
        Clear(Config."Report Parameters");
        Config.Modify();
        if PreviewData.Get(Config."Target Report ID") then
            PreviewData.Delete();
    end;

    /// "Your documents" gallery: the draft (theme and header/footer as they are now) aimed at another document.
    /// It is a temporary copy, so the selected document and the saved draft are not touched.
    procedure GalleryConfig(Config: Record "Report Style Config"; ReportID: Integer; LayoutName: Text; LayoutAppID: Text; var GalleryRec: Record "Report Style Config" temporary)
    begin
        GalleryRec.Reset();
        GalleryRec.DeleteAll();
        GalleryRec := Config;
        GalleryRec."Target Report ID" := ReportID;
        GalleryRec."Target Layout Name" := CopyStr(LayoutName, 1, MaxStrLen(GalleryRec."Target Layout Name"));
        if not Evaluate(GalleryRec."Target Layout App ID", LayoutAppID) then
            Clear(GalleryRec."Target Layout App ID");
        Clear(GalleryRec."Report Parameters");
        if ReportID = Config."Target Report ID" then
            SetParametersOnly(GalleryRec, GetParameters(Config))
        else
            SetParametersOnly(GalleryRec, GetReportData(ReportID));
        GalleryRec.Insert();
    end;

    /// Lets the user choose the preview data of a gallery document (its request page).
    procedure ChooseGalleryData(ReportID: Integer): Boolean
    var
        NewParameters: Text;
    begin
        NewParameters := Report.RunRequestPage(ReportID, GetReportData(ReportID));
        if NewParameters = '' then
            exit(false);
        SetReportData(ReportID, NewParameters);
        exit(true);
    end;

    local procedure GetReportData(ReportID: Integer) Parameters: Text
    var
        PreviewData: Record "Report Style Preview Data";
        ParamInStream: InStream;
    begin
        if not PreviewData.Get(ReportID) then
            exit('');
        PreviewData.CalcFields(Parameters);
        if not PreviewData.Parameters.HasValue() then
            exit('');
        PreviewData.Parameters.CreateInStream(ParamInStream, TextEncoding::UTF8);
        ParamInStream.Read(Parameters);
    end;

    local procedure SetReportData(ReportID: Integer; Parameters: Text)
    var
        PreviewData: Record "Report Style Preview Data";
        ParamOutStream: OutStream;
    begin
        if not PreviewData.Get(ReportID) then begin
            PreviewData.Init();
            PreviewData."Report ID" := ReportID;
            PreviewData.Insert();
        end;
        PreviewData.Parameters.CreateOutStream(ParamOutStream, TextEncoding::UTF8);
        ParamOutStream.Write(Parameters);
        PreviewData.Modify();
    end;

    local procedure SetParametersOnly(var Rec: Record "Report Style Config"; Parameters: Text)
    var
        ParamOutStream: OutStream;
    begin
        if Parameters = '' then
            exit;
        Rec."Report Parameters".CreateOutStream(ParamOutStream, TextEncoding::UTF8);
        ParamOutStream.Write(Parameters);
    end;

    local procedure StateFromConfig(var Config: Record "Report Style Config") State: JsonObject
    begin
        State.Add('reportId', Config."Target Report ID");
        State.Add('layoutName', Config."Target Layout Name");
        State.Add('layoutAppId', LowerCase(Format(Config."Target Layout App ID", 0, 4)));
        State.Add('baseTheme', Config."Base Theme");
        State.Add('palette', Config.Palette.AsInteger());
        State.Add('customColors', CustomColorsJson(Config."Custom Colors"));
        State.Add('fonts', Config."Font Pair".AsInteger());
        State.Add('size', Config."Base Font Size");
        State.Add('pageColor', Config."Page Color".AsInteger());
        State.Add('customPage', Config."Custom Page Color");
        State.Add('tableStyle', Config."Table Style".AsInteger());
        State.Add('headerPart', Config."Header Part");
        State.Add('headerAppId', LowerCase(Format(Config."Header Part App ID", 0, 4)));
        State.Add('themeMode', ModeOr(Config."Theme Mode", 'custom'));
        State.Add('headerMode', ModeOr(Config."Header Mode", 'keep'));
        State.Add('applyTo', ModeOr(Config."Apply To", 'layout'));
        State.Add('applyGroup', Config."Apply Group");
        State.Add('hfLogo', ModeOr(Config."HF Logo", 'right'));
        State.Add('hfPageNumber', ModeOr(Config."HF Page Number", 'header'));
        State.Add('hfShowDate', Config."HF Show Date");
        State.Add('hfLaterPages', ModeOr(Config."HF Later Pages", 'minimal'));
        State.Add('hfFooter', ModeOr(Config."HF Footer", 'contact'));
        State.Add('hfAccentLine', Config."HF Accent Line");
        State.Add('hfName', Config."HF Name");
        State.Add('themeName', Config."Theme Name");
        State.Add('hasData', Config."Report Parameters".HasValue());
    end;

    local procedure CustomColorsJson(CustomColors: Text) Colors: JsonArray
    var
        Color: Text;
    begin
        if CustomColors <> '' then
            foreach Color in CustomColors.Split(',') do
                Colors.Add(Color);
    end;

    /// Only 12 valid hex colours are accepted from the browser; anything else clears the custom palette.
    local procedure CustomColorsFromJson(Token: JsonToken) Result: Text
    var
        Rules: Codeunit "Report Style Theme Rules";
        Color: JsonToken;
        Hex: Text;
        Count: Integer;
    begin
        if not Token.IsArray() then
            exit('');
        foreach Color in Token.AsArray() do begin
            if not Color.IsValue() then
                exit('');
            if not Rules.TryNormalizeHex(Color.AsValue().AsText(), Hex) then
                exit('');
            if Result <> '' then
                Result += ',';
            Result += Hex;
            Count += 1;
        end;
        if Count <> 12 then
            exit('');
    end;

    /// The layout the report prints with for everyone in this company (the selection without a user).
    local procedure IsDefaultLayout(var ReportLayoutList: Record "Report Layout List"): Boolean
    var
        Selection: Record "Tenant Report Layout Selection";
        EmptyGuid: Guid;
    begin
        if not Selection.Get(ReportLayoutList."Report ID", CompanyName(), EmptyGuid) then
            if not Selection.Get(ReportLayoutList."Report ID", '', EmptyGuid) then
                exit(false);
        exit((Selection."Layout Name" = ReportLayoutList.Name) and (Selection."App ID" = ReportLayoutList."Application ID"));
    end;

    /// A page colour from the browser: must be a valid colour, and is lightened if it would print too dark.
    local procedure CustomPageFromJson(Token: JsonToken): Text[10]
    var
        Rules: Codeunit "Report Style Theme Rules";
        Hex: Text;
    begin
        if not Token.IsValue() then
            exit('');
        if not Rules.TryNormalizeHex(Token.AsValue().AsText(), Hex) then
            exit('');
        exit(CopyStr(Rules.LightPage(Hex), 1, 10));
    end;

    local procedure GetBodyLayouts() Layouts: JsonArray
    var
        ReportLayoutList: Record "Report Layout List";
        Item: JsonObject;
    begin
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Body);
        if ReportLayoutList.FindSet() then
            repeat
                Clear(Item);
                Item.Add('reportId', ReportLayoutList."Report ID");
                Item.Add('reportName', ReportLayoutList."Report Name");
                Item.Add('name', ReportLayoutList.Name);
                Item.Add('caption', CaptionOf(ReportLayoutList));
                Item.Add('appId', LowerCase(Format(ReportLayoutList."Application ID", 0, 4)));
                Item.Add('status', Format(ReportLayoutList."Layout Status"));
                Item.Add('isDefault', IsDefaultLayout(ReportLayoutList));
                AddCurrentParts(Item, ReportLayoutList."Report ID", CopyStr(ConfiguratorMgt.EncodePartName(ReportLayoutList."Application ID", ReportLayoutList.Name), 1, 250));
                Layouts.Add(Item);
            until ReportLayoutList.Next() = 0;
    end;

    local procedure GetThemes() Themes: JsonArray
    var
        ReportLayoutList: Record "Report Layout List";
        Item: JsonObject;
    begin
        ReportLayoutList.SetRange("Report ID", ConfiguratorMgt.TenantReportDefaultsId());
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Theme);
        if ReportLayoutList.FindSet() then
            repeat
                if (not ReportLayoutList.Name.StartsWith(PreviewPrefixTok)) and HasThemePart(ReportLayoutList) then begin
                    Clear(Item);
                    Item.Add('name', ReportLayoutList.Name);
                    Item.Add('caption', CaptionOf(ReportLayoutList));
                    Item.Add('summary', ReportLayoutList.Description);
                    Themes.Add(Item);
                end;
            until ReportLayoutList.Next() = 0;
    end;

    local procedure GetPalettes() Palettes: JsonArray
    var
        Palette: Enum "Report Style Palette";
        Ordinal: Integer;
        Item: JsonObject;
        Colors: JsonArray;
        Color: Text;
    begin
        foreach Ordinal in Enum::"Report Style Palette".Ordinals() do begin
            Palette := Enum::"Report Style Palette".FromInteger(Ordinal);
            if Palette = Palette::Custom then
                continue;   // shown by the add-in from the state's own colours
            Clear(Item);
            Clear(Colors);
            foreach Color in ConfiguratorMgt.GetPaletteColors(Palette) do
                Colors.Add(Color);
            Item.Add('id', Ordinal);
            Item.Add('caption', Format(Palette));
            Item.Add('colors', Colors);
            Palettes.Add(Item);
        end;
    end;

    local procedure GetFonts() Fonts: JsonArray
    var
        FontPair: Enum "Report Style Font Pair";
        Ordinal: Integer;
        Item: JsonObject;
        HeadingFont: Text;
        BodyFont: Text;
    begin
        foreach Ordinal in Enum::"Report Style Font Pair".Ordinals() do begin
            FontPair := Enum::"Report Style Font Pair".FromInteger(Ordinal);
            Clear(Item);
            Clear(HeadingFont);
            Clear(BodyFont);
            ConfiguratorMgt.GetFontPair(FontPair, HeadingFont, BodyFont);
            Item.Add('id', Ordinal);
            Item.Add('caption', Format(FontPair));
            Item.Add('heading', HeadingFont);
            Item.Add('body', BodyFont);
            Fonts.Add(Item);
        end;
    end;

    local procedure GetPageColors() PageColors: JsonArray
    var
        PageColor: Enum "Report Style Page Color";
        Ordinal: Integer;
        Item: JsonObject;
    begin
        foreach Ordinal in Enum::"Report Style Page Color".Ordinals() do begin
            PageColor := Enum::"Report Style Page Color".FromInteger(Ordinal);
            if PageColor = PageColor::Custom then
                continue;   // shown by the add-in from the state's own colour
            Clear(Item);
            Item.Add('id', Ordinal);
            Item.Add('caption', Format(PageColor));
            Item.Add('hex', ConfiguratorMgt.GetPageColorHex(PageColor));
            PageColors.Add(Item);
        end;
    end;

    // A part is identified by app ID and name: designs shipped by an app (BaseApp in SaaS) carry that app's ID,
    // tenant layouts the empty GUID. The platform rejects a reference with the wrong ID.
    local procedure HeaderPartRef(Config: Record "Report Style Config"): Text
    var
        ReportLayoutList: Record "Report Layout List";
    begin
        if Config."Header Part" = '' then
            exit('');
        if IsNullGuid(Config."Header Part App ID") then begin
            ReportLayoutList.SetRange("Report ID", ConfiguratorMgt.TenantReportDefaultsId());
            ReportLayoutList.SetRange(Name, Config."Header Part");
            ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::HeaderFooter);
            if ReportLayoutList.FindFirst() then
                exit(ConfiguratorMgt.EncodePartName(ReportLayoutList."Application ID", Config."Header Part"));
        end;
        exit(ConfiguratorMgt.EncodePartName(Config."Header Part App ID", Config."Header Part"));
    end;

    /// Builds the "Design your own" header/footer from BaseApp's External Default Detailed design.
    procedure GenerateHeaderFooter(Config: Record "Report Style Config"; var Generated: Codeunit "Temp Blob")
    var
        ReportLayoutList: Record "Report Layout List";
        Generator: Codeunit "Report Header Footer Generator";
        Base: Codeunit "Temp Blob";
        BaseOutStream: OutStream;
    begin
        ReportLayoutList.SetRange("Report ID", ConfiguratorMgt.TenantReportDefaultsId());
        ReportLayoutList.SetRange(Name, HeaderFooterBaseTok);
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::HeaderFooter);
        if not ReportLayoutList.FindFirst() then
            Error('The header/footer design "%1" that "Design your own" starts from was not found.', HeaderFooterBaseTok);
        Base.CreateOutStream(BaseOutStream);
        ReportLayoutList.Layout.ExportStream(BaseOutStream);

        Generator.SetLogo(ModeOr(Config."HF Logo", 'right'));
        Generator.SetPageNumber(ModeOr(Config."HF Page Number", 'header'));
        Generator.SetShowDate(Config."HF Show Date");
        Generator.SetLaterPages(ModeOr(Config."HF Later Pages", 'minimal'));
        Generator.SetFooter(ModeOr(Config."HF Footer", 'contact'));
        Generator.SetAccentLine(Config."HF Accent Line");
        Generator.Generate(Base.CreateInStream(), Generated);
    end;

    local procedure PreviewHeaderName(PreviewName: Text[250]): Text[250]
    begin
        exit(CopyStr(PreviewName + ' HF', 1, 250));
    end;

    local procedure PreviewHeaderRef(Config: Record "Report Style Config"; PreviewName: Text[250]): Text
    var
        EmptyGuid: Guid;
    begin
        if HeaderMode(Config) = 'design' then
            exit(ConfiguratorMgt.EncodePartName(EmptyGuid, PreviewHeaderName(PreviewName)));
        exit(HeaderPartRef(Config));
    end;

    local procedure GetHeaderParts() Headers: JsonArray
    var
        ReportLayoutList: Record "Report Layout List";
        Item: JsonObject;
    begin
        ReportLayoutList.SetRange("Report ID", ConfiguratorMgt.TenantReportDefaultsId());
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::HeaderFooter);
        if ReportLayoutList.FindSet() then
            repeat
                if not ReportLayoutList.Name.StartsWith(PreviewPrefixTok) then begin
                    Clear(Item);
                    Item.Add('name', ReportLayoutList.Name);
                    Item.Add('caption', CaptionOf(ReportLayoutList));
                    Item.Add('appId', LowerCase(Format(ReportLayoutList."Application ID", 0, 4)));
                    Headers.Add(Item);
                end;
            until ReportLayoutList.Next() = 0;
    end;

    // Short label for chips and lists; long descriptions (design summaries) are sent separately as tooltips.
    local procedure CaptionOf(var ReportLayoutList: Record "Report Layout List"): Text
    begin
        if (ReportLayoutList.Description <> '') and (StrLen(ReportLayoutList.Description) <= 40) then
            exit(ReportLayoutList.Description);
        // For tenant layouts Caption just repeats the name.
        if (ReportLayoutList.Caption <> '') and (ReportLayoutList.Caption <> ReportLayoutList.Name) and (StrLen(ReportLayoutList.Caption) <= 40) then
            exit(ReportLayoutList.Caption);
        exit(PrettyName(ReportLayoutList.Name));
    end;

    // "ExternalModernLogoHFDesign" -> "External Modern Logo", "CalmTheme" -> "Calm".
    local procedure PrettyName(Name: Text) Result: Text
    var
        Position: Integer;
    begin
        if Name.EndsWith('HFDesign') then
            Name := CopyStr(Name, 1, StrLen(Name) - 8)
        else
            if Name.EndsWith('Theme') and (StrLen(Name) > 5) then
                Name := CopyStr(Name, 1, StrLen(Name) - 5);
        for Position := 1 to StrLen(Name) do begin
            // AL does not short-circuit "and", so guard the look-back separately.
            if Position > 1 then
                if (Name[Position] in ['A' .. 'Z']) and (Name[Position - 1] in ['a' .. 'z']) then
                    Result += ' ';
            Result += Format(Name[Position]);
        end;
    end;

    local procedure GetTableStyles() TableStyles: JsonArray
    var
        Ordinal: Integer;
        Item: JsonObject;
    begin
        foreach Ordinal in Enum::"Report Theme Table Style".Ordinals() do begin
            Clear(Item);
            Item.Add('id', Ordinal);
            Item.Add('caption', Format(Enum::"Report Theme Table Style".FromInteger(Ordinal)));
            TableStyles.Add(Item);
        end;
    end;

    // Platform placeholder themes have no theme part, so they cannot be used as a base.
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

    local procedure GetPreviewPartName(): Text[250]
    begin
        exit(CopyStr(PreviewPrefixTok + LowerCase(Format(CreateGuid(), 0, 4)), 1, 250));
    end;

    // Leftovers of previews that were interrupted (for example a closed browser) are removed after 10 minutes.
    local procedure RemoveStalePreviewArtifacts()
    var
        TenantReportLayout: Record "Tenant Report Layout";
        PreviewCfg: Record "Tenant Report Layout Cfg";
        Selection: Record "Tenant Report Layout Selection";
        Cutoff: DateTime;
    begin
        Cutoff := CurrentDateTime() - 10 * 60 * 1000;
        // Read without locks: concurrent previews insert into the same table, and a locking scan deadlocks with them.
        TenantReportLayout.ReadIsolation := IsolationLevel::ReadUncommitted;
        TenantReportLayout.SetFilter(Name, PreviewPrefixTok + '*');
        TenantReportLayout.SetFilter(SystemCreatedAt, '<%1', Cutoff);
        if TenantReportLayout.IsEmpty() then
            exit;
        if TenantReportLayout.FindSet() then
            repeat
                PreviewCfg.SetRange("Report ID", TenantReportLayout."Report ID");
                PreviewCfg.SetFilter("Layout Name", '*::' + TenantReportLayout.Name);
                PreviewCfg.DeleteAll();
                Selection.SetRange("Layout Name", TenantReportLayout.Name);
                Selection.DeleteAll();
                TenantReportLayout.Delete();
            until TenantReportLayout.Next() = 0;
    end;

    local procedure SelectForCurrentUser(ReportID: Integer; PreviewName: Text[250]; var Previous: Record "Tenant Report Layout Selection" temporary; var HadPrevious: Boolean)
    var
        Selection: Record "Tenant Report Layout Selection";
        EmptyGuid: Guid;
    begin
        HadPrevious := Selection.Get(ReportID, CompanyName(), UserSecurityId());
        if HadPrevious then begin
            // A row pointing at a preview copy belongs to another preview of this report by the same user (another
            // window), or is left over from an interrupted one. It is never the user's real selection.
            if Selection."Layout Name".StartsWith(PreviewPrefixTok) and PreviewInFlight(ReportID, Selection."Layout Name") then
                Error(PreviewBusyErr);
            HadPrevious := not Selection."Layout Name".StartsWith(PreviewPrefixTok);
            if HadPrevious then begin
                Previous := Selection;
                Previous.Insert();
            end;
            Selection.Delete();
        end;
        Selection.Init();
        Selection."Report ID" := ReportID;
        Selection."Company Name" := CopyStr(CompanyName(), 1, MaxStrLen(Selection."Company Name"));
        Selection."User ID" := UserSecurityId();
        Selection."Layout Name" := PreviewName;
        Selection."App ID" := EmptyGuid;
        Selection.Insert();
    end;

    local procedure PreviewInFlight(ReportID: Integer; PreviewLayoutName: Text): Boolean
    var
        TenantReportLayout: Record "Tenant Report Layout";
    begin
        TenantReportLayout.ReadIsolation := IsolationLevel::ReadUncommitted;
        TenantReportLayout.SetRange("Report ID", ReportID);
        TenantReportLayout.SetRange(Name, CopyStr(PreviewLayoutName, 1, MaxStrLen(TenantReportLayout.Name)));
        // A preview takes about a second; a younger preview layout belongs to a preview that is still running.
        TenantReportLayout.SetFilter(SystemCreatedAt, '>%1', CurrentDateTime() - 30 * 1000);
        exit(not TenantReportLayout.IsEmpty());
    end;

    local procedure RestoreUserSelection(ReportID: Integer; PreviewName: Text[250]; var Previous: Record "Tenant Report Layout Selection" temporary; HadPrevious: Boolean)
    var
        Selection: Record "Tenant Report Layout Selection";
    begin
        if Selection.Get(ReportID, CompanyName(), UserSecurityId()) then begin
            if Selection."Layout Name" <> PreviewName then
                exit; // not ours any more: another preview or a real selection was made meanwhile
            Selection.Delete();
        end;
        if HadPrevious then begin
            Selection := Previous;
            Selection.Insert();
        end;
    end;

    local procedure DeletePart(PartName: Text[250])
    var
        TenantReportLayout: Record "Tenant Report Layout";
        EmptyGuid: Guid;
    begin
        if TenantReportLayout.Get(ConfiguratorMgt.TenantReportDefaultsId(), PartName, EmptyGuid) then
            TenantReportLayout.Delete();
    end;

    local procedure GetParameters(var Config: Record "Report Style Config") Parameters: Text
    var
        ParamInStream: InStream;
    begin
        Config.CalcFields("Report Parameters");
        if not Config."Report Parameters".HasValue() then
            exit('');
        Config."Report Parameters".CreateInStream(ParamInStream, TextEncoding::UTF8);
        ParamInStream.Read(Parameters);
    end;

    local procedure SetParameters(var Config: Record "Report Style Config"; Parameters: Text)
    var
        ParamOutStream: OutStream;
    begin
        Config."Report Parameters".CreateOutStream(ParamOutStream, TextEncoding::UTF8);
        ParamOutStream.Write(Parameters);
        Config.Modify();
    end;

    procedure GetReportCaption(Config: Record "Report Style Config"): Text
    begin
        exit(GetReportName(Config."Target Report ID"));
    end;

    local procedure GetReportName(ReportID: Integer): Text
    var
        AllObjWithCaption: Record AllObjWithCaption;
    begin
        if AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Report, ReportID) then
            exit(AllObjWithCaption."Object Caption");
        exit(Format(ReportID));
    end;
}
