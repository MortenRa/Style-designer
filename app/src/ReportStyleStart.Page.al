namespace Abakion.ReportStyleDesigner;

using System.Reflection;
using System.Text;
using System.Utilities;

/// The simple entry point (phase 1): a few plain choices for the look, then the full designer for more detail.
/// A standard page, not the designer add-in; only the preview uses a small image box (Report Style Page Preview).
page 50105 "Report Style Start"
{
    Caption = 'Theme Designer - Quick Start';
    PageType = Card;
    SourceTable = "Report Style Config";
    UsageCategory = Administration;
    ApplicationArea = All;
    AdditionalSearchTerms = 'report style, report theme, report design, document design, colours, fonts, start';

    layout
    {
        area(Content)
        {
            // One FastTab with two columns: the choices on the left, the preview on the right (wider than a factbox).
            group(Main)
            {
                ShowCaption = false;
            group(Choices)
            {
                ShowCaption = false;
            group(LogoGroup)
            {
                Caption = 'Your logo';
                InstructionalText = 'Start with your logo. Choose where it goes on your documents.';

                usercontrol(LogoPicker; "Report Style Logo Picker")
                {
                    ApplicationArea = All;

                    trigger Ready()
                    begin
                        LogoPickerReady := true;
                        ShowLogo();
                    end;

                    trigger PlacementChosen(Placement: Text)
                    begin
                        Rec."HF Logo" := CopyStr(Placement, 1, MaxStrLen(Rec."HF Logo"));
                        Rec."Logo Chosen" := true;
                        Rec."Header Mode" := 'design';
                        RefreshAdvice();
                    end;

                    trigger UploadRequested()
                    begin
                        UploadLogo();
                    end;

                    trigger TryLogoRequested()
                    begin
                        TryLogo();
                    end;

                    trigger CompanyLogoRequested()
                    begin
                        UseCompanyLogo();
                    end;

                    trigger LogoColorsComputed(Colors: Text)
                    begin
                        LogoColorsJson := Colors;
                    end;
                }
                // The logo comes with a whole header and footer; say so in words. The details are in the designer.
                field(HeaderFooterSummary; HeaderFooterText)
                {
                    ApplicationArea = All;
                    Caption = 'Header and footer';
                    Editable = false;
                    MultiLine = true;
                    Style = Subordinate;
                    ToolTip = 'What the header and footer of the documents show. Page number, footer, date and accent line are changed in the designer.';
                }
                field(ChangeHeaderFooter; ChangeHeaderFooterTxt)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    ToolTip = 'Open the designer to change the page number, footer, date and accent line.';

                    trigger OnDrillDown()
                    begin
                        OpenTheDesigner();
                    end;
                }
            }
            group(DirectionGroup)
            {
                Caption = 'Design direction';
                field(Direction; Rec.Direction)
                {
                    ApplicationArea = All;
                    Caption = 'Direction';
                    ToolTip = 'A finished look to start from. It sets the colours, fonts, tables, header and footer in one step. You can change every detail below.';

                    trigger OnValidate()
                    var
                        Directions: Codeunit "Report Style Directions";
                    begin
                        Directions.Apply(Rec);
                        LeaveSuggestion();
                        ShowLogo();
                        RefreshAdvice();
                    end;
                }
                field(DirectionDescription; DirectionText)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                    Style = Subordinate;
                    ToolTip = 'What the chosen direction looks like.';
                }
            }
            group(Look)
            {
                Caption = 'Look';
                field(LookFrom; LookFromText)
                {
                    ApplicationArea = All;
                    Caption = 'Look from';
                    Editable = false;
                    Style = Strong;
                    ToolTip = 'Where the colours and fonts come from: a Copilot suggestion, a design direction or a theme. Fonts, page colour and table style below adjust it.';
                }
                field("Base Theme"; Rec."Base Theme")
                {
                    ApplicationArea = All;
                    Caption = 'Theme';
                    Editable = not InSuggestion;
                    ToolTip = 'A theme that already exists in Business Central. Choosing one shows it as it is; the choices below then change it. While a Copilot suggestion is the look, the suggestion sets the colours and fonts on the neutral DefaultTheme; choose Use my theme on the preview to come back to your theme.';

                    // Our own list with the theme names only, instead of the layout table's technical columns.
                    trigger OnLookup(var Text: Text): Boolean
                    var
                        Themes: Page "Report Style Themes";
                        ReportLayoutList: Record "Report Layout List";
                    begin
                        Themes.LookupMode(true);
                        if Themes.RunModal() <> Action::LookupOK then
                            exit(false);
                        Themes.GetRecord(ReportLayoutList);
                        Text := ReportLayoutList.Name;
                        exit(true);
                    end;

                    trigger OnValidate()
                    var
                        ReportLayoutList: Record "Report Layout List";
                    begin
                        ReportLayoutList.SetRange("Report ID", 2000000001);
                        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Theme);
                        ReportLayoutList.SetRange(Name, Rec."Base Theme");
                        if ReportLayoutList.IsEmpty() then
                            Error(UnknownThemeErr, Rec."Base Theme");
                        // Shown as it is: the choices below go back to "keep the base theme".
                        LeaveSuggestion();
                        Rec.Direction := Rec.Direction::NotChosen;
                        Rec."Own Theme" := Rec."Base Theme";
                        Rec."Theme Mode" := 'custom';
                        Rec.Palette := Rec.Palette::KeepBase;
                        Rec."Font Pair" := Rec."Font Pair"::KeepBase;
                        Rec."Page Color" := Rec."Page Color"::KeepBase;
                        Rec."Table Style" := Rec."Table Style"::KeepBase;
                        RefreshAdvice();
                    end;
                }
                field(Palette; Rec.Palette)
                {
                    ApplicationArea = All;
                    Editable = not InSuggestion;
                    ToolTip = 'The main colours of the reports. "Keep base theme colours" leaves them as they are.';

                    trigger OnValidate()
                    begin
                        RefreshAdvice();
                    end;
                }
                field("Font Pair"; Rec."Font Pair")
                {
                    ApplicationArea = All;
                    ToolTip = 'The fonts for headings and text. Only fonts that print correctly are offered.';

                    trigger OnValidate()
                    begin
                        RefreshAdvice();
                    end;
                }
                field("Page Color"; Rec."Page Color")
                {
                    ApplicationArea = All;
                    ToolTip = 'The background of the page. White is the safest choice for printing.';

                    trigger OnValidate()
                    begin
                        RefreshAdvice();
                    end;
                }
                field("Table Style"; Rec."Table Style")
                {
                    ApplicationArea = All;
                    ToolTip = 'How lines with many rows, such as invoice lines, look.';

                    trigger OnValidate()
                    begin
                        RefreshAdvice();
                    end;
                }
            }
            group(SaveGroup)
            {
                Caption = 'Save';
                field(ThemeName; Rec."Theme Name")
                {
                    ApplicationArea = All;
                    Caption = 'Name';
                    ToolTip = 'The name the theme is saved under. Approvers see it on the Theme Approvals page.';
                }
                field(UseOn; UseOn)
                {
                    ApplicationArea = All;
                    Caption = 'Use on';
                    OptionCaption = 'This document,All documents in its group,Company default';
                    ToolTip = 'Which documents get the new look when it is approved and activated: the document in the preview, every document of its group (customer, vendor or internal), or the company default.';

                    trigger OnValidate()
                    begin
                        SetUseOn();
                    end;
                }
            }
            group(Advice)
            {
                Caption = 'Recommendations';
                field(AdviceText; AdviceText)
                {
                    ApplicationArea = All;
                    Caption = 'Advice';
                    Editable = false;
                    MultiLine = true;
                    ToolTip = 'Soft recommendations based on the settings. They explain a likely problem; you can still send the design for approval.';
                }
            }
            }
            group(PreviewGroup)
            {
                Caption = 'Preview';
                field(DocumentName; DocumentText)
                {
                    ApplicationArea = All;
                    Caption = 'Document';
                    Editable = false;
                    ToolTip = 'The document the preview shows. Choose another report layout to see the style on it.';

                    trigger OnAssistEdit()
                    var
                        ConfiguratorMgt: Codeunit "Report Style Configurator Mgt.";
                    begin
                        Rec.Modify(true);
                        Commit();
                        if not ConfiguratorMgt.LookupBodyLayout(Rec) then
                            exit;
                        Rec.Modify(true);
                        Commit();
                        ComputeDocumentText();
                        UpdatePreview();
                        CurrPage.Update(false);
                    end;
                }
                // A small image box of our own: a Media field is a thumbnail outside a factbox, and the
                // Web Page Viewer stays 320 px high on a Card page, too low for a whole page.
                usercontrol(PreviewViewer; "Report Style Page Preview")
                {
                    ApplicationArea = All;

                    trigger Ready()
                    begin
                        ViewerReady := true;
                        CurrPage.PreviewViewer.SetOpenOnClick(true);
                        ShowMessage(StartTxt);
                        UpdateSuggestionBar();
                    end;

                    trigger SuggestionStep(Delta: Integer)
                    begin
                        ShowSuggestion(SuggestionIndex + Delta);
                    end;

                    trigger UseMyThemeRequested()
                    begin
                        UseMyTheme();
                    end;

                    trigger FullViewRequested()
                    var
                        FullPreview: Page "Report Style Full Preview";
                    begin
                        FullPreview.SetPreview(LastPdfBase64, PreviewStatusText);
                        FullPreview.RunModal();
                    end;
                }
                field(PreviewStatus; PreviewStatusText)
                {
                    ApplicationArea = All;
                    ShowCaption = false;
                    Editable = false;
                    Style = Subordinate;
                    ToolTip = 'What the preview shows, or why it could not be shown.';
                }
            }
            }
        }
    }

    actions
    {
        area(Prompting)
        {
            action(DraftWithCopilot)
            {
                ApplicationArea = All;
                Caption = 'Draft with Copilot';
                ToolTip = 'Describe the look you want, and Copilot suggests themes built on your logo and brand colours.';
                Image = Sparkle;
                Visible = CopilotAvailable;

                trigger OnAction()
                begin
                    RunCopilot();
                end;
            }
        }
        area(Promoted)
        {
            actionref(UpdatePreview_Promoted; UpdatePreviewAction) { }
            actionref(SendForApproval_Promoted; SendForApproval) { }
            actionref(OpenDesigner_Promoted; OpenDesigner) { }
        }
        area(Processing)
        {
            // Not rendered while the page opens: the report's progress dialog cannot be shown before the page is there.
            action(UpdatePreviewAction)
            {
                ApplicationArea = All;
                Caption = 'Update preview';
                ToolTip = 'Show the first page of the chosen document with these choices. The preview also updates after each change.';
                Image = Refresh;

                trigger OnAction()
                begin
                    Rec.Modify(true);
                    Commit();
                    UpdatePreview();
                end;
            }
            action(SendForApproval)
            {
                ApplicationArea = All;
                Caption = 'Send for approval';
                ToolTip = 'Save the theme and header/footer and send them for approval. Customers see the new look only after it is approved and activated on the Theme Approvals page.';
                Image = SendApprovalRequest;

                trigger OnAction()
                var
                    Runner: Codeunit "Report Style Designer Runner";
                begin
                    SetUseOn();
                    Rec.Modify(true);
                    Commit();
                    Runner.SetSaveMode('submit');
                    if not Runner.Run(Rec) then
                        Error(GetLastErrorText());
                    Message(Runner.GetResultText());
                end;
            }
            action(OpenDesigner)
            {
                ApplicationArea = All;
                Caption = 'Open designer';
                ToolTip = 'See your documents with these choices and send the design for approval. More options are in the designer.';

                trigger OnAction()
                begin
                    OpenTheDesigner();
                end;
            }
        }
    }

    var
        AdviceText: Text;
        DirectionText: Text;
        LogoPickerReady: Boolean;
        HeaderFooterText: Text;
        PageNumberChoice: Option Header,Footer,None;
        FooterChoice: Option Contact,Bank,None;
        HFUnchangedTxt: Label 'Unchanged: the documents keep the header and footer they have today. Choosing a logo position or a design direction gives them a new one.';
        ChangeHeaderFooterTxt: Label 'Change header and footer in the designer';
        HFHeaderTxt: Label 'Header: report title%1%2%3.', Comment = '%1 = page number part, %2 = date part, %3 = logo part';
        HFPageNumberTxt: Label ', page number', Locked = true;
        HFDateTxt: Label ', date', Locked = true;
        HFLogoTxt: Label ' and logo (%1)', Comment = '%1 = left, centre or right';
        HFLaterMinimalTxt: Label 'Later pages: a smaller header.';
        HFLaterSameTxt: Label 'Later pages: the same header as page 1.';
        HFFooterContactTxt: Label 'Footer: company contact details%1.', Comment = '%1 = page number part';
        HFFooterBankTxt: Label 'Footer: company contact and bank details%1.', Comment = '%1 = page number part';
        HFFooterNoneTxt: Label 'No footer.';
        HFFooterPageOnlyTxt: Label 'Footer: page number only.';
        HFFooterPageTxt: Label ' and page number', Locked = true;
        HFBasedOnTxt: Label 'Built on Microsoft''s External Default Detailed design; fonts and colours follow the theme.';
        InSuggestion: Boolean;
        LookFromText: Text;
        UseOn: Option ThisDocument,Group,Company;
        LookFromSuggestionTxt: Label 'Copilot suggestion "%1"', Comment = '%1 = theme name';
        LookFromDirectionTxt: Label 'Design direction "%1"', Comment = '%1 = direction';
        LookFromThemeTxt: Label 'Theme "%1"', Comment = '%1 = theme name';
        NoGroupErr: Label 'The document in the preview does not belong to a document group. Choose This document or Company default.';
        LogoColorsJson: Text;
        CopilotAvailable: Boolean;
        SuggestionCount: Integer;
        SuggestionIndex: Integer;
        SuggestionText: Text;
        SuggestionReasonText: Text;
        TempProposals: Record "Report Style Proposal" temporary;
        SuggestionTxt: Label '%1 (%2 of %3)', Comment = '%1 = theme name, %2 = number, %3 = how many';
        NotInPreviewTxt: Label '%1 suggestions from your last Copilot run. Use Next suggestion to see them.', Comment = '%1 = how many';
        CreatedTxt: Label 'Copilot made %1 themes. "%2" is in the preview now. Use the arrows over the preview to see the others, or compare them in the designer.', Comment = '%1 = how many, %2 = theme name';
        OpenDesignerTxt: Label 'Compare in the designer';
        ReplaceLogoQst: Label 'This replaces the company logo in Company Information. All documents show the new logo right away, without approval. Continue?';
        UnknownThemeErr: Label 'There is no theme called "%1". Choose one from the list.', Comment = '%1 = the name typed';
        NoLogoTxt: Label 'Your company has no logo in Company Information yet. Upload one to see it on your documents.';
        UploadTitleTxt: Label 'Upload logo';
        TryLogoTitleTxt: Label 'Try a logo in the preview';
        LogoTooLargeErr: Label 'The picture is larger than 2 MB. Choose a smaller logo.';
        TrialLogoAdviceTxt: Label 'The logo in the preview is a trial logo. Documents keep using the logo in Company Information; change it there to use the new one.';
        ImageFilterTxt: Label 'Images (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp', Locked = true;
        CompanyInformationTableTok: Label '79', Locked = true;
        NoCompanyInformationErr: Label 'Company Information is not set up, so the logo cannot be saved.';
        DocumentText: Text;
        PreviewCaptionTxt: Label '%1 · page 1 · not applied yet', Comment = '%1 = report name';
        DocumentTxt: Label '%1 (%2) · layout %3', Comment = '%1 = report name, %2 = report ID, %3 = layout name';
        NoDocumentTxt: Label 'No document chosen yet. Choose one to see the preview.';
        PreviewStatusText: Text;
        ViewerReady: Boolean;
        StartTxt: Label 'Change a choice, or choose Update preview, to see the first page of the document here.';
        ZoomTipTxt: Label 'Click to see the page full size.';
        LastPdfBase64: Text;

    trigger OnOpenPage()
    var
        ReportStyleCopilot: Codeunit "Report Style Copilot";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        DesignerMgt.GetConfig(Rec);
        CopilotAvailable := ReportStyleCopilot.IsAvailable();
        LoadStoredSuggestions();
        // Start on the user's own theme, not on a Copilot suggestion left from browsing them last time;
        // the suggestions stay one click away on the preview.
        if SuggestionIndex <> 0 then begin
            ResetToOwnTheme();
            Rec.Modify(true);
        end;
        case Rec."Apply To" of
            'group':
                UseOn := UseOn::Group;
            'company':
                UseOn := UseOn::Company;
            else
                UseOn := UseOn::ThisDocument;
        end;
    end;

    // The trial logo or else the company logo on the picker's small pages, or a prompt when there is none.
    local procedure ShowLogo()
    var
        Copilot: Codeunit "Report Style Copilot";
        Base64Convert: Codeunit "Base64 Convert";
        TempBlob: Codeunit "Temp Blob";
        BrandHex: Text;
        LogoBase64: Text;
        IsTrial: Boolean;
    begin
        if not LogoPickerReady then
            exit;
        Rec.CalcFields("Preview Logo");
        IsTrial := Rec."Preview Logo".HasValue();
        if IsTrial then begin
            TempBlob.FromRecord(Rec, Rec.FieldNo("Preview Logo"));
            LogoBase64 := Base64Convert.ToBase64(TempBlob.CreateInStream());
        end else
            Copilot.GetCompanyBrand(BrandHex, LogoBase64);
        CurrPage.LogoPicker.SetTrialLogo(IsTrial);
        if LogoBase64 = '' then
            CurrPage.LogoPicker.ShowNoLogo(NoLogoTxt)
        else
            CurrPage.LogoPicker.ShowLogo(LogoBase64, Rec."HF Logo");
    end;

    // A logo for the preview only: kept on the settings, put in Company Information just while the preview renders.
    local procedure TryLogo()
    var
        TempBlob: Codeunit "Temp Blob";
        PictureStream: InStream;
        PictureOutStream: OutStream;
        FileName: Text;
    begin
        Rec.Modify(true);
        Commit();
        if not UploadIntoStream(TryLogoTitleTxt, '', ImageFilterTxt, FileName, PictureStream) then
            exit;
        TempBlob.CreateOutStream(PictureOutStream);
        CopyStream(PictureOutStream, PictureStream);
        if TempBlob.Length() > 2000000 then
            Error(LogoTooLargeErr);
        Rec."Preview Logo".CreateOutStream(PictureOutStream);
        CopyStream(PictureOutStream, TempBlob.CreateInStream());
        if not Rec."Logo Chosen" then begin
            Rec."Logo Chosen" := true;
            Rec."Header Mode" := 'design';
        end;
        Rec.Modify(true);
        ShowLogo();
        RefreshAdvice();
    end;

    local procedure UseCompanyLogo()
    begin
        Clear(Rec."Preview Logo");
        Rec.Modify(true);
        ShowLogo();
        RefreshAdvice();
    end;

    // Saves the picture in Company Information (Picture), read without a Base Application dependency.
    local procedure UploadLogo()
    var
        TempBlob: Codeunit "Temp Blob";
        CompanyInformation: RecordRef;
        PictureStream: InStream;
        PictureOutStream: OutStream;
        FileName: Text;
        TableNo: Integer;
    begin
        if HasCompanyLogo() then
            if not Confirm(ReplaceLogoQst, false) then
                exit;
        Rec.Modify(true);
        Commit();
        if not UploadIntoStream(UploadTitleTxt, '', ImageFilterTxt, FileName, PictureStream) then
            exit;
        TempBlob.CreateOutStream(PictureOutStream);
        CopyStream(PictureOutStream, PictureStream);
        Evaluate(TableNo, CompanyInformationTableTok);
        CompanyInformation.Open(TableNo);
        if not CompanyInformation.FindFirst() then
            Error(NoCompanyInformationErr);
        TempBlob.ToRecordRef(CompanyInformation, 29);
        CompanyInformation.Modify(true);
        Commit();
        ShowLogo();
        UpdatePreview();
    end;

    local procedure HasCompanyLogo(): Boolean
    var
        Copilot: Codeunit "Report Style Copilot";
        BrandHex: Text;
        LogoBase64: Text;
    begin
        Copilot.GetCompanyBrand(BrandHex, LogoBase64);
        exit(LogoBase64 <> '');
    end;

    // The same Copilot dialog as the designer. The first suggestion goes into the preview; the others are a click
    // away here (Next suggestion) and in the designer, which shows the same suggestions.
    local procedure RunCopilot()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        ReportStyleCopilot: Codeunit "Report Style Copilot";
        CopilotDialog: Page "Report Style Copilot";
    begin
        Rec.Modify(true);
        Commit();
        CopilotDialog.SetContext(DesignerMgt.GetReportCaption(Rec), LogoColorsJson);
        CopilotDialog.RunModal();
        if not CopilotDialog.GetProposals(TempProposals) then
            exit;
        DesignerMgt.SaveSuggestions(ReportStyleCopilot.ProposalsToJson(TempProposals));
        SuggestionCount := TempProposals.Count();
        ShowSuggestion(1);
        NotifyCreated();
    end;

    // The suggestions from the last Copilot run (kept until Clear in the designer). The configuration is not
    // changed: if it is one of them, that one is marked; otherwise Next suggestion starts with the first.
    local procedure LoadStoredSuggestions()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        ReportStyleCopilot: Codeunit "Report Style Copilot";
    begin
        ReportStyleCopilot.JsonToProposals(DesignerMgt.GetStoredSuggestions(), TempProposals);
        SuggestionCount := TempProposals.Count();
        SuggestionIndex := 0;
        if SuggestionCount = 0 then
            exit;
        TempProposals.FindSet();
        repeat
            if (Rec.Palette = Rec.Palette::Custom) and (Rec."Custom Colors" = TempProposals.Colors) and
               (Rec."Font Pair" = TempProposals."Font Pair") and (Rec."Table Style" = TempProposals."Table Style") and
               (Rec."Page Color" = TempProposals."Page Color")
            then
                SuggestionIndex := TempProposals."Entry No.";
        until (TempProposals.Next() = 0) or (SuggestionIndex <> 0);
        if SuggestionIndex <> 0 then begin
            TempProposals.Get(SuggestionIndex);
            SuggestionText := StrSubstNo(SuggestionTxt, TempProposals.Name, SuggestionIndex, SuggestionCount);
            SuggestionReasonText := TempProposals.Reason;
        end else begin
            SuggestionText := StrSubstNo(NotInPreviewTxt, SuggestionCount);
            SuggestionReasonText := '';
        end;
    end;

    local procedure OpenTheDesigner()
    var
        Designer: Page "Report Style Designer";
    begin
        Rec.Modify(true);
        Commit();
        Designer.Run();
    end;

    // The header and footer in words, and the options in step with the record (a direction changes them too).
    local procedure ComputeHeaderFooter()
    var
        Lines: TextBuilder;
        PagePart: Text;
        DatePart: Text;
        LogoPart: Text;
        FooterPage: Text;
    begin
        case Rec."HF Page Number" of
            'footer':
                PageNumberChoice := PageNumberChoice::Footer;
            'none':
                PageNumberChoice := PageNumberChoice::None;
            else
                PageNumberChoice := PageNumberChoice::Header;
        end;
        case Rec."HF Footer" of
            'bank':
                FooterChoice := FooterChoice::Bank;
            'none':
                FooterChoice := FooterChoice::None;
            else
                FooterChoice := FooterChoice::Contact;
        end;
        if Rec."Header Mode" <> 'design' then begin
            HeaderFooterText := HFUnchangedTxt;
            exit;
        end;
        if PageNumberChoice = PageNumberChoice::Header then
            PagePart := HFPageNumberTxt;
        if Rec."HF Show Date" then
            DatePart := HFDateTxt;
        case Rec."HF Logo" of
            'left':
                LogoPart := StrSubstNo(HFLogoTxt, 'left');
            'center':
                LogoPart := StrSubstNo(HFLogoTxt, 'centred above the title');
            'none':
                LogoPart := '';
            else
                LogoPart := StrSubstNo(HFLogoTxt, 'right');
        end;
        Lines.AppendLine(StrSubstNo(HFHeaderTxt, PagePart, DatePart, LogoPart));
        if Rec."HF Later Pages" = 'same' then
            Lines.AppendLine(HFLaterSameTxt)
        else
            Lines.AppendLine(HFLaterMinimalTxt);
        if PageNumberChoice = PageNumberChoice::Footer then
            FooterPage := HFFooterPageTxt;
        case FooterChoice of
            FooterChoice::Bank:
                Lines.AppendLine(StrSubstNo(HFFooterBankTxt, FooterPage));
            FooterChoice::None:
                if FooterPage <> '' then
                    Lines.AppendLine(HFFooterPageOnlyTxt)
                else
                    Lines.AppendLine(HFFooterNoneTxt);
            else
                Lines.AppendLine(StrSubstNo(HFFooterContactTxt, FooterPage));
        end;
        Lines.Append(HFBasedOnTxt);
        HeaderFooterText := Lines.ToText();
    end;

    // The look comes from the Copilot suggestion in the preview, else a chosen design direction, else the theme.
    local procedure ComputeLookFrom()
    begin
        InSuggestion := SuggestionIndex > 0;
        if InSuggestion then begin
            TempProposals.Get(SuggestionIndex);
            LookFromText := StrSubstNo(LookFromSuggestionTxt, TempProposals.Name);
        end else
            if Rec.Direction <> Rec.Direction::NotChosen then
                LookFromText := StrSubstNo(LookFromDirectionTxt, Format(Rec.Direction))
            else
                LookFromText := StrSubstNo(LookFromThemeTxt, Rec."Base Theme");
    end;

    // No suggestion in the preview any more; the bar keeps the suggestions one click away.
    local procedure LeaveSuggestion()
    begin
        SuggestionIndex := 0;
        SuggestionText := '';
        SuggestionReasonText := '';
        UpdateSuggestionBar();
    end;

    // "Use my theme" on the bar: the chosen theme as it is, without the suggestion's colours and fonts.
    local procedure UseMyTheme()
    begin
        ResetToOwnTheme();
        RefreshAdvice();
    end;

    local procedure ResetToOwnTheme()
    begin
        LeaveSuggestion();
        if Rec."Own Theme" <> '' then
            Rec."Base Theme" := Rec."Own Theme";
        Rec.Direction := Rec.Direction::NotChosen;
        // A theme cannot be saved under the name of the theme it starts from.
        Rec."Theme Name" := CopyStr(Rec."Base Theme" + ' (copy)', 1, MaxStrLen(Rec."Theme Name"));
        Rec."Theme Mode" := 'custom';
        Rec.Palette := Rec.Palette::KeepBase;
        Rec."Font Pair" := Rec."Font Pair"::KeepBase;
        Rec."Page Color" := Rec."Page Color"::KeepBase;
        Rec."Table Style" := Rec."Table Style"::KeepBase;
    end;

    local procedure SetUseOn()
    var
        DocGroups: Codeunit "Report Style Doc Groups";
    begin
        case UseOn of
            UseOn::ThisDocument:
                Rec."Apply To" := 'layout';
            UseOn::Company:
                Rec."Apply To" := 'company';
            UseOn::Group:
                begin
                    Rec."Apply Group" := CopyStr(DocGroups.GroupOf(Rec."Target Report ID"), 1, MaxStrLen(Rec."Apply Group"));
                    if Rec."Apply Group" = '' then
                        Error(NoGroupErr);
                    Rec."Apply To" := 'group';
                end;
        end;
    end;

    local procedure UpdateSuggestionBar()
    var
        Name: Text;
    begin
        if not ViewerReady then
            exit;
        if SuggestionIndex > 0 then begin
            TempProposals.Get(SuggestionIndex);
            Name := TempProposals.Name;
        end;
        CurrPage.PreviewViewer.SetSuggestion(Name, SuggestionIndex, SuggestionCount, SuggestionReasonText);
    end;

    // Tells the user what Copilot made and where to go next, at the top of the page.
    local procedure NotifyCreated()
    var
        Created: Notification;
    begin
        Created.Id := '6f2b6d5e-0c3a-4d7e-9a51-3b9f1d2c7e40';
        Created.Recall();
        Created.Message(StrSubstNo(CreatedTxt, SuggestionCount, TempProposals.Name));
        Created.Scope := NotificationScope::LocalScope;
        Created.AddAction(OpenDesignerTxt, Codeunit::"Report Style Notifications", 'OpenDesigner');
        Created.Send();
    end;

    local procedure ShowSuggestion(Index: Integer)
    var
        ReportStyleCopilot: Codeunit "Report Style Copilot";
    begin
        if SuggestionCount = 0 then
            exit;
        // Round: after the last comes the first.
        if Index < 1 then
            Index := SuggestionCount;
        if Index > SuggestionCount then
            Index := 1;
        SuggestionIndex := Index;
        TempProposals.FindSet();
        TempProposals.Next(Index - 1);
        ReportStyleCopilot.ApplyProposal(Rec, TempProposals);
        SuggestionText := StrSubstNo(SuggestionTxt, TempProposals.Name, Index, SuggestionCount);
        SuggestionReasonText := TempProposals.Reason;
        UpdateSuggestionBar();
        RefreshAdvice();
    end;

    local procedure ComputeDocumentText()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        if Rec."Target Report ID" = 0 then
            DocumentText := NoDocumentTxt
        else
            DocumentText := StrSubstNo(DocumentTxt, DesignerMgt.GetReportCaption(Rec), Rec."Target Report ID", Rec."Target Layout Name");
    end;

    // Renders the chosen document with the current choices and shows page 1 as a picture (turned into PNG on the server).
    // The preview writes per-user layout settings and restores them, so it runs outside the page's write transaction.
    local procedure UpdatePreview()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Runner: Codeunit "Report Style Designer Runner";
        Base64Convert: Codeunit "Base64 Convert";
        Pdf: Codeunit "Temp Blob";
    begin
        if not ViewerReady then
            exit;
        if not Runner.Preview(Rec) then begin
            PreviewStatusText := Runner.GetErrorText();
            ShowMessage(PreviewStatusText);
            exit;
        end;
        Runner.GetPdf(Pdf);
        PreviewStatusText := StrSubstNo(PreviewCaptionTxt, DesignerMgt.GetReportCaption(Rec));
        LastPdfBase64 := Base64Convert.ToBase64(Pdf.CreateInStream());
        CurrPage.PreviewViewer.ShowPdf(LastPdfBase64, ZoomTipTxt);
    end;

    local procedure ShowMessage(Message: Text)
    begin
        if ViewerReady then
            CurrPage.PreviewViewer.ShowMessage(Message);
    end;


    // A Card page fills its non-source fields here, not in OnAfterGetCurrRecord (that is for list pages).
    trigger OnAfterGetRecord()
    begin
        ComputeAdvice();
        ComputeDocumentText();
    end;

    local procedure ComputeAdvice()
    var
        Advice: Codeunit "Report Style Advice";
        Lines: TextBuilder;
    begin
        AdviceText := Advice.GetAdviceText(Rec);
        Rec.CalcFields("Preview Logo");
        if Rec."Preview Logo".HasValue() then begin
            Lines.AppendLine('- ' + TrialLogoAdviceTxt);
            Lines.Append(AdviceText);
            AdviceText := Lines.ToText();
        end;
        ComputeLookFrom();
        ComputeHeaderFooter();
        ComputeDirectionText();
    end;

    local procedure ComputeDirectionText()
    var
        Directions: Codeunit "Report Style Directions";
    begin
        DirectionText := Directions.Describe(Rec.Direction);
    end;

    // After a change the page must be redrawn, or a non-source field keeps its old text.
    local procedure RefreshAdvice()
    begin
        ComputeAdvice();
        Rec.Modify(true);
        Commit();
        UpdatePreview();
        CurrPage.Update(false);
    end;
}
