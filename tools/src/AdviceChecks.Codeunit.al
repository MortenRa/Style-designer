namespace Abakion.ReportStyleDesigner;

/// Checks the soft recommendations: each rule fires for its own setting and stays quiet for a clean style.
codeunit 50133 "Advice Checks"
{
    var
        Advice: Codeunit "Report Style Advice";
        Passed: Integer;

    trigger OnRun()
    var
        Config: Record "Report Style Config";
        Items: List of [Text];
    begin
        // A normal logo: wide enough to print well, not so wide that it belongs in the centre.
        Advice.SetLogoSize(800, 300);
        Config.Init();
        Config."HF Logo" := 'right';
        Config."HF Footer" := 'contact';
        Config."HF Page Number" := 'header';
        Config."HF Accent Line" := false;
        Config."Page Color" := Config."Page Color"::White;
        Config."Font Pair" := Config."Font Pair"::SegoeUI;

        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 0, 'a clean style gives no recommendations');
        Check(Advice.GetAdviceText(Config) = 'No recommendations for this style.', 'the clean style gives the short message');

        Config."HF Logo" := 'none';
        Config."HF Footer" := 'none';
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 1, 'no logo and no footer gives one recommendation');
        Config."HF Logo" := 'right';
        Config."HF Footer" := 'contact';

        Config."HF Accent Line" := true;
        Config."Page Color" := Config."Page Color"::WarmPaper;
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 1, 'an accent line on a warm page gives one recommendation');
        Config."Page Color" := Config."Page Color"::White;
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 0, 'an accent line on a white page is fine');
        Config."HF Accent Line" := false;

        Config."HF Page Number" := 'footer';
        Config."HF Footer" := 'none';
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 1, 'page number in a turned-off footer gives one recommendation');
        Config."HF Page Number" := 'header';
        Config."HF Footer" := 'contact';

        Config."Font Pair" := Config."Font Pair"::Sitka;
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 1, 'Sitka gives the font caution');
        Config."Font Pair" := Config."Font Pair"::SegoeUI;

        // Wide logo: a recommendation at the side, none when centred or hidden.
        Advice.SetLogoSize(1200, 300);
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 1, 'a 4:1 logo on the right gives one recommendation');
        Check(Items.Get(1).Contains('about 4 times'), 'the wide-logo text names the ratio');
        Config."HF Logo" := 'left';
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 1, 'a 4:1 logo on the left gives one recommendation');
        Config."HF Logo" := 'center';
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 0, 'a 4:1 logo in the centre is fine');
        Config."HF Logo" := 'right';
        Advice.SetLogoSize(800, 300);

        // Small logo picture.
        Advice.SetLogoSize(150, 60);
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 1, 'a 150 px logo gives one recommendation');
        Check(Items.Get(1).Contains('150 × 60'), 'the small-logo text names the size');
        Config."HF Logo" := 'none';
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 0, 'no recommendation about the logo when it is not shown');
        Config."HF Logo" := 'right';
        Advice.SetLogoSize(800, 300);

        // No logo in Company Information: no logo rules.
        Advice.SetLogoSize(0, 0);
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 0, 'an unknown logo size gives no logo recommendation');
        Advice.SetLogoSize(800, 300);

        // Striped tables on a coloured page.
        Config."Table Style" := Config."Table Style"::Banded;
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 0, 'striped tables on a white page are fine');
        Config."Page Color" := Config."Page Color"::SoftBlue;
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 1, 'striped tables on a coloured page give one recommendation');
        Config."Page Color" := Config."Page Color"::White;
        Config."Table Style" := Config."Table Style"::Minimal;

        // Text size.
        Config."Base Font Size" := 7;
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 1, '7 pt gives one recommendation');
        Config."Base Font Size" := 10;
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 0, '10 pt is fine');
        Config."Base Font Size" := 14;
        Advice.GetAdvice(Config, Items);
        Check(Items.Count() = 1, '14 pt gives one recommendation');
        Config."Base Font Size" := 0;

        // The designer gets the same sentences as JSON.
        Config."HF Logo" := 'none';
        Config."HF Footer" := 'none';
        Check(Advice.GetAdviceJson(Config).StartsWith('["The header and footer show neither'), 'the JSON holds the sentences');

        Message('ADVICE CHECKS PASSED: %1', Passed);
    end;

    local procedure Check(Condition: Boolean; What: Text)
    begin
        if not Condition then
            Error('Advice check failed: %1', What);
        Passed += 1;
    end;
}
