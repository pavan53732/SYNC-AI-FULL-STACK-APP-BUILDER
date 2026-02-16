# Features & Roadmap

**Core Design Philosophy**: Hide complexity, show results. A fully self-contained **Autonomous Software Construction Environment** leveraging multi-agent orchestration and silent error fixing to replace the need for an external IDE.

See [DESIGN_PHILOSOPHY.md](DESIGN_PHILOSOPHY.md) for UX principles and [INTERNAL_ARCHITECTURE.md](INTERNAL_ARCHITECTURE.md) for technical implementation.

---

## Feature Matrix

### Core Features (MVP)

#### 1. Intent Parsing & Specification
- [x] Natural language prompt input
- [x] Feature extraction from prompt
- [x] Stack selection (constrained choices)
- [x] Structured spec generation (JSON)
- [x] Conflict detection (contradictory requirements)
- [x] Dependency mapping

**Example:**
```
Input: "Build a CRM with auth, roles, and customer database"
↓
Output: 
{
  "features": [
    {"id": "authentication", "type": "auth", "dependencies": ["user-database"]},
    {"id": "roles", "type": "access-control", "dependencies": ["authentication"]},
    {"id": "database", "type": "data-model", "dependencies": []}
  ]
}
```

#### 2. Task Planning (DAG/Graph)
- [x] Create ordered task graph
- [x] Identify dependencies
- [x] Find parallelizable work
- [x] Serialization points
- [x] Retry strategy per task

#### 3. Code Intelligence & Indexing
- [x] File index (symbols, exports, imports)
- [x] Dependency graph (file relationships)
- [x] Semantic embeddings (for smart retrieval)
- [x] Route registry (API endpoints)
- [x] Database schema map
- [x] Architecture config snapshot

**Storage**: SQLite with vector embeddings

#### 4. Multi-Agent Code Generation
- [x] **Architect Agent** - defines project structure
- [x] **Schema Agent** - generates database models
- [x] **Frontend Agent** - generates XAML UI
- [x] **Backend Agent** - generates API/services
- [x] **Integration Agent** - wires dependencies
- [x] **Fix Agent** - repairs build errors

All agents are powered by the **AI Engine** via `z-ai-web-dev-sdk`.

Each agent produces structured patches, not full files.

#### 5. Structured Patch Engine (AST-Based)
- [x] Parse code to Abstract Syntax Tree
- [x] Apply targeted modifications
- [x] Preserve formatting & comments
- [x] Avoid full-file rewrites
- [x] Merge-friendly diffs

**Technology**: Roslyn for C# AST manipulation

#### 6. Validation & Silent Retry Loop
- [x] MSBuild compilation
- [x] Error detection & classification
- [x] Automatic error fixing
- [x] Transparent retries (hidden from user)
- [x] Final success notification only

**User sees**: [spinner] → ✅ Success (no intermediate errors)

#### 7. Project State & Memory
- [x] Persist architectural decisions
- [x] Track naming conventions
- [x] Remember common patterns
- [x] Store error solutions
- [x] Session context tracking

#### 8. Live Preview
- [x] Compile XAML in real-time
- [x] Display UI without full build
- [x] Show rendering errors
- [x] Interactive preview

#### 9. One-Click Build & Deploy
- [x] Automated compilation
- [x] Package as .exe
- [x] Auto-dependency resolution
- [x] Hosting setup (optional)

#### 10. Project Management
- [x] Create new projects
- [x] View project history
- [x] Export projects
- [x] Version snapshots
- [x] Recent projects list

#### 11. Environment Bootstrapping & Self-Repair
- [x] Automatic .NET SDK detection
- [x] Guided SDK installation/setup
- [x] NuGet cache corruption detection
- [x] "Self-repair" strategy for build environments
- [x] Low-resource (RAM/Disk) mitigation strategies

#### 12. Real Code Export & Portability (Post-Construction)
- [x] Generate real, editable C# code (not templates)
- [x] Generate real, editable XAML (not proprietary format)
- [x] Download as ZIP (full project, all source)
- [x] GitHub sync (create repo, push code automatically)
- [x] Visual Studio compatibility (open project directly for manual dev)
- [x] Standalone execution (code runs anywhere)
- [x] Continue development post-export (code not locked)

**Key Differentiator**: Users own the code, not locked to platform

---

### Advanced Features (Phase 2)

#### 11. Automatic Error Detection & Fixing
- [ ] **Silent Error Loop**: Compile → Detect → Fix → Retry (all hidden)
- [ ] **Error Classification**:
  - Syntax errors (CS1002, etc.)
  - Type mismatches (CS1503)
  - Missing using statements (CS0106)
  - Build failures
  - Configuration errors
- [ ] **Auto-Fix Strategies**:
  - Add missing using statements
  - Insert type conversions
  - Fix null reference exceptions
  - Add missing attributes
  - Correct method signatures
- [ ] **Retry Logic**: Up to 5 auto-fix attempts before showing to user
- [ ] **Fix Success Tracking**: Remember solutions for future errors

**User Experience:**
```
Input: "Add customer validation to CRM"
↓
[spinner for 2-3 seconds - internal retries hidden]
↓
✅ Output: "Added DataAnnotations validation to Customer model"

(Internally: Generated code → Compiled → Missing [Required] attribute 
  → Fix Agent added it → Recompiled → Success)
```

#### 12. Smart Component Library
- [ ] Pre-built UI components (50+ components)
- [ ] Professionally designed XAML components
  - Form controls (TextBox, DatePicker, ComboBox)
  - Data display (DataGrid, ListView, TreeView)
  - Navigation (TabControl, Menu, NavigationPane)
  - Dialogs & modals
  - Rich text editor
  - Color & file pickers
- [ ] Component metadata (dependencies, requirements)
- [ ] Custom component creation
- [ ] Component marketplace search

#### 13. Data & Database
- [ ] Database schema generation from prompts
- [ ] SQLite integration with migrations
- [ ] Entity Framework Core scaffolding
- [ ] CRUD operation generation (Repository pattern)
- [ ] Database migration helpers
- [ ] Relationship mapping (FK, 1-to-many, many-to-many)
- [ ] Seed data generation

#### 14. API Integration
- [ ] REST API endpoint generation
- [ ] HTTP client auto-generation
- [ ] API endpoint configuration
- [ ] Authentication helpers (JWT, OAuth, Windows Auth)
- [ ] HTTP request/response handling
- [ ] Error handling & retry policies
- [ ] Swagger/OpenAPI documentation generation

#### 15. State Management
- [ ] MVVM pattern template generation
- [ ] Dependency injection auto-wiring (Microsoft.Extensions.DependencyInjection)
- [ ] Observable properties (INotifyPropertyChanged)
- [ ] Command pattern (ICommand)
- [ ] Event aggregation
- [ ] Reactive programming support (Rx.NET)

#### 16. Testing Framework
- [ ] Unit test generation (NUnit/xUnit)
- [ ] Test file scaffolding with templates
- [ ] Mock object auto-generation (Moq)
- [ ] Integration test helpers
- [ ] UI automation test generation (Windows Application Driver)
- [ ] Test data generators
- [ ] Code coverage reporting

#### 17. Version Control Integration
- [ ] Git initialization & setup
- [ ] Auto-commit on generation
- [ ] Diff visualization
- [ ] GitHub/GitLab integration
- [ ] Change tracking & history
- [ ] Branch management

#### 18. Code Quality & Analysis
- [ ] Static analysis integration (SonarQube)
- [ ] Code formatting enforcement
- [ ] Design pattern suggestions
- [ ] Performance warnings
- [ ] Security vulnerability scanning
- [ ] Code duplication detection

---

### Production Features (Phase 3)

#### 19. Marketplace
- [ ] Template marketplace
- [ ] Component library marketplace
- [ ] Code snippet sharing
- [ ] User ratings & reviews
- [ ] Community contributions

#### 20. Team Collaboration
- [ ] Team workspaces
- [ ] Real-time collaboration
- [ ] Comments & code review
- [ ] Permission management
- [ ] Activity logs

#### 20. Team Collaboration
- [ ] Team workspaces
- [ ] Real-time collaboration
- [ ] Comments & code review
- [ ] Permission management
- [ ] Activity logs

#### 21. Advanced Build Options
- [ ] MSIX packaging
- [ ] Installer generation (Setup.exe, .msi)
- [ ] Code signing
- [ ] Auto-update capability
- [ ] Release notes generation

#### 22. Cloud Features
- [ ] Cloud project storage
- [ ] Backup & restore
- [ ] Cross-device sync
- [ ] Cloud compilation (optional)
- [ ] Analytics dashboard

#### 23. IDE Integration
- [ ] VS Code extension
- [ ] Visual Studio extension
- [ ] Live sync with IDE
- [ ] Integrated debug support

#### 24. Performance Tools
- [ ] Build time optimization
- [ ] App performance profiling
- [ ] Memory leak detection
- [ ] Startup time reduction
- [ ] UI responsiveness tools

---

## Detailed Feature Descriptions

### Feature 1: Intent Parsing & Structured Specification

**Description**: Convert natural language prompts into machine-readable specifications that guide generation and prevent hallucination.

**Process**:
1. Extract features from prompt
2. Normalize feature names
3. Identify dependencies
4. Check for conflicts
5. Generate spec JSON

**Example**:
```
Input: "Build a CRM with user authentication and role-based access"

Output JSON:
{
  "projectType": "windows-desktop-app",
  "features": [
    {
      "id": "authentication",
      "type": "auth",
      "dependencies": ["user-database"],
      "priority": 1
    },
    {
      "id": "rbac",
      "type": "access-control",
      "roles": ["admin", "manager", "user"],
      "dependencies": ["authentication"],
      "priority": 2
    }
  ],
  "stack": {
    "ui": "WinUI3",
    "database": "SQLite"
  }
}
```

**Benefits**:
- ✅ Clear, explicit requirements
- ✅ No hallucinated features
- ✅ Dependency graph enables planning
- ✅ Conflict detection

---

### Feature 2: Multi-Agent Code Generation

**Description**: Decompose complex app generation into 6 specialized agents, each with narrow responsibility and deterministic output.

**The Agents**:

1. **Architect Agent** - Designs project structure
2. **Schema Agent** - Generates database models
3. **Frontend Agent** - Generates XAML UI
4. **Backend Agent** - Generates services/APIs
5. **Integration Agent** - Wires dependencies
6. **Fix Agent** - Repairs build errors

**Orchestration Strategy**:
```
Phase 1: Architect defines structure
Phase 2: Schema + Backend agents run in parallel
Phase 3: Frontend agent uses output from Phase 2
Phase 4: Integration agent wires everything
Phase 5: Compile → If errors → Fix agent → Retry
```

**Benefits**:
- ✅ Each agent is easier to test & control
- ✅ Parallel execution where possible
- ✅ Easy to debug specific generation stage
- ✅ Structured output schema (not free-form)

---

### Feature 3: Structured Patch Engine (AST-Based)

**Description**: Apply surgical, targeted code modifications without full file rewrites, preserving formatting and comments.

**Traditional Approach ❌**:
```
User: "Add validation to Customer model"
→ Retrieve entire Customer.cs
→ Send to AI Engine: "Rewrite this"
→ AI Engine regenerates entire file  
→ Lose comments, formatting, developer notes
→ Risk introducing bugs
```

**AST-Based Approach ✅**:
```
User: "Add validation to Customer model"
↓
Parse to AST → Find "Name" property node
↓
Generate minimal patch [Required] attribute
↓
Apply patch surgically via AST
↓
Recompile AST → Preserve all formatting
```

**Result**:
- Only changed lines in diff
- All comments preserved
- Developer notes intact
- Merge-friendly

---

### Feature 4: Silent Validation & Auto-Retry Loop

**Description**: Automatically detect build errors, classify them, apply fixes, and retry—all hidden from the user.

**The Loop**:
```
Generate Code
    ↓
[Compile MSBuild]
    ↓
Check for errors?
    ├─ NO → Success! Show to user ✅
    └─ YES → Classify error
        ├─ syntax error → Fix Agent patches
        ├─ missing using → Add automatically
        ├─ type mismatch → Add type conversion
        └─ build error → Analyze & fix
        
        After fix → Recompile
            ├─ Success? → Show to user ✅
            └─ Still errors? → Retry (up to 5x)
```

**Error Classification**:
- Syntax errors (CS1002, CS1003, etc.)
- Type mismatches (CS1503)
- Missing references (CS0106)
- Undefined variables (CS0103)
- Build failures
- Configuration errors

**Auto-Fix Strategies**:
- Insert missing using statements
- Add type conversions (int.Parse, Convert.ToInt32)
- Add missing attributes ([Required], [StringLength])
- Fix method signatures
- Add missing properties

**User Experience**:
```
User types: "Add customer validation"
↓
[Spinner: 2-3 seconds]
↓
✅ Output: "Added DataAnnotations validation"

(Internally: 
  - Generated model
  - Compile failed: Missing [Required] 
  - Fix Agent added attribute
  - Recompiled → Success)
```

---

### Feature 5: Project Memory & State Management

**Description**: Persist architectural decisions, patterns, and error solutions across iterations.

**What Gets Remembered**:

1. **Stack Decisions**:
   ```json
   {
     "ui_framework": "WinUI3",
     "database": "SQLite",
     "orm": "Entity Framework Core",
     "auth_provider": "Windows Authentication"
   }
   ```

2. **Naming Conventions**:
   ```json
   {
     "models": "PascalCase",
     "private_fields": "_camelCase",
     "config_files": ".json"
   }
   ```

3. **Error Solutions**:
   ```json
   {
     "CS0103: missing field": ["Add field definition", "Check imports"],
     "validation error": ["Check DataAnnotations", "Verify model"]
   }
   ```

4. **Session Context**:
   ```json
   {
     "user_preferences": {
       "auto_fix": true,
       "show_code": true
     },
     "conversation": [...]
   }
   ```

**Benefits**:
- ✅ Consistent architecture across iterations
- ✅ No drift in coding style
- ✅ Faster error fixes (reuse solutions)
- ✅ Personalized experience (remember preferences)

---

### Feature 6: Smart Code Retrieval & Context Management

**Description**: Use semantic embeddings to intelligently retrieve only relevant code files, solving AI Engine context window limits.

**Strategy**:
```
User prompt: "Add customer validation"
↓
Embed prompt to vector
↓
Search embeddings for "validation", "customer", "model"
↓
Get top 5 matches:
  - Customer.cs (99% match)
  - CustomerValidator.cs (95%)
  - ValidationExtensions.cs (89%)
  - DataAnnotations setup (85%)
  - Error handling (75%)
↓
Send ONLY these 5 files (~2000 lines) to AI Engine
↓
(Not the entire 10K-file project)
```

**Benefits**:
- ✅ Stays within context limit
- ✅ Semantic understanding (embeddings)
- ✅ Scales as project grows
- ✅ Faster AI Engine processing

---

### Feature: Prompt-Based Code Generation

**Description**: Users input natural language descriptions and the AI generates corresponding Windows app code.

**Examples**:
- "Create a to-do list app with add, edit, delete buttons"
- "Build a calculator with basic operations"
- "Make a weather app that fetches data from an API"

**Implementation** (Multi-Agent):
1. Parse intent to structured spec
2. Create task graph with dependencies
3. Execute agents in parallel (where possible)
4. Patch code using AST
5. Build & auto-fix errors
6. Show success to user

**Output**:
```
Models/Customer.cs
Services/CustomerService.cs
UI/Pages/CustomerPage.xaml
UI/Pages/CustomerPage.xaml.cs
ViewModels/CustomerViewModel.cs
Database/ApplicationDbContext.cs
```

---

### Feature: Live Preview

**Description**: Real-time preview of generated Windows app UI without compilation.


**Implementation**:
- Compile generated XAML to preview
- Hot-reload UI changes
- Display rendering errors
- Show UI layout issues

---

### Feature: Smart Component Library

**Description**: Pre-built, professionally designed components that can be added to projects.

**Components Include**:
- Form inputs (TextBox, ComboBox, DatePicker)
- Data display (DataGrid, ListView)
- Navigation (TabControl, Menu)
- Dialogs (MessageBox, FileDialog)
- Rich text editor
- Color picker
- File browser

**Benefits**:
- Faster development
- Consistent design
- Tested & optimized
- Style customization

---

### Feature: Database Integration

**Description**: Automatically generate database models and CRUD operations.

**Steps**:
1. User describes data model (prompt)
2. AI generates SQLite schema
3. Generate Entity Framework models
4. Create repository pattern
5. Generate CRUD service layer

**Example**:
```
Prompt: "Create a database for storing user accounts with name, email, and password"
↓
Generated Files:
- Models/User.cs
- Data/ApplicationDbContext.cs
- Services/UserRepository.cs
- Migrations/
```

---

### Feature 7: Observable System Behaviors (Inferred from Usage)

**Based on evidence-driven analysis of how Lovable systems work:**

#### Behavior 1: Complex Apps Generate in Seconds
- Initial generation: 30-60 seconds typical
- Refinements: 5-15 seconds
- **Why**: Multi-stage pipeline (parsing → architecture → generation → validation)
- **Not** a single AI Engine call (which would be slower)

#### Behavior 2: Intelligent Incremental Updates
- User: "Change button colors" → Only CSS/styles regenerate
- User: "Add customer search" → Only frontend + API routes regenerate
- Existing code preserved, not full rewrite
- **Why**: System performs **impact analysis** before regeneration

#### Behavior 3: Dependency Management Is Automatic
- Generated code includes .csproj with all dependencies
- No manual "NuGet package addition"
- Required libraries automatically detected and added
- **Why**: System tracks dependencies across all generated modules

#### Behavior 4: Code Quality Is Consistent
- Generated apps deploy and run successfully (not broken code)
- Users report working applications, not theoretical outputs
- No significant debugging needed
- **Why**: Every output goes through build validation before showing to user

#### Behavior 5: Real Code Ownership
- Users can download and run code locally
- Code works in IDE (Visual Studio, VS Code)
- Code can be deployed independently
- Code can be forked and modified
- **Why**: Output is actual C# + XAML, not proprietary format

#### Behavior 6: Error-Free User Experience
- Users never see compilation errors
- Users never see "build failed" messages
- Users don't debug syntax/type errors
- **Why**: Errors are fixed silently, before preview shown

---

## Testing & QA

### Observ Test Coverage Goals
- Real generated code: 95%+ must be syntactically valid
- Build validation: 99%+ must compile successfully
- Functional validation: 90%+ must execute expected behavior
- User satisfaction: 4.5+ stars
- No broken code shown to users: 100% enforcement

---

## User Workflows

### Workflow 1: From Prompt to Deployed App
```
1. User enters prompt
2. [System: Parse → Generate → Validate]
3. User sees working app in 30-60 seconds
4. User previews, tests app
5. User refines with prompts or manual edits
6. User exports to GitHub or downloads
7. User deploys or continues development
```

### Workflow 2: Incremental Refinement
```
1. Start with base app
2. User: "Add dark mode"
3. [System: Analyze impact → Regenerate themes → Validate]
4. Preview updates in 5-15 seconds
5. Repeat with new requests
6. Each iteration improves app without breaking existing code
```

### Workflow 3: Export & Independence
```
1. Generate app in Lovable
2. Export to GitHub (automatic sync)
3. Take code, open in Visual Studio
4. Modify code locally (add features, customize)
5. Deploy as .exe/.msi independently
6. Lovable not needed anymore (code is yours)
```

---

## Success Metrics (Observable)

- [ ] Generation time: < 60 seconds (cold), < 15 seconds (refinement)
- [ ] Code accuracy: > 95% of generated code syntactically valid
- [ ] Build success: > 99% of generated code compiles first pass
- [ ] User satisfaction: 4.5+ stars
- [ ] Export/portability: 100% of code is real and runnable
- [ ] Error visibility: 0% of compile errors shown to user
- [ ] Documentation: 100% coverage
- [ ] Real code generation: 100% (not templates)

---

## Constraints & Limitations

### Current (MVP)
- Windows only (no macOS/Linux)
- .NET apps only (no other languages)
- Limited component library (30-50 components)
- No collaboration features

### Future Roadmap
- Multi-platform support (Phase 4)
- Other languages (Python, C++, etc.)
- Extended component library
- Team collaboration tools

