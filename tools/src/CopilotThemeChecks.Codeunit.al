namespace Abakion.ReportStyleDesigner;

using System.AI;
using System.IO;
using System.Utilities;

/// Checks the deterministic half of the Copilot feature: colour rules, parsing of the AI's tool arguments
/// (including bad values), and that a kept proposal really reaches the generated theme.
codeunit 50124 "Copilot Theme Checks"
{
    var
        Rules: Codeunit "Report Style Theme Rules";
        ReportStyleCopilot: Codeunit "Report Style Copilot";
        Passed: Integer;

    trigger OnRun()
    begin
        ToolDefinition();
        HexRules();
        ColourNames();
        Contrast();
        PaletteFixes();
        ParseArguments();
        ParseGarbage();
        StandInFollowsColour();
        BackgroundModes();
        ProposalReachesTheme();
        ProposalsForDesigner();
        Message('COPILOT CHECKS PASSED: %1', Passed);
    end;

    local procedure HexRules()
    var
        Hex: Text;
    begin
        Check(Rules.TryNormalizeHex('#1f6fa8', Hex) and (Hex = '1F6FA8'), 'hex with # and lower case, got ' + Hex);
        Check(Rules.TryNormalizeHex('abc', Hex) and (Hex = 'AABBCC'), 'short hex, got ' + Hex);
        Check(not Rules.TryNormalizeHex('12345G', Hex), 'G is not hex');
        Check(not Rules.TryNormalizeHex('blue', Hex), 'colour names are rejected');
        Check(not Rules.TryNormalizeHex('"/><x', Hex), 'markup is rejected');
    end;

    // The real call builds the tool definition first; the local stand-in skips that call, so test it here.
    local procedure ToolDefinition()
    var
        ProposeThemes: Codeunit "Report Style Propose Themes";
        Prompt: JsonObject;
        Text: Text;
    begin
        Prompt := ProposeThemes.GetPrompt();
        Prompt.WriteTo(Text);
        Check(Text.Contains('"name":"propose_themes"'), 'tool definition has the function name');
        Check(Text.Contains('"Sitka"') and not Text.Contains('"KeepBase"'), 'font choices without KeepBase');
        Check(Text.Contains('"WarmPaper"') and not Text.Contains('"Custom"'), 'page colours without KeepBase and Custom');
        Check(ProposeThemes.TableStyleChoices().Count() = 4, 'four table styles');
        ProposeThemes.SetCount(6);
        Prompt := ProposeThemes.GetPrompt();
        Prompt.WriteTo(Text);
        Check(Text.Contains('"minItems":6') and Text.Contains('"maxItems":6'), 'six proposals in the tool definition');
        ProposeThemes.SetCount(9);
        Prompt := ProposeThemes.GetPrompt();
        Prompt.WriteTo(Text);
        Check(Text.Contains('"maxItems":3'), 'a count outside 1 to 6 falls back to three');
        BuildsTheRequest();
    end;

    // Runs the real request building (system message, user message, tool, tool choice) without calling the service.
    local procedure BuildsTheRequest()
    var
        Messages: Codeunit "AOAI Chat Messages";
    begin
        ReportStyleCopilot.BuildMessages('Calm and modern in pink', Messages);
        Check(Messages.ToolsExists(), 'the request carries the propose_themes tool');
    end;

    local procedure ColourNames()
    begin
        CheckName('FFFFFF', 'white');
        CheckName('000000', 'black');
        CheckName('363636', 'dark grey');
        CheckName('A7A7A7', 'grey');
        CheckName('C8C8C8', 'light grey');
        CheckName('0B1F4D', 'navy');
        CheckName('1F3A93', 'blue');
        CheckName('2F6F6A', 'teal');
        CheckName('4F7A3A', 'green');
        CheckName('C2502A', 'orange');
        CheckName('FFD500', 'gold');
        CheckName('6B4E71', 'purple');
        CheckName('B00020', 'red');
    end;

    local procedure CheckName(Hex: Text; Expected: Text)
    begin
        Check(Rules.ColourName(Hex) = Expected, StrSubstNo('%1 should be called %2, got %3', Hex, Expected, Rules.ColourName(Hex)));
    end;

    local procedure Contrast()
    begin
        Check(Round(Rules.ContrastRatio('000000', 'FFFFFF'), 0.1) = 21, 'black on white is 21:1');
        Check(Round(Rules.ContrastRatio('FFFFFF', 'FFFFFF'), 0.1) = 1, 'white on white is 1:1');
        Check(Rules.Tint('000000', 0.1) = 'E6E6E6', 'tint 10% of black, got ' + Rules.Tint('000000', 0.1));
    end;

    local procedure PaletteFixes()
    var
        Colors: List of [Text];
        Notes: List of [Text];
    begin
        // readable input stays as it is
        Rules.BuildPalette('1A1A1A', '1F6FA8', '4F9AC9', 'E0A100', '7A5BA8', '', Colors, Notes);
        Check(Colors.Count() = 12, 'palette has 12 slots');
        Check((Colors.Get(1) = '1A1A1A') and (Colors.Get(7) = '1F6FA8'), 'readable colours are kept');
        Check(Notes.Count() = 0, 'no adjustments for readable colours');
        Check(Colors.Get(2) = 'FFFFFF', 'background slot stays white');

        // light grey text and a yellow accent get darkened until they print well
        Rules.BuildPalette('999999', 'FFE600', '4F9AC9', 'E0A100', '7A5BA8', 'FBF7F0', Colors, Notes);
        Check(Rules.ContrastRatio(Colors.Get(1), 'FFFFFF') >= 7, 'text reaches 7:1 on white');
        Check(Rules.ContrastRatio(Colors.Get(1), 'FBF7F0') >= 7, 'text reaches 7:1 on the page colour');
        Check(Rules.ContrastRatio(Colors.Get(7), 'FFFFFF') >= 3, 'accent reaches 3:1 on white');
        Check(Notes.Count() = 2, 'both adjustments are reported');

        // missing or invalid colours are filled in
        Rules.BuildPalette('', 'not a colour', '', '', '', '', Colors, Notes);
        Check(Colors.Count() = 12, 'fallback palette has 12 slots');
        Check(Notes.Count() >= 1, 'filled colours are reported');
    end;

    local procedure ParseArguments()
    var
        Proposal: Record "Report Style Proposal";
        Simulation: Codeunit "Copilot Simulation";
        Arguments: JsonObject;
        Colors: List of [Text];
    begin
        Arguments.ReadFrom(Simulation.CannedArguments());
        ReportStyleCopilot.ParseProposals(Arguments, Proposal);
        Check(Proposal.Count() = 3, 'only three proposals are kept, got ' + Format(Proposal.Count()));

        Proposal.Get(1);
        Check(Proposal."Font Pair" = Proposal."Font Pair"::Sitka, 'font pair by name');
        Check(Proposal."Table Style" = Proposal."Table Style"::Banded, 'table style by name');
        Check(Proposal."Page Color" = Proposal."Page Color"::White, 'page colour by name');
        Check(Proposal.Adjustments = '', 'first proposal needs no adjustments, got ' + Proposal.Adjustments);

        Proposal.Get(2);
        Check(Proposal."Font Pair" = Proposal."Font Pair"::SegoeUI, 'unknown font falls back to Segoe UI');
        Check(Proposal."Table Style" = Proposal."Table Style"::Banded, 'KeepBase is not allowed and falls back to Banded');

        Proposal.Get(3);
        Colors := Proposal.Colors.Split(',');
        Check(Proposal.Adjustments <> '', 'weak colours are reported');
        Check(Rules.ContrastRatio(Colors.Get(1), 'FFFFFF') >= 7, 'weak text colour was fixed');
        Check(Rules.ContrastRatio(Colors.Get(7), 'FFFFFF') >= 3, 'weak accent was fixed');
        Check(Proposal."Main Colour" = '#' + Colors.Get(7), 'main colour shows the fixed accent');
    end;

    local procedure ParseGarbage()
    var
        Proposal: Record "Report Style Proposal";
        Arguments: JsonObject;
    begin
        Arguments.ReadFrom('{"themes":"no"}');
        ReportStyleCopilot.ParseProposals(Arguments, Proposal);
        Check(Proposal.IsEmpty(), 'themes must be an array');
        Arguments.ReadFrom('{"themes":[{"name":null,"primary":42}]}');
        ReportStyleCopilot.ParseProposals(Arguments, Proposal);
        Check(Proposal.Count() = 1, 'a sparse theme still gives one proposal');
        Proposal.FindFirst();
        Check(Proposal.Name <> '', 'a missing name is filled in');
        Check(StrLen(Proposal.Colors) = 12 * 7 - 1, 'a sparse theme still has 12 colours');
    end;

    local procedure BackgroundModes()
    var
        Proposal: Record "Report Style Proposal";
        Simulation: Codeunit "Copilot Simulation";
        Arguments: JsonObject;
        Colors: List of [Text];
    begin
        Check(Rules.LightPage(Rules.LightPage('D81B60')) = Rules.LightPage('D81B60'), 'a lightened page colour is light enough');
        Check(Rules.LightPage('FBF7F0') = 'FBF7F0', 'a pale page colour is kept as it is');

        // soft tint: every proposal gets its own light page colour, and the text still reads 7:1 on it
        ReportStyleCopilot.SetBackground(2);
        Arguments.ReadFrom(Simulation.ArgumentsFor('modern in pink'));
        ReportStyleCopilot.ParseProposals(Arguments, Proposal);
        if Proposal.FindSet() then
            repeat
                Colors := Proposal.Colors.Split(',');
                Check(Proposal."Page Color" = Proposal."Page Color"::Custom, 'tint gives a custom page colour');
                Check(Rules.LightPage(Proposal."Custom Page Color") = Proposal."Custom Page Color", 'tinted page is light, got ' + Proposal."Custom Page Color");
                Check(Rules.ColourName(Proposal."Custom Page Color") <> 'white', 'tinted page is not plain white');
                Check(Rules.ContrastRatio(Colors.Get(1), Proposal."Custom Page Color") >= 7, 'text reads on the tinted page');
            until Proposal.Next() = 0;

        // white: no page colour, whatever the model said (the fixed set has WarmPaper in it)
        ReportStyleCopilot.SetBackground(1);
        Arguments.ReadFrom(Simulation.CannedArguments());
        ReportStyleCopilot.ParseProposals(Arguments, Proposal);
        Proposal.SetFilter("Page Color", '<>%1', Proposal."Page Color"::White);
        Check(Proposal.IsEmpty(), 'white background means white pages');
        Proposal.SetRange("Page Color");
        ReportStyleCopilot.SetBackground(0);
    end;

    // The local stand-in must follow a colour in the request, like the real model, or local tests mislead.
    local procedure StandInFollowsColour()
    var
        Proposal: Record "Report Style Proposal";
        Simulation: Codeunit "Copilot Simulation";
        Arguments: JsonObject;
    begin
        Arguments.ReadFrom(Simulation.ArgumentsFor('Calm and modern in PINK please'));
        ReportStyleCopilot.ParseProposals(Arguments, Proposal);
        Check(Proposal.Count() = 3, 'three pink proposals');
        if Proposal.FindSet() then
            repeat
                Check(StrPos(Rules.ColourName(CopyStr(Proposal."Main Colour", 2)), 'pink') > 0, 'main colour is pink, got ' + Proposal."Main Colour" + ' = ' + Rules.ColourName(CopyStr(Proposal."Main Colour", 2)));
            until Proposal.Next() = 0;
        Arguments.ReadFrom(Simulation.ArgumentsFor('Rolig og professionel i lyserød'));
        ReportStyleCopilot.ParseProposals(Arguments, Proposal);
        Proposal.FindFirst();
        Check(StrPos(Proposal.Name, 'pink') > 0, 'Danish lyserød gives pink, got ' + Proposal.Name);
    end;

    local procedure ProposalReachesTheme()
    var
        Proposal: Record "Report Style Proposal";
        Config: Record "Report Style Config";
        ConfiguratorMgt: Codeunit "Report Style Configurator Mgt.";
        Simulation: Codeunit "Copilot Simulation";
        Generated: Codeunit "Temp Blob";
        Arguments: JsonObject;
        Colors: List of [Text];
        ThemeXml: Text;
    begin
        Arguments.ReadFrom(Simulation.CannedArguments());
        ReportStyleCopilot.ParseProposals(Arguments, Proposal);
        Proposal.Get(1);
        Colors := Proposal.Colors.Split(',');

        Config.Init();
        Config."Base Theme" := 'DefaultTheme';
        Config."Theme Name" := Proposal.Name;
        Config.Palette := Config.Palette::Custom;
        Config."Custom Colors" := Proposal.Colors;
        Config."Font Pair" := Proposal."Font Pair";
        Config."Table Style" := Proposal."Table Style";
        Config."Page Color" := Proposal."Page Color";
        ConfiguratorMgt.GenerateTheme(Config, Generated);

        ThemeXml := ReadEntry(Generated, 'word/theme/theme1.xml');
        Check(SlotHas(ThemeXml, 'accent3', Colors.Get(7)), 'accent 3 carries the proposal''s main colour');
        Check(SlotHas(ThemeXml, 'dk1', Colors.Get(1)), 'dk1 carries the proposal''s text colour');
        Check(ThemeXml.Contains('typeface="Sitka Text"'), 'the proposal''s body font is in the theme');
    end;

    local procedure ProposalsForDesigner()
    var
        Proposal: Record "Report Style Proposal";
        Simulation: Codeunit "Copilot Simulation";
        Arguments: JsonObject;
        Items: JsonArray;
        Item: JsonToken;
        Value: JsonToken;
    begin
        Arguments.ReadFrom(Simulation.CannedArguments());
        ReportStyleCopilot.ParseProposals(Arguments, Proposal);
        Items.ReadFrom(ReportStyleCopilot.ProposalsToJson(Proposal));
        Check(Items.Count() = 3, 'three suggestions for the designer');
        Items.Get(0, Item);
        Item.AsObject().Get('colors', Value);
        Check(Value.AsArray().Count() = 12, 'each suggestion carries 12 colours');
        Item.AsObject().Get('fonts', Value);
        Check(Value.AsValue().AsInteger() = Proposal."Font Pair"::Sitka.AsInteger(), 'font pair as the designer''s id');
    end;

    local procedure SlotHas(ThemeXml: Text; Slot: Text; Hex: Text): Boolean
    var
        Start: Integer;
        SlotXml: Text;
    begin
        Start := StrPos(ThemeXml, '<a:' + Slot + '>');
        if Start = 0 then
            exit(false);
        SlotXml := CopyStr(ThemeXml, Start, StrPos(CopyStr(ThemeXml, Start), '</a:' + Slot + '>'));
        exit(SlotXml.Contains('val="' + Hex + '"'));
    end;

    local procedure ReadEntry(Package: Codeunit "Temp Blob"; EntryName: Text) Content: Text
    var
        DataCompression: Codeunit "Data Compression";
        Entry: Codeunit "Temp Blob";
        Reader: InStream;
        Line: Text;
    begin
        DataCompression.OpenZipArchive(Package, false);
        DataCompression.ExtractEntry(EntryName, Entry);
        DataCompression.CloseZipArchive();
        Reader := Entry.CreateInStream(TextEncoding::UTF8);
        while not Reader.EOS() do begin
            Reader.ReadText(Line);
            Content += Line;
        end;
    end;

    local procedure Check(Condition: Boolean; What: Text)
    begin
        if not Condition then
            Error('Copilot check failed: %1', What);
        Passed += 1;
    end;
}
