namespace Abakion.ReportStyleDesigner;

/// The design directions (archetypes): each sets the look and the header/footer in one step.
/// Draft for the design team to review; the values are set in "Report Style Directions".
enum 50105 "Report Style Direction"
{
    Extensible = false;

    // Nothing is changed; the current choices stay.
    value(0; NotChosen) { Caption = 'Not chosen'; }
    value(1; Classic) { Caption = 'Classic'; }
    value(2; Modern) { Caption = 'Modern'; }
    value(3; Formal) { Caption = 'Formal'; }
    value(4; Friendly) { Caption = 'Friendly'; }
    value(5; Minimal) { Caption = 'Minimal'; }
}
