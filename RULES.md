# General Principles

## Establish understanding before acting

Before taking action on any request, build a picture of the current state from available evidence: existing files, configuration, prior context, or error messages.

When evidence is insufficient, locate and read relevant documentation before proceeding.

When no authoritative document exists and evidence is still insufficient, surface the open question and wait for a resolution before proceeding. Accuracy takes priority over speed: a decision built on an unresolved question does not save time.

---

## Show state and state changes, do not only describe them

When explaining what something does or what will change, show the literal state: the actual value, structure, output, or condition before and after. A reader should be able to understand what will change at a glance, without having to reconstruct it from a verbal account.

Reserve prose for explaining why. Use literal representations to show what.

---

## Illustrate explanations with examples and diagrams

Use examples and diagrams generously when explaining. An example makes a point concrete; a diagram makes structure and relationships visible. Both remove ambiguity that prose alone cannot resolve.

---

## Write rules and instructions at the level of general principles

Express rules and instructions in terms of intent and reasoning, not tied to a specific language, framework, or tool.

Use neutral wording that does not imply a particular syntax, convention, or ecosystem. Avoid symbols, operators, or notation that could be confused with programming language constructs.

Express a rule in terms of why the behavior matters, not only what to do.

---

# Development Workflow

## Write a behaviour spec before implementation

Before writing any implementation code, determine whether the required behavior is explicit enough to define module and function specs:

- If the required behavior is explicit enough, proceed to defining specs directly.
- If the required behavior is not explicit enough to define specs, create a behaviour spec before proceeding.
- If there is insufficient information to create a behaviour spec, use example mapping to surface the behavior first, then create the behaviour spec.

**Exceptions**: changes with no integration surface:

- Mechanical fixes with no logic change (typos, renaming within a single function)
- Adding comments or log statements

---

## Fill out a coding task template before writing code

Before writing any code, document a spec for every function and module being created or modified. Each spec defines the purpose, public interface, inputs, outputs, and behavioral contract. When a spec already exists for a module or function being modified, read the current implementation, verify the spec against it, and update any spec that has drifted before using it as the implementation contract.

After coding, validate the implementation against each spec. Update any spec that drifted during implementation.

---

## Create a timestamped checklist when working on complex tasks

When a task has multiple distinct steps, spans several files, or could take more than a few tool calls to complete, create a checklist at the outset. Record a start and completion timestamp for each item. Update the checklist in place as work progresses.

Checklist format:

```
- [ ] HH:MM: Item description
- [x] HH:MM-HH:MM: Completed item description
```

---

# Code Design

## Design against public contracts, not internal representations

At any code boundary, depend only on the public contract: the shape callers pass in and the shape they receive back.

This applies everywhere code crosses a boundary: function inputs, return values, test assertions, interface definitions, and module dependencies. Never couple to internal representations, intermediate forms, or implementation details.

---

# Claude Code

## Delegate code changes to the code-implementer agent

When making any change to code, delegate the implementation to the `claude-copilot:code-implementer` subagent rather than writing code inline.

This applies to new features, bug fixes, refactors, and any edit that modifies executable code. It does not apply to configuration-only changes, documentation edits, or changes to non-code files.

---

## Claude Code agents orientation

Before working with Claude Code agents, fetch the current Anthropic documentation. Orient on:

1. **Isolation model**: what an agent can and cannot see, what context it inherits, and what is withheld
2. **Trust boundaries**: which agents can call which tools, and what elevated permissions must be explicitly granted
3. **Communication patterns**: how agents pass results back and what is guaranteed vs. best-effort
4. **Security constraints**: prompt injection from agent outputs, over-broad tool grants, and side effects from parallel agents touching shared state
5. **When not to use agents**: inline execution is faster and simpler; agents add overhead and coordination cost

If the documentation and your training knowledge conflict, trust the fetched documentation.

---

## Claude Code skills orientation

Before working with Claude Code skills, fetch the current Anthropic documentation. Orient on:

1. **Current API shape**: how skills are structured in the version of Claude Code in use
2. **Security constraints**: what a skill is and is not permitted to do, particularly around file access, shell execution, and outbound network calls
3. **Best practices**: design patterns the Anthropic team has validated, including progressive disclosure and the principle of least surprise
4. **Changes**: any behavior that differs from a prior version

If the documentation and your training knowledge conflict, trust the fetched documentation.
