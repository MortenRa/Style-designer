namespace Abakion.ReportStyleDesigner;

using System.Reflection;

/// Document groups: customer documents, vendor documents and internal reports, based on Report Selections
/// (the usages a company prints its documents with). Business Central has no group level for themes and
/// header/footers, so "Apply to this group" writes the same assignment for every Body layout of the group's reports.
codeunit 50128 "Report Style Doc Groups"
{
    Access = Internal;

    var
        ReportSelectionsTableTok: Label '77', Locked = true;
        CustomerTok: Label 'customer', Locked = true;
        VendorTok: Label 'vendor', Locked = true;
        InternalTok: Label 'internal', Locked = true;
        CustomerTxt: Label 'Customer documents';
        VendorTxt: Label 'Vendor documents';
        InternalTxt: Label 'Internal reports';

    /// The groups for the designer: [{id, caption, reports: [report IDs with a Body layout]}].
    procedure GetGroups() Groups: JsonArray
    var
        Customer: List of [Integer];
        Vendor: List of [Integer];
        Others: List of [Integer];
    begin
        Classify(Customer, Vendor, Others);
        Groups.Add(GroupJson(CustomerTok, CustomerTxt, Customer));
        Groups.Add(GroupJson(VendorTok, VendorTxt, Vendor));
        Groups.Add(GroupJson(InternalTok, InternalTxt, Others));
    end;

    procedure ReportsOf(GroupID: Text) Reports: List of [Integer]
    var
        Customer: List of [Integer];
        Vendor: List of [Integer];
        Others: List of [Integer];
    begin
        Classify(Customer, Vendor, Others);
        case GroupID of
            CustomerTok:
                Reports := Customer;
            VendorTok:
                Reports := Vendor;
            else
                Reports := Others;
        end;
    end;

    procedure GroupCaption(GroupID: Text): Text
    begin
        case GroupID of
            CustomerTok:
                exit(CustomerTxt);
            VendorTok:
                exit(VendorTxt);
        end;
        exit(InternalTxt);
    end;

    /// Sorts every report that has a Body layout into one group. Report Selections decides customer and vendor
    /// documents; everything else is an internal report.
    local procedure Classify(var Customer: List of [Integer]; var Vendor: List of [Integer]; var Others: List of [Integer])
    var
        ReportLayoutList: Record "Report Layout List";
    begin
        ReadReportSelections(Customer, Vendor);
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Body);
        if ReportLayoutList.FindSet() then
            repeat
                if not Customer.Contains(ReportLayoutList."Report ID") and not Vendor.Contains(ReportLayoutList."Report ID") and
                   not Others.Contains(ReportLayoutList."Report ID")
                then
                    Others.Add(ReportLayoutList."Report ID");
            until ReportLayoutList.Next() = 0;
        KeepWithBodyLayouts(Customer);
        KeepWithBodyLayouts(Vendor);
    end;

    /// Reads Report Selections without a Base Application dependency. Usage names (not captions) decide the group.
    procedure ReadReportSelections(var Customer: List of [Integer]; var Vendor: List of [Integer])
    var
        ReportSelections: RecordRef;
        UsageField: FieldRef;
        UsageNames: Dictionary of [Text, Text];
        TableNo: Integer;
        Index: Integer;
        UsageName: Text;
        ReportID: Integer;
    begin
        Evaluate(TableNo, ReportSelectionsTableTok);
        ReportSelections.Open(TableNo);
        if not ReportSelections.ReadPermission() then
            exit;
        UsageField := ReportSelections.Field(1);
        // Captions are translated, names are not: map caption -> name once.
        for Index := 1 to UsageField.EnumValueCount() do
            if not UsageNames.ContainsKey(UsageField.GetEnumValueCaption(Index)) then
                UsageNames.Add(UsageField.GetEnumValueCaption(Index), UsageField.GetEnumValueName(Index));
        if ReportSelections.FindSet() then
            repeat
                UsageField := ReportSelections.Field(1);
                if UsageNames.Get(Format(UsageField.Value()), UsageName) then begin
                    ReportID := ReportSelections.Field(3).Value();
                    if IsCustomerUsage(UsageName) and not Customer.Contains(ReportID) then
                        Customer.Add(ReportID);
                    if IsVendorUsage(UsageName) and not Vendor.Contains(ReportID) then
                        Vendor.Add(ReportID);
                end;
            until ReportSelections.Next() = 0;
    end;

    /// Documents that go to customers; tests, archives and internal sales printouts are left out.
    local procedure IsCustomerUsage(UsageName: Text): Boolean
    begin
        if UsageName.StartsWith('SM.') and not UsageName.Contains('Test') then
            exit(true);   // Service Management documents
        exit(UsageName in ['S.Quote', 'S.Order', 'S.Invoice', 'S.Cr.Memo', 'S.Blanket', 'S.Return', 'S.Shipment', 'S.Ret.Rcpt.',
            'Reminder', 'Fin.Charge', 'C.Statement', 'JQ', 'Pro Forma S. Invoice', 'S.Invoice Draft', 'Job Task Quote']);
    end;

    /// Documents that go to vendors.
    local procedure IsVendorUsage(UsageName: Text): Boolean
    begin
        exit(UsageName in ['P.Quote', 'P.Order', 'P.Blanket', 'P.Return', 'V.Remittance', 'P.V.Remit.', 'P.Self Billing Invoice']);
    end;

    local procedure KeepWithBodyLayouts(var Reports: List of [Integer])
    var
        ReportLayoutList: Record "Report Layout List";
        Kept: List of [Integer];
        ReportID: Integer;
    begin
        ReportLayoutList.SetRange("Layout Subtype", ReportLayoutList."Layout Subtype"::Body);
        foreach ReportID in Reports do begin
            ReportLayoutList.SetRange("Report ID", ReportID);
            if not ReportLayoutList.IsEmpty() then
                Kept.Add(ReportID);
        end;
        Reports := Kept;
    end;

    local procedure GroupJson(ID: Text; Caption: Text; Reports: List of [Integer]) Group: JsonObject
    var
        Ids: JsonArray;
        ReportID: Integer;
    begin
        foreach ReportID in Reports do
            Ids.Add(ReportID);
        Group.Add('id', ID);
        Group.Add('caption', Caption);
        Group.Add('reports', Ids);
    end;
}
