namespace Abakion.ReportStyleDesigner;

using System.Utilities;

/// Shows the recommendations for the saved configuration with the real company logo, for a quick look.
codeunit 50137 "Advice Probe"
{
    trigger OnRun()
    var
        Config: Record "Report Style Config";
        Advice: Codeunit "Report Style Advice";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Copilot: Codeunit "Report Style Copilot";
        Picture: Codeunit Image;
        BrandHex: Text;
        LogoBase64: Text;
    begin
        Copilot.GetCompanyBrand(BrandHex, LogoBase64);
        if LogoBase64 <> '' then
            Picture.FromBase64(LogoBase64);
        DesignerMgt.GetConfig(Config);
        Config."HF Logo" := 'right';
        Message('LOGO %1 x %2 | ADVICE (logo right): %3', Picture.GetWidth(), Picture.GetHeight(), Advice.GetAdviceText(Config));
    end;
}