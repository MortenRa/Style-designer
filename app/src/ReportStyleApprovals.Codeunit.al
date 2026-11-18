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
        NoStateErr: Label 'Request %1 has no design stored.', Comment = '%1 = request number';

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
    procedure Activate(var Approval: Record "Report Style Approval"): Text
    var
        TempConfig: Record "Report Style Config" temporary;
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Result: Text;
    begin
        if Approval.Status <> Approval.Status::Approved then
            Error(NotApprovedErr, Approval."Entry No.", Approval.Status);
        GetConfig(Approval, TempConfig);
        Result := DesignerMgt.Save(TempConfig, 'apply');
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
