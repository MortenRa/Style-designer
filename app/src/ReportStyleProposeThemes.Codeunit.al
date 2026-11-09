namespace Abakion.ReportStyleDesigner;

using System.AI;

/// The one tool Copilot may call: theme proposals as structured arguments (1 to 6, default 3).
/// The arguments are read by "Report Style Copilot"; nothing is executed here.
codeunit 50120 "Report Style Propose Themes" implements "AOAI Function"
{
    Access = Internal;

    var
        FunctionNameTok: Label 'propose_themes', Locked = true;
        ProposalCount: Integer;

    /// How many proposals Copilot must return; values outside 1 to 6 are set to the default of 3.
    procedure SetCount(NewCount: Integer)
    begin
        if (NewCount < 1) or (NewCount > 6) then
            NewCount := 3;
        ProposalCount := NewCount;
    end;

    procedure GetName(): Text
    begin
        exit(FunctionNameTok);
    end;

    procedure GetPrompt() Prompt: JsonObject
    var
        Function: JsonObject;
        Parameters: JsonObject;
        Properties: JsonObject;
        Themes: JsonObject;
        Theme: JsonObject;
        ThemeProperties: JsonObject;
        Required: JsonArray;
    begin
        AddString(ThemeProperties, 'name', 'Short theme name, 2-4 words.');
        AddString(ThemeProperties, 'reason', 'One sentence, at most 25 words, on why this fits the request.');
        AddString(ThemeProperties, 'text', 'Body text colour, hex RRGGBB. Very dark, near black; may lean towards the primary hue.');
        AddString(ThemeProperties, 'primary', 'Main accent, hex RRGGBB: header rules, totals and table headers. Must read well on white.');
        AddString(ThemeProperties, 'secondary', 'Supporting accent, hex RRGGBB, harmonising with primary.');
        AddString(ThemeProperties, 'tertiary', 'Supporting accent, hex RRGGBB.');
        AddString(ThemeProperties, 'quaternary', 'Supporting accent, hex RRGGBB.');
        AddEnum(ThemeProperties, 'fontPair', 'Heading / body font pair.', FontPairChoices());
        AddEnum(ThemeProperties, 'tableStyle', 'How tables look.', TableStyleChoices());
        AddEnum(ThemeProperties, 'pageColor', 'Page background. It prints on every page, so prefer White.', PageColorChoices());
        Required.ReadFrom('["name","reason","text","primary","secondary","tertiary","quaternary","fontPair","tableStyle","pageColor"]');
        Theme.Add('type', 'object');
        Theme.Add('properties', ThemeProperties);
        Theme.Add('required', Required);

        Themes.Add('type', 'array');
        if ProposalCount < 1 then
            ProposalCount := 3;
        Themes.Add('description', StrSubstNo('Exactly %1 clearly different proposals.', ProposalCount));
        Themes.Add('minItems', ProposalCount);
        Themes.Add('maxItems', ProposalCount);
        Themes.Add('items', Theme);
        Properties.Add('themes', Themes);

        Parameters.Add('type', 'object');
        Parameters.Add('properties', Properties);
        Required.ReadFrom('["themes"]');
        Parameters.Add('required', Required);

        Function.Add('name', FunctionNameTok);
        Function.Add('description', StrSubstNo('Propose %1 visual themes for printed Business Central reports.', ProposalCount));
        Function.Add('parameters', Parameters);
        Prompt.Add('type', 'function');
        Prompt.Add('function', Function);
    end;

    procedure Execute(Arguments: JsonObject): Variant
    begin
        exit(true);
    end;

    /// Names Copilot may use for each option, without the "keep the base theme" values.
    procedure FontPairChoices(): List of [Text]
    begin
        exit(Without(Enum::"Report Style Font Pair".Names(), 'KeepBase', ''));
    end;

    procedure TableStyleChoices(): List of [Text]
    begin
        exit(Without(Enum::"Report Theme Table Style".Names(), 'KeepBase', ''));
    end;

    procedure PageColorChoices(): List of [Text]
    begin
        // tinted pages are computed, not guessed
        exit(Without(Enum::"Report Style Page Color".Names(), 'KeepBase', 'Custom'));
    end;

    /// Enum.Names() is read-only, so the choices are copied into a new list.
    local procedure Without(Names: List of [Text]; Skip1: Text; Skip2: Text) Choices: List of [Text]
    var
        Name: Text;
    begin
        foreach Name in Names do
            if (Name <> Skip1) and (Name <> Skip2) then
                Choices.Add(Name);
    end;

    local procedure AddString(var Properties: JsonObject; Name: Text; Description: Text)
    var
        Property: JsonObject;
    begin
        Property.Add('type', 'string');
        Property.Add('description', Description);
        Properties.Add(Name, Property);
    end;

    local procedure AddEnum(var Properties: JsonObject; Name: Text; Description: Text; Choices: List of [Text])
    var
        Property: JsonObject;
        Values: JsonArray;
        Choice: Text;
    begin
        foreach Choice in Choices do
            Values.Add(Choice);
        Property.Add('type', 'string');
        Property.Add('description', Description);
        Property.Add('enum', Values);
        Properties.Add(Name, Property);
    end;
}
