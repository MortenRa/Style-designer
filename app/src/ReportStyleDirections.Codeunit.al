namespace Abakion.ReportStyleDesigner;

/// The five design directions. A direction sets the colours, fonts, page, tables and header/footer together,
/// so the user starts from a finished look and changes details afterwards.
/// Only options the Word platform can deliver are used: the checked font pairs and the generator's header/footer parts.
/// A logo placement the user has picked is kept.
codeunit 50134 "Report Style Directions"
{
    Access = Internal;

    var
        NotChosenTxt: Label 'Choose a direction to set the look and the header and footer in one step. You can change every detail afterwards.';
        ClassicTxt: Label 'Calm and familiar. Cambria headings, grey tones, logo on the right and contact details in the footer. Fits most companies.';
        ModernTxt: Label 'Clean and light. Segoe UI, blue tones, logo on the left and a coloured line under the header. Tables with thin accent lines.';
        FormalTxt: Label 'Serious and traditional. Georgia headings on warm paper, the logo centred above the title, bank details and page number in the footer. For finance, law and consulting.';
        FriendlyTxt: Label 'Warm and open. Warm colours, banded tables, logo on the left and a coloured line under the header. For retail, crafts and hospitality.';
        MinimalTxt: Label 'As little as possible. Grey tones, no footer and no lines. The content speaks for itself.';

    /// Sets every choice of the direction on the configuration. Not chosen leaves the configuration as it is.
    procedure Apply(var Config: Record "Report Style Config")
    var
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
    begin
        if Config.Direction = Config.Direction::NotChosen then
            exit;

        DesignerMgt.UseNeutralBase(Config);
        Config."Theme Mode" := 'custom';
        Config."Header Mode" := 'design';
        Config."HF Later Pages" := 'minimal';
        Config."HF Show Date" := true;
        Config."Base Font Size" := 0;

        case Config.Direction of
            Config.Direction::Classic:
                begin
                    SetLook(Config, Config."Font Pair"::CambriaCalibri, Config.Palette::Graphite, Config."Page Color"::White, Config."Table Style"::Minimal);
                    SetHeaderFooter(Config, 'right', 'header', 'contact', false);
                end;
            Config.Direction::Modern:
                begin
                    SetLook(Config, Config."Font Pair"::SegoeUI, Config.Palette::Ocean, Config."Page Color"::White, Config."Table Style"::AccentLines);
                    SetHeaderFooter(Config, 'left', 'header', 'contact', true);
                end;
            Config.Direction::Formal:
                begin
                    SetLook(Config, Config."Font Pair"::GeorgiaVerdana, Config.Palette::Graphite, Config."Page Color"::WarmPaper, Config."Table Style"::Minimal);
                    SetHeaderFooter(Config, 'center', 'footer', 'bank', false);
                end;
            Config.Direction::Friendly:
                begin
                    SetLook(Config, Config."Font Pair"::SegoeUI, Config.Palette::Sunset, Config."Page Color"::White, Config."Table Style"::Banded);
                    SetHeaderFooter(Config, 'left', 'header', 'contact', true);
                end;
            Config.Direction::Minimal:
                begin
                    SetLook(Config, Config."Font Pair"::SegoeUI, Config.Palette::Graphite, Config."Page Color"::White, Config."Table Style"::Minimal);
                    SetHeaderFooter(Config, 'right', 'header', 'none', false);
                end;
        end;
    end;

    /// One or two sentences that tell a non-designer what the direction looks like.
    procedure Describe(Direction: Enum "Report Style Direction"): Text
    begin
        case Direction of
            Direction::Classic:
                exit(ClassicTxt);
            Direction::Modern:
                exit(ModernTxt);
            Direction::Formal:
                exit(FormalTxt);
            Direction::Friendly:
                exit(FriendlyTxt);
            Direction::Minimal:
                exit(MinimalTxt);
        end;
        exit(NotChosenTxt);
    end;

    local procedure SetLook(var Config: Record "Report Style Config"; FontPair: Enum "Report Style Font Pair"; Palette: Enum "Report Style Palette"; PageColor: Enum "Report Style Page Color"; TableStyle: Enum "Report Theme Table Style")
    begin
        Config."Font Pair" := FontPair;
        Config.Palette := Palette;
        Config."Page Color" := PageColor;
        Config."Table Style" := TableStyle;
    end;

    local procedure SetHeaderFooter(var Config: Record "Report Style Config"; Logo: Text[10]; PageNumber: Text[10]; Footer: Text[10]; AccentLine: Boolean)
    begin
        // The logo placement the user picked wins over the direction's own.
        if not Config."Logo Chosen" then
            Config."HF Logo" := Logo;
        Config."HF Page Number" := PageNumber;
        Config."HF Footer" := Footer;
        Config."HF Accent Line" := AccentLine;
    end;
}
