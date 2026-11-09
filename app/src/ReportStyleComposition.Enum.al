namespace Abakion.ReportStyleDesigner;

/// Draft compositions for the start page: each sets the header/footer design fields in one step.
/// The five archetypes are not defined in the repo yet; these are placeholders to review with the design team.
enum 50105 "Report Style Composition"
{
    Extensible = false;

    value(0; Standard) { Caption = 'Standard - logo right and page number in header'; }
    value(1; LogoLeft) { Caption = 'Logo left and accent line under header'; }
    value(2; BankFooter) { Caption = 'Logo right and page number in footer with bank details'; }
    value(3; NoDate) { Caption = 'Logo right and no date'; }
    value(4; Minimal) { Caption = 'Minimal - no footer and accent line'; }
}
