# Engineering Standards — Algorithm-First & Functional Programming

Baseline standard for **all code generation, in every project, by every agent**.
It is the default behavior; a project's `AGENTS.md` may refine it, never silently
override it.

This is the canonical engineering standard for the repository that contains it.
Repositories provisioned by `setup-repository` receive it verbatim at
`.agents/rules/engineering-standards.md` and load it at repository level through
a project `opencode.json` `instructions` entry and an `AGENTS.md` section.

## 0. Pre-flight checklist

Scan this before writing non-trivial code:

- [ ] Problem understood; inputs, outputs, constraints written down.
- [ ] Algorithm defined as steps; edge cases and failure modes listed.
- [ ] Business logic isolated in pure functions; I/O pushed to the edges.
- [ ] Tests identified (normal, boundary, invalid input) before implementation.
- [ ] Complete diff reviewed before reporting.
- [ ] Completion report (§9) delivered.

For trivial changes, use a concise implementation plan instead of full
documentation.

## 1. Algorithm-First Development

Before implementing complex functionality:

1. Understand the problem and requirements.
2. Identify inputs, outputs, constraints, and expected behavior.
3. Define a clear step-by-step algorithm.
4. Identify edge cases and failure scenarios.
5. Break the algorithm into smaller logical operations.
6. Translate the algorithm into code.
7. Verify that the implementation follows the original algorithm.

Do not begin complex implementations before understanding the problem.

## 2. Functional Programming Principles

Prefer functional programming patterns whenever practical.

- Prefer pure functions over functions with side effects.
- Functions should produce deterministic outputs for identical inputs.
- Avoid hidden dependencies and global mutable state.
- Prefer explicit inputs and outputs.
- Prefer immutable data transformations.
- Avoid unnecessary mutations.
- Keep functions small and focused.
- Prefer function composition over unnecessarily complex control flow.
- Avoid introducing abstractions without a clear benefit.

Pure functions should be the default for business logic, calculations,
validation, and data transformations.

## 3. Functional Core, Imperative Shell

Structure applications around the Functional Core, Imperative Shell principle.

- Keep business logic independent of infrastructure.
- Isolate database operations, network requests, filesystem operations, and external services.
- Separate data retrieval from data processing.
- Separate business decisions from state mutations.
- Keep side effects explicit and predictable.
- Keep the functional core as large as reasonably practical.
- Keep the imperative shell as small and simple as possible.

Do not force pure functional patterns where they introduce unnecessary
complexity.

## 4. Function Design

- Each function should have one clear responsibility.
- Use descriptive names that communicate intent.
- Prefer explicit parameters over hidden dependencies.
- Define clear return types.
- Avoid excessive function parameters.
- Avoid deeply nested conditional logic.
- Avoid functions that combine unrelated operations.
- Avoid excessive decomposition into meaningless one-line functions.
- Prefer straightforward implementations over clever solutions.

## 5. Data and State Management

- Prefer immutable data structures where practical.
- Avoid modifying function arguments.
- Minimize shared mutable state.
- Make state transitions explicit.
- Keep state ownership clear.
- Avoid unexpected mutations across application boundaries.

## 6. Testing and Verification

- Pure functions should be independently unit-testable.
- Test normal cases, boundary conditions, and invalid inputs.
- Add regression tests for bug fixes.
- Test side-effect boundaries separately.
- Verify composed workflows through integration tests.
- Never claim tests passed without executing them.

## 7. Implementation and Reviewability

- Make the smallest changes necessary.
- Follow existing project architecture.
- Avoid unrelated refactoring.
- Avoid unnecessary dependencies.
- Keep changes logically grouped.
- Review the complete Git diff before finishing.
- Explain significant architectural decisions.
- Ensure the implementation is easy for another developer to understand.

## 8. Engineering Judgment

These principles are defaults, not absolute restrictions.

Do not sacrifice correctness, performance, readability, or maintainability to
follow a programming paradigm.

When deviating from these principles:

- Explain why the deviation is necessary.
- Prefer the simplest reasonable alternative.
- Avoid introducing unnecessary complexity.

## 9. Required Completion Report

After implementation, provide:

1. Problem summary.
2. Algorithm or implementation approach.
3. Functions and responsibilities.
4. Side effects and their locations.
5. Files modified and reasons.
6. Tests executed and their results.
7. Known limitations and potential risks.

The ultimate objective is to produce predictable, modular, testable,
maintainable, and easily reviewable software.
