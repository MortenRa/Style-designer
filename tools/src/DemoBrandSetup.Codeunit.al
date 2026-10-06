namespace Abakion.ReportStyleDesigner;

using System.Text;
using System.Utilities;

/// Local demo setup: puts a logo (base64 PNG) and a brand colour on Company Information, and puts the original back.
/// The original is kept in isolated storage. Company Information is read through RecordRef (no Base App dependency).
codeunit 50131 "Demo Brand Setup"
{
    var
        BackupLogoKeyTok: Label 'RSD-Demo-OriginalLogo', Locked = true;
        BackupBrandKeyTok: Label 'RSD-Demo-OriginalBrand', Locked = true;

    /// For Invoke-NAVCodeunit, which passes one argument: "#RRGGBB|<base64 png>".
    procedure SetBrandFromText(Value: Text)
    var
        Bar: Integer;
    begin
        Bar := StrPos(Value, '|');
        SetBrand(CopyStr(Value, Bar + 1), CopyStr(Value, 1, Bar - 1));
    end;

    procedure SetBrand(LogoBase64: Text; BrandHex: Text)
    var
        CompanyInformation: RecordRef;
        Base64Convert: Codeunit "Base64 Convert";
        TempBlob: Codeunit "Temp Blob";
        Original: Codeunit "Temp Blob";
        OutStr: OutStream;
        PictureField: FieldRef;
    begin
        CompanyInformation.Open(79);
        CompanyInformation.FindFirst();
        PictureField := CompanyInformation.Field(29);
        PictureField.CalcField();
        if not IsolatedStorage.Contains(BackupLogoKeyTok, DataScope::Company) then begin
            Original.FromFieldRef(PictureField);
            if Original.HasValue() then
                IsolatedStorage.Set(BackupLogoKeyTok, Base64Convert.ToBase64(Original.CreateInStream()), DataScope::Company)
            else
                IsolatedStorage.Set(BackupLogoKeyTok, '', DataScope::Company);
            IsolatedStorage.Set(BackupBrandKeyTok, Format(CompanyInformation.Field(300).Value()), DataScope::Company);
        end;
        TempBlob.CreateOutStream(OutStr);
        Base64Convert.FromBase64(LogoBase64, OutStr);
        TempBlob.ToFieldRef(PictureField);
        CompanyInformation.Field(300).Value := BrandHex;
        CompanyInformation.Modify();
        Message('Demo brand set: logo %1 bytes, brand colour %2. Original kept for RestoreBrand.', TempBlob.Length(), BrandHex);
    end;

    procedure RestoreBrand()
    var
        CompanyInformation: RecordRef;
        Base64Convert: Codeunit "Base64 Convert";
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        PictureField: FieldRef;
        LogoBase64: Text;
        BrandHex: Text;
    begin
        if not IsolatedStorage.Get(BackupLogoKeyTok, DataScope::Company, LogoBase64) then
            Error('No original logo was kept.');
        IsolatedStorage.Get(BackupBrandKeyTok, DataScope::Company, BrandHex);
        CompanyInformation.Open(79);
        CompanyInformation.FindFirst();
        PictureField := CompanyInformation.Field(29);
        if LogoBase64 <> '' then begin
            TempBlob.CreateOutStream(OutStr);
            Base64Convert.FromBase64(LogoBase64, OutStr);
        end;
        TempBlob.ToFieldRef(PictureField);
        CompanyInformation.Field(300).Value := BrandHex;
        CompanyInformation.Modify();
        IsolatedStorage.Delete(BackupLogoKeyTok, DataScope::Company);
        IsolatedStorage.Delete(BackupBrandKeyTok, DataScope::Company);
        Message('Original logo and brand colour restored.');
    end;
}
