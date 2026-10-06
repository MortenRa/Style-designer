namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;

/// One-off cleanup: replaces the old seeded theme and header/footer parts (names with spaces, e.g. "External Modern
/// Logo") by main's parts (e.g. "ExternalModernLogoHFDesign"). References are moved to main's part first, then the
/// seed is deleted. Also removes leftover preview rows, layouts and parts.
codeunit 50112 "Seed Cleanup"
{
    var
        Log: TextBuilder;

    trigger OnRun()
    begin
        Replace('Calm', 'CalmTheme');
        Replace('Default', 'DefaultTheme');
        Replace('Playful', 'PlayfulTheme');
        Replace('External Default', 'ExternalDefaultHFDesign');
        Replace('External Default Detailed', 'ExternalDefaultDetailedHFDesign');
        Replace('External Minimalistic', 'ExternalMinimalisticHFDesign');
        Replace('External Minimalistic Detailed', 'ExternalMinimalisticDetailedHFDesign');
        Replace('External Modern', 'ExternalModernHFDesign');
        Replace('External Modern Logo', 'ExternalModernLogoHFDesign');
        Replace('Internal Default', 'InternalDefaultHFDesign');
        Replace('Internal Minimalistic', 'InternalMinimalisticHFDesign');
        Replace('Internal Minimalistic Centered', 'InternalMinimalisticCenteredHFDesign');
        Replace('Internal Modern', 'InternalModernHFDesign');
        Replace('Internal Modern Maxi', 'InternalModernMaxiHFDesign');
        RemovePreviewLeftovers();
        Message('%1', Log.ToText());
    end;

    local procedure Replace(OldName: Text[250]; NewName: Text[250])
    var
        TenantReportLayout: Record "Tenant Report Layout";
        NewPart: Record "Tenant Report Layout";
        Cfg: Record "Tenant Report Layout Cfg";
        Selection: Record "Tenant Report Layout Selection";
        Config: Record "Report Style Config";
        EmptyGuid: Guid;
        OldRef: Text[300];
        OldAppRef: Text[300];
        NewRef: Text[300];
        Moved: Integer;
    begin
        // The seeds were stored with the Base Application's app ID; references may use either that or the empty GUID.
        TenantReportLayout.SetRange("Report ID", 2000000001);
        TenantReportLayout.SetRange(Name, OldName);
        if not TenantReportLayout.FindFirst() then begin
            Log.Append(StrSubstNo('%1: not found; ', OldName));
            exit;
        end;
        NewPart.Get(2000000001, NewName, EmptyGuid); // main's part must exist before anything is moved to it
        OldRef := CopyStr(LowerCase(Format(EmptyGuid, 0, 4)) + '::' + OldName, 1, 300);
        OldAppRef := CopyStr(LowerCase(Format(TenantReportLayout."App ID", 0, 4)) + '::' + OldName, 1, 300);
        NewRef := CopyStr(LowerCase(Format(EmptyGuid, 0, 4)) + '::' + NewName, 1, 300);

        if Cfg.FindSet() then
            repeat
                if (Cfg."Header Part Name" in [OldRef, OldAppRef]) or (Cfg."Theme Part Name" in [OldRef, OldAppRef]) then begin
                    if Cfg."Header Part Name" in [OldRef, OldAppRef] then
                        Cfg."Header Part Name" := NewRef;
                    if Cfg."Theme Part Name" in [OldRef, OldAppRef] then
                        Cfg."Theme Part Name" := NewRef;
                    Cfg.Modify(true);
                    Moved += 1;
                end;
            until Cfg.Next() = 0;
        if Selection.FindSet() then
            repeat
                if (Selection."Header Part Name" in [OldRef, OldAppRef]) or (Selection."Theme Part Name" in [OldRef, OldAppRef]) then begin
                    if Selection."Header Part Name" in [OldRef, OldAppRef] then
                        Selection."Header Part Name" := NewRef;
                    if Selection."Theme Part Name" in [OldRef, OldAppRef] then
                        Selection."Theme Part Name" := NewRef;
                    Selection.Modify();
                    Moved += 1;
                end;
            until Selection.Next() = 0;
        if Config.FindSet() then
            repeat
                if (Config."Base Theme" = OldName) or (Config."Header Part" = OldName) then begin
                    if Config."Base Theme" = OldName then
                        Config."Base Theme" := NewName;
                    if Config."Header Part" = OldName then
                        Config."Header Part" := NewName;
                    Config.Modify();
                end;
            until Config.Next() = 0;

        TenantReportLayout.Delete(true);
        Log.Append(StrSubstNo('%1 -> %2 (%3 refs moved); ', OldName, NewName, Moved));
    end;

    local procedure RemovePreviewLeftovers()
    var
        Selection: Record "Tenant Report Layout Selection";
        Cfg: Record "Tenant Report Layout Cfg";
        TenantReportLayout: Record "Tenant Report Layout";
        Removed: Integer;
    begin
        Selection.SetFilter("Layout Name", 'Preview *');
        Removed += Selection.Count();
        Selection.DeleteAll();
        Cfg.SetFilter("Layout Name", '*::Preview *');
        Removed += Cfg.Count();
        Cfg.DeleteAll();
        TenantReportLayout.SetFilter(Name, 'Preview *');
        Removed += TenantReportLayout.Count();
        TenantReportLayout.DeleteAll();
        Log.Append(StrSubstNo('preview leftovers removed: %1', Removed));
    end;
}
