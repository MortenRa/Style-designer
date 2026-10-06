namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;
using System.Utilities;

/// Headless run of the configurator page's Apply and Preview, for Invoke-NAVCodeunit.
codeunit 50103 "Configurator Smoke Test"
{
    trigger OnRun()
    var
        Config: Record "Report Style Config" temporary;
        TenantReportLayout: Record "Tenant Report Layout";
        TenantReportLayoutCfg: Record "Tenant Report Layout Cfg";
        Selection: Record "Tenant Report Layout Selection";
        ConfiguratorMgt: Codeunit "Report Style Configurator Mgt.";
        Pdf: Codeunit "Temp Blob";
        PdfFile: File;
        PdfOutStream: OutStream;
        EmptyGuid: Guid;
        HadSelectionBefore: Boolean;
    begin
        HadSelectionBefore := Selection.Get(114, CompanyName(), EmptyGuid);
        if TenantReportLayoutCfg.Get(114, '00000000-0000-0000-0000-000000000000::Approved', '') then
            OriginalTheme := TenantReportLayoutCfg."Theme Part Name";

        Config.Init();
        Config."Base Theme" := 'Default';
        Config."Theme Name" := 'Smoke Test Theme';
        Config.Palette := Config.Palette::Nature;
        Config."Font Pair" := Config."Font Pair"::GeorgiaVerdana;
        Config."Base Font Size" := 9;
        Config."Page Color" := Config."Page Color"::SoftGreen;
        Config."Target Report ID" := 114;
        Config."Target Layout Name" := 'Approved';
        Config."Assign To" := Config."Assign To"::Layout;

        ConfiguratorMgt.ApplyAndRenderPdf(Config, Pdf);

        if not TenantReportLayout.Get(2000000001, 'Smoke Test Theme', EmptyGuid) then
            Error('FAIL: theme part not stored');
        if TenantReportLayout."Layout Subtype" <> TenantReportLayout."Layout Subtype"::Theme then
            Error('FAIL: stored part is not a Theme');
        if TenantReportLayout."Layout Status" <> TenantReportLayout."Layout Status"::Approved then
            Error('FAIL: stored part is not Approved');
        if not TenantReportLayoutCfg.Get(114, '00000000-0000-0000-0000-000000000000::Approved', '') then
            Error('FAIL: no layout cfg row');
        if TenantReportLayoutCfg."Theme Part Name" <> '00000000-0000-0000-0000-000000000000::Smoke Test Theme' then
            Error('FAIL: cfg theme is %1', TenantReportLayoutCfg."Theme Part Name");
        if Selection.Get(114, CompanyName(), EmptyGuid) <> HadSelectionBefore then
            Error('FAIL: layout selection was not restored');
        if Pdf.Length() < 1000 then
            Error('FAIL: PDF is only %1 bytes', Pdf.Length());

        PdfFile.Create(TemporaryPath + 'themegen-smoke.pdf');
        PdfFile.CreateOutStream(PdfOutStream);
        CopyStream(PdfOutStream, Pdf.CreateInStream());
        PdfFile.Close();

        // Put report 114 back the way it was.
        TenantReportLayoutCfg."Theme Part Name" := OriginalTheme;
        TenantReportLayoutCfg.Modify(true);
        TenantReportLayout.Delete(true);
        Message('SMOKE OK, PDF %1 bytes, theme restored to %2', Pdf.Length(), OriginalTheme);
    end;

    var
        OriginalTheme: Text[300];
}
