namespace Abakion.ReportStyleDesigner;

using System.Text;
using System.Utilities;

/// Checks the server-side colour reader on two small PNGs: navy and gold on white, and the same on a transparent
/// background (transparent pixels must not turn into a black main colour).
codeunit 50141 "Image Color Checks"
{
    var
        Passed: Integer;
        OnWhiteTok: Label 'iVBORw0KGgoAAAANSUhEUgAAADwAAAAeCAYAAABwmH1PAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAACESURBVFhH7c8xDcMAAAPBMOkWEKVZDOEVJu3+m/uSs9jS7f7j9f58n3Bf59/MDh5pYUTCbMEtjEiYLbiFEQmzBbcwImG24BZGJMwW3MKIhNmCWxiRMFtwCyMSZgtuYUTCbMEtjEiYLbiFEQmzBbcwImG24BZGJMwW3MKIhNmCWxiRMPsByoRvB4iG0P8AAAAASUVORK5CYII=', Locked = true;
        OnClearTok: Label 'iVBORw0KGgoAAAANSUhEUgAAADwAAAAeCAYAAABwmH1PAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAADvSURBVFhHxc+xDcIAAAPBbJKOIVgzM7AXm4T+ugfJWLref5zP6/6H9+vxteOXeWTFiMKGNI+sGFHYkOaRFSMKG9I8smJEYUOaR1aMKGxI88iKEYUNaR5ZMaKwIc0jK0YUNqR5ZMWIwoY0j6wYUdiQ5pEVIwob0jyyYkRhQ5pHVowobEjzyIoRhQ1pHlkxorAhzSMrRhQ2pHlkxYjChjSPrBhR2JDmkRUjChvSPLJiRGFDmkdWjChsSPPIihGFDWkeWTGisCHNIytGFDakeWTFiMKGNI+sGFHYkOaRFSMKG9I8smJEYUOaR1aMKGwo+wDMwm2mNEQAawAAAABJRU5ErkJggg==', Locked = true;

    trigger OnRun()
    var
        Colors: List of [Text];
        Mood: Text;
    begin
        Check(Analyse(OnWhiteTok, Colors, Mood), 'the PNG on white is read');
        Check(Colors.Count() = 2, 'two main colours on white, white ignored (got ' + Join(Colors) + ')');
        Check(Near(Colors.Get(1), '1F3A93'), 'navy first, most used (got ' + Join(Colors) + ')');
        Check(Near(Colors.Get(2), 'E0A526'), 'gold second (got ' + Join(Colors) + ')');
        Check(Mood <> '', 'a mood is given (' + Mood + ')');

        Check(Analyse(OnClearTok, Colors, Mood), 'the transparent PNG is read');
        Check(not HasNear(Colors, '000000'), 'transparent pixels are not black (got ' + Join(Colors) + ')');
        Check(HasNear(Colors, '1F3A93') and HasNear(Colors, 'E0A526'), 'navy and gold on transparent (got ' + Join(Colors) + ')');

        Check(not Analyse('bm90IGEgcGljdHVyZQ==', Colors, Mood), 'a file that is not a picture is refused');
        Message('IMAGE COLOR CHECKS PASSED: %1 (mood on white: %2)', Passed, Mood);
    end;

    local procedure Analyse(Base64: Text; var Colors: List of [Text]; var Mood: Text): Boolean
    var
        ImageColors: Codeunit "Report Style Image Colors";
        Base64Convert: Codeunit "Base64 Convert";
        Blob: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        Blob.CreateOutStream(OutStream);
        Base64Convert.FromBase64(Base64, OutStream);
        exit(ImageColors.Analyse(Blob.CreateInStream(), Colors, Mood));
    end;

    // Resizing blends edge pixels a little, so a colour may differ by a few steps.
    local procedure Near(Actual: Text; Expected: Text): Boolean
    begin
        exit(Distance(Actual, Expected) <= 12);
    end;

    local procedure HasNear(Colors: List of [Text]; Expected: Text): Boolean
    var
        Color: Text;
    begin
        foreach Color in Colors do
            if Near(Color, Expected) then
                exit(true);
        exit(false);
    end;

    local procedure Distance(A: Text; B: Text): Integer
    begin
        exit(Abs(Channel(A, 1) - Channel(B, 1)) + Abs(Channel(A, 3) - Channel(B, 3)) + Abs(Channel(A, 5) - Channel(B, 5)));
    end;

    local procedure Channel(HexColor: Text; Start: Integer): Integer
    begin
        exit(StrPos('0123456789ABCDEF', CopyStr(HexColor, Start, 1)) * 16 + StrPos('0123456789ABCDEF', CopyStr(HexColor, Start + 1, 1)) - 17);
    end;

    local procedure Join(Colors: List of [Text]) Result: Text
    var
        Color: Text;
    begin
        foreach Color in Colors do
            Result += Color + ' ';
        exit(Result.Trim());
    end;

    local procedure Check(Condition: Boolean; What: Text)
    begin
        if not Condition then
            Error('Image colour check failed: %1', What);
        Passed += 1;
    end;
}