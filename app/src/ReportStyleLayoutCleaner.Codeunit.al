namespace Abakion.ReportStyleDesigner;

using System.IO;
using System.Utilities;

/// Removes links to external files (for example the attached template Word adds when a document is saved on
/// someone's PC) from a Word layout before it is stored as a tenant layout. Newer platforms reject such layouts
/// ("UnsupportedExternalContentFields"), also when they are copies of layouts that work as app layouts.
/// Hyperlinks are kept: they are allowed.
codeunit 50116 "Report Style Layout Cleaner"
{
    Access = Internal;

    var
        ExternalRelationshipPatternTxt: Label '<Relationship\b(?![^>]*/hyperlink["''])[^>]*TargetMode=["'']External["''][^>]*/>', Locked = true;
        AttachedTemplatePatternTxt: Label '<w:attachedTemplate\b[^>]*/>', Locked = true;
        SettingsEntryTxt: Label 'word/settings.xml', Locked = true;

    /// Removes the external references from the Word package in Document. Returns true when something was removed.
    procedure RemoveExternalReferences(var Document: Codeunit "Temp Blob"): Boolean
    var
        Source: Codeunit "Data Compression";
        Target: Codeunit "Data Compression";
        Regex: Codeunit Regex;
        EntryBlob: Codeunit "Temp Blob";
        Cleaned: Codeunit "Temp Blob";
        Changed: Dictionary of [Text, Text];
        EntryNames: List of [Text];
        EntryName: Text;
        Xml: Text;
        CleanXml: Text;
        CleanedOutStream: OutStream;
    begin
        if not Source.IsZip(Document.CreateInStream()) then
            exit(false);
        Source.OpenZipArchive(Document.CreateInStream(), false);
        Source.GetEntryList(EntryNames);
        foreach EntryName in EntryNames do
            if EntryName.EndsWith('.rels') then begin
                Source.ExtractEntry(EntryName, EntryBlob);
                Xml := ReadText(EntryBlob);
                CleanXml := Regex.Replace(Xml, ExternalRelationshipPatternTxt, '');
                if CleanXml <> Xml then
                    Changed.Set(EntryName, CleanXml);
            end;
        if Changed.Count() = 0 then begin
            Source.CloseZipArchive();
            exit(false);
        end;
        // The attached template is referenced from the settings by relationship id; drop the element with it.
        if EntryNames.Contains(SettingsEntryTxt) then begin
            Source.ExtractEntry(SettingsEntryTxt, EntryBlob);
            Xml := ReadText(EntryBlob);
            CleanXml := Regex.Replace(Xml, AttachedTemplatePatternTxt, '');
            if CleanXml <> Xml then
                Changed.Set(SettingsEntryTxt, CleanXml);
        end;

        Target.CreateZipArchive();
        foreach EntryName in EntryNames do
            if not EntryName.EndsWith('/') then begin
                if Changed.ContainsKey(EntryName) then
                    WriteText(EntryBlob, Changed.Get(EntryName))
                else
                    Source.ExtractEntry(EntryName, EntryBlob);
                Target.AddEntry(EntryBlob.CreateInStream(), EntryName);
            end;
        Source.CloseZipArchive();
        Cleaned.CreateOutStream(CleanedOutStream);
        Target.SaveZipArchive(CleanedOutStream);
        Target.CloseZipArchive();
        Document := Cleaned;
        exit(true);
    end;

    local procedure ReadText(Blob: Codeunit "Temp Blob") Result: Text
    var
        BlobInStream: InStream;
        Line: Text;
    begin
        BlobInStream := Blob.CreateInStream(TextEncoding::UTF8);
        while not BlobInStream.EOS() do begin
            BlobInStream.Read(Line);
            Result += Line;
        end;
    end;

    local procedure WriteText(var Blob: Codeunit "Temp Blob"; Xml: Text)
    var
        BlobOutStream: OutStream;
    begin
        Clear(Blob);
        Blob.CreateOutStream(BlobOutStream, TextEncoding::UTF8);
        BlobOutStream.WriteText(Xml);
    end;
}
