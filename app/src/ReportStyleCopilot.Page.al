namespace Abakion.ReportStyleDesigner;

/// Copilot dialog of the Report Style Designer: describe a look and Copilot proposes 1 to 6 checked themes.
/// The proposals open in the designer as suggestion cards with the first one in the live preview, so the user
/// compares them on the real report; nothing is applied until the user applies it from the designer.
page 50103 "Report Style Copilot"
{
    Caption = 'Draft a report theme with Copilot';
    PageType = PromptDialog;
    Extensible = false;
    IsPreview = true;
    ApplicationArea = All;

    layout
    {
        // Shown as buttons under the prompt, so nobody needs colour codes.
        area(PromptOptions)
        {
            field(ColourChoice; ColourChoice)
            {
                Caption = 'Colours';
                OptionCaption = 'Our brand and logo,Let Copilot choose,Blues,Greens,Warm tones,Neutral greys';
                ToolTip = 'Which colours Copilot builds the themes on. "Our brand and logo" uses the company brand colour and the main colours of the company logo (the logo itself is not sent). Colours you name in the description always win.';
            }
            field(BackgroundChoice; BackgroundChoice)
            {
                Caption = 'Background';
                OptionCaption = 'White,Soft tint of the theme colour,Let Copilot choose';
                ToolTip = 'The page colour behind the report. It prints on every page, so a tint is always kept very light.';
            }
            field(ProposalCountChoice; ProposalCountChoice)
            {
                Caption = 'Number of themes';
                OptionCaption = '1,2,3,4,5,6';
                ToolTip = 'How many themes Copilot suggests. Each one is shown in the designer, where you can preview it on your reports before you apply it.';
            }
        }
        area(Prompt)
        {
            field(UserPrompt; UserPrompt)
            {
                ShowCaption = false;
                MultiLine = true;
                InstructionalText = 'Describe the look you want, for example: calm and modern in soft pink, with easy-to-read tables.';
            }
        }
    }

    actions
    {
        area(PromptGuide)
        {
            action(BrandColours)
            {
                Caption = 'Use our brand colours';
                ToolTip = 'Themes built around the brand colour and the logo.';
                trigger OnAction()
                begin
                    UserPrompt := BrandPromptTxt;
                    ColourChoice := ColourChoice::BrandLogo;
                end;
            }
            action(Formal)
            {
                Caption = 'Formal and classic';
                ToolTip = 'A conservative look for invoices and statements.';
                trigger OnAction()
                begin
                    UserPrompt := FormalPromptTxt;
                end;
            }
            action(CalmModern)
            {
                Caption = 'Calm and modern';
                ToolTip = 'Light, airy and modern.';
                trigger OnAction()
                begin
                    UserPrompt := CalmPromptTxt;
                end;
            }
            action(ReadableTables)
            {
                Caption = 'Easier-to-read tables';
                ToolTip = 'Focus on tables with many lines.';
                trigger OnAction()
                begin
                    UserPrompt := TablesPromptTxt;
                end;
            }
        }
        area(SystemActions)
        {
            systemaction(Generate)
            {
                Caption = 'Generate';
                ToolTip = 'Let Copilot suggest the chosen number of themes and show them in the designer.';
                trigger OnAction()
                begin
                    case BackgroundChoice of
                        BackgroundChoice::White:
                            ReportStyleCopilot.SetBackground(1);
                        BackgroundChoice::ThemeTint:
                            ReportStyleCopilot.SetBackground(2);
                        else
                            ReportStyleCopilot.SetBackground(0);
                    end;
                    ReportStyleCopilot.SetProposalCount(ProposalCountChoice.AsInteger() + 1);
                    ReportStyleCopilot.Generate(UserPrompt, ReportName, ColoursForCopilot(), Proposals);
                    // The designer is the place to compare them: real preview, real swatches.
                    CurrPage.Close();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        ProposalCountChoice := ProposalCountChoice::Three;
    end;

    var
        Proposals: Record "Report Style Proposal";
        ReportStyleCopilot: Codeunit "Report Style Copilot";
        UserPrompt: Text;
        ReportName: Text;
        Colours: Text;
        ColourChoice: Option BrandLogo,CopilotChooses,Blues,Greens,WarmTones,NeutralGreys;
        BackgroundChoice: Option White,ThemeTint,CopilotChooses;
        ProposalCountChoice: Option One,Two,Three,Four,Five,Six;
        BrandPromptTxt: Label 'Use our brand colours and logo colours. Professional and clear.';
        FormalPromptTxt: Label 'Formal and classic, suitable for invoices and statements to customers.';
        CalmPromptTxt: Label 'Calm and modern, light and airy, not too colourful.';
        TablesPromptTxt: Label 'Make tables with many lines easy to read, and keep totals clear.';
        BluesTxt: Label 'blues (navy, steel blue, sky blue)', Locked = true;
        GreensTxt: Label 'greens (forest green, sage, teal)', Locked = true;
        WarmTxt: Label 'warm tones (terracotta, amber, sand)', Locked = true;
        NeutralTxt: Label 'neutral greys (charcoal, slate, stone)', Locked = true;
    /// Context from the designer: the report being styled and the colours read from the logo (JSON array of hex).
    /// The colour field starts with the brand colour and the logo colours; the user can change it freely.
    procedure SetContext(NewReportName: Text; LogoColors: Text)
    var
        BrandHex: Text;
        LogoBase64: Text;
        Colors: JsonArray;
        Color: JsonToken;
    begin
        ReportName := NewReportName;
        Colours := '';
        ReportStyleCopilot.GetCompanyBrand(BrandHex, LogoBase64);
        if BrandHex <> '' then
            AddColour(BrandHex);
        if Colors.ReadFrom(LogoColors) then
            foreach Color in Colors do
                if Color.IsValue() then
                    AddColour(Color.AsValue().AsText());
        if Colours = '' then
            ColourChoice := ColourChoice::CopilotChooses;
    end;

    /// Adds a colour as its plain name, with the exact code after it for Copilot: "navy (#1F3A93)". Not shown to the user.
    local procedure AddColour(Hex: Text)
    var
        Rules: Codeunit "Report Style Theme Rules";
        Normalized: Text;
    begin
        if not Rules.TryNormalizeHex(Hex, Normalized) then
            exit;
        if StrPos(Colours, Normalized) > 0 then
            exit;
        if Colours <> '' then
            Colours += ', ';
        Colours += Rules.ColourName(Normalized) + ' (#' + Normalized + ')';
    end;

    local procedure ColoursForCopilot(): Text
    begin
        case ColourChoice of
            ColourChoice::BrandLogo:
                exit(Colours);
            ColourChoice::CopilotChooses:
                exit('');
            ColourChoice::Blues:
                exit(BluesTxt);
            ColourChoice::Greens:
                exit(GreensTxt);
            ColourChoice::WarmTones:
                exit(WarmTxt);
            ColourChoice::NeutralGreys:
                exit(NeutralTxt);
        end;
    end;

    /// The proposals, best match first; empty if the user closed the dialog without generating.
    procedure GetProposals(var Proposal: Record "Report Style Proposal"): Boolean
    begin
        Proposal.Copy(Proposals, true);
        exit(Proposal.FindFirst());
    end;
}
