namespace Abakion.ReportStyleDesigner;

/// Local stand-in for the AI service: Copilot is not available on an on-premises server, so this tools app
/// (never shipped) answers with fixed proposals. It lets the whole designer flow be tested locally;
/// the real call runs in Business Central online.
codeunit 50125 "Copilot Simulation"
{
    SingleInstance = true;

    var
        ShortBy: Integer;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Report Style Copilot", 'OnIsAvailable', '', false, false)]
    local procedure SimulateAvailable(var Available: Boolean)
    begin
        Available := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Report Style Copilot", 'OnBeforeGenerate', '', false, false)]
    local procedure SimulateGenerate(UserPrompt: Text; Kept: Integer; Wanted: Integer; var ArgumentsText: Text; var Handled: Boolean)
    begin
        // The real service takes seconds; an instant answer races the dialog's generating animation.
        Sleep(2500);
        if ShortBy > 0 then begin
            // A short answer, as the real service may give: fewer themes and no extra.
            ArgumentsText := ArgumentsFor(UserPrompt, Kept, Wanted - ShortBy, false);
            ShortBy := 0;
        end else
            ArgumentsText := ArgumentsFor(UserPrompt, Kept, Wanted, true);
        Handled := true;
    end;

    /// The next answer has this many themes too few; the one after is complete again.
    procedure AnswerShortOnce(Missing: Integer)
    begin
        ShortBy := Missing;
    end;

    /// Three themes, like the default request.
    procedure ArgumentsFor(UserPrompt: Text): Text
    begin
        exit(ArgumentsFor(UserPrompt, 0, 3, true));
    end;

    /// Like the real model, follows a colour named in the request ("pink", "lyserød", ...); otherwise the fixed set.
    /// Skip themes already given, then Wanted themes, then (WithExtra) one theme too many that must be cut.
    procedure ArgumentsFor(UserPrompt: Text; Skip: Integer; Wanted: Integer; WithExtra: Boolean): Text
    var
        Rules: Codeunit "Report Style Theme Rules";
        Pool: List of [Text];
        Words: List of [Text];
        Hexes: List of [Text];
        Result: Text;
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
            CannedPool(Pool)
        else begin
            Name := Rules.ColourName(Hex);
            Pool.Add(Theme('Soft ' + Name, 'A light, calm take on ' + Word + ' with a quiet serif.', Rules.Mix(Hex, '000000', 0.75), Hex, Rules.Tint(Hex, 0.5), '5A6B70', 'C9A227', 'Sitka', 'Banded', 'White'));
            Pool.Add(Theme('Classic ' + Name, 'A restrained, darker ' + Word + ' with accent lines for formal documents.', '1E1E1E', Rules.Mix(Hex, '000000', 0.35), Rules.Tint(Hex, 0.4), '7A7A7A', Hex, 'GeorgiaVerdana', 'AccentLines', 'White'));
            Pool.Add(Theme('Bold ' + Name, 'A bolder ' + Word + ' with a filled header row.', '202020', Hex, Rules.Mix(Hex, '000000', 0.5), '2F3E46', Rules.Tint(Hex, 0.6), 'Bahnschrift', 'BoldHeader', 'White'));
            Pool.Add(Theme('Modern ' + Name, 'A clean ' + Word + ' with neutral fonts and thin rules.', '1A1A1A', Rules.Mix(Hex, '000000', 0.2), '6C7A80', Rules.Tint(Hex, 0.5), 'B0802A', 'SegoeUI', 'Minimal', 'White'));
            Pool.Add(Theme('Formal ' + Name, 'A formal ' + Word + ' with classic fonts for contracts and statements.', '141414', Rules.Mix(Hex, '000000', 0.45), '4A4A4A', Rules.Tint(Hex, 0.3), '8C6D1F', 'CambriaCalibri', 'AccentLines', 'White'));
            Pool.Add(Theme('Quiet ' + Name, 'A muted ' + Word + ' that leaves the numbers in front.', '222222', Rules.Mix(Hex, '5A5A5A', 0.4), '8A9499', Rules.Tint(Hex, 0.7), '3A3A3A', 'SegoeUI', 'Banded', 'White'));
        end;
        for Index := Skip + 1 to Skip + Wanted do
            if Index <= Pool.Count() then
                AddTo(Result, Pool.Get(Index));
        if WithExtra then
            AddTo(Result, Theme('Ignored', 'One proposal too many is never shown.', '000000', 'FF0000', '00FF00', '0000FF', 'FFFF00', 'SegoeUI', 'Minimal', 'White'));
        exit('{"themes":[' + Result + ']}');
    end;

    local procedure AddTo(var Result: Text; Item: Text)
    begin
        if Result <> '' then
            Result += ',';
        Result += Item;
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
        exit(ArgumentsFor('', 0, 3, true));
    end;

    local procedure CannedPool(var Pool: List of [Text])
    begin
        Pool.Add(Theme('Calm Harbour', 'Muted sea greens with a quiet serif feel calm and trustworthy on invoices.', '1E2B2A', '2F6F6A', '7FA9A3', 'C47A3D', '5A7D8C', 'Sitka', 'Banded', 'White'));
        Pool.Add(Theme('Clear Ledger', 'A restrained navy with neutral fonts keeps long tables easy to scan.', '1B1F24', '24476B', '6C8EAD', 'A3B8CC', 'D08C2E', 'Comic Sans', 'KeepBase', 'White'));
        Pool.Add(Theme('Sunny Studio', 'A bolder, warm look built around the yellow in the logo.', '8A8A8A', 'FFD500', 'F28C28', '3A3A3A', '8C6D1F', 'Bahnschrift', 'BoldHeader', 'WarmPaper'));
        Pool.Add(Theme('Slate Office', 'Cool greys with one blue accent for a sober, modern look.', '1C1F22', '3D5A80', '98A6B5', '5C6B73', 'E07A2F', 'SegoeUI', 'Minimal', 'White'));
        Pool.Add(Theme('Heritage Print', 'Deep burgundy and classic fonts give a long-established feel.', '1F1416', '7A1F2B', 'B7848C', '4F4F4F', 'A88A3D', 'CambriaCalibri', 'AccentLines', 'White'));
        Pool.Add(Theme('Field Notes', 'Olive and sand tones with a compact font for practical documents.', '1E2118', '556B2F', 'A3A07A', '6B5B3E', '3E6B7A', 'GeorgiaVerdana', 'Banded', 'White'));
    end;
}
