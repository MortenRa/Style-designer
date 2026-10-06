namespace Abakion.ReportStyleDesigner;

/// Local stand-in for the AI service: Copilot is not available on an on-premises server, so this tools app
/// (never shipped) answers with fixed proposals. It lets the whole designer flow be tested locally;
/// the real call runs in Business Central online.
codeunit 50125 "Copilot Simulation"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Report Style Copilot", 'OnIsAvailable', '', false, false)]
    local procedure SimulateAvailable(var Available: Boolean)
    begin
        Available := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Report Style Copilot", 'OnBeforeGenerate', '', false, false)]
    local procedure SimulateGenerate(UserPrompt: Text; var ArgumentsText: Text; var Handled: Boolean)
    begin
        // The real service takes seconds; an instant answer races the dialog's generating animation.
        Sleep(2500);
        ArgumentsText := ArgumentsFor(UserPrompt);
        Handled := true;
    end;

    /// Like the real model, follows a colour named in the request ("pink", "lyserød", ...); otherwise the fixed set.
    procedure ArgumentsFor(UserPrompt: Text): Text
    var
        Rules: Codeunit "Report Style Theme Rules";
        Words: List of [Text];
        Hexes: List of [Text];
        Index: Integer;
        Word: Text;
        Hex: Text;
        Name: Text;
    begin
        // Longer words first, so "lyserød" is found before "rød".
        Words.AddRange('lyserød', 'pink', 'rosa', 'navy', 'red', 'rød', 'orange', 'gold', 'yellow', 'gul', 'green', 'grøn', 'teal', 'blue', 'blå', 'purple', 'lilla', 'brown', 'brun', 'grey', 'gray', 'grå');
        Hexes.AddRange('D81B60', 'D81B60', 'D81B60', '1A237E', 'C62828', 'C62828', 'EF6C00', 'C99700', 'F2C200', 'F2C200', '2E7D32', '2E7D32', '00796B', '1565C0', '1565C0', '6A1B9A', '6A1B9A', '6D4C41', '6D4C41', '546E7A', '546E7A', '546E7A');
        for Index := 1 to Words.Count() do
            if (Hex = '') and (StrPos(LowerCase(UserPrompt), Words.Get(Index)) > 0) then begin
                Word := Words.Get(Index);
                Hex := Hexes.Get(Index);
            end;
        if Hex = '' then
            exit(CannedArguments());
        Name := Rules.ColourName(Hex);
        exit(
            '{"themes":[' +
            Theme('Soft ' + Name, 'A light, calm take on ' + Word + ' with a quiet serif.', Rules.Mix(Hex, '000000', 0.75), Hex, Rules.Tint(Hex, 0.5), '5A6B70', 'C9A227', 'Sitka', 'Banded', 'White') + ',' +
            Theme('Classic ' + Name, 'A restrained, darker ' + Word + ' with accent lines for formal documents.', '1E1E1E', Rules.Mix(Hex, '000000', 0.35), Rules.Tint(Hex, 0.4), '7A7A7A', Hex, 'GeorgiaVerdana', 'AccentLines', 'White') + ',' +
            Theme('Bold ' + Name, 'A bolder ' + Word + ' with a filled header row.', '202020', Hex, Rules.Mix(Hex, '000000', 0.5), '2F3E46', Rules.Tint(Hex, 0.6), 'Bahnschrift', 'BoldHeader', 'White') +
            ']}');
    end;

    local procedure Theme(Name: Text; Reason: Text; TextHex: Text; Primary: Text; Secondary: Text; Tertiary: Text; Quaternary: Text; FontPair: Text; TableStyle: Text; PageColor: Text): Text
    begin
        exit(StrSubstNo('{"name":"%1","reason":"%2","text":"%3","primary":"%4","secondary":"%5","tertiary":"%6","quaternary":"%7",', Name, Reason, TextHex, Primary, Secondary, Tertiary, Quaternary) +
            StrSubstNo('"fontPair":"%1","tableStyle":"%2","pageColor":"%3"}', FontPair, TableStyle, PageColor));
    end;

    /// Three proposals as the model would return them, plus traps: an unknown font, a value that is not
    /// allowed (KeepBase), weak colours, and a fourth theme that must be ignored.
    procedure CannedArguments(): Text
    begin
        exit(
            '{"themes":[' +
            '{"name":"Calm Harbour","reason":"Muted sea greens with a quiet serif feel calm and trustworthy on invoices.",' +
            '"text":"1E2B2A","primary":"2F6F6A","secondary":"7FA9A3","tertiary":"C47A3D","quaternary":"5A7D8C",' +
            '"fontPair":"Sitka","tableStyle":"Banded","pageColor":"White"},' +
            '{"name":"Clear Ledger","reason":"A restrained navy with neutral fonts keeps long tables easy to scan.",' +
            '"text":"1B1F24","primary":"24476B","secondary":"6C8EAD","tertiary":"A3B8CC","quaternary":"D08C2E",' +
            '"fontPair":"Comic Sans","tableStyle":"KeepBase","pageColor":"White"},' +
            '{"name":"Sunny Studio","reason":"A bolder, warm look built around the yellow in the logo.",' +
            '"text":"8A8A8A","primary":"FFD500","secondary":"F28C28","tertiary":"3A3A3A","quaternary":"8C6D1F",' +
            '"fontPair":"Bahnschrift","tableStyle":"BoldHeader","pageColor":"WarmPaper"},' +
            '{"name":"Ignored","reason":"A fourth proposal is never shown.","text":"000000","primary":"FF0000","secondary":"00FF00",' +
            '"tertiary":"0000FF","quaternary":"FFFF00","fontPair":"SegoeUI","tableStyle":"Minimal","pageColor":"White"}' +
            ']}');
    end;
}
