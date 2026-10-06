namespace Abakion.ReportStyleDesigner;

using System.Environment.Configuration;

/// Imports the layouts extracted from BCApps main (main-layouts\manifest.txt in the session temp folder)
/// as approved tenant layouts under their main names, and writes import-result.txt next to it.
codeunit 50107 "Main Layout Importer"
{
    trigger OnRun()
    var
        Item: Codeunit "Main Layout Import Item";
        ManifestFile: File;
        ResultFile: File;
        ManifestInStream: InStream;
        ResultOutStream: OutStream;
        Line: Text;
        Parts: List of [Text];
        Folder: Text;
        Imported: Integer;
        Failed: Integer;
    begin
        Folder := TemporaryPath + 'main-layouts\';
        ManifestFile.TextMode(true);
        ManifestFile.Open(Folder + 'manifest.txt');
        ManifestFile.CreateInStream(ManifestInStream);
        ResultFile.Create(Folder + 'import-result.txt');
        ResultFile.CreateOutStream(ResultOutStream);

        while not ManifestInStream.EOS() do begin
            ManifestInStream.ReadText(Line);
            Line := Line.Trim();
            if Line <> '' then begin
                Parts := Line.Split('|');
                Clear(Item);
                Item.SetItem(Folder, Parts);
                Commit();
                if Item.Run() then begin
                    Imported += 1;
                    ResultOutStream.WriteText('OK    ' + Line);
                end else begin
                    Failed += 1;
                    ResultOutStream.WriteText('FAIL  ' + Line + '  ->  ' + GetLastErrorText());
                end;
                ResultOutStream.WriteText();
            end;
        end;
        ManifestFile.Close();
        ResultFile.Close();
        Message('IMPORT DONE: %1 imported, %2 failed', Imported, Failed);
    end;
}

codeunit 50109 "Main Layout Import Item"
{
    var
        Folder: Text;
        ReportID: Integer;
        LayoutName: Text[250];
        Subtype: Text;
        Caption: Text[250];
        FileName: Text;

    procedure SetItem(NewFolder: Text; Parts: List of [Text])
    begin
        Folder := NewFolder;
        Evaluate(ReportID, Parts.Get(1));
        LayoutName := CopyStr(Parts.Get(2), 1, 250);
        Subtype := Parts.Get(3);
        Caption := CopyStr(Parts.Get(4), 1, 250);
        FileName := Parts.Get(5);
    end;

    trigger OnRun()
    var
        TenantReportLayout: Record "Tenant Report Layout";
        LayoutFile: File;
        LayoutInStream: InStream;
        EmptyGuid: Guid;
    begin
        if TenantReportLayout.Get(ReportID, LayoutName, EmptyGuid) then
            TenantReportLayout.Delete(true);

        TenantReportLayout.Init();
        TenantReportLayout."Report ID" := ReportID;
        TenantReportLayout.Name := LayoutName;
        TenantReportLayout.Description := Caption;
        TenantReportLayout."Layout Format" := TenantReportLayout."Layout Format"::Word;
        case Subtype of
            'Theme':
                begin
                    TenantReportLayout."Layout Subtype" := TenantReportLayout."Layout Subtype"::Theme;
                    TenantReportLayout."MIME Type" := 'application/vnd.openxmlformats-officedocument.wordprocessingml.template';
                end;
            'HeaderFooter':
                begin
                    TenantReportLayout."Layout Subtype" := TenantReportLayout."Layout Subtype"::HeaderFooter;
                    TenantReportLayout."MIME Type" := 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
                end;
            'Body':
                begin
                    TenantReportLayout."Layout Subtype" := TenantReportLayout."Layout Subtype"::Body;
                    TenantReportLayout."MIME Type" := 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
                end;
            else
                Error('Unknown subtype %1', Subtype);
        end;
        TenantReportLayout."Layout Status" := TenantReportLayout."Layout Status"::Approved;
        LayoutFile.Open(Folder + FileName);
        LayoutFile.CreateInStream(LayoutInStream);
        TenantReportLayout.Layout.ImportStream(LayoutInStream, FileName);
        LayoutFile.Close();
        TenantReportLayout.Insert(true);
    end;
}
