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

                trigger CopilotRequested(State: Text; LogoColors: Text)
                var
                    Proposals: Record "Report Style Proposal";
                    ReportStyleCopilot: Codeunit "Report Style Copilot";
                    CopilotDialog: Page "Report Style Copilot";
                begin
                    DesignerMgt.ApplyState(Config, State);
                    Commit();
                    CopilotDialog.SetContext(DesignerMgt.GetReportCaption(Config), LogoColors);
                    CopilotDialog.RunModal();
                    if not CopilotDialog.GetProposals(Proposals) then
                        exit;
                    Suggestions := ReportStyleCopilot.ProposalsToJson(Proposals);
                    // Only the draft changes: the first proposal goes into the preview, the others are one click away.
                    Proposals.FindFirst();
                    ReportStyleCopilot.ApplyProposal(Config, Proposals);
                    CurrPage.Designer.Init(DesignerMgt.BuildStudioData(Config, Suggestions));
                end;
            }
        }
    }

    var
        Config: Record "Report Style Config";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Suggestions: Text;
}
