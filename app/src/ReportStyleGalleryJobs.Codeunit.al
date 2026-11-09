namespace Abakion.ReportStyleDesigner;

using System.Utilities;

/// "Your documents" in the background: queues one job per document and renders them in a background session
/// (no UI, so no "Working on it" dialogs). The designer polls for finished pages.
/// OnRun is the background session: it renders the jobs of one batch, one after another.
codeunit 50127 "Report Style Gallery Jobs"
{
    Access = Internal;
    TableNo = "Report Style Gallery Job";

    trigger OnRun()
    var
        Job: Record "Report Style Gallery Job";
    begin
        Job.SetCurrentKey("User Security ID", "Batch ID");
        Job.SetRange("User Security ID", Rec."User Security ID");
        Job.SetRange("Batch ID", Rec."Batch ID");
        Job.SetRange(Status, Job.Status::Pending);
        // A newer batch deletes these rows, which simply ends this loop.
        while Job.FindFirst() do
            RenderJob(Job."Entry No.");
    end;

    /// Queues the documents (JSON array of {reportId, name, appId, seq}) and starts the background session.
    /// False when no background session could be started; the caller then renders in the foreground.
    procedure StartBatch(StateText: Text; DocsText: Text; var BatchID: Guid): Boolean
    var
        Job: Record "Report Style Gallery Job";
        Docs: JsonArray;
        Doc: JsonToken;
        StateOutStream: OutStream;
        SessionID: Integer;
        FirstEntryNo: Integer;
        StateToken: JsonToken;
    begin
        CancelBatches();
        BatchID := CreateGuid();
        if not Docs.ReadFrom(DocsText) then
            exit(true);
        foreach Doc in Docs do begin
            Job.Init();
            Job."Entry No." := 0;   // Init keeps the key; 0 lets AutoIncrement number the row
            Job."User Security ID" := UserSecurityId();
            Job."Batch ID" := BatchID;
            Job.Seq := IntOf(Doc, 'seq');
            Job."Report ID" := IntOf(Doc, 'reportId');
            Job."Layout Name" := CopyStr(TextOf(Doc, 'name'), 1, MaxStrLen(Job."Layout Name"));
            Job."Layout App ID" := CopyStr(TextOf(Doc, 'appId'), 1, MaxStrLen(Job."Layout App ID"));
            Job.Status := Job.Status::Pending;
            Job.Created := CurrentDateTime();
            Job.State.CreateOutStream(StateOutStream, TextEncoding::UTF8);
            // A document may carry its own style (used to compare proposals); otherwise the batch style applies.
            if Doc.AsObject().Get('state', StateToken) and StateToken.IsValue() then
                StateOutStream.Write(StateToken.AsValue().AsText())
            else
                StateOutStream.Write(StateText);
            Job.Insert();
            if FirstEntryNo = 0 then
                FirstEntryNo := Job."Entry No.";
        end;
        Commit();
        if FirstEntryNo = 0 then
            exit(true);
        Job.Get(FirstEntryNo);
        if Session.StartSession(SessionID, Codeunit::"Report Style Gallery Jobs", CompanyName(), Job) then
            exit(true);
        CancelBatches();
        Commit();
        exit(false);
    end;

    /// Removes the current user's queued and finished jobs (a new batch replaces them), plus anything older than
    /// an hour from anyone (left behind by a closed designer).
    procedure CancelBatches()
    var
        Job: Record "Report Style Gallery Job";
    begin
        Job.SetRange("User Security ID", UserSecurityId());
        Job.DeleteAll();
        Job.Reset();
        Job.SetFilter(Created, '<%1', CurrentDateTime() - 3600000);
        Job.DeleteAll();
    end;

    local procedure RenderJob(EntryNo: Integer)
    var
        Job: Record "Report Style Gallery Job";
        Config: Record "Report Style Config";
        Draft: Record "Report Style Config" temporary;
        GalleryRec: Record "Report Style Config" temporary;
        DesignerMgt: Codeunit "Report Style Designer Mgt.";
        Runner: Codeunit "Report Style Designer Runner";
        Pdf: Codeunit "Temp Blob";
        PdfOutStream: OutStream;
        StateInStream: InStream;
        StateText: Text;
        Rendered: Boolean;
    begin
        Job.Get(EntryNo);
        Job.Status := Job.Status::Running;
        Job.Modify();
        Job.CalcFields(State);
        Job.State.CreateInStream(StateInStream, TextEncoding::UTF8);
        StateInStream.Read(StateText);
        Commit();

        // The style as the designer had it when the batch started, on temporary copies only.
        DesignerMgt.GetConfig(Config);
        Config.CalcFields("Report Parameters");
        Draft := Config;
        Draft.Insert();
        DesignerMgt.ApplyState(Draft, StateText);
        DesignerMgt.GalleryConfig(Draft, Job."Report ID", Job."Layout Name", Job."Layout App ID", GalleryRec);
        Commit();
        Rendered := Runner.Preview(GalleryRec);

        if not Job.Get(EntryNo) then
            exit;   // a newer batch took over
        if Rendered then begin
            Runner.GetPdf(Pdf);
            Job.Pdf.CreateOutStream(PdfOutStream);
            CopyStream(PdfOutStream, Pdf.CreateInStream());
            Job.Status := Job.Status::Done;
        end else begin
            Job."Error Text" := CopyStr(Runner.GetErrorText(), 1, MaxStrLen(Job."Error Text"));
            Job.Status := Job.Status::Failed;
        end;
        Job.Modify();
        Commit();
    end;

    local procedure IntOf(Token: JsonToken; Name: Text): Integer
    var
        Value: JsonToken;
    begin
        if Token.AsObject().Get(Name, Value) then
            if Value.IsValue() then
                exit(Value.AsValue().AsInteger());
    end;

    local procedure TextOf(Token: JsonToken; Name: Text): Text
    var
        Value: JsonToken;
    begin
        if Token.AsObject().Get(Name, Value) then
            if Value.IsValue() and not Value.AsValue().IsNull() then
                exit(Value.AsValue().AsText());
    end;
}
