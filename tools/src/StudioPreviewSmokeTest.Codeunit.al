namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;
using System.Reflection;
using System.Utilities;

/// Headless check of the studio preview: renders with a per-user theme and leaves no trace.
codeunit 50106 "Studio Preview Smoke Test"
{
    trigger OnRun()
    var
        Config: Record "Report Style Config";
        TenantReportLayoutCfg: Record "Tenant Report Layout Cfg";
        Selection: Record "Tenant Report Layout Selection";
        ReportLayoutList: Record "Report Layout List";
        Runner: Codeunit "Report Style Designer Runner";
        StudioMgt: Codeunit "Report Style Designer Mgt.";
        Pdf: Codeunit "Temp Blob";
        PdfFile: File;
        PdfOutStream: OutStream;
        ThemeBefore: Text;
        Started: DateTime;
    begin
        TenantReportLayoutCfg.Get(114, '00000000-0000-0000-0000-000000000000::Approved', '');
        ThemeBefore := TenantReportLayoutCfg."Theme Part Name";

        StudioMgt.GetConfig(Config);
        StudioMgt.ApplyState(Config, '{"reportId":114,"layoutName":"Approved","layoutAppId":"00000000-0000-0000-0000-000000000000","baseTheme":"DefaultTheme","palette":2,"fonts":2,"size":9,"pageColor":3}');
        Commit();

        Started := CurrentDateTime();
        if not Runner.Preview(Config) then
            Error('FAIL: preview failed: %1', Runner.GetErrorText());
        Runner.GetPdf(Pdf);


        TenantReportLayoutCfg.Get(114, '00000000-0000-0000-0000-000000000000::Approved', '');
        if TenantReportLayoutCfg."Theme Part Name" <> ThemeBefore then
            Error('FAIL: shared theme assignment changed to %1', TenantReportLayoutCfg."Theme Part Name");
        Selection.SetRange("Report ID", 114);
        Selection.SetRange("User ID", UserSecurityId());
        if not Selection.IsEmpty() then
            Error('FAIL: user layout selection left behind');
        ReportLayoutList.SetFilter("Report ID", '%1|%2', 114, 2000000001);
        ReportLayoutList.SetFilter(Name, 'Preview *');
        if not ReportLayoutList.IsEmpty() then
            Error('FAIL: preview layout or theme part left behind');
        TenantReportLayoutCfg.Reset();
        TenantReportLayoutCfg.SetFilter("Layout Name", '*Preview *');
        if not TenantReportLayoutCfg.IsEmpty() then
            Error('FAIL: preview theme assignment left behind');

        PdfFile.Create(TemporaryPath + 'themegen-studio.pdf');
        PdfFile.CreateOutStream(PdfOutStream);
        CopyStream(PdfOutStream, Pdf.CreateInStream());
        PdfFile.Close();
        Message('STUDIO PREVIEW OK: %1 bytes in %2 ms; shared theme still %3; cleanup retried: %4', Pdf.Length(), CurrentDateTime() - Started, ThemeBefore, Runner.GetCleanupErrorText() <> '');
    end;
}
