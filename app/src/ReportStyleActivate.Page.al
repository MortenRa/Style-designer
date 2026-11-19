namespace Abakion.ReportStyleDesigner;

/// Asked when an approved design is activated: which documents get it. The designer only made the design; where it
/// is used is the approver's decision. Prefilled with the document it was designed on.
page 50113 "Report Style Activate"
{
    Caption = 'Activate design';
    PageType = StandardDialog;
    ApplicationArea = All;
    AboutTitle = 'Choose where the design goes live';
    AboutText = 'Put the design on the document it was made for, on all documents of its group, or make it the company default. From then on, customers receive documents with this look.';

    layout
    {
        area(Content)
        {
            group(Design)
            {
                Caption = 'Design';

                field(ThemeField; ThemeName)
                {
                    ApplicationArea = All;
                    Caption = 'Theme';
                    Editable = false;
                    ToolTip = 'The theme in the request, or Unchanged when the request has no theme.';
                }
                field(HeaderFooterField; HeaderFooterName)
                {
                    ApplicationArea = All;
                    Caption = 'Header/footer';
                    Editable = false;
                    ToolTip = 'The header and footer in the request, or Unchanged when the request has none.';
                }
                field(DesignedOnField; DesignedOn)
                {
                    ApplicationArea = All;
                    Caption = 'Designed on';
                    Editable = false;
                    ToolTip = 'The document the designer made the design on.';
                }
            }
            group(Documents)
            {
                Caption = 'Documents';
                InstructionalText = 'Customers receive the new look on these documents as soon as you choose OK.';

                field(UseOnField; UseOn)
                {
                    ApplicationArea = All;
                    Caption = 'Use on';
                    OptionCaption = 'The document it was designed on,All documents in its group,Company default';
                    ToolTip = 'Which documents get the design: the document it was designed on, every document of its group (customer, vendor or internal), or the company default for all documents.';
                }
            }
        }
    }

    var
        ThemeName: Text;
        HeaderFooterName: Text;
        DesignedOn: Text;
        UseOn: Option ThisDocument,Group,Company;
        UnchangedTxt: Label 'Unchanged';

    internal procedure SetApproval(Approval: Record "Report Style Approval")
    begin
        ThemeName := Approval."Theme Name";
        if ThemeName = '' then
            ThemeName := UnchangedTxt;
        HeaderFooterName := Approval."Header/Footer Name";
        if HeaderFooterName = '' then
            HeaderFooterName := UnchangedTxt;
        DesignedOn := Approval.Target;
        UseOn := UseOn::ThisDocument;
    end;

    procedure GetUseOn(): Integer
    begin
        exit(UseOn);
    end;
}
