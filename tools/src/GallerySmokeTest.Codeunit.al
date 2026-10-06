namespace Abakion.ReportStyleDesigner;

using System.Reflection;
using System.Utilities;

/// "Your documents" gallery: renders the current draft on every Body layout and checks that the selected document
/// and the saved draft are left exactly as they were.
codeunit 50126 "Gallery Smoke Test"
{
    trigger OnRun()
    var
        Config: Record "Report Style Config";
        After: Record "Report Style Config";
        GalleryRec: Record "Report Style Config" temporary;
        ReportLayoutList: Record "Report Layout List";
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Runner: Codeunit "Report Style Designer Runner";
        Pdf: Codeunit "Temp Blob";
        Rendered: Integer;
        Report114: Boolean;
    begin
        DesignerMgt.GetConfig(Config);
        Commit();
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Body);
        if ReportLayoutList.FindSet() then
            repeat
                DesignerMgt.GalleryConfig(Config, ReportLayoutList."Report ID", ReportLayoutList.Name, Format(ReportLayoutList."Application ID"), GalleryRec);
                if not Runner.Preview(GalleryRec) then
                    Error('Gallery render failed for %1 %2: %3', ReportLayoutList."Report ID", ReportLayoutList.Name, Runner.GetErrorText());
                Runner.GetPdf(Pdf);
                if Pdf.Length() < 1000 then
                    Error('Gallery render of %1 is empty', ReportLayoutList."Report ID");
                if ReportLayoutList."Report ID" = 114 then
                    Report114 := true;
                Rendered += 1;
            until ReportLayoutList.Next() = 0;

        After.Get();
        if (After."Target Report ID" <> Config."Target Report ID") or (After."Target Layout Name" <> Config."Target Layout Name") then
            Error('The gallery changed the selected document: %1 %2', After."Target Report ID", After."Target Layout Name");
        if After."Custom Colors" <> Config."Custom Colors" then
            Error('The gallery changed the draft');
        Message('GALLERY OK: %1 documents rendered (report 114 included: %2); selected document unchanged', Rendered, Report114);
    end;
}
