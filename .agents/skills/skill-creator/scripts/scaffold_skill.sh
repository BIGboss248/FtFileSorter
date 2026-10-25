#!/usr/bin/env bash
# ==============================================================================
# Scaffold and validate AI skills conforming to Open Agent Skills specification
# ==============================================================================

set -euo pipefail

NAME=""
DESCRIPTION=""
TARGET_DIR="skills"
VALIDATE=""

show_help() {
    cat << EOF
Usage:
  Scaffold: ./scaffold_skill.sh -n <skill-name> -d <skill-description> [-t <target-dir>]
  Validate: ./scaffold_skill.sh -v <path-to-skill-dir>

Options:
  -n, --name         Skill name (lowercase, alphanumeric with single hyphens, 1-64 chars)
  -d, --description  Skill description declaring what and when (1-1024 chars)
  -t, --target-dir   Base directory for scaffolding (default: 'skills')
  -v, --validate     Path to an existing skill directory to validate against specification
  -h, --help         Show this help message
EOF
}

# Parse command-line flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            NAME="$2"
            shift 2
            ;;
        -d|--description)
            DESCRIPTION="$2"
            shift 2
            ;;
        -t|--target-dir)
            TARGET_DIR="$2"
            shift 2
            ;;
        -v|--validate)
            VALIDATE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ----------------- VALIDATION MODE -----------------
if [[ -n "$VALIDATE" ]]; then
    echo "Validating skill at: $VALIDATE"
    errors=()

    if [[ ! -d "$VALIDATE" ]]; then
        echo "ERROR: Directory '$VALIDATE' does not exist."
        exit 1
    fi

    SKILL_FILE="$VALIDATE/SKILL.md"
    if [[ ! -f "$SKILL_FILE" ]]; then
        errors+=("Missing required 'SKILL.md' file.")
    else
        # Check YAML Frontmatter delimiters
        if ! grep -q "^---" "$SKILL_FILE"; then
            errors+=("SKILL.md is missing valid YAML frontmatter delimiters ('---').")
        fi

        # Parse Name
        PARSED_NAME=$(grep -E "^name:" "$SKILL_FILE" | head -n 1 | sed -E 's/^name:[[:space:]]*["'"'"']?([^"'"'"']+)["'"'"']?/\1/' || true)
        if [[ -z "$PARSED_NAME" ]]; then
            errors+=("Frontmatter is missing required 'name' field.")
        else
            if [[ ${#PARSED_NAME} -lt 1 || ${#PARSED_NAME} -gt 64 ]]; then
                errors+=("Skill name length (${#PARSED_NAME}) must be between 1 and 64 characters.")
            fi
            if ! [[ "$PARSED_NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
                errors+=("Skill name '$PARSED_NAME' is invalid. Must use only lowercase alphanumeric characters and single hyphens.")
            fi
            DIR_NAME=$(basename "$VALIDATE")
            if [[ "$PARSED_NAME" != "$DIR_NAME" ]]; then
                errors+=("Skill name '$PARSED_NAME' does not match directory name '$DIR_NAME'.")
            fi
        fi

        # Check Line Count Budget
        LINE_COUNT=$(wc -l < "$SKILL_FILE" || true)
        if [[ $LINE_COUNT -gt 250 ]]; then
            echo "WARNING: SKILL.md is $LINE_COUNT lines (recommended: <150-250 lines). Consider offloading technical details to references/ and templates to resources/templates/."
        fi
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        echo ""
        echo "Validation FAILED with ${#errors[@]} error(s):"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
        exit 1
    else
        echo ""
        echo "Validation PASSED! Skill conforms to Open Agent Skills specification."
        exit 0
    fi
fi

# ----------------- SCAFFOLDING MODE -----------------
if [[ -z "$NAME" ]]; then
    show_help
    exit 1
fi

if ! [[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || [[ ${#NAME} -gt 64 ]]; then
    echo "ERROR: Invalid name '$NAME'. Must be lowercase alphanumeric with single hyphens, max 64 chars."
    exit 1
fi

if [[ -z "$DESCRIPTION" ]]; then
    DESCRIPTION="Executes $NAME procedures. Use when the user asks to perform tasks related to $NAME."
fi

SKILL_PATH="$TARGET_DIR/$NAME"
if [[ -d "$SKILL_PATH" ]]; then
    echo "ERROR: Target directory '$SKILL_PATH' already exists."
    exit 1
fi

echo "Scaffolding skill '$NAME' at: $SKILL_PATH"

mkdir -p "$SKILL_PATH/references"
mkdir -p "$SKILL_PATH/scripts"
mkdir -p "$SKILL_PATH/examples"
mkdir -p "$SKILL_PATH/resources/templates"

cat << EOF > "$SKILL_PATH/SKILL.md"
---
name: $NAME
description: >-
  $DESCRIPTION
---

# $NAME

Orchestration runbook for $NAME procedures.

---

## Prerequisites & Preconditions
- [ ] Required tools and environment variables verified.
- [ ] Working workspace context loaded.

---

## Step-by-Step Execution Flow

### 1. Step One: Inspection & Setup
1. Inspect input parameters and current workspace state.
2. If optional configurations are missing, initialize safe defaults.

### 2. Step Two: Template Scaffolding
1. Inspect the starter configuration in [config.template.json](./resources/templates/config.template.json).
2. Generate target configurations from the template.
3. For in-depth rules and edge cases, consult [reference.md](./references/reference.md).

### 3. Step Three: Execution & Verification
1. Run the operational workflow.
2. Confirm outputs and state integrity.

---

## Edge Cases & AI Pitfalls
- **Common Mistake**: Watch out for subtle assumptions or hallucinated arguments.
- **State Validation**: Ensure dependencies and directories exist before running modifications.

---

## Verification & Self-Check
- [ ] Run verification tests or dry-run checks.
- [ ] Confirm no unexpected side effects occurred.
EOF

cat << EOF > "$SKILL_PATH/references/reference.md"
# $NAME Reference Guide

Detailed technical manual and operational deep-dive for $NAME.

## Technical Specifications
- Detailed schemas, parameters, and system behaviors.
EOF

cat << EOF > "$SKILL_PATH/resources/templates/config.template.json"
{
  "\$schema": "https://json-schema.org/draft/2020-12/schema",
  "name": "$NAME",
  "version": "1.0.0"
}
EOF

echo "Skill '$NAME' successfully scaffolded at $SKILL_PATH"

