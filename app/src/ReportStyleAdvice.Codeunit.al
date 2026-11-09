namespace Abakion.ReportStyleDesigner;

using System.Text;

/// Soft recommendations for a report style: they explain a likely problem and never block a choice.
/// Only the saved settings are read, so the rules run without a preview or Copilot.
codeunit 50132 "Report Style Advice"
{
    Access = Internal;

    var
        NoAdviceTxt: Label 'No recommendations for this style.';
        LogoAndFooterOffTxt: Label 'The header and footer show neither a logo nor contact details. Show at least one of them so the reports can be recognised.';
        AccentOnColouredPageTxt: Label 'An accent line on a coloured page can be hard to see when printed. A white page is safer for printing.';
        PageNumberInFooterOffTxt: Label 'The page number is in the footer, but the footer is turned off. Choose a footer, or move the page number to the header.';
        FontCautionTxt: Label '%1 has only been checked in some PDF tests. Look at the preview and check the printed result before you apply it.', Comment = '%1 = font pair name';

    /// The recommendations as a list of sentences, in the order the rules are checked.
    procedure GetAdvice(Config: Record "Report Style Config"; var Advice: List of [Text])
    begin
        Clear(Advice);
        if (Config."HF Logo" = 'none') and (Config."HF Footer" = 'none') then
            Advice.Add(LogoAndFooterOffTxt);
        if Config."HF Accent Line" and (Config."Page Color" <> Config."Page Color"::White) and (Config."Page Color" <> Config."Page Color"::KeepBase) then
            Advice.Add(AccentOnColouredPageTxt);
        if (Config."HF Page Number" = 'footer') and (Config."HF Footer" = 'none') then
            Advice.Add(PageNumberInFooterOffTxt);
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
}
