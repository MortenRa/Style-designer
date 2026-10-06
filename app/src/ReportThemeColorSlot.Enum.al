// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Abakion.ReportStyleDesigner;

/// <summary>
/// The twelve colour slots of a Word theme colour scheme (a:clrScheme), in schema order.
/// </summary>
enum 50100 "Report Theme Color Slot"
{
    Access = Internal;
    Extensible = false;

    value(0; Dark1) { Caption = 'Text/Background - Dark 1'; }
    value(1; Light1) { Caption = 'Text/Background - Light 1'; }
    value(2; Dark2) { Caption = 'Text/Background - Dark 2'; }
    value(3; Light2) { Caption = 'Text/Background - Light 2'; }
    value(4; Accent1) { Caption = 'Accent 1'; }
    value(5; Accent2) { Caption = 'Accent 2'; }
    value(6; Accent3) { Caption = 'Accent 3'; }
    value(7; Accent4) { Caption = 'Accent 4'; }
    value(8; Accent5) { Caption = 'Accent 5'; }
    value(9; Accent6) { Caption = 'Accent 6'; }
    value(10; Hyperlink) { Caption = 'Hyperlink'; }
    value(11; FollowedHyperlink) { Caption = 'Followed Hyperlink'; }
}
