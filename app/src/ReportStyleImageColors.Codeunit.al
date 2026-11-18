namespace Abakion.ReportStyleDesigner;

using System.Utilities;

/// Reads the main colours and the mood of a picture on the server, for Copilot: the picture is made small and saved as
/// an uncompressed BMP, whose pixels AL can read. Only the colours and a few mood words are used; the picture is never
/// sent to Copilot. The same rules as the designer's browser code (studio.js): near-white and transparent pixels are
/// not main colours, and colours closer than 90 (sum of RGB differences) count as one.
codeunit 50140 "Report Style Image Colors"
{
    Access = Internal;

    var
        SampleSize: Integer;
        MaxColors: Integer;

    /// False when the file is not a picture Business Central can read.
    procedure Analyse(PictureStream: InStream; var Colors: List of [Text]; var Mood: Text): Boolean
    var
        Picture: Codeunit Image;
        Bitmap: Codeunit "Temp Blob";
        BitmapStream: InStream;
        OutStream: OutStream;
    begin
        Clear(Colors);
        Mood := '';
        SampleSize := 48;
        MaxColors := 5;
        if not TryLoad(Picture, PictureStream) then
            exit(false);
        if not TryShrinkToBitmap(Picture, Bitmap, OutStream) then
            exit(false);
        Bitmap.CreateInStream(BitmapStream);
        exit(ReadBitmap(BitmapStream, Colors, Mood));
    end;

    [TryFunction]
    local procedure TryLoad(var Picture: Codeunit Image; PictureStream: InStream)
    begin
        Picture.FromStream(PictureStream);
    end;

    [TryFunction]
    local procedure TryShrinkToBitmap(var Picture: Codeunit Image; var Bitmap: Codeunit "Temp Blob"; var OutStream: OutStream)
    var
        Width: Integer;
        Height: Integer;
    begin
        Width := Picture.GetWidth();
        Height := Picture.GetHeight();
        if Width >= Height then
            Picture.Resize(SampleSize, MaxValue(1, Round(SampleSize * Height / Width, 1)))
        else
            Picture.Resize(MaxValue(1, Round(SampleSize * Width / Height, 1)), SampleSize);
        Picture.SetFormat(Enum::"Image Format"::Bmp);
        Bitmap.CreateOutStream(OutStream);
        Picture.Save(OutStream);
    end;

    local procedure ReadBitmap(BitmapStream: InStream; var Colors: List of [Text]; var Mood: Text): Boolean
    var
        Bytes: List of [Integer];
        Buckets: Dictionary of [Integer, Integer];
        SumR: Dictionary of [Integer, Integer];
        SumG: Dictionary of [Integer, Integer];
        SumB: Dictionary of [Integer, Integer];
        DataOffset: Integer;
        Width: Integer;
        Height: Integer;
        BitsPerPixel: Integer;
        RowSize: Integer;
        X: Integer;
        Y: Integer;
        Pos: Integer;
        R: Integer;
        G: Integer;
        B: Integer;
        A: Integer;
        UsesAlpha: Boolean;
        Counted: Integer;
        ColourPixels: Integer;
        Light: Decimal;
        Sat: Decimal;
        Warm: Decimal;
        MaxC: Integer;
        MinC: Integer;
        BucketKey: Integer;
    begin
        ReadAll(BitmapStream, Bytes);
        if (Bytes.Count() < 54) or (Bytes.Get(1) <> 66) or (Bytes.Get(2) <> 77) then // "BM"
            exit(false);
        DataOffset := LittleEndian(Bytes, 11, 4);
        Width := LittleEndian(Bytes, 19, 4);
        Height := Abs(SignedLittleEndian(Bytes, 23));
        BitsPerPixel := LittleEndian(Bytes, 29, 2);
        if not (BitsPerPixel in [24, 32]) then
            exit(false);
        RowSize := ((BitsPerPixel * Width + 31) div 32) * 4;

        // A 32-bit bitmap only has real transparency when some pixel is not fully opaque.
        if BitsPerPixel = 32 then
            for Y := 0 to Height - 1 do
                for X := 0 to Width - 1 do begin
                    Pos := DataOffset + Y * RowSize + X * 4 + 1;
                    if Pos + 3 <= Bytes.Count() then
                        if Bytes.Get(Pos + 3) < 255 then
                            UsesAlpha := true;
                end;

        for Y := 0 to Height - 1 do
            for X := 0 to Width - 1 do begin
                Pos := DataOffset + Y * RowSize + X * (BitsPerPixel div 8) + 1;
                if Pos + 2 <= Bytes.Count() then begin
                    B := Bytes.Get(Pos);
                    G := Bytes.Get(Pos + 1);
                    R := Bytes.Get(Pos + 2);
                    A := 255;
                    if UsesAlpha then
                        A := Bytes.Get(Pos + 3);
                    if A >= 128 then begin
                        MaxC := MaxValue(R, MaxValue(G, B));
                        MinC := MinValue(R, MinValue(G, B));
                        Counted += 1;
                        Light += (MaxC + MinC) / 510;
                        if MaxC > 0 then
                            Sat += (MaxC - MinC) / MaxC;
                        Warm += (R - B) / 255;
                        // White and pale grey are background, not a main colour.
                        if not ((MinC > 215) and (MaxC - MinC < 20)) then begin
                            BucketKey := (R div 16) * 256 + (G div 16) * 16 + (B div 16);
                            AddTo(Buckets, BucketKey, 1);
                            AddTo(SumR, BucketKey, R);
                            AddTo(SumG, BucketKey, G);
                            AddTo(SumB, BucketKey, B);
                            ColourPixels += 1;
                        end;
                    end;
                end;
            end;
        if Counted = 0 then
            exit(false);
        PickColors(Buckets, SumR, SumG, SumB, ColourPixels, Colors);
        Mood := MoodWords(Light / Counted, Sat / Counted, Warm / Counted);
        exit(true);
    end;

    // Most used first; a bucket under 2 % of the coloured pixels or close to a picked colour is skipped.
    local procedure PickColors(Buckets: Dictionary of [Integer, Integer]; SumR: Dictionary of [Integer, Integer]; SumG: Dictionary of [Integer, Integer]; SumB: Dictionary of [Integer, Integer]; Total: Integer; var Colors: List of [Text])
    var
        PickedR: List of [Integer];
        PickedG: List of [Integer];
        PickedB: List of [Integer];
        Used: List of [Integer];
        BucketKey: Integer;
        BestKey: Integer;
        BestCount: Integer;
        N: Integer;
        R: Integer;
        G: Integer;
        B: Integer;
        I: Integer;
        Near: Boolean;
    begin
        while Colors.Count() < MaxColors do begin
            BestCount := 0;
            foreach BucketKey in Buckets.Keys() do
                if not Used.Contains(BucketKey) then
                    if Buckets.Get(BucketKey) > BestCount then begin
                        BestCount := Buckets.Get(BucketKey);
                        BestKey := BucketKey;
                    end;
            if (BestCount = 0) or (BestCount < Total * 0.02) then
                exit;
            Used.Add(BestKey);
            N := Buckets.Get(BestKey);
            R := Round(SumR.Get(BestKey) / N, 1);
            G := Round(SumG.Get(BestKey) / N, 1);
            B := Round(SumB.Get(BestKey) / N, 1);
            Near := false;
            for I := 1 to PickedR.Count() do
                if Abs(PickedR.Get(I) - R) + Abs(PickedG.Get(I) - G) + Abs(PickedB.Get(I) - B) < 90 then
                    Near := true;
            if not Near then begin
                PickedR.Add(R);
                PickedG.Add(G);
                PickedB.Add(B);
                Colors.Add(Hex(R) + Hex(G) + Hex(B));
            end;
        end;
    end;

    /// Light or dark, muted or colourful, warm or cool; "balanced" when none of them stands out.
    procedure MoodWords(Light: Decimal; Sat: Decimal; Warm: Decimal) Words: Text
    begin
        if Light > 0.65 then
            Words := AddWord(Words, 'light')
        else
            if Light < 0.35 then
                Words := AddWord(Words, 'dark');
        if Sat < 0.2 then
            Words := AddWord(Words, 'muted')
        else
            if Sat > 0.45 then
                Words := AddWord(Words, 'colourful');
        if Warm > 0.06 then
            Words := AddWord(Words, 'warm')
        else
            if Warm < -0.06 then
                Words := AddWord(Words, 'cool');
        if Words = '' then
            Words := 'balanced';
    end;

    local procedure AddWord(Words: Text; Word: Text): Text
    begin
        if Words = '' then
            exit(Word);
        exit(Words + ', ' + Word);
    end;

    local procedure AddTo(var Sums: Dictionary of [Integer, Integer]; BucketKey: Integer; Value: Integer)
    begin
        if Sums.ContainsKey(BucketKey) then
            Sums.Set(BucketKey, Sums.Get(BucketKey) + Value)
        else
            Sums.Add(BucketKey, Value);
    end;

    local procedure ReadAll(BitmapStream: InStream; var Bytes: List of [Integer])
    var
        Value: Byte;
    begin
        while not BitmapStream.EOS() do begin
            BitmapStream.Read(Value);
            Bytes.Add(Value);
        end;
    end;

    // Bytes are 1-based in the list; Start is the 1-based position of the lowest byte.
    local procedure LittleEndian(Bytes: List of [Integer]; Start: Integer; Count: Integer) Value: Integer
    var
        I: Integer;
        Factor: Integer;
    begin
        Factor := 1;
        for I := 0 to Count - 1 do begin
            Value += Bytes.Get(Start + I) * Factor;
            if I < Count - 1 then
                Factor := Factor * 256;
        end;
    end;

    // A signed 32-bit value: a top-down bitmap stores its height as a negative number.
    local procedure SignedLittleEndian(Bytes: List of [Integer]; Start: Integer): Integer
    var
        Low: Integer;
        High: Integer;
    begin
        Low := LittleEndian(Bytes, Start, 3);
        High := Bytes.Get(Start + 3);
        if High >= 128 then
            exit(Low + (High - 256) * 16777216);
        exit(Low + High * 16777216);
    end;

    local procedure Hex(Value: Integer): Text
    var
        Digits: Text;
    begin
        Digits := '0123456789ABCDEF';
        exit(CopyStr(Digits, Value div 16 + 1, 1) + CopyStr(Digits, Value mod 16 + 1, 1));
    end;

    local procedure MaxValue(A: Integer; B: Integer): Integer
    begin
        if A > B then
            exit(A);
        exit(B);
    end;

    local procedure MinValue(A: Integer; B: Integer): Integer
    begin
        if A < B then
            exit(A);
        exit(B);
    end;
}
