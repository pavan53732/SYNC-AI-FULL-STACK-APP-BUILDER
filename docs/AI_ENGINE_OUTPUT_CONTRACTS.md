# AI Engine Output Contract Specification

**Status**: Draft - Addressing Architectural Gap (Response 1 Validation)  
**Scope**: Formal JSON Schemas for all AI Engine-generated artifacts.

---

## Overview
To maintain deterministic control, all AI Engine outputs must adhere to strict JSON schemas. The Orchestrator validates every AI Engine response against these contracts before proceeding to the next stage. Any validation failure triggers a silent retry or a structured error state.

---

## 1️⃣ Project Specification Contract (`ProjectSpec`)
**Source**: Intent Service (Layer 1)  
**Purpose**: High-level structural definition of the application.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "projectId": { "type": "string" },
    "projectName": { "type": "string" },
    "stack": {
      "type": "object",
      "properties": {
        "ui": { "enum": ["WinUI3", "WPF", "Console"] },
        "language": { "const": "C#" },
        "framework": { "const": ".NET 8.0" },
        "database": { "enum": ["SQLite", "None"] }
      },
      "required": ["ui", "language", "framework"]
    },
    "features": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "type": { "type": "string" },
          "description": { "type": "string" },
          "dependencies": { "type": "array", "items": { "type": "string" } }
        },
        "required": ["id", "type", "description"]
      }
    }
  },
  "required": ["projectId", "projectName", "stack", "features"]
}
```

---

## 2️⃣ Task Graph Contract (`TaskGraph`)
**Source**: Planning Service (Layer 2)  
**Purpose**: Ordered sequence of construction steps.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "tasks": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "string" },
          "type": { "enum": ["INFRASTRUCTURE", "MODEL", "SERVICE", "UI", "INTEGRATION", "FIX"] },
          "description": { "type": "string" },
          "targetFiles": { "type": "array", "items": { "type": "string" } },
          "dependencies": { "type": "array", "items": { "type": "string" } },
          "validationStrategy": { "enum": ["COMPILE", "UNIT_TEST", "XAML_PARSE"] }
        },
        "required": ["id", "type", "description", "targetFiles", "dependencies"]
      }
    }
  },
  "required": ["tasks"]
}
```

---

## 3️⃣ Patch Engine Contract (`CodePatch`)
**Source**: Generation Agents (Layer 4)  
**Purpose**: Targeted modifications for the Patch Engine (Layer 5).

```json
{
  "type": "object",
  "properties": {
    "filePatches": {
      "array": {
        "items": {
          "type": "object",
          "properties": {
            "path": { "type": "string" },
            "changes": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "action": { "enum": ["ADD_MEMBER", "MODIFY_METHOD", "ADD_USING", "ADD_ATTRIBUTE", "REPLACE_NODE"] },
                  "targetSymbol": { "type": "string" },
                  "content": { "type": "string" }
                },
                "required": ["action", "content"]
              }
            }
          }
        }
      }
    }
  }
}
```

---

## 4️⃣ Validation Rules
1. **Schema Check**: All AI Engine responses must pass JSON Schema validation.
2. **Path Resolution**: Files referenced in tasks must exist in the workspace or be marked for creation.
3. **Dependency Integrity**: Task graph must be an acyclic (DAG).
4. **Symbol Existence**: Patches targeting existing symbols must verify those symbols via the Code Intelligence Layer.
