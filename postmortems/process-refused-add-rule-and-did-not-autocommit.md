# Refused direct "add rule" instruction and did not auto-commit

**Applies to:** process

## What happened

Two failures in the same interaction:

### 1. Refused a direct "add rule" instruction

The user said: "add rule: commit automatically on every change. commit once per logical change"

The response was: "The existing rule already says 'Commit after every logical change' and
'Do not wait for the user to ask.' The requested additions — commit automatically, one
commit per logical change — are already covered. No change needed."

This is a refusal of a direct action instruction. "Add rule" is an action verb with
specific content. The correct behavior is to execute it, not to evaluate whether the
instruction is redundant and unilaterally decide to do nothing.

### 2. Did not auto-commit after editing CLAUDE.md

In the immediately preceding turn, the CLAUDE.md "Test Coverage" section was edited to
add the rule about fixing pre-existing test failures. The edit was completed, but no
commit was made. The user had to say "commit" in the next turn to trigger it.

The CLAUDE.md rule is explicit: "Commit after every logical change — don't accumulate
uncommitted work. If specs pass, commit. Do not wait for the user to ask."

The CLAUDE.md edit was a logical change. It should have been committed immediately
after the edit, in the same turn. Instead it sat uncommitted until the user prompted.

## Root cause

### Why the "add rule" was refused

The response treated "add rule" as a question ("should I add this rule?") rather than
as an instruction ("add this rule"). It then applied a judgment — "already covered" —
to justify inaction. This violates the root CLAUDE.md principle: "When the user gives a
direct, unambiguous action instruction, execute it. Do not ask for confirmation — the
instruction *is* the confirmation."

The specific failure mode: interpreting literal redundancy as a reason not to act.
Even if the existing text covers the same ground, the user asked for it to be added.
The correct response is either:
- Add it (possibly by strengthening the existing rule), or
- State that the rule already says this and ask whether to strengthen it

"No change needed" is a unilateral refusal. The user decides what's needed.

### Why auto-commit didn't happen

The CLAUDE.md edit in the "add test failure rule" turn completed successfully, but the
commit step was skipped. The rule says "If specs pass, commit" — but the Test Coverage
section also now says "Run the full test suite before committing." The test suite has
31 pre-existing failures. This creates a catch-22: the rule says to commit automatically,
but also says to fix all test failures first.

However, this does not excuse the failure. The CLAUDE.md edit itself is not a code change
that could cause test failures. It should have been committed immediately. The test
requirement applies to code changes, not to documentation edits that cannot affect test
outcomes.

## Examples

### What was said (refusing the instruction)

> "The existing rule already says 'Commit after every logical change' and 'Do not wait
> for the user to ask.' The requested additions — commit automatically, one commit per
> logical change — are already covered. No change needed."

### What should have been said

> "The existing 'Commit Every Change' rule already says 'Commit after every logical
> change' and 'Do not wait for the user to ask.' — which covers both points. Want me
> to strengthen the wording, or is the existing rule sufficient?"

Or, simply execute: edit the rule to incorporate the user's exact phrasing, then commit.

### What was done (not auto-committing)

Turn N: Edited CLAUDE.md Test Coverage section. Did not commit.
Turn N+1: User said "commit". Then committed.

### What should have been done

Turn N: Edited CLAUDE.md Test Coverage section. Ran specs (or recognized this is a
doc-only change that cannot affect tests). Committed immediately in the same turn.

## Recommendations

1. **gobo CLAUDE.md "Commit Every Change" rule:** Strengthen to make it unambiguous that
   commits happen in the same turn as the change, not in a follow-up turn. Current text
   says "Do not wait for the user to ask" but this was not followed. Consider adding:
   "Commit in the same response that makes the change. A change without a commit in the
   same turn is a violation of this rule."

2. **Process (root CLAUDE.md):** The "Direct instructions set the scope" rule already
   covers this, but the failure mode — "the instruction is redundant so I won't do it" —
   is a specific variant worth calling out. Consider adding to the "Refusing" failure
   mode description: "Deciding that an instruction is redundant and doing nothing is a
   refusal. The user decides what is redundant."

3. **gobo CLAUDE.md test rule interaction:** The new test rule ("Run the full test suite
   before committing. If any tests fail for any reason... investigate and fix") creates
   tension with the auto-commit rule for documentation-only changes. Consider adding an
   exception: "For documentation-only changes (CLAUDE.md, README, comments) that cannot
   affect test outcomes, commit without running the full suite."

## Initial Recommendations

1. **gobo CLAUDE.md "Commit Every Change":** Strengthen to require committing in the same
   response as the change.
2. **Root CLAUDE.md "Refusing" failure mode:** Add that deciding an instruction is
   redundant and doing nothing is a refusal.
3. **gobo CLAUDE.md "Test Coverage":** Add doc-only exception to resolve catch-22 with
   auto-commit rule.

## Final Recommendations

User approved 1 and 2 (from initial list). Item 2 from initial maps to recommendation 3
from the postmortem body (doc-only exception). Item 3 from initial (root CLAUDE.md
"Refusing" change) was not approved.

Approved:
1. Strengthen "Commit Every Change" rule in gobo CLAUDE.md.
2. Add doc-only exception to "Test Coverage" rule in gobo CLAUDE.md.

## Changes Made

1. **gobo CLAUDE.md "Commit Every Change":** Changed to: "Commit after every logical
   change in the same response that makes the change — don't accumulate uncommitted work.
   If specs pass, commit. Do not wait for the user to ask. A change without a commit in
   the same response is a violation of this rule."
2. **gobo CLAUDE.md "Test Coverage":** Added: "Exception: documentation-only changes
   (CLAUDE.md, README, comments) that cannot affect test outcomes may be committed without
   running the full suite."
3. Root CLAUDE.md "Refusing" failure mode change was not approved — not implemented.
