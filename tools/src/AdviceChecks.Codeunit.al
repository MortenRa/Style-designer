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

        Message('ADVICE CHECKS PASSED: %1', Passed);
    end;

    local procedure Check(Condition: Boolean; What: Text)
    begin
        if not Condition then
            Error('Advice check failed: %1', What);
        Passed += 1;
    end;
}
