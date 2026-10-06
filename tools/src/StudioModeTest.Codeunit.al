namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;
using System.Utilities;

/// Checks that theme and header/footer are saved independently (keep / default / custom, per layout or company).
/// Snapshots all Tenant Report Layout Cfg rows first and restores them at the end.
codeunit 50113 "Studio Mode Test"
{
    var
        Snapshot: Record "Tenant Report Layout Cfg" temporary;
        StudioMgt: Codeunit "Report Style Designer Mgt.";
        Passed: Integer;
        LayoutKeyTok: Label '00000000-0000-0000-0000-000000000000::Approved', Locked = true;
        RefTok: Label '00000000-0000-0000-0000-000000000000::%1', Locked = true;

    trigger OnRun()
    var
        Failure: Text;
    begin
        TakeSnapshot();
        if not Codeunit.Run(Codeunit::"Studio Mode Test Cases") then
            Failure := GetLastErrorText();
        RestoreSnapshot();
        if Failure <> '' then
            Error(Failure);
        Message('MODE TESTS PASSED');
    end;

    local procedure TakeSnapshot()
    var
        Cfg: Record "Tenant Report Layout Cfg";
    begin
        if Cfg.FindSet() then
            repeat
                Snapshot := Cfg;
                Snapshot.Insert();
            until Cfg.Next() = 0;
    end;

    local procedure RestoreSnapshot()
    var
        Cfg: Record "Tenant Report Layout Cfg";
        TenantReportLayout: Record "Tenant Report Layout";
    begin
        Cfg.DeleteAll();
        if Snapshot.FindSet() then
            repeat
                Cfg := Snapshot;
                Cfg.Insert();
            until Snapshot.Next() = 0;
        TenantReportLayout.SetRange("Report ID", 2000000001);
        TenantReportLayout.SetFilter(Name, '%1|%2', 'Mode Test Theme', 'Mode Test HF');
        TenantReportLayout.DeleteAll();
        Commit();
    end;
}

codeunit 50114 "Studio Mode Test Cases"
{
    var
        StudioMgt: Codeunit "Report Style Designer Mgt.";
        LayoutKeyTok: Label '00000000-0000-0000-0000-000000000000::Approved', Locked = true;
        RefTok: Label '00000000-0000-0000-0000-000000000000::%1', Locked = true;

    trigger OnRun()
    var
        Cfg: Record "Tenant Report Layout Cfg";
        ThemeBefore: Text;
        HeaderBefore: Text;
    begin
        Cfg.Get(114, LayoutKeyTok, '');
        ThemeBefore := Cfg."Theme Part Name";
        HeaderBefore := Cfg."Header Part Name";

        // a) keep theme, choose header -> only the header changes
        Save('keep', 'custom', 'InternalDefaultHFDesign', 'layout');
        Cfg.Get(114, LayoutKeyTok, '');
        Check(Cfg."Theme Part Name" = ThemeBefore, 'a) theme must be unchanged, got ' + Cfg."Theme Part Name");
        Check(Cfg."Header Part Name" = StrSubstNo(RefTok, 'InternalDefaultHFDesign'), 'a) header, got ' + Cfg."Header Part Name");

        // b) default theme, keep header -> theme cleared, header kept
        Save('default', 'keep', '', 'layout');
        Cfg.Get(114, LayoutKeyTok, '');
        Check(Cfg."Theme Part Name" = '', 'b) theme must be cleared, got ' + Cfg."Theme Part Name");
        Check(Cfg."Header Part Name" = StrSubstNo(RefTok, 'InternalDefaultHFDesign'), 'b) header must be kept, got ' + Cfg."Header Part Name");

        // c) default header too -> row has nothing left and is removed
        Save('keep', 'default', '', 'layout');
        Check(not Cfg.Get(114, LayoutKeyTok, ''), 'c) empty layout row must be removed');

        // d) custom theme as company default, header default -> company row with only the theme
        Save('custom', 'default', '', 'company');
        Check(Cfg.Get(0, '', CopyStr(CompanyName(), 1, 30)), 'd) company row must exist');
        Check(Cfg."Theme Part Name" = StrSubstNo(RefTok, 'Mode Test Theme'), 'd) company theme, got ' + Cfg."Theme Part Name");
        Check(Cfg."Header Part Name" = '', 'd) company header must be empty, got ' + Cfg."Header Part Name");

        // f) a design owned by an app (as BaseApp's designs are in SaaS) is referenced with that app's ID, not the
        //    empty GUID; the platform rejects the wrong ID with "must reference a Header/Footer-subtype layout".
        Save('keep', 'custom', 'RSDTestHFDesign', 'layout');
        Cfg.Get(114, LayoutKeyTok, '');
        Check(Cfg."Header Part Name".EndsWith('::RSDTestHFDesign'), 'f) header, got ' + Cfg."Header Part Name");
        Check(not Cfg."Header Part Name".StartsWith('00000000-0000-0000-0000-000000000000'), 'f) app-owned design saved with the empty app ID: ' + Cfg."Header Part Name");

        // g) the old behaviour (empty app ID for an app-owned design) reproduces the sandbox error
        asserterror SetHeaderDirectly('00000000-0000-0000-0000-000000000000::RSDTestHFDesign');
        Check(GetLastErrorText().Contains('must reference a Header/Footer-subtype layout'), 'g) expected the sandbox error, got ' + GetLastErrorText());

        // h) design your own: the generated header/footer is stored as a HeaderFooter part and assigned
        Save('keep', 'design', '', 'layout');
        Cfg.Get(114, LayoutKeyTok, '');
        Check(Cfg."Header Part Name" = StrSubstNo(RefTok, 'Mode Test HF'), 'h) designed header, got ' + Cfg."Header Part Name");
        Check(IsHeaderFooterPart('Mode Test HF'), 'h) designed part must be a HeaderFooter part');

        // e) keep + keep -> refused
        asserterror Save('keep', 'keep', '', 'layout');
        Check(GetLastErrorText().Contains('Nothing to apply'), 'e) expected "Nothing to apply", got ' + GetLastErrorText());
    end;

    local procedure Save(ThemeMode: Text; HeaderMode: Text; HeaderPart: Text; ApplyTo: Text)
    var
        Config: Record "Report Style Config" temporary;
    begin
        Config.Init();
        Config."Target Report ID" := 114;
        Config."Target Layout Name" := 'Approved';
        Config."Base Theme" := 'DefaultTheme';
        Config."Theme Name" := 'Mode Test Theme';
        Config.Palette := Config.Palette::Ocean;
        Config."Theme Mode" := CopyStr(ThemeMode, 1, 10);
        Config."Header Mode" := CopyStr(HeaderMode, 1, 10);
        Config."Header Part" := CopyStr(HeaderPart, 1, 250);
        Config."Apply To" := CopyStr(ApplyTo, 1, 10);
        Config."HF Name" := 'Mode Test HF';
        Config."HF Logo" := 'left';
        Config."HF Page Number" := 'footer';
        Config."HF Accent Line" := true;
        Config.Insert();
        StudioMgt.Save(Config, 'apply');
    end;

    local procedure IsHeaderFooterPart(Name: Text[250]): Boolean
    var
        TenantReportLayout: Record "Tenant Report Layout";
        EmptyGuid: Guid;
    begin
        if not TenantReportLayout.Get(2000000001, Name, EmptyGuid) then
            exit(false);
        exit(TenantReportLayout."Layout Subtype" = TenantReportLayout."Layout Subtype"::HeaderFooter);
    end;

    local procedure SetHeaderDirectly(HeaderRef: Text)
    var
        Cfg: Record "Tenant Report Layout Cfg";
    begin
        Cfg.Get(114, LayoutKeyTok, '');
        Cfg."Header Part Name" := CopyStr(HeaderRef, 1, MaxStrLen(Cfg."Header Part Name"));
        Cfg.Modify(true);
    end;

    local procedure Check(Condition: Boolean; What: Text)
    begin
        if not Condition then
            Error('FAIL: %1', What);
    end;
}
