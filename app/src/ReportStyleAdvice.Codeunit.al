namespace Abakion.ReportStyleDesigner;

using System.Text;
using System.Utilities;

/// Soft recommendations for a report style: they explain a likely problem and never block a choice.
/// The saved settings are read, plus the size of the company logo; no preview or Copilot is needed.
codeunit 50132 "Report Style Advice"
{
    Access = Internal;

    var
        LogoWidth: Integer;
        LogoHeight: Integer;
        LogoSizeKnown: Boolean;
        NoAdviceTxt: Label 'No recommendations for this style.';
        LogoAndFooterOffTxt: Label 'The header and footer show neither a logo nor contact details. Show at least one of them so the reports can be recognised.';
        AccentOnColouredPageTxt: Label 'An accent line on a coloured page can be hard to see when printed. A white page is safer for printing.';
        PageNumberInFooterOffTxt: Label 'The page number is in the footer, but the footer is turned off. Choose a footer, or move the page number to the header.';
        FontCautionTxt: Label '%1 has only been checked in some PDF tests. Look at the preview and check the printed result before you apply it.', Comment = '%1 = font pair name';
        WideLogoTxt: Label 'Your logo is very wide (about %1 times as wide as it is high). Centred on its own line above the title usually works better than at the side.', Comment = '%1 = width divided by height, rounded';
        SmallLogoTxt: Label 'Your logo picture is only %1 × %2 pixels, so it can look blurred when printed. Upload a larger version, at least %3 pixels wide.', Comment = '%1 = width, %2 = height, %3 = recommended width';
        BandsOnColouredPageTxt: Label 'Striped table rows on a coloured page can be hard to tell apart when printed. Use a white page or another table style.';
        SmallTextTxt: Label 'Text smaller than %1 pt is hard to read on paper.', Comment = '%1 = smallest recommended size';
        LargeTextTxt: Label 'Text larger than %1 pt makes the documents longer, and wide tables may no longer fit on the page.', Comment = '%1 = largest recommended size';

    /// The logo size in pixels, instead of reading the company logo. Used by the checks.
    procedure SetLogoSize(Width: Integer; Height: Integer)
    begin
        LogoWidth := Width;
        LogoHeight := Height;
        LogoSizeKnown := true;
    end;

    /// The recommendations as a list of sentences, in the order the rules are checked.
    procedure GetAdvice(Config: Record "Report Style Config"; var Advice: List of [Text])
    begin
        Clear(Advice);
        if not LogoSizeKnown then
            ReadCompanyLogoSize();

        // Header and footer
        if (Config."HF Logo" = 'none') and (Config."HF Footer" = 'none') then
            Advice.Add(LogoAndFooterOffTxt);
        if (Config."HF Page Number" = 'footer') and (Config."HF Footer" = 'none') then
            Advice.Add(PageNumberInFooterOffTxt);

        // Logo
        if (LogoWidth > 0) and (LogoHeight > 0) and (Config."HF Logo" <> 'none') then begin
            if (Config."HF Logo" in ['', 'left', 'right']) and (LogoWidth >= 3 * LogoHeight) then
                Advice.Add(StrSubstNo(WideLogoTxt, Round(LogoWidth / LogoHeight, 1)));
            if LogoWidth < MinLogoWidth() then
                Advice.Add(StrSubstNo(SmallLogoTxt, LogoWidth, LogoHeight, MinLogoWidth() * 2));
        end;

        // Theme and body: how the page, tables and text work together on paper
        if Config."HF Accent Line" and IsColouredPage(Config) then
            Advice.Add(AccentOnColouredPageTxt);
        if (Config."Table Style" = Config."Table Style"::Banded) and IsColouredPage(Config) then
            Advice.Add(BandsOnColouredPageTxt);
        if (Config."Base Font Size" > 0) and (Config."Base Font Size" < MinFontSize()) then
            Advice.Add(StrSubstNo(SmallTextTxt, MinFontSize()));
        if Config."Base Font Size" > MaxFontSize() then
            Advice.Add(StrSubstNo(LargeTextTxt, MaxFontSize()));
        if Config."Font Pair" in [Config."Font Pair"::Sitka, Config."Font Pair"::Bahnschrift] then
            Advice.Add(StrSubstNo(FontCautionTxt, Format(Config."Font Pair")));
    end;

    /// The recommendations as one bulleted text for the page; a short message when there are none.
    procedure GetAdviceText(Config: Record "Report Style Config"): Text
    var
        Advice: List of [Text];
        Line: Text;
        Lines: TextBuilder;
    begin
        GetAdvice(Config, Advice);
        if Advice.Count() = 0 then
            exit(NoAdviceTxt);
        foreach Line in Advice do
            Lines.AppendLine('- ' + Line);
        exit(Lines.ToText().TrimEnd());
    end;

    /// The recommendations as a JSON array of sentences, for the designer.
    procedure GetAdviceJson(Config: Record "Report Style Config") Json: Text
    var
        Advice: List of [Text];
        Items: JsonArray;
        Line: Text;
    begin
        GetAdvice(Config, Advice);
        foreach Line in Advice do
            Items.Add(Line);
        Items.WriteTo(Json);
    end;

    local procedure IsColouredPage(Config: Record "Report Style Config"): Boolean
    begin
        exit(not (Config."Page Color" in [Config."Page Color"::White, Config."Page Color"::KeepBase]));
    end;

    local procedure ReadCompanyLogoSize()
    var
        Copilot: Codeunit "Report Style Copilot";
        BrandHex: Text;
        LogoBase64: Text;
    begin
        LogoSizeKnown := true;
        LogoWidth := 0;
        LogoHeight := 0;
        Copilot.GetCompanyBrand(BrandHex, LogoBase64);
        if LogoBase64 <> '' then
            if not TryReadSize(LogoBase64) then begin
                LogoWidth := 0;
                LogoHeight := 0;
            end;
    end;

    [TryFunction]
    local procedure TryReadSize(LogoBase64: Text)
    var
        Picture: Codeunit Image;
    begin
        Picture.FromBase64(LogoBase64);
        LogoWidth := Picture.GetWidth();
        LogoHeight := Picture.GetHeight();
    end;

    local procedure MinLogoWidth(): Integer
    begin
        exit(300);
    end;

    local procedure MinFontSize(): Decimal
    begin
        exit(8);
    end;

    local procedure MaxFontSize(): Decimal
    begin
        exit(12);
    end;
}
