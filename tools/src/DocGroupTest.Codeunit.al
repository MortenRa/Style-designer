namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;
using System.Reflection;

/// Document groups: every report with a Body layout lands in exactly one group, and "Apply to this group" assigns
/// the theme to every Body layout of the group and nothing else. Assignments are restored afterwards.
codeunit 50129 "Doc Group Test"
{
    var
        Snapshot: Record "Tenant Report Layout Cfg" temporary;
        TestThemeTok: Label 'Group Test Theme', Locked = true;

    trigger OnRun()
    var
        Cases: Codeunit "Doc Group Test Cases";
        Failure: Text;
    begin
        TakeSnapshot();
        Commit();
        if not Cases.Run() then
            Failure := GetLastErrorText();
        RestoreSnapshot();
        if Failure <> '' then
            Error(Failure);
        Message('DOC GROUPS OK: %1', Cases.GetSummary());
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
        TenantReportLayout.SetRange(Name, TestThemeTok);
        TenantReportLayout.DeleteAll();
        Commit();
    end;
}

codeunit 50130 "Doc Group Test Cases"
{
    var
        Summary: Text;
        TestThemeTok: Label 'Group Test Theme', Locked = true;

    trigger OnRun()
    begin
        Summary := GroupsCoverEveryReport();
        Summary += '; ' + ApplyToGroup();
        Summary += '; ' + SelectionsRead();
    end;

    procedure GetSummary(): Text
    begin
        exit(Summary);
    end;

    // Report Selections decide customer and vendor documents (before the Body-layout filter).
    local procedure SelectionsRead(): Text
    var
        DocGroups: Codeunit "Report Style Doc Groups";
        Customer: List of [Integer];
        Vendor: List of [Integer];
    begin
        DocGroups.ReadReportSelections(Customer, Vendor);
        if Customer.Count() = 0 then
            Error('No customer documents found in Report Selections');
        if Customer.Contains(1322) or Vendor.Contains(1306) then
            Error('A purchase order is a customer document or a sales invoice a vendor document');
        exit(StrSubstNo('Report Selections: %1 customer and %2 vendor reports (sales invoice 1306: %3, purchase order 1322: %4)',
            Customer.Count(), Vendor.Count(), Customer.Contains(1306), Vendor.Contains(1322)));
    end;

    local procedure GroupsCoverEveryReport() Summary: Text
    var
        ReportLayoutList: Record "Report Layout List";
        DocGroups: Codeunit "Report Style Doc Groups";
        Groups: JsonArray;
        Group: JsonToken;
        Value: JsonToken;
        Seen: Dictionary of [Integer, Text];
        ReportToken: JsonToken;
        GroupID: Text;
    begin
        Groups := DocGroups.GetGroups();
        foreach Group in Groups do begin
            Group.AsObject().Get('id', Value);
            GroupID := Value.AsValue().AsText();
            Group.AsObject().Get('reports', Value);
            foreach ReportToken in Value.AsArray() do begin
                if Seen.ContainsKey(ReportToken.AsValue().AsInteger()) then
                    Error('Report %1 is in two groups', ReportToken.AsValue().AsInteger());
                Seen.Add(ReportToken.AsValue().AsInteger(), GroupID);
            end;
            Summary += StrSubstNo('%1=%2 ', GroupID, Value.AsArray().Count());
        end;
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Body);
        if ReportLayoutList.FindSet() then
            repeat
                if not Seen.ContainsKey(ReportLayoutList."Report ID") then
                    Error('Report %1 has a Body layout but no group', ReportLayoutList."Report ID");
            until ReportLayoutList.Next() = 0;
    end;

    local procedure ApplyToGroup(): Text
    var
        Config: Record "Report Style Config" temporary;
        Saved: Record "Report Style Config";
        ReportLayoutList: Record "Report Layout List";
        Cfg: Record "Tenant Report Layout Cfg";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        DocGroups: Codeunit "Report Style Doc Groups";
        ConfiguratorMgt: Codeunit "Report Style Configurator Mgt.";
        Reports: List of [Integer];
        ReportID: Integer;
        Layouts: Integer;
        Expected: Text;
    begin
        DesignerMgt.GetConfig(Saved);
        Config := Saved;
        Config."Theme Mode" := 'custom';
        Config."Header Mode" := 'keep';
        Config."Base Theme" := 'DefaultTheme';
        Config."Theme Name" := TestThemeTok;
        Config."Apply To" := 'group';
        Config."Apply Group" := 'internal';
        Config.Insert();
        DesignerMgt.Save(Config, 'apply');

        Expected := '00000000-0000-0000-0000-000000000000::' + TestThemeTok;
        Reports := DocGroups.ReportsOf('internal');
        foreach ReportID in Reports do begin
            ReportLayoutList.SetRange("Report ID", ReportID);
            ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Body);
            if ReportLayoutList.FindSet() then
                repeat
                    if not Cfg.Get(ReportID, ConfiguratorMgt.EncodePartName(ReportLayoutList."Application ID", ReportLayoutList.Name), '') then
                        Error('No assignment for %1 %2', ReportID, ReportLayoutList.Name);
                    if Cfg."Theme Part Name" <> Expected then
                        Error('%1 %2 got theme %3', ReportID, ReportLayoutList.Name, Cfg."Theme Part Name");
                    Layouts += 1;
                until ReportLayoutList.Next() = 0;
        end;
        // Nothing outside the group, and no company default, may have changed.
        Cfg.Reset();
        Cfg.SetRange("Theme Part Name", Expected);
        if Cfg.Count() <> Layouts then
            Error('The group theme reached %1 assignments, expected %2', Cfg.Count(), Layouts);
        exit(StrSubstNo('internal group applied to %1 layouts of %2 reports', Layouts, Reports.Count()));
    end;

}
