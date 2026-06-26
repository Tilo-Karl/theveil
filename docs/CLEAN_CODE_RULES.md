Clean Code Rules (Hard Rules)

These rules are non-negotiable.
Violations are bugs, not style issues.

1. Responsibility & Boundaries
	•	A file may have exactly one domain responsibility.
	•	A file may not mix:
	•	orchestration + mutation
	•	domain logic + transport logic
	•	validation + side effects

If you need to explain a file with “and”, it is already wrong.

⸻

2. Execution Roles & Boundaries

    Writers
	•	Perform state mutation only
	•	Must be deterministic
	•	Must not call external services
	•	Must not decide when something happens

    Readers
	•	May read state or call external services
	•	Must not mutate state
	•	Must not contain business invariants
	•	May normalize data, but must not decide meaning

    Orchestrators
	•	Decide when things happen
	•	Call readers and writers
	•	Must not mutate state directly
	•	Must not contain business invariants
	•	Must not access external systems or raw storage directly; they must go through readers or writers

This boundary is absolute.

⸻


3. Shared Invariants (Critical)
	•	If a rule, invariant, or micro-pattern appears twice, it MUST be extracted.
	•	Extraction is mandatory on the second occurrence, not the third.
	•	Examples of invariants:
	•	position validation
	•	ID parsing
	•	cell identity rules
	•	permission checks
	•	transaction preconditions

Duplication of invariants is a correctness bug.

⸻

4. DRY Applies to Rules, Not Lines
	•	Repeating logic is worse than repeating code.
	•	Prefer a shared helper even if it adds indirection.
	•	Centralized invariants always win over “local clarity”.

If multiple files “know the same rule”, the system is already broken.

⸻

5. File Size & Structure
	•	Prefer 5 small files over 1 clever file.
	•	Files over ~300 lines are suspect.
	•	Files over ~500 lines are violations unless explicitly justified.

Cleverness is technical debt.

⸻

6. Evolution & Deletion
	•	Old code may only be deleted after the replacement is complete and verified.
	•	Temporary duplication during migration is allowed.
	•	Permanent duplication is not.

Stability during change is mandatory.

⸻

7. Naming & Intent
	•	Names must describe what the code guarantees, not how it works.
	•	Files named utils, helpers, or misc are forbidden.
	•	Shared code must encode why it exists, not just what it does.

⸻

8. Defaults for AI Code Generation

When generating code, the AI must:
	•	Assume future reuse
	•	Extract shared invariants early
	•	Avoid local optimizations that block global structure
	•	Optimize for the final system, not the first working version

⸻

Enforcement Clause

If any rule conflicts with speed, convenience, or brevity:

The rule wins.

⸻

Summary (for AI)
	•	One responsibility per file
	•	Orchestration ≠ mutation
	•	Extract invariants on second use
	•	Prefer structure over cleverness
	•	Delete only after replacement
	•	Optimize for the end state

_____

Mandatory Refactor Triggers
	1.	Second occurrence of a shared invariant
	•	If the same rule/validation/derivation appears twice → extract immediately.
	•	No third occurrence is ever allowed.
	2.	File exceeds one domain responsibility
	•	If a file answers two different “why does this exist?” questions → split it.
	3.	Orchestrator mutates state
	•	If orchestration code writes to storage directly → refactor.
	•	Orchestrators call writers. Writers mutate. No exceptions.
	4.	Helper logic copied instead of imported
	•	If logic is duplicated because “it was faster” → refactor before proceeding.
    •   Copied logic includes copy-paste with renamed variables.

______

UI Exception (Applies to all platforms)
UI components (e.g. SwiftUI Views) are presentation-only.
They are exempt from orchestrator/writer classification.
They must not contain business logic, invariants, validation, or state mutation beyond UI state.
ViewModels are orchestrators and must obey all orchestration rules.

Note: All user-visible strings must come from AppStrings (no hardcoded UI strings in views).
