namespace Abakion.ReportStyleDesigner;

using System.Utilities;

/// Designs sent for approval. An approver looks at the preview, approves or rejects, and activates an approved
/// design, which assigns it to its documents. Approving and activating need the "Theme Designer - Approve"
/// permission set.
page 50106 "Report Style Approvals"
{
    Caption = 'Theme Approvals';
    AboutTitle = 'Approve new looks before customers see them';
    AboutText = 'Designers send their designs here. Preview a request, approve or reject it, and activate it when it should go live. Only Activate changes the documents your customers receive.';
    PageType = List;
    SourceTable = "Report Style Approval";
    SourceTableView = sorting("Entry No.") order(descending);
    UsageCategory = Lists;
    ApplicationArea = All;
    AdditionalSearchTerms = 'theme designer, report style, approve design, activate theme';
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Requests)
            {
                Editable = false;
                field("Entry No."; Rec."Entry No.") { ToolTip = 'The number of the request.'; }
                field(Status; Rec.Status)
                {
                    StyleExpr = StatusStyle;
                    ToolTip = 'Waiting for approval, approved, rejected, or active on the documents.';
                }
                field(Target; Rec.Target) { ToolTip = 'Before activation: the document the design was made on. After activation: the documents that got it.'; }
                field(Change; Rec.Change) { ToolTip = 'What the design changes: the theme, the header and footer, or both.'; }
                field("Theme Name"; Rec."Theme Name") { ToolTip = 'The theme that is saved with the request.'; }
                field("Header/Footer Name"; Rec."Header/Footer Name") { ToolTip = 'The header and footer that are saved with the request.'; }
                field("Sent By"; Rec."Sent By") { ToolTip = 'Who sent the design for approval.'; }
                field("Sent At"; Rec."Sent At") { ToolTip = 'When the design was sent for approval.'; }
                field("Decided By"; Rec."Decided By") { ToolTip = 'Who approved or rejected the design.'; }
                field("Decided At"; Rec."Decided At") { ToolTip = 'When the design was approved or rejected.'; }
                field("Activated By"; Rec."Activated By") { ToolTip = 'Who activated the design on the documents.'; }
                field("Activated At"; Rec."Activated At") { ToolTip = 'When the design was activated.'; }
                field(Comment; Rec.Comment) { ToolTip = 'Why the design was rejected, or a note for the designer.'; }
            }
        }
    }

    actions
    {
        area(Promoted)
        {
            actionref(Preview_Promoted; PreviewAction) { }
            actionref(Approve_Promoted; ApproveAction) { }
            actionref(Reject_Promoted; RejectAction) { }
            actionref(Activate_Promoted; ActivateAction) { }
        }
        area(Processing)
        {
            action(PreviewAction)
            {
                ApplicationArea = All;
                Caption = 'Preview';
                ToolTip = 'Download page 1 of the document with this design, as it will look when it is activated.';
                Image = View;

                trigger OnAction()
                begin
                    DownloadPreview();
                end;
            }
            action(ApproveAction)
            {
                ApplicationArea = All;
                Caption = 'Approve';
                ToolTip = 'Approve the design. It is not used on any document until it is activated.';
                Image = Approve;
                Enabled = Rec.Status = Rec.Status::Pending;

                trigger OnAction()
                var
                    Approvals: Codeunit "Report Style Approvals";
                begin
                    if Rec."Sent By" = UserId() then
                        if not Confirm(OwnRequestQst, false) then
                            exit;
                    Approvals.Approve(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(RejectAction)
            {
                ApplicationArea = All;
                Caption = 'Reject';
                AboutTitle = 'Say why';
                AboutText = 'Write the reason in Comment before you reject. The designer sees it on Quick Start and knows what to change.';
                ToolTip = 'Reject the design. Write the reason in Comment first, so the designer knows what to change.';
                Image = Reject;
                Enabled = (Rec.Status = Rec.Status::Pending) or (Rec.Status = Rec.Status::Approved);

                trigger OnAction()
                var
                    Approvals: Codeunit "Report Style Approvals";
                begin
                    Approvals.Reject(Rec, Rec.Comment);
                    CurrPage.Update(false);
                end;
            }
            action(ActivateAction)
            {
                ApplicationArea = All;
                Caption = 'Activate';
                AboutTitle = 'Activate is when it goes live';
                AboutText = 'Approving only says yes. Activate is where you choose the documents (the one it was designed on, its group, or the company default) and when customers start receiving the new look.';
                ToolTip = 'Choose which documents get the approved design and put it live. From then on, customers receive those documents with this look.';
                Image = Start;
                Enabled = Rec.Status = Rec.Status::Approved;

                trigger OnAction()
                var
                    Approvals: Codeunit "Report Style Approvals";
                    ActivateDialog: Page "Report Style Activate";
                begin
                    ActivateDialog.SetApproval(Rec);
                    if ActivateDialog.RunModal() <> Action::OK then
                        exit;
                    Message(Approvals.Activate(Rec, ActivateDialog.GetUseOn()));
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        StatusStyle: Text;
        OwnRequestQst: Label 'You sent this design yourself. Approve it anyway?';
        PreviewFileTxt: Label 'Theme approval %1.pdf', Comment = '%1 = request number';

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Pending:
                StatusStyle := 'Ambiguous';
            Rec.Status::Approved:
                StatusStyle := 'Favorable';
            Rec.Status::Rejected:
                StatusStyle := 'Unfavorable';
            Rec.Status::Active:
                StatusStyle := 'Strong';
        end;
    end;

    local procedure DownloadPreview()
    var
        TempConfig: Record "Report Style Config" temporary;
        Approvals: Codeunit "Report Style Approvals";
        Runner: Codeunit "Report Style Designer Runner";
        Pdf: Codeunit "Temp Blob";
        PdfStream: InStream;
        FileName: Text;
    begin
        Approvals.GetConfig(Rec, TempConfig);
        // A group or the company default has no single document: the preview uses the document saved with the design.
        Commit();
        if not Runner.Preview(TempConfig) then
            Error(Runner.GetErrorText());
        Runner.GetPdf(Pdf);
        Pdf.CreateInStream(PdfStream);
        FileName := StrSubstNo(PreviewFileTxt, Rec."Entry No.");
        DownloadFromStream(PdfStream, '', '', '', FileName);
    end;
}
