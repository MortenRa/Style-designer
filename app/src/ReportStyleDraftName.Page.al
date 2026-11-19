namespace Abakion.ReportStyleDesigner;

/// Asks for the name of a draft. A draft with a name you used before is updated.
page 50112 "Report Style Draft Name"
{
    Caption = 'Save as draft';
    PageType = StandardDialog;
    ApplicationArea = All;
    AboutTitle = 'Save your work for later';
    AboutText = 'A draft keeps all your choices: logo, theme, and header and footer. Nothing is sent or changed for anyone. Open it again from My drafts to continue, or send it for approval from there.';

    layout
    {
        area(Content)
        {
            field(DraftNameField; DraftName)
            {
                ApplicationArea = All;
                Caption = 'Draft name';
                ShowMandatory = true;
                ToolTip = 'A name you recognise later, for example the customer or the idea. Using a name you used before updates that draft.';
            }
        }
    }

    var
        DraftName: Text[100];
        NoNameErr: Label 'Give the draft a name.';

    procedure SetName(NewName: Text)
    begin
        DraftName := CopyStr(NewName, 1, MaxStrLen(DraftName));
    end;

    procedure GetName(): Text[100]
    begin
        exit(DraftName);
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if (CloseAction = Action::OK) and (DraftName.Trim() = '') then
            Error(NoNameErr);
        exit(true);
    end;
}
