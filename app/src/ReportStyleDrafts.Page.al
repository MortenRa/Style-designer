namespace Abakion.ReportStyleDesigner;

/// Designs saved to continue later. Open one to keep working on it, or send it for approval as it is.
page 50110 "Report Style Drafts"
{
    Caption = 'My Theme Drafts';
    PageType = List;
    SourceTable = "Report Style Draft";
    SourceTableView = sorting("Entry No.") order(descending);
    // Not in search: it opens from Quick Start (My drafts).
    ApplicationArea = All;
    InsertAllowed = false;
    ModifyAllowed = false;
    AboutTitle = 'Your saved drafts';
    AboutText = 'Drafts are designs you saved to continue later. Nothing in a draft reaches your customers. Open a draft to keep working on it, or send it for approval.';

    layout
    {
        area(Content)
        {
            repeater(Drafts)
            {
                field(Name; Rec.Name) { ToolTip = 'The name you gave the draft.'; }
                field(Document; Rec.Document) { ToolTip = 'The document the draft was designed on.'; }
                field(Change; Rec.Change) { ToolTip = 'What the draft changes: the theme, the header and footer, or both.'; }
                field("Theme Name"; Rec."Theme Name") { ToolTip = 'The theme in the draft: a new theme''s name, Default, or Unchanged.'; }
                field("Header/Footer Name"; Rec."Header/Footer Name") { ToolTip = 'The header and footer in the draft: a new design''s name, a chosen design, Default, or Unchanged.'; }
                field("Saved By"; Rec."Saved By") { ToolTip = 'Who saved the draft.'; }
                field("Saved At"; Rec."Saved At") { ToolTip = 'When the draft was last saved.'; }
            }
        }
    }

    actions
    {
        area(Promoted)
        {
            actionref(Open_Promoted; OpenAction) { }
            actionref(Send_Promoted; SendAction) { }
        }
        area(Processing)
        {
            action(OpenAction)
            {
                ApplicationArea = All;
                Caption = 'Open';
                AboutTitle = 'Continue where you left off';
                AboutText = 'Open puts the draft in Quick Start, with the preview, so you can change it further.';
                ToolTip = 'Continue working on the draft in Quick Start. Your current choices there are replaced by the draft''s; save them as a draft first if you want to keep them.';
                Image = Edit;
                Scope = Repeater;

                trigger OnAction()
                var
                    Drafts: Codeunit "Report Style Drafts";
                begin
                    if not Confirm(OpenQst, true, Rec.Name) then
                        exit;
                    Drafts.OpenDraft(Rec);
                end;
            }
            action(SendAction)
            {
                ApplicationArea = All;
                Caption = 'Send for approval';
                ToolTip = 'Send the draft for approval as it is. You choose what to send, the names and the documents. The draft is removed when it is sent.';
                Image = SendApprovalRequest;
                Scope = Repeater;

                trigger OnAction()
                var
                    Drafts: Codeunit "Report Style Drafts";
                begin
                    if Drafts.SendDraft(Rec) then
                        CurrPage.Update(false);
                end;
            }
        }
    }

    var
        OpenQst: Label 'Open "%1" in Quick Start? Your current choices there are replaced.', Comment = '%1 = draft name';
}
