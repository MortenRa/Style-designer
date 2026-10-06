namespace Abakion.ReportStyleDesigner;

/// Colour rules for themes that are not picked from the fixed palettes (Copilot proposals): turns a few
/// colours into the 12 theme slots and fixes contrast, so text stays readable when printed.
codeunit 50121 "Report Style Theme Rules"
{
    Access = Internal;

    var
        TextDarkenedTxt: Label 'Text colour darkened for readability.';
        AccentDarkenedTxt: Label 'Accent colour darkened so lines and totals stay visible.';
        MissingColorTxt: Label 'A missing colour was filled in.';

    /// Builds the 12 colours in clrScheme order (dk1, lt1, dk2, lt2, accent1-6, hlink, folHlink).
    /// Slot roles follow the shipped palettes: Accent 1 = table banding, Accent 2 = rules, Accent 3 = main accent.
    /// PageHex is the page colour ('' = white); Notes lists what had to be adjusted.
    procedure BuildPalette(TextHex: Text; PrimaryHex: Text; SecondaryHex: Text; TertiaryHex: Text; QuaternaryHex: Text; PageHex: Text; var Colors: List of [Text]; var Notes: List of [Text])
    var
        Page: Text;
        Band: Text;
        Rule: Text;
    begin
        Clear(Colors);
        Clear(Notes);
        Page := 'FFFFFF';
        if PageHex <> '' then
            Page := PageHex;

        PrimaryHex := ValidOr(PrimaryHex, '1F6FA8', Notes);
        TextHex := ValidOr(TextHex, '242424', Notes);
        SecondaryHex := ValidOr(SecondaryHex, Tint(PrimaryHex, 0.6), Notes);
        TertiaryHex := ValidOr(TertiaryHex, Mix(PrimaryHex, '000000', 0.3), Notes);
        QuaternaryHex := ValidOr(QuaternaryHex, Tint(PrimaryHex, 0.45), Notes);

        // Lines, totals and bold headers use the main accent: it must stand out on white and on the page.
        if Darken(PrimaryHex, 'FFFFFF', 3) or Darken(PrimaryHex, Page, 3) then
            Notes.Add(AccentDarkenedTxt);
        // Body text sits on white, on the page colour and on the bold-header fill (a 40% tint of the accent).
        if Darken(TextHex, 'FFFFFF', 7) or Darken(TextHex, Page, 7) or Darken(TextHex, Tint(PrimaryHex, 0.4), 4.5) then
            Notes.Add(TextDarkenedTxt);

        Band := Tint(PrimaryHex, 0.1);
        Rule := Tint(PrimaryHex, 0.3);
        Colors.AddRange(TextHex, 'FFFFFF', TextHex, Band, Band, Rule, PrimaryHex, SecondaryHex, TertiaryHex, QuaternaryHex, PrimaryHex, TextHex);
    end;

    /// Accepts 'RRGGBB', '#RRGGBB' or '#RGB' (any case); returns upper-case RRGGBB.
    procedure TryNormalizeHex(Value: Text; var Hex: Text): Boolean
    var
        Index: Integer;
    begin
        Value := UpperCase(DelChr(Value, '<>', ' #'));
        if StrLen(Value) = 3 then
            Value := CopyStr(Value, 1, 1) + CopyStr(Value, 1, 1) + CopyStr(Value, 2, 1) + CopyStr(Value, 2, 1) + CopyStr(Value, 3, 1) + CopyStr(Value, 3, 1);
        if StrLen(Value) <> 6 then
            exit(false);
        for Index := 1 to 6 do
            if StrPos('0123456789ABCDEF', Value[Index]) = 0 then
                exit(false);
        Hex := Value;
        exit(true);
    end;

    /// A page colour that goes with a theme colour: a very light tint of it.
    procedure SoftPage(Hex: Text): Text
    begin
        exit(LightPage(Tint(Hex, 0.08)));
    end;

    /// Page colours print on every page: anything darker than a pale tint is lightened.
    procedure LightPage(Hex: Text): Text
    var
        Step: Integer;
        Result: Text;
    begin
        Result := Hex;
        while (Lightness(Result) < 0.92) and (Step < 20) do begin
            Step += 1;
            Result := Mix(Hex, 'FFFFFF', Step * 0.05);
        end;
        exit(Result);
    end;

    local procedure Lightness(Hex: Text): Decimal
    var
        Red: Decimal;
        Green: Decimal;
        Blue: Decimal;
    begin
        Red := ChannelOf(Hex, 0) / 255;
        Green := ChannelOf(Hex, 1) / 255;
        Blue := ChannelOf(Hex, 2) / 255;
        exit((MaxOf(Red, MaxOf(Green, Blue)) + MinOf(Red, MinOf(Green, Blue))) / 2);
    end;

    /// A plain name for a colour, such as 'navy', 'dark green' or 'light grey', so users need no colour codes.
    procedure ColourName(Hex: Text): Text
    var
        Red: Decimal;
        Green: Decimal;
        Blue: Decimal;
        MaxValue: Decimal;
        MinValue: Decimal;
        Lightness: Decimal;
        Saturation: Decimal;
        Hue: Decimal;
        Base: Text;
    begin
        Red := ChannelOf(Hex, 0) / 255;
        Green := ChannelOf(Hex, 1) / 255;
        Blue := ChannelOf(Hex, 2) / 255;
        MaxValue := MaxOf(Red, MaxOf(Green, Blue));
        MinValue := MinOf(Red, MinOf(Green, Blue));
        Lightness := (MaxValue + MinValue) / 2;
        if MaxValue = MinValue then
            Saturation := 0
        else
            if Lightness > 0.5 then
                Saturation := (MaxValue - MinValue) / (2 - MaxValue - MinValue)
            else
                Saturation := (MaxValue - MinValue) / (MaxValue + MinValue);

        if Saturation < 0.15 then
            case true of
                Lightness < 0.12:
                    exit('black');
                Lightness < 0.35:
                    exit('dark grey');
                Lightness < 0.7:
                    exit('grey');
                Lightness < 0.93:
                    exit('light grey');
                else
                    exit('white');
            end;

        case MaxValue of
            Red:
                Hue := 60 * ((Green - Blue) / (MaxValue - MinValue));
            Green:
                Hue := 60 * ((Blue - Red) / (MaxValue - MinValue)) + 120;
            else
                Hue := 60 * ((Red - Green) / (MaxValue - MinValue)) + 240;
        end;
        if Hue < 0 then
            Hue += 360;

        case true of
            Hue < 12, Hue >= 345:
                Base := 'red';
            Hue < 40:
                if Lightness < 0.4 then
                    Base := 'brown'
                else
                    Base := 'orange';
            Hue < 65:
                if Lightness < 0.4 then
                    Base := 'olive'
                else
                    Base := 'gold';
            Hue < 160:
                Base := 'green';
            Hue < 195:
                Base := 'teal';
            Hue < 250:
                if Lightness < 0.3 then
                    exit('navy')
                else
                    Base := 'blue';
            Hue < 290:
                Base := 'purple';
            else
                Base := 'pink';
        end;
        if Lightness < 0.3 then
            exit('dark ' + Base);
        if Lightness > 0.75 then
            exit('light ' + Base);
        exit(Base);
    end;

    local procedure MaxOf(A: Decimal; B: Decimal): Decimal
    begin
        if A > B then
            exit(A);
        exit(B);
    end;

    local procedure MinOf(A: Decimal; B: Decimal): Decimal
    begin
        if A < B then
            exit(A);
        exit(B);
    end;

    /// WCAG contrast ratio between two colours, 1 to 21.
    procedure ContrastRatio(HexA: Text; HexB: Text): Decimal
    var
        LumA: Decimal;
        LumB: Decimal;
    begin
        LumA := Luminance(HexA);
        LumB := Luminance(HexB);
        if LumA < LumB then
            exit((LumB + 0.05) / (LumA + 0.05));
        exit((LumA + 0.05) / (LumB + 0.05));
    end;

    /// Moves the colour towards white; Strength 1 keeps it, 0 gives white.
    procedure Tint(Hex: Text; Strength: Decimal): Text
    begin
        exit(Mix(Hex, 'FFFFFF', 1 - Strength));
    end;

    /// Blends Hex towards Target by Amount (0 = Hex, 1 = Target).
    procedure Mix(Hex: Text; Target: Text; Amount: Decimal): Text
    var
        Channel: Integer;
        Value: Integer;
        Result: Text;
    begin
        for Channel := 0 to 2 do begin
            Value := Round(ChannelOf(Hex, Channel) + (ChannelOf(Target, Channel) - ChannelOf(Hex, Channel)) * Amount, 1);
            Result += ToHex(Value);
        end;
        exit(Result);
    end;

    local procedure ValidOr(Value: Text; Fallback: Text; var Notes: List of [Text]): Text
    var
        Hex: Text;
    begin
        if TryNormalizeHex(Value, Hex) then
            exit(Hex);
        if not Notes.Contains(MissingColorTxt) then
            Notes.Add(MissingColorTxt);
        exit(Fallback);
    end;

    /// Darkens Hex in steps until it reaches MinRatio against Background; true if it had to change.
    local procedure Darken(var Hex: Text; Background: Text; MinRatio: Decimal): Boolean
    var
        Original: Text;
        Step: Integer;
    begin
        Original := Hex;
        while (ContrastRatio(Hex, Background) < MinRatio) and (Step < 20) do begin
            Step += 1;
            Hex := Mix(Original, '000000', Step * 0.05);
        end;
        exit(Hex <> Original);
    end;

    local procedure Luminance(Hex: Text): Decimal
    begin
        exit(0.2126 * Linear(ChannelOf(Hex, 0)) + 0.7152 * Linear(ChannelOf(Hex, 1)) + 0.0722 * Linear(ChannelOf(Hex, 2)));
    end;

    local procedure Linear(Channel: Integer): Decimal
    var
        Value: Decimal;
    begin
        Value := Channel / 255;
        if Value <= 0.03928 then
            exit(Value / 12.92);
        exit(Power((Value + 0.055) / 1.055, 2.4));
    end;

    local procedure ChannelOf(Hex: Text; Channel: Integer): Integer
    begin
        exit(HexDigit(Hex[Channel * 2 + 1]) * 16 + HexDigit(Hex[Channel * 2 + 2]));
    end;

    local procedure HexDigit(Digit: Char): Integer
    begin
        exit(StrPos('0123456789ABCDEF', UpperCase(Format(Digit))) - 1);
    end;

    local procedure ToHex(Value: Integer): Text
    var
        Digits: Text;
    begin
        Digits := '0123456789ABCDEF';
        if Value < 0 then
            Value := 0;
        if Value > 255 then
            Value := 255;
        exit(Format(Digits[Value div 16 + 1]) + Format(Digits[Value mod 16 + 1]));
    end;
}
