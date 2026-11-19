namespace Abakion.ReportStyleDesigner;

/// The way from a saved design to the customers: Send for approval, then Approve (or Reject), then Activate.
/// Only Activate assigns the theme and header/footer to documents. Who may approve and activate is set with
/// Business Central permissions: the "Theme Designer - Approve" permission set can change requests, the designer's
/// own permission set can only send them.
codeunit 50138 "Report Style Approvals"
{
    Access = Internal;

    var
        SentTxt: Label 'Sent for approval as request %1. Nothing changes on any document until it is approved and activated on the Theme Approvals page.', Comment = '%1 = request number';
        NotPendingErr: Label 'Request %1 is %2. Only a request that is waiting for approval can be approved.', Comment = '%1 = request number, %2 = status';
        CannotRejectErr: Label 'Request %1 is %2 and can no longer be rejected.', Comment = '%1 = request number, %2 = status';
        NotApprovedErr: Label 'Request %1 is %2. Approve it before you activate it.', Comment = '%1 = request number, %2 = status';
        ActivatedTxt: Label 'Request %1 is active. %2', Comment = '%1 = request number, %2 = what was updated';
        WaitingTxt: Label '"%1" is waiting for approval since %2 (sent by %3). Sending again makes a second request.', Comment = '%1 = theme name, %2 = date, %3 = user';
        RejectedTxt: Label '"%1" was rejected on %2. Change it and send it again.', Comment = '%1 = theme name, %2 = date';
        RejectedCommentTxt: Label '"%1" was rejected on %2: %3', Comment = '%1 = theme name, %2 = date, %3 = the approver''s comment';
        ApprovedTxt: Label '"%1" was approved on %2 and is waiting to be activated.', Comment = '%1 = theme name, %2 = date';
        ActiveTxt: Label '"%1" is active on the documents since %2.', Comment = '%1 = theme name, %2 = date';
        NoStateErr: Label 'Request %1 has no design stored.', Comment = '%1 = request number';
        OwnApprovedTxt: Label 'Your design "%1" was approved. It goes live when an administrator activates it.', Comment = '%1 = theme or header/footer name';
        OwnRejectedTxt: Label 'Your design "%1" was rejected. Change it and send it again.', Comment = '%1 = theme or header/footer name';
        OwnRejectedCommentTxt: Label 'Your design "%1" was rejected: %2', Comment = '%1 = theme or header/footer name, %2 = the approver''s reason';
        OwnActiveTxt: Label 'Your design "%1" is live on %2.', Comment = '%1 = theme or header/footer name, %2 = the documents';
        OpenApprovalsTxt: Label 'Open the request';

    /// The latest request in words, for Quick Start: waiting, rejected or active. Empty when there is none.
    /// IsAttention is true when the user should act or wait (waiting or rejected).
    procedure LatestStatusText(var IsAttention: Boolean): Text
    var
        Approval: Record "Report Style Approval";
    begin
        IsAttention := false;
        Approval.SetCurrentKey(Status, "Sent At");
        Approval.SetRange(Status, Approval.Status::Pending);
        if Approval.FindLast() then begin
            IsAttention := true;
            exit(StrSubstNo(WaitingTxt, NameOf(Approval), DT2Date(Approval."Sent At"), Approval."Sent By"));
        end;
        Approval.Reset();
        if not Approval.FindLast() then
            exit('');
        case Approval.Status of
            Approval.Status::Rejected:
                begin
                    IsAttention := true;
                    if Approval.Comment <> '' then
                        exit(StrSubstNo(RejectedCommentTxt, NameOf(Approval), DT2Date(Approval."Decided At"), Approval.Comment));
                    exit(StrSubstNo(RejectedTxt, NameOf(Approval), DT2Date(Approval."Decided At")));
                end;
            Approval.Status::Approved:
                exit(StrSubstNo(ApprovedTxt, NameOf(Approval), DT2Date(Approval."Decided At")));
            Approval.Status::Active:
                exit(StrSubstNo(ActiveTxt, NameOf(Approval), DT2Date(Approval."Activated At")));
        end;
    end;

    /// Shows news about the user's own latest request as a notification on Quick Start: approved, rejected (with the
    /// reason) or activated. Each change shows once; a request still waiting shows nothing, the user just sent it.
    procedure NotifyOwnRequest(var Config: Record "Report Style Config")
    var
        Approval: Record "Report Style Approval";
        News: Notification;
        Text: Text;
    begin
        Approval.SetRange("Sent By", CopyStr(UserId(), 1, MaxStrLen(Approval."Sent By")));
        if not Approval.FindLast() then
            exit;
        if (Approval."Entry No." = Config."Seen Request No.") and (Approval.Status.AsInteger() = Config."Seen Request Status") then
            exit;
        case Approval.Status of
            Approval.Status::Approved:
                Text := StrSubstNo(OwnApprovedTxt, NameOf(Approval));
            Approval.Status::Rejected:
                if Approval.Comment <> '' then
                    Text := StrSubstNo(OwnRejectedCommentTxt, NameOf(Approval), Approval.Comment)
                else
                    Text := StrSubstNo(OwnRejectedTxt, NameOf(Approval));
            Approval.Status::Active:
                Text := StrSubstNo(OwnActiveTxt, NameOf(Approval), Approval.Target);
        end;
        Config."Seen Request No." := Approval."Entry No.";
        Config."Seen Request Status" := Approval.Status.AsInteger();
        Config.Modify();
        if Text = '' then
            exit;
        News.Id := CreateGuid();
        News.Message(Text);
        News.Scope := NotificationScope::LocalScope;
        News.AddAction(OpenApprovalsTxt, Codeunit::"Report Style Notifications", 'OpenApprovals');
        News.Send();
    end;

    /// True for a theme that was sent for approval but is not approved: waiting or rejected, and no request with that
    /// theme was ever approved. Such a theme is saved already, but must not be offered as a choice yet.
    procedure IsThemeAwaitingApproval(ThemeName: Text): Boolean
    var
        Approval: Record "Report Style Approval";
    begin
        Approval.SetRange("Theme Name", CopyStr(ThemeName, 1, MaxStrLen(Approval."Theme Name")));
        if Approval.IsEmpty() then
            exit(false);
        Approval.SetFilter(Status, '%1|%2', Approval.Status::Approved, Approval.Status::Active);
        exit(Approval.IsEmpty());
    end;

    local procedure NameOf(Approval: Record "Report Style Approval"): Text
    begin
        if Approval."Theme Name" <> '' then
            exit(Approval."Theme Name");
        exit(Approval."Header/Footer Name");
    end;

    /// Records a request for the design. The parts must already be saved; nothing is assigned here.
    procedure Submit(Config: Record "Report Style Config") Message: Text
    var
        Approval: Record "Report Style Approval";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        OutStream: OutStream;
    begin
        Approval.Init();
        Approval.Status := Approval.Status::Pending;
        if DesignerMgt.ThemeModeOf(Config) = 'custom' then
            Approval."Theme Name" := Config."Theme Name";
        if DesignerMgt.HeaderModeOf(Config) = 'design' then
            Approval."Header/Footer Name" := Config."HF Name"
        else
            if DesignerMgt.HeaderModeOf(Config) = 'custom' then
                Approval."Header/Footer Name" := Config."Header Part";
        Approval.Target := CopyStr(DesignerMgt.DescribeTarget(Config), 1, MaxStrLen(Approval.Target));
        Approval.Change := CopyStr(DesignerMgt.DescribeChange(Config), 1, MaxStrLen(Approval.Change));
        Approval."Sent By" := CopyStr(UserId(), 1, MaxStrLen(Approval."Sent By"));
        Approval."Sent At" := CurrentDateTime();
        Approval.State.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(DesignerMgt.GetStateJson(Config));
        Approval.Insert(true);
        exit(StrSubstNo(SentTxt, Approval."Entry No."));
    end;

    procedure Approve(var Approval: Record "Report Style Approval")
    begin
        if Approval.Status <> Approval.Status::Pending then
            Error(NotPendingErr, Approval."Entry No.", Approval.Status);
        Approval.Status := Approval.Status::Approved;
        SetDecided(Approval);
        Approval.Modify(true);
    end;

    procedure Reject(var Approval: Record "Report Style Approval"; Reason: Text)
    begin
        if not (Approval.Status in [Approval.Status::Pending, Approval.Status::Approved]) then
            Error(CannotRejectErr, Approval."Entry No.", Approval.Status);
        Approval.Status := Approval.Status::Rejected;
        Approval.Comment := CopyStr(Reason, 1, MaxStrLen(Approval.Comment));
        SetDecided(Approval);
        Approval.Modify(true);
    end;

    /// Assigns the approved design to its documents, exactly as it was sent.
    /// UseOn: 0 = the document it was designed on, 1 = all documents in its group, 2 = the company default.
    procedure Activate(var Approval: Record "Report Style Approval"; UseOn: Integer): Text
    var
        TempConfig: Record "Report Style Config" temporary;
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Drafts: Codeunit "Report Style Drafts";
        Result: Text;
    begin
        if Approval.Status <> Approval.Status::Approved then
            Error(NotApprovedErr, Approval."Entry No.", Approval.Status);
        GetConfig(Approval, TempConfig);
        Drafts.ApplyUseOn(TempConfig, UseOn);
        TempConfig.Modify();
        Result := DesignerMgt.Save(TempConfig, 'apply');
        Approval.Target := CopyStr(DesignerMgt.DescribeTarget(TempConfig), 1, MaxStrLen(Approval.Target));
        Approval.Status := Approval.Status::Active;
        Approval."Activated By" := CopyStr(UserId(), 1, MaxStrLen(Approval."Activated By"));
        Approval."Activated At" := CurrentDateTime();
        Approval.Modify(true);
        exit(StrSubstNo(ActivatedTxt, Approval."Entry No.", Result));
    end;

    /// The design of the request as a configuration (temporary), for a preview or the activation.
    procedure GetConfig(var Approval: Record "Report Style Approval"; var TempConfig: Record "Report Style Config" temporary)
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        InStream: InStream;
        StateText: Text;
    begin
        Approval.CalcFields(State);
        if not Approval.State.HasValue() then
            Error(NoStateErr, Approval."Entry No.");
        Approval.State.CreateInStream(InStream, TextEncoding::UTF8);
        InStream.ReadText(StateText);
        TempConfig.Reset();
        TempConfig.DeleteAll();
        TempConfig.Init();
        TempConfig.Insert();
        DesignerMgt.ApplyState(TempConfig, StateText);
    end;

    local procedure SetDecided(var Approval: Record "Report Style Approval")
    begin
        Approval."Decided By" := CopyStr(UserId(), 1, MaxStrLen(Approval."Decided By"));
        Approval."Decided At" := CurrentDateTime();
    end;
}
