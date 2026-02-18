# Execution Lifecycle & Threading Model Specification

**Purpose**: Define systems-level execution flow, threading architecture, and boot sequence  
**Framework**: WinUI 3 + .NET 8 + Deterministic Orchestrator  
**Philosophy**: Responsive UI with controlled background execution

---

## Core Principle

> **User sees: "Building your app…"**
>
> **Internally**: 6-phase execution lifecycle across 6 thread types with deterministic state transitions

---

## 1. Full Hidden Background Execution Lifecycle

This is what happens when user clicks **Generate** or **Improve this app**.

---

### Phase 0 — Pre-Execution Guard

**UI Thread**:

```csharp
public async Task OnGenerateCommandAsync(string prompt)
{
    // Submit to Orchestrator (non-blocking)
    await _orchestrator.SubmitGenerateRequestAsync(prompt);
}
```

**Orchestrator immediately**:

```csharp
public async Task<ExecutionSession> SubmitGenerateRequestAsync(string prompt)
{
    // 1. Validate current state
    if (_currentState != OrchestratorState.IDLE)
    {
        throw new InvalidOperationException("Orchestrator busy");
    }

    // 2. Lock workspace (mutex)
    await _workspaceLock.WaitAsync();

    // 3. Create ExecutionSession
    var session = new ExecutionSession
    {
        Id = Guid.NewGuid(),
        Prompt = prompt,
        StartTime = DateTime.UtcNow,
        CancellationToken = new CancellationTokenSource()
    };

    // 4. Transition state
    _currentState = OrchestratorState.AI_PLANNING;

    // 5. Queue for execution
    await _executionQueue.EnqueueAsync(session);

    return session;
}
```

---

### Phase 1 — AI Planning

**Worker Thread**: `AI_Planning_Worker`

```csharp
private async Task ExecuteAIPlanningAsync(ExecutionSession session)
{
    try
    {
        // 1. Prepare Context
        var context = await PrepareAIContextAsync(session.ProjectId);

        // 2. Retrieve relevant symbols
        var symbols = await _indexer.GetRelevantSymbolsAsync(session.Prompt);

        // 3. Retrieve dependency graph
        var dependencies = await _database.GetDependencyGraphAsync(session.ProjectId);

        // 4. Trim context to token budget
        var trimmedContext = await _tokenManager.TrimContextAsync(
            context,
            symbols,
            dependencies,
            maxTokens: 8000
        );

        // 5. Call z-ai-web-dev-sdk (Spec Mode)
        var response = await _aiClient.GenerateTaskGraphAsync(new
        {
            Prompt = session.Prompt,
            Context = trimmedContext,
            Mode = "spec"
        });

        // 6. Validate JSON schema
        var taskGraph = JsonSerializer.Deserialize<TaskGraph>(response.Content);

        if (!ValidateTaskGraphSchema(taskGraph))
        {
            // Retry with AI correction mode
            response = await _aiClient.CorrectTaskGraphAsync(response.Content);
            taskGraph = JsonSerializer.Deserialize<TaskGraph>(response.Content);
        }

        // 7. Persist TaskGraph to SQLite
        await _database.SaveTaskGraphAsync(session.Id, taskGraph);

        // 8. Transition state
        _currentState = OrchestratorState.TASK_GRAPH_READY;

        // 9. Proceed to execution
        await ExecuteTaskGraphAsync(session, taskGraph);
    }
    catch (Exception ex)
    {
        await HandlePlanningErrorAsync(session, ex);
    }
}
```

---

### Phase 2 — Task Execution Loop

**Orchestrator Thread**:

```csharp
private async Task ExecuteTaskGraphAsync(ExecutionSession session, TaskGraph taskGraph)
{
    // Topological sort for dependency order
    var sortedTasks = taskGraph.TopologicalSort();

    foreach (var task in sortedTasks)
    {
        _currentState = OrchestratorState.TASK_EXECUTING;

        // 1. Create snapshot
        var snapshotId = await _snapshotManager.CreateAsync(
            session.ProjectPath,
            reason: $"Before task: {task.Name}"
        );

        try
        {
            // 2. Apply patch
            var patchResult = await _patchEngine.ApplyPatchAsync(task.Patch);

            if (!patchResult.Success)
            {
                throw new PatchException(patchResult.Error);
            }

            // 3. Update Roslyn index
            await _roslynIndexer.IncrementalIndexFileAsync(task.Patch.FilePath);

            // 4. Execute build
            var buildResult = await _buildKernel.BuildProjectAsync(session.ProjectPath);

            if (!buildResult.Success)
            {
                // 5. Classify error
                var errorClass = _errorClassifier.Classify(buildResult.Error);

                // 6. Check retry budget
                if (session.RetryCount < session.RetryBudget)
                {
                    // Enter AI Fix Mode
                    await ExecuteAIFixAsync(session, task, buildResult.Error);
                }
                else
                {
                    // Retry budget exhausted
                    throw new RetryBudgetExhaustedException();
                }
            }
            else
            {
                // Success - commit snapshot
                await _snapshotManager.CommitAsync(snapshotId);
            }
        }
        catch (Exception ex)
        {
            // Rollback to snapshot
            await _snapshotManager.RollbackAsync(snapshotId);
            throw;
        }
    }

    // All tasks completed
    await FinalizeExecutionAsync(session);
}
```

---

### Phase 3 — Patch Application

**Worker Thread**: `Patch_Worker`

```csharp
public async Task<PatchResult> ApplyPatchAsync(Patch patch)
{
    try
    {
        // 1. Load target file
        var sourceCode = await File.ReadAllTextAsync(patch.FilePath);

        // 2. Parse SyntaxTree
        var tree = CSharpSyntaxTree.ParseText(sourceCode);
        var root = await tree.GetRootAsync();

        // 3. Apply AST transformation
        var modifiedRoot = patch.Operation switch
        {
            PatchOperation.ADD_CLASS => AddClass(root, patch.ClassDeclaration),
            PatchOperation.ADD_METHOD => AddMethod(root, patch.MethodDeclaration),
            PatchOperation.MODIFY_METHOD => ModifyMethod(root, patch.MethodName, patch.NewBody),
            PatchOperation.DELETE_METHOD => DeleteMethod(root, patch.MethodName),
            _ => throw new InvalidOperationException($"Unknown operation: {patch.Operation}")
        };

        // 4. Validate syntax
        var diagnostics = modifiedRoot.GetDiagnostics();
        if (diagnostics.Any(d => d.Severity == DiagnosticSeverity.Error))
        {
            return PatchResult.Failed($"Syntax error: {diagnostics.First().GetMessage()}");
        }

        // 5. Format code
        var workspace = new AdhocWorkspace();
        var formattedRoot = Formatter.Format(modifiedRoot, workspace);

        // 6. Write atomically
        var tempFile = Path.GetTempFileName();
        await File.WriteAllTextAsync(tempFile, formattedRoot.ToFullString());
        File.Move(tempFile, patch.FilePath, overwrite: true);

        // 7. Update SQLite graph
        await _database.UpdateFileGraphAsync(patch.FilePath, modifiedRoot);

        return PatchResult.Success();
    }
    catch (Exception ex)
    {
        return PatchResult.Failed(ex.Message);
    }
}
```

---

### Phase 4 — Build Execution

**Worker Thread**: `Build_Worker`

```csharp
public async Task<BuildResult> BuildProjectAsync(string projectPath)
{
    // BuildKernel (Embedded API Mode)
    // - Uses Microsoft.Build.Execution.BuildManager
    // - Uses NuGet.Commands RestoreCommand
    // - No CLI process spawn
    // - No dotnet.exe execution

    return await _executionKernel.BuildAsync(projectPath, "Debug");
}


```

---

### Phase 5 — Silent Retry Loop

**Worker Thread**: `AI_Fix_Worker`

```csharp
private async Task ExecuteAIFixAsync(
    ExecutionSession session,
    Task task,
    BuildError error)
{
    session.RetryCount++;

    // Update UI state if retry count > 3
    if (session.RetryCount > 3)
    {
        await _uiStateManager.TransitionToAsync(UIState.SOFT_RECOVERY);
    }

    // 1. Construct minimal error context
    var errorContext = new
    {
        ErrorMessage = error.Message,
        ErrorCode = error.Code,
        FilePath = error.FilePath,
        LineNumber = error.LineNumber,
        RelevantCode = await GetRelevantCodeAsync(error.FilePath, error.LineNumber)
    };

    // 2. Call z-ai-web-dev-sdk (Fix Mode)
    var fixResponse = await _aiClient.GenerateFixAsync(errorContext);

    // 3. Receive structured patch
    var fixPatch = JsonSerializer.Deserialize<Patch>(fixResponse.Content);

    // 4. Apply patch
    var patchResult = await _patchEngine.ApplyPatchAsync(fixPatch);

    if (!patchResult.Success)
    {
        throw new PatchException($"Fix patch failed: {patchResult.Error}");
    }

    // 5. Build again
    var buildResult = await _buildKernel.BuildProjectAsync(session.ProjectPath);

    if (!buildResult.Success)
    {
        // Retry again if budget allows
        if (session.RetryCount < session.RetryBudget)
        {
            await ExecuteAIFixAsync(session, task, buildResult.Error);
        }
        else
        {
            throw new RetryBudgetExhaustedException();
        }
    }
}
```

---

### Phase 6 — Finalization

**Orchestrator Thread**:

```csharp
private async Task FinalizeExecutionAsync(ExecutionSession session)
{
    try
    {
        // 1. Commit final snapshot
        var finalSnapshotId = await _snapshotManager.CreateAsync(
            session.ProjectPath,
            reason: "Execution completed"
        );

        // 2. Record version in timeline
        await _database.AddVersionAsync(new ProjectVersion
        {
            Id = Guid.NewGuid(),
            ProjectId = session.ProjectId,
            SnapshotId = finalSnapshotId,
            Description = GenerateVersionDescription(session),
            Timestamp = DateTime.UtcNow
        });

        // 3. Update project metadata
        await _database.UpdateProjectMetadataAsync(session.ProjectId, new
        {
            LastBuildResult = "Success",
            LastModified = DateTime.UtcNow,
            SnapshotCount = await _database.GetSnapshotCountAsync(session.ProjectId)
        });

        // 4. Release workspace lock
        _workspaceLock.Release();

        // 5. Transition state
        _currentState = OrchestratorState.COMPLETED;

        // 6. Notify UI
        await _uiStateManager.TransitionToAsync(UIState.PREVIEW_READY);

        // 7. Trigger preview refresh
        await _eventAggregator.PublishAsync(new PreviewRefreshEvent
        {
            ProjectPath = session.ProjectPath
        });
    }
    finally
    {
        // Cleanup
        session.CancellationToken.Dispose();
    }
}
```

---

## 2. AI Trust Boundary & Validation Specification

The Orchestrator enforces a strict **Zero-Trust** policy on all AI-generated code.

### A. Mandatory Validation Gates

All code generated by `AI_Planning_Worker` or `AI_Fix_Worker` must pass these checks **before** touching the disk:

1. **JSON Schema Compliance**: Output must parse strictly against `TaskGraph` or `Patch` schemas.
2. **Path Sandbox**:
   - All paths must be relative to project root.
   - No absolute paths.
   - No `..` traversal.
   - **Banned Directories**: `.git`, `.vs`, `bin`, `obj`, `.metadata.json`, `*.csproj`.
3. **Symbol Consistency**:
   - Modified methods must exist in Roslyn Index.
   - Referenced classes must be resolvable.
4. **File Size Limit**:
   - No single file > 1MB generated.
   - Patch total size < 5MB.

```csharp
if (!PathSecurity.IsSafePath(patch.FilePath, session.ProjectPath))
{
    throw new SecurityException($"AI attempted sandbox violation: {patch.FilePath}");
}
```

---

## 3. Exact Threading Model (WinUI 3)

WinUI 3 has **single UI thread**. Everything heavy must be offloaded.

### A. Formal Invariants

1. **Single Orchestrator**: Only one `ExecutionSession` active at any time.
2. **Serialized Mutations**: File writes are strictly serialized via `WorkspaceLock`.
3. **Singleton Workers**: Exactly one `PatchWorker` and one `BuildWorker` instance exists.
4. **Async Indexing**: Roslyn indexing happens asynchronously after mutations, never blocking the write.
5. **No Shared State**: Workers communicate solely via message passing (Channels/Queues).

---

### Thread Types

#### 🟢 1. UI Thread

**Handles**:

- Rendering
- Button clicks
- ViewModel updates
- Animation
- Status updates

**Never blocks**

**Implementation**:

```csharp
// All UI updates must use DispatcherQueue
private async Task UpdateUIAsync(Action action)
{
    await _dispatcherQueue.EnqueueAsync(action);
}
```

---

#### 🔵 2. Orchestrator Thread

**Single background thread** responsible for:

- State machine transitions
- Task queue management
- Retry controller
- Lock control

**Must be sequential** - No parallel task execution

**Implementation**:

```csharp
public class Orchestrator
{
    private readonly Thread _orchestratorThread;
    private readonly BlockingCollection<ExecutionSession> _executionQueue;

    public Orchestrator()
    {
        _executionQueue = new BlockingCollection<ExecutionSession>();

        _orchestratorThread = new Thread(OrchestratorLoop)
        {
            Name = "Orchestrator",
            IsBackground = true,
            Priority = ThreadPriority.AboveNormal
        };

        _orchestratorThread.Start();
    }

    private void OrchestratorLoop()
    {
        foreach (var session in _executionQueue.GetConsumingEnumerable())
        {
            try
            {
                ExecuteSessionAsync(session).Wait();
            }
            catch (Exception ex)
            {
                HandleExecutionErrorAsync(session, ex).Wait();
            }
        }
    }
}
```

---

#### 🟣 3. AI Worker Thread Pool

**Used for**:

- SDK API calls
- Context preparation
- JSON validation

**Parallel safe** (but limit concurrency to 2 max)

**Implementation**:

```csharp
private static readonly SemaphoreSlim _aiConcurrencyLimit = new(2, 2);

public async Task<AIResponse> CallAIAsync(AIRequest request)
{
    await _aiConcurrencyLimit.WaitAsync();

    try
    {
        return await Task.Run(async () =>
        {
            return await _aiClient.GenerateAsync(request);
        });
    }
    finally
    {
        _aiConcurrencyLimit.Release();
    }
}
```

---

#### 🟡 4. Patch Worker Thread

**Handles**:

- Roslyn parsing
- AST transformations
- Graph updates

**Single-threaded** to prevent file race conditions

**Implementation**:

```csharp
public class PatchEngine
{
    private readonly SemaphoreSlim _patchLock = new(1, 1);

    public async Task<PatchResult> ApplyPatchAsync(Patch patch)
    {
        await _patchLock.WaitAsync();

        try
        {
            return await Task.Run(async () =>
            {
                // Roslyn operations here
                return await ApplyPatchInternalAsync(patch);
            });
        }
        finally
        {
            _patchLock.Release();
        }
    }
}
```

---

#### 🔴 5. Build Worker Thread

**Handles**:

- dotnet restore
- dotnet build
- Log parsing

**Must run isolated. Must be killable.**

**Implementation**:

```csharp
public class BuildKernel
{
    private Process _currentBuildProcess;

    public async Task<BuildResult> BuildProjectAsync(string projectPath)
    {
        return await Task.Run(async () =>
        {
            _currentBuildProcess = new Process { /* ... */ };

            try
            {
                return await ExecuteBuildAsync();
            }
            finally
            {
                _currentBuildProcess = null;
            }
        });
    }

    public void CancelBuild()
    {
        _currentBuildProcess?.Kill();
    }
}
```

---

#### ⚪ 6. Background Maintenance Thread

**Low priority thread**:

- Snapshot pruning
- SQLite vacuum
- Disk usage monitoring
- Index consistency check

**Runs when idle only**

**Implementation**:

```csharp
public class BackgroundMaintenance
{
    private readonly Timer _maintenanceTimer;

    public void StartMaintenance()
    {
        _maintenanceTimer = new Timer(
            callback: RunMaintenanceAsync,
            state: null,
            dueTime: TimeSpan.FromMinutes(5),
            period: TimeSpan.FromMinutes(10)
        );
    }

    private async void RunMaintenanceAsync(object state)
    {
        // Only run if orchestrator is idle
        if (_orchestrator.CurrentState != OrchestratorState.IDLE)
            return;

        await Task.Run(async () =>
        {
            await _snapshotPruner.PruneOldSnapshotsAsync();
            await _database.VacuumAsync();
            await _resourceMonitor.CheckDiskUsageAsync();
            await _indexer.ValidateConsistencyAsync();
        });
    }
}
```

---

### Thread Communication Model

**Use**:

- Channels or BlockingCollection
- Immutable command objects
- Event-driven architecture
- CancellationToken everywhere

**Never**:

- Share mutable state across threads
- Allow patch + build concurrently
- Allow two builds at once

**Implementation**:

```csharp
// Immutable command
public record GenerateCommand(string Prompt, string ProjectId);

// Event-driven
public class EventAggregator
{
    private readonly ConcurrentDictionary<Type, List<Delegate>> _subscribers = new();

    public void Subscribe<T>(Action<T> handler)
    {
        _subscribers.GetOrAdd(typeof(T), _ => new List<Delegate>()).Add(handler);
    }

    public async Task PublishAsync<T>(T @event)
    {
        if (_subscribers.TryGetValue(typeof(T), out var handlers))
        {
            foreach (var handler in handlers.Cast<Action<T>>())
            {
                await Task.Run(() => handler(@event));
            }
        }
    }
}
```

---

## 4. Full Boot Sequence (App Launch)

When user launches app:

---

### Stage 1 — App Startup

**UI thread**:

```csharp
protected override async void OnLaunched(LaunchActivatedEventArgs args)
{
    // 1. Initialize WinUI window
    _window = new MainWindow();

    // 2. Show splash screen
    _window.Content = new SplashScreen { Status = "Preparing environment…" };
    _window.Activate();

    // 3. Start background initialization
    await InitializeApplicationAsync();
}
```

---

### Stage 2 — Environment Validation (Background)

**Worker Thread**:

```csharp
private async Task<ValidationResult> ValidateEnvironmentAsync()
{
    var results = new List<ValidationIssue>();

    // 1. Check .NET SDK availability
    var sdkVersion = await GetDotNetSdkVersionAsync();
    if (sdkVersion == null)
    {
        results.Add(new ValidationIssue(".NET SDK not found", Severity.Critical));
    }

    // 2. Validate MSBuild path
    var msbuildPath = await FindMSBuildAsync();
    if (msbuildPath == null)
    {
        results.Add(new ValidationIssue("MSBuild not accessible", Severity.Critical));
    }

    // 3. Verify NuGet integrity
    var nugetValid = await ValidateNuGetAsync();
    if (!nugetValid)
    {
        results.Add(new ValidationIssue("NuGet configuration issue", Severity.Warning));
    }

    // 4. Check disk space
    var availableGB = GetAvailableDiskSpace();
    if (availableGB < 1.0)
    {
        results.Add(new ValidationIssue("Low disk space", Severity.Warning));
    }

    // 5. Validate workspace folder
    if (!Directory.Exists(_workspacePath))
    {
        Directory.CreateDirectory(_workspacePath);
    }

    // 6. Initialize SQLite connection
    await _database.InitializeAsync();

    return new ValidationResult(results);
}
```

**If failure**:

```csharp
if (validationResult.HasCriticalIssues)
{
    await ShowEnvironmentErrorPanelAsync(validationResult);
    return;
}
```

---

### Stage 3 — Load Project Registry

**Background thread**:

```csharp
private async Task LoadProjectRegistryAsync()
{
    // 1. Read Workspaces directory
    var projectDirs = Directory.GetDirectories(_workspacePath);

    foreach (var projectDir in projectDirs)
    {
        // 2. Load metadata.json
        var metadataPath = Path.Combine(projectDir, ".metadata.json");

        if (File.Exists(metadataPath))
        {
            var metadata = await JsonSerializer.DeserializeAsync<ProjectMetadata>(
                File.OpenRead(metadataPath)
            );

            // 3. Validate snapshots
            var snapshotsValid = await ValidateSnapshotsAsync(metadata.Id);

            // 4. Validate graph integrity
            var graphValid = await ValidateGraphIntegrityAsync(metadata.Id);

            if (!snapshotsValid || !graphValid)
            {
                // Attempt auto-repair
                await AttemptAutoRepairAsync(metadata.Id);
            }

            // Add to registry
            _projectRegistry.Add(metadata);
        }
    }
}
```

---

### Stage 4 — Initialize Services

**Instantiate singletons**:

```csharp
private void InitializeServices()
{
    // Orchestrator
    _orchestrator = new Orchestrator(_database, _eventAggregator);

    // RoslynIndexer
    _roslynIndexer = new RoslynIndexer(_database);

    // PatchEngine
    _patchEngine = new PatchEngine(_roslynIndexer, _database);

    // BuildKernel
    _buildKernel = new BuildKernel();

    // SnapshotManager
    _snapshotManager = new SnapshotManager(_database, _workspacePath);

    // AIClient (z-ai-web-dev-sdk)
    _aiClient = new AIClient(apiKey: _configuration["AI:ApiKey"]);

    // ResourceMonitor
    _resourceMonitor = new ResourceMonitor(_workspacePath);
    _resourceMonitor.StartMonitoring();
}
```

---

### Stage 5 — Warm-Up Index

**If last project exists**:

```csharp
private async Task WarmUpIndexAsync()
{
    var lastProject = await _database.GetLastOpenedProjectAsync();

    if (lastProject != null)
    {
        // 1. Pre-load symbol graph
        await _roslynIndexer.IndexProjectAsync(lastProject.WorkspacePath);

        // 2. Pre-cache dependency tree
        await _database.CacheDependencyTreeAsync(lastProject.Id);

        // 3. Prepare AI context
        await _aiContextCache.PrepareContextAsync(lastProject.WorkspacePath);

        // This reduces first-generation latency
    }
}
```

---

### Stage 6 — UI Ready

```csharp
private async Task FinalizeBootAsync()
{
    // 1. Fade out splash
    await SplashScreen.FadeOutAsync(duration: 300);

    // 2. Show main window
    _window.Content = new MainPage();

    // 3. Set initial state
    var lastProject = await _database.GetLastOpenedProjectAsync();

    if (lastProject != null)
    {
        await _uiStateManager.TransitionToAsync(UIState.PREVIEW_READY);
        await LoadProjectAsync(lastProject.Id);
    }
    else
    {
        await _uiStateManager.TransitionToAsync(UIState.EMPTY_IDLE);
    }
}
```

---

## 4. Safety Controls During Boot

**Must enforce**:

```csharp
private async Task EnforceSafetyControlsAsync()
{
    // 1. No orphan build processes
    await KillOrphanBuildProcessesAsync();

    // 2. Clean leftover lock files
    CleanLockFiles();

    // 3. Terminate stale sessions
    await TerminateStaleSessionsAsync();

    // 4. Validate last incomplete execution
    var incompleteSession = await _database.GetIncompleteSessionAsync();

    if (incompleteSession != null)
    {
        // 5. Rollback partial snapshot if crash occurred
        await HandleCrashRecoveryAsync(incompleteSession);
    }
}
```

---

## 5. Crash Recovery Flow

**If app previously crashed mid-build**:

```csharp
private async Task HandleCrashRecoveryAsync(ExecutionSession incompleteSession)
{
    // 1. Detect incomplete ExecutionSession
    _logger.LogWarning("Detected incomplete session: {SessionId}", incompleteSession.Id);

    // 2. Rollback to last stable snapshot
    var lastStableSnapshot = await _database.GetLastStableSnapshotAsync(
        incompleteSession.ProjectId
    );

    await _snapshotManager.RollbackAsync(lastStableSnapshot.Id);

    // 3. Mark previous version as failed
    await _database.MarkVersionAsFailedAsync(incompleteSession.Id);

    // 4. Notify user gently
    await ShowToastAsync(
        "We restored your project to a stable version.",
        severity: InfoBarSeverity.Informational
    );

    // No panic. No logs shown.
}
```

---

## 6. Full Hidden Lifecycle Summary

**From launch → build → export**:

```
Boot
  → Validate environment
  → Load services
  → Warm-up index
  → Wait for user (IDLE)

Generate command
  → AI planning (Worker Thread)
  → Snapshot (Background)
  → Patch (Patch Worker)
  → Index (Background)
  → Build (Build Worker)
  → Retry if needed (AI Fix Worker)
  → Commit (Orchestrator)
  → Update timeline (Database)
  → Idle (COMPLETED → IDLE)
```

**All while**:

- UI remains responsive
- No blocking main thread
- No visible internal mechanics

---

## Final Architecture Maturity

With this specification, you now have:

✔ Deterministic state engine  
✔ Safe multithreaded model  
✔ Controlled AI integration  
✔ Local build kernel  
✔ Snapshot rollback system  
✔ Crash recovery  
✔ Hidden background maintenance  
✔ Clean Lovable-style surface

**This is production-grade.**

---

## References

- [BACKGROUND_SYSTEMS_SPECIFICATION.md](./BACKGROUND_SYSTEMS_SPECIFICATION.md) - Hidden systems
- [ORCHESTRATOR_SPECIFICATION.md](./ORCHESTRATOR_SPECIFICATION.md) - State machine
- [UI_STATE_MACHINE.md](./UI_STATE_MACHINE.md) - User-visible states
- [ERROR_HANDLING_SPECIFICATION.md](./ERROR_HANDLING_SPECIFICATION.md) - Retry logic
