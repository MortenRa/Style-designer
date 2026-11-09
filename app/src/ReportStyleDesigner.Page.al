namespace Abakion.ReportStyleDesigner;

using System.Text;
using System.Utilities;

page 50102 "Report Style Designer"
{
    Caption = 'Report Style Designer';
    // A Card page, not UserControlHost: that page type shows an "Add-in" label above the title.
    PageType = Card;
    UsageCategory = Administration;
    ApplicationArea = All;
    AdditionalSearchTerms = 'report theme, report design, document design, header, footer, colours, colors, fonts, branding, layout style';
    Editable = false;

    layout
    {
        area(Content)
        {
            usercontrol(Designer; "Report Style Designer")
            {
                ApplicationArea = All;

                trigger Ready()
                begin
                    DesignerMgt.GetConfig(Config);
                    CurrPage.Designer.Init(DesignerMgt.BuildStudioData(Config));
                end;

                trigger PreviewRequested(State: Text; Seq: Integer)
                var
                    Runner: Codeunit "Report Style Designer Runner";
                    Pdf: Codeunit "Temp Blob";
                    Base64Convert: Codeunit "Base64 Convert";
                begin
                    DesignerMgt.ApplyState(Config, State);
                    Commit();
                    if Runner.Preview(Config) then begin
                        Runner.GetPdf(Pdf);
                        CurrPage.Designer.ShowPreview(Seq, Base64Convert.ToBase64(Pdf.CreateInStream()));
                    end else
                        CurrPage.Designer.ShowPreviewError(Seq, Runner.GetErrorText());
                end;

                trigger SaveRequested(State: Text; Mode: Text)
                var
                    Runner: Codeunit "Report Style Designer Runner";
                begin
                    DesignerMgt.ApplyState(Config, State);
                    Commit();
                    Runner.SetSaveMode(Mode);
                    if Runner.Run(Config) then begin
                        CurrPage.Designer.Notify(Runner.GetResultText(), 'success');
                        Config.Get();
                        CurrPage.Designer.Init(DesignerMgt.BuildStudioData(Config, Suggestions));
                    end else
                        CurrPage.Designer.Notify(GetLastErrorText(), 'error');
                end;

                trigger DraftThemeRequested()
                begin
                    DraftTheme();
                end;

                trigger ClearSuggestionsRequested()
                begin
                    DesignerMgt.ClearSuggestions();
                    DesignerMgt.GetConfig(Config);
                    CurrPage.Designer.Init(DesignerMgt.BuildStudioData(Config));
                end;

                trigger ChooseDataRequested(State: Text)
                begin
                    DesignerMgt.ApplyState(Config, State);
                    Commit();
                    if DesignerMgt.ChooseData(Config) then
                        CurrPage.Designer.SetHasData(true);
                end;

                trigger ClearDataRequested(State: Text)
                begin
                    DesignerMgt.ApplyState(Config, State);
                    DesignerMgt.ClearData(Config);
                    CurrPage.Designer.SetHasData(false);
                end;

                trigger GalleryBatchRequested(State: Text; Docs: Text)
                var
                    GalleryJobs: Codeunit "Report Style Gallery Jobs";
                begin
                    DesignerMgt.ApplyState(Config, State);
                    Commit();
                    if GalleryJobs.StartBatch(State, Docs, GalleryBatchID) then
                        CurrPage.Designer.GalleryProgress(1)   // the add-in starts polling
                    else
                        RenderGalleryHere(Docs);
                end;

                trigger GalleryPoll()
                var
                    Job: Record "Report Style Gallery Job";
                    Base64Convert: Codeunit "Base64 Convert";
                    PdfInStream: InStream;
                begin
                    Job.SetCurrentKey("User Security ID", "Batch ID");
                    Job.SetRange("User Security ID", UserSecurityId());
                    Job.SetRange("Batch ID", GalleryBatchID);
                    Job.SetFilter(Status, '%1|%2', Job.Status::Done, Job.Status::Failed);
                    if Job.FindSet() then
                        repeat
                            if Job.Status = Job.Status::Done then begin
                                Job.CalcFields(Pdf);
                                Job.Pdf.CreateInStream(PdfInStream);
                                CurrPage.Designer.ShowGalleryPage(Job.Seq, Base64Convert.ToBase64(PdfInStream));
                            end else
                                CurrPage.Designer.ShowGalleryError(Job.Seq, Job."Error Text");
                        until Job.Next() = 0;
                    Job.DeleteAll();
                    Job.SetRange(Status);
                    CurrPage.Designer.GalleryProgress(Job.Count());
                end;

                trigger GalleryChooseDataRequested(State: Text; ReportId: Integer)
                begin
                    DesignerMgt.ApplyState(Config, State);
                    Commit();
                    if DesignerMgt.ChooseGalleryData(ReportId) then
                        CurrPage.Designer.GalleryDataChanged(ReportId);
                end;

                trigger BrowseLayoutsRequested(State: Text)
                var
                    ConfiguratorMgt: Codeunit "Report Style Configurator Mgt.";
                begin
                    DesignerMgt.ApplyState(Config, State);
                    Commit();
                    if not ConfiguratorMgt.LookupBodyLayout(Config) then
                        exit;
                    Config.Modify();
                    CurrPage.Designer.Init(DesignerMgt.BuildStudioData(Config, Suggestions));
                end;

                trigger LogoColorsComputed(Colors: Text)
                begin
                    LogoColorsJson := Colors;
                end;
            }
        }
    }

    actions
    {
        // Business Central's standard place for Copilot: the "Here's what Copilot can do on this page" menu.
        area(Prompting)
        {
            action(DraftThemeAction)
            {
                ApplicationArea = All;
                // Hidden: the designer has one Copilot entry, "Draft with Copilot", at the top right of the preview.
                Caption = 'Draft a theme';
                ToolTip = 'Describe the look you want and get three themes to preview. Nothing is applied until you choose Apply.';
                Image = Sparkle;
                Visible = false;

                trigger OnAction()
                begin
                    DraftTheme();
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        ReportStyleCopilot: Codeunit "Report Style Copilot";
    begin
        CopilotAvailable := ReportStyleCopilot.IsAvailable();
    end;

    trigger OnClosePage()
    var
        GalleryJobs: Codeunit "Report Style Gallery Jobs";
    begin
        GalleryJobs.CancelBatches();
    end;

    var
        Config: Record "Report Style Config";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Suggestions: Text;
        GalleryBatchID: Guid;
        LogoColorsJson: Text;
        CopilotAvailable: Boolean;

    /// Opens the Copilot dialog for the current draft (the add-in saves it with every preview) and puts the
    /// proposals into the designer. Started from the page's prompt action.
    local procedure DraftTheme()
    var
        Proposals: Record "Report Style Proposal";
        ReportStyleCopilot: Codeunit "Report Style Copilot";
        CopilotDialog: Page "Report Style Copilot";
    begin
        DesignerMgt.GetConfig(Config);
        CopilotDialog.SetContext(DesignerMgt.GetReportCaption(Config), LogoColorsJson);
        CopilotDialog.RunModal();
        if not CopilotDialog.GetProposals(Proposals) then
            exit;
        Suggestions := ReportStyleCopilot.ProposalsToJson(Proposals);
        DesignerMgt.SaveSuggestions(Suggestions);
        // Only the draft changes: the first proposal goes into the preview, the others are one click away.
        Proposals.FindFirst();
        ReportStyleCopilot.ApplyProposal(Config, Proposals);
        CurrPage.Designer.Init(DesignerMgt.BuildStudioData(Config, Suggestions));
    end;

    /// Fallback when no background session can be started: render the gallery here (with progress dialogs).
    local procedure RenderGalleryHere(DocsText: Text)
    var
        GalleryRec: Record "Report Style Config" temporary;
        Runner: Codeunit "Report Style Designer Runner";
        Pdf: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        Docs: JsonArray;
        Doc: JsonToken;
        Value: JsonToken;
        ReportId: Integer;
        Seq: Integer;
        LayoutName: Text;
        LayoutAppId: Text;
    begin
        if Docs.ReadFrom(DocsText) then
            foreach Doc in Docs do begin
                Doc.AsObject().Get('reportId', Value);
                ReportId := Value.AsValue().AsInteger();
                Doc.AsObject().Get('seq', Value);
                Seq := Value.AsValue().AsInteger();
                Doc.AsObject().Get('name', Value);
                LayoutName := Value.AsValue().AsText();
                LayoutAppId := '';
                if Doc.AsObject().Get('appId', Value) then
                    if not Value.AsValue().IsNull() then
                        LayoutAppId := Value.AsValue().AsText();
                DesignerMgt.GalleryConfig(Config, ReportId, LayoutName, LayoutAppId, GalleryRec);
                if Runner.Preview(GalleryRec) then begin
                    Runner.GetPdf(Pdf);
                    CurrPage.Designer.ShowGalleryPage(Seq, Base64Convert.ToBase64(Pdf.CreateInStream()));
                end else
                    CurrPage.Designer.ShowGalleryError(Seq, Runner.GetErrorText());
            end;
        CurrPage.Designer.GalleryProgress(0);
    end;
}
