namespace Abakion.ReportStyleDesigner;

/// Saving a design as a draft, opening a draft again, and sending a design for approval.
/// A draft is a copy of the designer's choices only. Sending asks what to send (theme, header/footer or both) and
/// the names, then saves the parts and records the request. The approver chooses the documents when activating.
codeunit 50108 "Report Style Drafts"
{
    Access = Internal;

    var
        DraftSavedTxt: Label 'Saved as draft "%1". Open it again from My drafts.', Comment = '%1 = draft name';
        DraftUpdatedTxt: Label 'Draft "%1" is updated.', Comment = '%1 = draft name';
        DraftSentTxt: Label '%1 The draft "%2" is removed, because the request now holds the design.', Comment = '%1 = result of sending, %2 = draft name';
        NoGroupErr: Label 'The document in the preview does not belong to a document group. Choose This document or Company default.';
        NoStateErr: Label 'Draft "%1" has no design stored.', Comment = '%1 = draft name';

    /// Asks for a name and saves the current choices as a draft. A draft with the same name of the same user is updated.
    procedure SaveDraft(var Config: Record "Report Style Config")
    var
        Draft: Record "Report Style Draft";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        NameDialog: Page "Report Style Draft Name";
        DraftName: Text[100];
        OutStream: OutStream;
        Existing: Boolean;
    begin
        NameDialog.SetName(DefaultDraftName(Config));
        if NameDialog.RunModal() <> Action::OK then
            exit;
        DraftName := NameDialog.GetName();

        Draft.SetRange(Name, DraftName);
        Draft.SetRange("Saved By", CopyStr(UserId(), 1, MaxStrLen(Draft."Saved By")));
        Existing := Draft.FindFirst();
        if not Existing then begin
            Draft.Init();
            Draft.Name := DraftName;
            Draft."Saved By" := CopyStr(UserId(), 1, MaxStrLen(Draft."Saved By"));
        end;
        Draft.Document := CopyStr(DesignerMgt.GetReportCaption(Config), 1, MaxStrLen(Draft.Document));
        Draft.Change := CopyStr(DesignerMgt.DescribeChange(Config), 1, MaxStrLen(Draft.Change));
        Draft."Theme Name" := CopyStr(ThemeCaption(Config), 1, MaxStrLen(Draft."Theme Name"));
        Draft."Header/Footer Name" := CopyStr(HeaderFooterCaption(Config), 1, MaxStrLen(Draft."Header/Footer Name"));
        Draft."Saved At" := CurrentDateTime();
        Clear(Draft.State);
        Draft.State.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(DesignerMgt.GetStateJson(Config));
        if Existing then begin
            Draft.Modify(true);
            Message(DraftUpdatedTxt, DraftName);
        end else begin
            Draft.Insert(true);
            Message(DraftSavedTxt, DraftName);
        end;
    end;

    /// Puts the draft's choices in the user's own design and opens Quick Start on it.
    procedure OpenDraft(var Draft: Record "Report Style Draft")
    var
        Config: Record "Report Style Config";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        DesignerMgt.GetConfig(Config);
        DesignerMgt.ApplyState(Config, ReadState(Draft));
        Commit();
        Page.Run(Page::"Report Style Start Tabs");
    end;

    /// Sends the draft for approval, as Send for approval on Quick Start does. The draft is removed when it is sent.
    procedure SendDraft(var Draft: Record "Report Style Draft"): Boolean
    var
        TempConfig: Record "Report Style Config" temporary;
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        DraftName: Text;
        Result: Text;
    begin
        TempConfig.Init();
        TempConfig.Insert();
        DesignerMgt.ApplyState(TempConfig, ReadState(Draft));
        if not RunSend(TempConfig, Result) then
            exit(false);
        DraftName := Draft.Name;
        Draft.Delete(true);
        Commit();
        Message(DraftSentTxt, Result, DraftName);
        exit(true);
    end;

    /// Asks what to send and the names, then saves the parts and records the request.
    procedure SendForApproval(var Config: Record "Report Style Config"): Boolean
    var
        Result: Text;
    begin
        if not RunSend(Config, Result) then
            exit(false);
        Message(Result);
        exit(true);
    end;

    local procedure RunSend(var Config: Record "Report Style Config"; var Result: Text): Boolean
    var
        TempToSend: Record "Report Style Config" temporary;
        Runner: Codeunit "Report Style Designer Runner";
        SendDialog: Page "Report Style Send";
    begin
        SendDialog.SetConfig(Config);
        if SendDialog.RunModal() <> Action::OK then
            exit(false);

        // The names stay with the design; what is left out of this request only changes the copy that is sent.
        SendDialog.GetNames(Config);
        Config.Modify(true);
        TempToSend := Config;
        if not SendDialog.SendTheme() then
            TempToSend."Theme Mode" := 'keep';
        if not SendDialog.SendHeaderFooter() then
            TempToSend."Header Mode" := 'keep';
        // The request names the document it was designed on; the approver chooses the documents when activating.
        TempToSend."Apply To" := 'layout';
        TempToSend.Insert();
        Commit();

        Runner.SetSaveMode('submit');
        if not Runner.Run(TempToSend) then
            Error(GetLastErrorText());
        Result := Runner.GetResultText();
        exit(true);
    end;

    /// 0 = this document, 1 = all documents in its group, 2 = the company default.
    procedure ApplyUseOn(var Config: Record "Report Style Config"; UseOn: Integer)
    var
        DocGroups: Codeunit "Report Style Doc Groups";
    begin
        case UseOn of
            1:
                begin
                    Config."Apply Group" := CopyStr(DocGroups.GroupOf(Config."Target Report ID"), 1, MaxStrLen(Config."Apply Group"));
                    if Config."Apply Group" = '' then
                        Error(NoGroupErr);
                    Config."Apply To" := 'group';
                end;
            2:
                Config."Apply To" := 'company';
            else
                Config."Apply To" := 'layout';
        end;
    end;

    /// The theme in words for lists and dialogs: the new theme's name, Default, or Unchanged.
    procedure ThemeCaption(Config: Record "Report Style Config"): Text
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        case DesignerMgt.ThemeModeOf(Config) of
            'custom':
                exit(Config."Theme Name");
            'default':
                exit('Default');
        end;
        exit('Unchanged');
    end;

    /// The header/footer in words: the new design's name, the chosen design, Default, or Unchanged.
    procedure HeaderFooterCaption(Config: Record "Report Style Config"): Text
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        case DesignerMgt.HeaderModeOf(Config) of
            'design':
                exit(Config."HF Name");
            'custom':
                exit(Config."Header Part");
            'default':
                exit('Default');
        end;
        exit('Unchanged');
    end;

    local procedure DefaultDraftName(Config: Record "Report Style Config"): Text
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        exit(StrSubstNo('%1 - %2', DesignerMgt.GetReportCaption(Config), Format(Today())));
    end;

    local procedure ReadState(var Draft: Record "Report Style Draft") StateText: Text
    var
        InStream: InStream;
    begin
        Draft.CalcFields(State);
        if not Draft.State.HasValue() then
            Error(NoStateErr, Draft.Name);
        Draft.State.CreateInStream(InStream, TextEncoding::UTF8);
        InStream.ReadText(StateText);
    end;
}
