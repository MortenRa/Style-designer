namespace Abakion.ReportStyleDesigner;

using System.Reflection;
using System.Text;
using System.Utilities;

/// Quick Start, with collapsible tabs: your brand (logo, design direction and recommendations) first,
/// then the theme and the header/footer, each with the document's preview next to its choices, then Send for approval.
page 50109 "Report Style Start Tabs"
{
    Caption = 'Theme Designer - Quick Start';
    PageType = Card;
    SourceTable = "Report Style Config";
    UsageCategory = Administration;
    AboutTitle = 'Give your documents your look';
    AboutText = 'Choose your logo, a theme, and a header and footer, and see the result on your own document right away. It is only a preview: nothing changes for your customers until the design is approved and activated.';
    ApplicationArea = All;
    AdditionalSearchTerms = 'theme designer, report style, report theme, report design, document design, header, footer, colours, colors, fonts, logo, branding, start';

    layout
    {
        area(Content)
        {
            // FastTabs that can each be collapsed: your brand (logo, direction, recommendations) first, then the theme and the header/footer,
            // each with the same document's preview next to its choices, and Send for approval last.
            group(LogoGroup)
            {
                Caption = 'Your brand';
                AboutTitle = 'Start with your brand';
                AboutText = 'Place your logo, or pick a design direction that sets colours, fonts, tables, header and footer in one step. Recommendations here warn when a choice can go wrong, for example when printing.';

                // Two columns: the logo on the left; the design direction and the recommendations on the right.
                group(BrandLogo)
                {
                    ShowCaption = false;
                    InstructionalText = 'Start with your logo. Choose where it goes on your documents, or a design direction that sets everything in one step.';

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
                }
                group(BrandDirection)
                {
                    ShowCaption = false;
                    field(Direction; Rec.Direction)
                    {
                        ApplicationArea = All;
                        Caption = 'Design direction';
                        ToolTip = 'A finished look to start from. It sets the colours, fonts, tables, header and footer in one step. You can change every detail in the tabs below.';

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
                    group(BrandAdvice)
                    {
                        Caption = 'Recommendations';

                        field(AdviceText; AdviceText)
                        {
                            ApplicationArea = All;
                            ShowCaption = false;
                            Editable = false;
                            MultiLine = true;
                            ToolTip = 'Soft recommendations based on the settings. They explain a likely problem; you can still send the design for approval.';
                        }
                    }
                }
            }
            group(ThemeTab)
            {
                Caption = 'Theme';
                AboutTitle = 'Colours and fonts';
                AboutText = 'The theme sets the colours, fonts and table style of the document. The preview next to it shows every change on your own data.';
                group(ThemeChoices)
                {
                    ShowCaption = false;
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
                            DesignerMgt: Codeunit "Report Style Designer Mgt.";
                        begin
                            ReportLayoutList.SetRange("Report ID", 2000000001);
                            ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Theme);
                            ReportLayoutList.SetRange(Name, Rec."Base Theme");
                            if not ReportLayoutList.FindFirst() then
                                Error(UnknownThemeErr, Rec."Base Theme");
                            if not DesignerMgt.IsUsableTheme(ReportLayoutList) then
                                Error(NotUsableThemeErr, Rec."Base Theme");
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
                group(ThemePreview)
                {
                    ShowCaption = false;
                    field(DocumentName; DocumentText)
                    {
                        ApplicationArea = All;
                        Caption = 'Document';
                        Editable = false;
                        ToolTip = 'The document both previews show. Choose another report layout to see the style on it.';

                        trigger OnAssistEdit()
                        begin
                            ChooseDocument();
                        end;
                    }
                    usercontrol(PreviewViewer; "Report Style Page Preview")
                    {
                        ApplicationArea = All;

                        trigger Ready()
                        begin
                            ViewerReady := true;
                            CurrPage.PreviewViewer.SetOpenOnClick(true);
                            CurrPage.PreviewViewer.SetNote(PreviewOnlyTxt);
                            if LastPdfBase64 <> '' then
                                CurrPage.PreviewViewer.ShowPdf(LastPdfBase64, ZoomTipTxt)
                            else
                                CurrPage.PreviewViewer.ShowMessage(StartTxt);
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

                        trigger RenderRequested()
                        begin
                            RenderPreview();
                        end;

                        trigger FullViewRequested()
                        begin
                            OpenFullPreview();
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
            group(HeaderFooterTab)
            {
                Caption = 'Header and footer';
                AboutTitle = 'What is at the top and bottom';
                AboutText = 'Choose where the page number goes and what the footer shows: your contact details, your bank details, or nothing.';
                group(HeaderFooterChoices)
                {
                    ShowCaption = false;
                    // In words, so it is clear the logo comes with a whole header and footer.
                    field(HeaderFooterSummary; HeaderFooterText)
                    {
                        ApplicationArea = All;
                        Caption = 'Contents';
                        Editable = false;
                        MultiLine = true;
                        Style = Subordinate;
                        ToolTip = 'What the header and footer of the documents show with these choices.';
                    }
                    field(PageNumber; PageNumberChoice)
                    {
                        ApplicationArea = All;
                        Caption = 'Page number';
                        OptionCaption = 'In the header,In the footer,None';
                        ToolTip = 'Where the page number goes.';

                        trigger OnValidate()
                        begin
                            case PageNumberChoice of
                                PageNumberChoice::Header:
                                    Rec."HF Page Number" := 'header';
                                PageNumberChoice::Footer:
                                    Rec."HF Page Number" := 'footer';
                                PageNumberChoice::None:
                                    Rec."HF Page Number" := 'none';
                            end;
                            Rec."Header Mode" := 'design';
                            RefreshAdvice();
                        end;
                    }
                    field(Footer; FooterChoice)
                    {
                        ApplicationArea = All;
                        Caption = 'Footer';
                        OptionCaption = 'Contact details,Contact and bank details,No footer';
                        ToolTip = 'What the footer shows: the company contact details from Company Information, also the bank details, or nothing.';

                        trigger OnValidate()
                        begin
                            case FooterChoice of
                                FooterChoice::Contact:
                                    Rec."HF Footer" := 'contact';
                                FooterChoice::Bank:
                                    Rec."HF Footer" := 'bank';
                                FooterChoice::None:
                                    Rec."HF Footer" := 'none';
                            end;
                            Rec."Header Mode" := 'design';
                            RefreshAdvice();
                        end;
                    }
                    field("HF Show Date"; Rec."HF Show Date")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Show the date in the header.';

                        trigger OnValidate()
                        begin
                            Rec."Header Mode" := 'design';
                            RefreshAdvice();
                        end;
                    }
                    field("HF Accent Line"; Rec."HF Accent Line")
                    {
                        ApplicationArea = All;
                        ToolTip = 'Draw a coloured line under the header.';

                        trigger OnValidate()
                        begin
                            Rec."Header Mode" := 'design';
                            RefreshAdvice();
                        end;
                    }
                    field(MoreHeaderFooter; MoreHeaderFooterTxt)
                    {
                        ApplicationArea = All;
                        ShowCaption = false;
                        Editable = false;
                        ToolTip = 'Open the designer for the other header and footer options, such as later pages or a header/footer design that already exists.';

                        trigger OnDrillDown()
                        begin
                            OpenTheDesigner();
                        end;
                    }
                }
                group(HeaderFooterPreview)
                {
                    ShowCaption = false;
                    field(HFDocumentName; DocumentText)
                    {
                        ApplicationArea = All;
                        Caption = 'Document';
                        Editable = false;
                        ToolTip = 'The document both previews show. Choose another report layout to see the style on it.';

                        trigger OnAssistEdit()
                        begin
                            ChooseDocument();
                        end;
                    }
                    usercontrol(HFPreviewViewer; "Report Style Page Preview")
                    {
                        ApplicationArea = All;

                        trigger Ready()
                        begin
                            HFViewerReady := true;
                            CurrPage.HFPreviewViewer.SetOpenOnClick(true);
                            CurrPage.HFPreviewViewer.SetNote(PreviewOnlyTxt);
                            if LastPdfBase64 <> '' then
                                CurrPage.HFPreviewViewer.ShowPdf(LastPdfBase64, ZoomTipTxt)
                            else
                                CurrPage.HFPreviewViewer.ShowMessage(StartTxt);
                        end;

                        trigger SuggestionStep(Delta: Integer)
                        begin
                        end;

                        trigger UseMyThemeRequested()
                        begin
                        end;

                        trigger RenderRequested()
                        begin
                            RenderPreview();
                        end;

                        trigger FullViewRequested()
                        begin
                            OpenFullPreview();
                        end;
                    }
                    field(HFPreviewStatus; PreviewStatusText)
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
            group(DownloadPreview_Promoted)
            {
                Caption = 'Download preview';
                Image = Download;

                actionref(DownloadPreviewPdf_Promoted; DownloadPreviewPdf) { }
                actionref(DownloadPreviewWord_Promoted; DownloadPreviewWord) { }
            }
            actionref(SendForApproval_Promoted; SendForApproval) { }
            actionref(SaveAsDraft_Promoted; SaveAsDraft) { }
            actionref(MyDrafts_Promoted; MyDrafts) { }
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
            action(DownloadPreviewPdf)
            {
                ApplicationArea = All;
                Caption = 'Download as PDF';
                AboutTitle = 'Share it before you decide';
                AboutText = 'Download the preview as PDF or Word and send it to a colleague or your manager. Nothing is saved or sent for approval.';
                ToolTip = 'Download the chosen document with these choices as a PDF file. Nothing is saved or changed for other users.';
                Image = SendAsPDF;

                trigger OnAction()
                begin
                    DownloadPreview(ReportFormat::Pdf);
                end;
            }
            action(DownloadPreviewWord)
            {
                ApplicationArea = All;
                Caption = 'Download as Word';
                ToolTip = 'Download the chosen document with these choices as a Word file. Nothing is saved or changed for other users.';
                Image = Word;

                trigger OnAction()
                begin
                    DownloadPreview(ReportFormat::Word);
                end;
            }
            action(SendForApproval)
            {
                ApplicationArea = All;
                Caption = 'Send for approval…';
                AboutTitle = 'Nothing changes until it is approved';
                AboutText = 'Changing the company''s documents is not one person''s decision. You send a request; an approver looks at it, approves it and activates it on the Theme Approvals page.';
                ToolTip = 'Choose what to send (the theme, the header and footer, or both), give it a name and choose the documents. Customers see the new look only after it is approved and activated on the Theme Approvals page.';
                Image = SendApprovalRequest;

                trigger OnAction()
                var
                    Drafts: Codeunit "Report Style Drafts";
                begin
                    Rec.Modify(true);
                    Commit();
                    if not Drafts.SendForApproval(Rec) then
                        exit;
                    Rec.Get(Rec."Primary Key");
                    ComputeAdvice();
                    CurrPage.Update(false);
                end;
            }
            action(SaveAsDraft)
            {
                ApplicationArea = All;
                Caption = 'Save as draft…';
                AboutTitle = 'Keep an idea for later';
                AboutText = 'Save as draft keeps your logo, theme and header/footer choices under a name. Find them again in My drafts.';
                ToolTip = 'Save all your choices under a name, to continue later or to keep an idea. Nothing is sent, and nothing changes for any document.';
                Image = Save;

                trigger OnAction()
                var
                    Drafts: Codeunit "Report Style Drafts";
                begin
                    Rec.Modify(true);
                    Commit();
                    Drafts.SaveDraft(Rec);
                end;
            }
            action(MyDrafts)
            {
                ApplicationArea = All;
                Caption = 'My drafts';
                ToolTip = 'See your saved drafts. Open one to continue working on it, or send it for approval.';
                Image = Documents;
                RunObject = page "Report Style Drafts";
            }
            action(OpenDesigner)
            {
                ApplicationArea = All;
                Caption = 'Open designer';
                AboutTitle = 'See all your documents';
                AboutText = 'The designer shows the look on all your documents side by side, and lets you compare themes before you choose.';
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
        HFUnchangedTxt: Label 'Unchanged: the documents keep the header and footer they have today. Choosing a logo position, a design direction or one of the options below gives them a new one.';
        MoreHeaderFooterTxt: Label 'More header and footer options in the designer';
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
        HFReplacesTxt: Label 'Replaces "%1", which this document uses today.', Comment = '%1 = header/footer name';
        PreviewOnlyTxt: Label 'Preview only. Nothing has changed in your layouts yet.';
        HFBasedOnTxt: Label 'Built on Microsoft''s External Default Detailed design; fonts and colours follow the theme.';
        InSuggestion: Boolean;
        LookFromText: Text;
        LookFromSuggestionTxt: Label 'Copilot suggestion "%1"', Comment = '%1 = theme name';
        LookFromDirectionTxt: Label 'Design direction "%1"', Comment = '%1 = direction';
        LookFromThemeTxt: Label 'Theme "%1"', Comment = '%1 = theme name';
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
        NotUsableThemeErr: Label 'The theme %1 is built into Business Central and cannot be the starting point. Choose another theme, for example DefaultTheme.', Comment = '%1 = theme name';
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
        PreviewCaptionTxt: Label '%1 · page 1', Comment = '%1 = report name';
        DocumentTxt: Label '%1 (%2) · layout %3', Comment = '%1 = report name, %2 = report ID, %3 = layout name';
        NoDocumentTxt: Label 'No document chosen yet. Choose one to see the preview.';
        PreviewStatusText: Text;
        ViewerReady: Boolean;
        HFViewerReady: Boolean;
        StartTxt: Label 'Change a choice, or choose Update preview, to see the first page of the document here.';
        BusyTxt: Label 'Showing page 1 of %1 with your choices. With a lot of data this can take a moment.', Comment = '%1 = report name';
        ZoomTipTxt: Label 'Click to see the page full size.';
        LastPdfBase64: Text;

    trigger OnOpenPage()
    var
        ReportStyleCopilot: Codeunit "Report Style Copilot";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Approvals: Codeunit "Report Style Approvals";
    begin
        DesignerMgt.GetConfig(Rec);
        // Only the user's own design: no paging to other users' designs (and no record navigation on the card).
        Rec.FilterGroup(2);
        Rec.SetRange("Primary Key", Rec."Primary Key");
        Rec.FilterGroup(0);
        CopilotAvailable := ReportStyleCopilot.IsAvailable();
        LoadStoredSuggestions();
        // Start on the user's own theme, not on a Copilot suggestion left from browsing them last time;
        // the suggestions stay one click away on the preview.
        if SuggestionIndex <> 0 then begin
            ResetToOwnTheme();
            Rec.Modify(true);
        end;
        // News about the user's own request (approved, rejected, activated) as a bar at the top, once.
        Approvals.NotifyOwnRequest(Rec);
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
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        CurrentHF: Text;
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
        CurrentHF := DesignerMgt.CurrentHeaderFooter(Rec);
        if (CurrentHF <> '') and (CurrentHF <> Rec."HF Name") then
            Lines.AppendLine(StrSubstNo(HFReplacesTxt, CurrentHF));
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
    // Shows the busy text on the preview first; the preview then asks for the render (RenderRequested), because the
    // page cannot show anything while the server renders.
    local procedure UpdatePreview()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        BusyText: Text;
    begin
        if not (ViewerReady or HFViewerReady) then
            exit;
        BusyText := StrSubstNo(BusyTxt, DesignerMgt.GetReportCaption(Rec));
        if ViewerReady then
            CurrPage.PreviewViewer.ShowBusy(BusyText, true);
        if HFViewerReady then
            CurrPage.HFPreviewViewer.ShowBusy(BusyText, not ViewerReady);
    end;

    local procedure DownloadPreview(Format: ReportFormat)
    var
        Runner: Codeunit "Report Style Designer Runner";
    begin
        Rec.Modify(true);
        Commit();
        Runner.DownloadPreview(Rec, Format);
    end;

    local procedure RenderPreview()
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Runner: Codeunit "Report Style Designer Runner";
        Base64Convert: Codeunit "Base64 Convert";
        Pdf: Codeunit "Temp Blob";
    begin
        if not (ViewerReady or HFViewerReady) then
            exit;
        if not Runner.Preview(Rec) then begin
            PreviewStatusText := Runner.GetErrorText();
            ShowMessage(PreviewStatusText);
            exit;
        end;
        Runner.GetPdf(Pdf);
        PreviewStatusText := StrSubstNo(PreviewCaptionTxt, DesignerMgt.GetReportCaption(Rec));
        LastPdfBase64 := Base64Convert.ToBase64(Pdf.CreateInStream());
        if ViewerReady then
            CurrPage.PreviewViewer.ShowPdf(LastPdfBase64, ZoomTipTxt);
        if HFViewerReady then
            CurrPage.HFPreviewViewer.ShowPdf(LastPdfBase64, ZoomTipTxt);
    end;

    local procedure ShowMessage(Message: Text)
    begin
        if ViewerReady then
            CurrPage.PreviewViewer.ShowMessage(Message);
        if HFViewerReady then
            CurrPage.HFPreviewViewer.ShowMessage(Message);
    end;

    local procedure ChooseDocument()
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

    local procedure OpenFullPreview()
    var
        FullPreview: Page "Report Style Full Preview";
    begin
        FullPreview.SetPreview(LastPdfBase64, PreviewStatusText);
        FullPreview.RunModal();
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
