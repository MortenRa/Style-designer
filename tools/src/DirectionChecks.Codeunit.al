namespace Abakion.ReportStyleDesigner;

/// Checks the design directions: each one sets a full look, gives no recommendations, and differs from the others.
codeunit 50135 "Direction Checks"
{
    var
        Directions: Codeunit "Report Style Directions";
        Advice: Codeunit "Report Style Advice";
        Passed: Integer;

    trigger OnRun()
    var
        Config: Record "Report Style Config";
        Items: List of [Text];
        Seen: List of [Text];
        Ordinal: Integer;
        Signature: Text;
    begin
        // A normal logo, so the result does not depend on the company's own logo.
        Advice.SetLogoSize(800, 300);

        // Not chosen changes nothing.
        Config.Init();
        Config."HF Logo" := 'none';
        Config.Direction := Config.Direction::NotChosen;
        Directions.Apply(Config);
        Check(Config."HF Logo" = 'none', 'Not chosen leaves the configuration as it is');

        // A logo placement the user picked is kept by every direction.
        Config.Init();
        Config."HF Logo" := 'left';
        Config."Logo Chosen" := true;
        Config.Direction := Config.Direction::Formal;
        Directions.Apply(Config);
        Check(Config."HF Logo" = 'left', 'Formal keeps the logo placement the user picked');
        Check(Config."Font Pair" = Config."Font Pair"::GeorgiaVerdana, 'Formal still sets its fonts when the logo is kept');

        foreach Ordinal in Enum::"Report Style Direction".Ordinals() do
            if Ordinal <> 0 then begin
                Config.Init();
                Config.Direction := Enum::"Report Style Direction".FromInteger(Ordinal);
                Directions.Apply(Config);
                Check(Config."Theme Mode" = 'custom', Format(Config.Direction) + ' sets a custom theme');
                Check(Config."Header Mode" = 'design', Format(Config.Direction) + ' designs the header/footer');
                Check(Config."Font Pair" <> Config."Font Pair"::KeepBase, Format(Config.Direction) + ' chooses fonts');
                Check(Config.Palette <> Config.Palette::KeepBase, Format(Config.Direction) + ' chooses colours');
                Check(Config."Table Style" <> Config."Table Style"::KeepBase, Format(Config.Direction) + ' chooses a table style');
                Check(Config."HF Logo" <> 'none', Format(Config.Direction) + ' shows the logo');
                Advice.GetAdvice(Config, Items);
                Check(Items.Count() = 0, Format(Config.Direction) + ' gives no recommendations');
                Check(Directions.Describe(Config.Direction) <> Directions.Describe(Config.Direction::NotChosen), Format(Config.Direction) + ' has its own description');
                Signature := StrSubstNo('%1|%2|%3|%4|%5|%6|%7|%8', Config."Font Pair", Config.Palette, Config."Page Color", Config."Table Style", Config."HF Logo", Config."HF Page Number", Config."HF Footer", Config."HF Accent Line");
                Check(not Seen.Contains(Signature), Format(Config.Direction) + ' differs from the other directions');
                Seen.Add(Signature);
            end;

        Message('DIRECTION CHECKS PASSED: %1', Passed);
    end;

    local procedure Check(Condition: Boolean; What: Text)
    begin
        if not Condition then
            Error('Direction check failed: %1', What);
        Passed += 1;
    end;
}
