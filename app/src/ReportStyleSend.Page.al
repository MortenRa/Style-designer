namespace Abakion.ReportStyleDesigner;

/// Asked when a design is sent for approval: what to send (the theme, the header and footer, or both) and the names
/// they are saved under. Which documents get them is chosen by the approver when the request is activated.
page 50111 "Report Style Send"
{
    Caption = 'Send for approval';
    PageType = StandardDialog;
    ApplicationArea = All;
    AboutTitle = 'Send your design for approval';
    AboutText = 'Choose what to send and give it a name. An administrator approves it and decides which documents get it. Nothing changes for your customers until then.';

    layout
    {
        area(Content)
        {
            group(ThemeGroup)
            {
                Caption = 'Theme';
                InstructionalText = 'Colours, fonts and table styles.';

                field(SendThemeField; SendThemeChoice)
                {
                    ApplicationArea = All;
                    Caption = 'Send the theme';
                    AboutTitle = 'Send only what you want approved';
                    AboutText = 'You can send the theme and the header/footer together, or one of them now and the other later. What you leave out stays as the documents have it today.';
                    Editable = ThemeChanged;
                    ToolTip = 'Include the theme in this request. Only possible when you changed the theme.';
                }
                field(ThemeNameField; ThemeName)
                {
                    ApplicationArea = All;
                    Caption = 'Theme name';
                    Editable = ThemeIsNew and SendThemeChoice;
                    ToolTip = 'The name the new theme is saved under. Approvers see it on the Theme Approvals page. Not editable when you chose an existing theme or the default.';
                    ShowMandatory = ThemeIsNew and SendThemeChoice;
                }
            }
            group(HeaderFooterGroup)
            {
                Caption = 'Header and footer';
                InstructionalText = 'Logo, page number, and the details in the footer.';

                field(SendHeaderFooterField; SendHeaderFooterChoice)
                {
                    ApplicationArea = All;
                    Caption = 'Send the header and footer';
                    Editable = HeaderFooterChanged;
                    ToolTip = 'Include the header and footer in this request. Only possible when you changed them.';
                }
                field(HeaderFooterNameField; HeaderFooterName)
                {
                    ApplicationArea = All;
                    Caption = 'Header/footer name';
                    Editable = HeaderFooterIsNew and SendHeaderFooterChoice;
                    ToolTip = 'The name the new header and footer are saved under. Approvers see it on the Theme Approvals page. Not editable when you chose an existing design or the default.';
                    ShowMandatory = HeaderFooterIsNew and SendHeaderFooterChoice;
                }
            }
        }
    }

    var
        ThemeName: Text[250];
        HeaderFooterName: Text[250];
        SendThemeChoice: Boolean;
        SendHeaderFooterChoice: Boolean;
        ThemeChanged: Boolean;
        ThemeIsNew: Boolean;
        HeaderFooterChanged: Boolean;
        HeaderFooterIsNew: Boolean;
        NothingErr: Label 'Choose the theme, the header and footer, or both.';
        NoThemeNameErr: Label 'Give the theme a name.';
        NoHeaderFooterNameErr: Label 'Give the header and footer a name.';

    /// Fills the dialog from the design: what changed is selected, with the names last used.
    internal procedure SetConfig(Config: Record "Report Style Config")
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Drafts: Codeunit "Report Style Drafts";
    begin
        ThemeChanged := DesignerMgt.ThemeModeOf(Config) <> 'keep';
        ThemeIsNew := DesignerMgt.ThemeModeOf(Config) = 'custom';
        HeaderFooterChanged := DesignerMgt.HeaderModeOf(Config) <> 'keep';
        HeaderFooterIsNew := DesignerMgt.HeaderModeOf(Config) = 'design';
        SendThemeChoice := ThemeChanged;
        SendHeaderFooterChoice := HeaderFooterChanged;
        ThemeName := CopyStr(Drafts.ThemeCaption(Config), 1, MaxStrLen(ThemeName));
        HeaderFooterName := CopyStr(Drafts.HeaderFooterCaption(Config), 1, MaxStrLen(HeaderFooterName));
    end;

    /// Writes the names back to the design. Only names of new parts are kept; chosen parts keep their own names.
    internal procedure GetNames(var Config: Record "Report Style Config")
    begin
        if ThemeIsNew then
            Config."Theme Name" := ThemeName;
        if HeaderFooterIsNew then
            Config."HF Name" := HeaderFooterName;
    end;

    procedure SendTheme(): Boolean
    begin
        exit(SendThemeChoice);
    end;

    procedure SendHeaderFooter(): Boolean
    begin
        exit(SendHeaderFooterChoice);
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if CloseAction <> Action::OK then
            exit(true);
        if not (SendThemeChoice or SendHeaderFooterChoice) then
            Error(NothingErr);
        if ThemeIsNew and SendThemeChoice and (ThemeName.Trim() = '') then
            Error(NoThemeNameErr);
        if HeaderFooterIsNew and SendHeaderFooterChoice and (HeaderFooterName.Trim() = '') then
            Error(NoHeaderFooterNameErr);
        exit(true);
    end;
}
