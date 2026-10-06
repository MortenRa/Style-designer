// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Abakion.ReportStyleDesigner;

/// <summary>
/// Looks for the BC table styles (BCDataTable, BCTotalsTable, BCBlockTable) that the Body layouts use.
/// </summary>
enum 50108 "Report Theme Table Style"
{
    Access = Internal;
    Extensible = false;

    value(0; KeepBase) { Caption = 'Keep base theme'; }
    value(1; Minimal) { Caption = 'Minimal'; }
    value(2; Banded) { Caption = 'Banded'; }
    value(3; AccentLines) { Caption = 'Accent lines'; }
    value(4; BoldHeader) { Caption = 'Bold header'; }
}
