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

        BackgroundBatch();

        After.Get();
        if (After."Target Report ID" <> Config."Target Report ID") or (After."Target Layout Name" <> Config."Target Layout Name") then
            Error('The gallery changed the selected document: %1 %2', After."Target Report ID", After."Target Layout Name");
        if After."Custom Colors" <> Config."Custom Colors" then
            Error('The gallery changed the draft');
        Message('GALLERY OK: %1 documents rendered in the foreground, %2 in the background (report 114 included: %3); selected document unchanged', Rendered, BackgroundDone, Report114);
    end;

    var
        BackgroundDone: Integer;

    // The real path: one background session renders the batch; this waits for it like the designer's polling.
    local procedure BackgroundBatch()
    var
        Config: Record "Report Style Config";
        Job: Record "Report Style Gallery Job";
        ReportLayoutList: Record "Report Layout List";
        GalleryJobs: Codeunit "Report Style Gallery Jobs";
        Docs: JsonArray;
        Doc: JsonObject;
        BatchID: Guid;
        DocsText: Text;
        Waited: Integer;
    begin
        Config.Get();
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Body);
        if ReportLayoutList.FindSet() then
            repeat
                Clear(Doc);
                Doc.Add('reportId', ReportLayoutList."Report ID");
                Doc.Add('name', ReportLayoutList.Name);
                Doc.Add('appId', Format(ReportLayoutList."Application ID"));
                Doc.Add('seq', Docs.Count() + 1);
                Docs.Add(Doc);
            until ReportLayoutList.Next() = 0;
        Docs.WriteTo(DocsText);
        if not GalleryJobs.StartBatch('{}', DocsText, BatchID) then
            Error('No background session could be started');

        Job.SetRange("Batch ID", BatchID);
        repeat
            Sleep(1000);
            Waited += 1;
            Job.SetFilter(Status, '%1|%2', Job.Status::Pending, Job.Status::Running);
        until Job.IsEmpty() or (Waited > 90);
        Job.SetRange(Status, Job.Status::Failed);
        if Job.FindFirst() then
            Error('Background render failed for %1: %2', Job."Report ID", Job."Error Text");
        Job.SetRange(Status, Job.Status::Done);
        BackgroundDone := Job.Count();
        if BackgroundDone <> Docs.Count() then
            Error('Background rendered %1 of %2 documents in %3 s', BackgroundDone, Docs.Count(), Waited);
        Job.SetRange(Status);
        Job.DeleteAll();
        Commit();
    end;
}
