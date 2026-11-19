namespace Abakion.ReportStyleDesigner;

/// Checks the approval flow: a sent design waits, only a waiting design can be approved, only an approved design can
/// be activated, and the stored design comes back as it was sent. Activation itself (Save 'apply') is not run here,
/// so no document assignment is changed. The requests it creates are removed again.
codeunit 50139 "Approval Checks"
{
    var
        Approvals: Codeunit "Report Style Approvals";
        Passed: Integer;

    trigger OnRun()
    var
        Config: Record "Report Style Config" temporary;
        TempBack: Record "Report Style Config" temporary;
        Approval: Record "Report Style Approval";
        LastBefore: Integer;
    begin
        if Approval.FindLast() then
            LastBefore := Approval."Entry No.";

        Config.Init();
        Config."Target Report ID" := 1306;
        Config."Target Layout Name" := 'Approval check layout';
        Config."Theme Mode" := 'custom';
        Config."Theme Name" := 'Approval Check Theme';
        Config."Header Mode" := 'design';
        Config."HF Name" := 'Approval Check Header';
        Config."HF Logo" := 'center';
        Config."Font Pair" := Config."Font Pair"::GeorgiaVerdana;
        Config."Apply To" := 'company';
        Config.Insert();

        Check(Approvals.Submit(Config).Contains('Sent for approval'), 'Submit returns the sent message');
        Approval.FindLast();
        Check(Approval."Entry No." > LastBefore, 'Submit creates a request');
        Check(Approval.Status = Approval.Status::Pending, 'a new request waits for approval');
        Check(Approval."Theme Name" = 'Approval Check Theme', 'the request names the theme');
        Check(Approval."Header/Footer Name" = 'Approval Check Header', 'the request names the header/footer');
        Check(Approval.Target.StartsWith('Company default'), 'the request names the documents');
        Check(Approval."Sent By" = UserId(), 'the request records who sent it');

        Approvals.GetConfig(Approval, TempBack);
        Check(TempBack."HF Logo" = 'center', 'the stored design keeps the logo placement');
        Check(TempBack."Font Pair" = TempBack."Font Pair"::GeorgiaVerdana, 'the stored design keeps the fonts');
        Check(TempBack."Apply To" = 'company', 'the stored design keeps the documents');

        Check(not TryActivate(Approval), 'a waiting request cannot be activated');
        Approvals.Approve(Approval);
        Check(Approval.Status = Approval.Status::Approved, 'Approve sets Approved');
        Check(Approval."Decided By" = UserId(), 'Approve records who approved');
        Check(not TryApprove(Approval), 'an approved request cannot be approved again');
        Approvals.Reject(Approval, 'Logo too large');
        Check(Approval.Status = Approval.Status::Rejected, 'an approved request can still be rejected');
        Check(Approval.Comment = 'Logo too large', 'Reject keeps the reason');
        Check(not TryActivate(Approval), 'a rejected request cannot be activated');

        Approval.SetFilter("Entry No.", '>%1', LastBefore);
        Approval.DeleteAll();
        Message('APPROVAL CHECKS PASSED: %1', Passed);
    end;

    [TryFunction]
    local procedure TryActivate(var Approval: Record "Report Style Approval")
    begin
        Approvals.Activate(Approval, 2);
    end;

    [TryFunction]
    local procedure TryApprove(var Approval: Record "Report Style Approval")
    begin
        Approvals.Approve(Approval);
    end;

    local procedure Check(Condition: Boolean; What: Text)
    begin
        if not Condition then
            Error('Approval check failed: %1', What);
        Passed += 1;
    end;
}