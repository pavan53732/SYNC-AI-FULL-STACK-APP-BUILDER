# Database Specification - SQLite Data Persistence

**Purpose:** Define complete database schema, migration strategy, and data persistence patterns.  
**Scope:** SQLite database for project metadata, symbol indexing, build history, and orchestrator state.  
**Framework:** SQLite with Dapper ORM, .NET 8

---

## 1. Database Architecture

### Overview

The system uses **SQLite** for all local data persistence. Each component has its own database file to ensure separation of concerns and enable independent backups.

### Database Files

```
C:\Users\{User}\AppData\Local\SyncAIAppBuilder\
├── application.db          # Application-level data (settings, projects list)
├── Workspaces\
│   └── {ProjectId}\
│       └── .builder\
│           ├── project_graph.db    # Symbol index, dependencies, Roslyn data
│           ├── orchestrator.db     # State machine, event log, task history
│           └── build_history.db    # Build results, error classifications
```

---

## 2. Complete Database Schemas

### 2.1 Application Database (application.db)

**Purpose**: Application-wide settings, project registry, user preferences.

```sql
-- ============================================
-- PROJECTS TABLE
-- ============================================
CREATE TABLE Projects (
    Id TEXT PRIMARY KEY,                    -- GUID
    Name TEXT NOT NULL,
    Description TEXT,
    WorkspacePath TEXT NOT NULL UNIQUE,     -- Absolute path to workspace
    CreatedDate DATETIME NOT NULL,
    ModifiedDate DATETIME NOT NULL,
    LastOpenedDate DATETIME,
    IsArchived INTEGER DEFAULT 0,           -- Boolean (0/1)
    HealthStatus TEXT DEFAULT 'Unknown',    -- 'Healthy', 'Warning', 'Error', 'Unknown'
    SdkVersion TEXT,                        -- Pinned .NET SDK version
    TargetFramework TEXT                    -- e.g., 'net8.0-windows10.0.19041.0'
);

CREATE INDEX idx_projects_modified ON Projects(ModifiedDate DESC);
CREATE INDEX idx_projects_health ON Projects(HealthStatus);

-- ============================================
-- APPLICATION SETTINGS
-- ============================================
CREATE TABLE Settings (
    Key TEXT PRIMARY KEY,
    Value TEXT NOT NULL,
    Category TEXT,                          -- 'AI', 'Build', 'UI', 'Advanced'
    DataType TEXT NOT NULL,                 -- 'String', 'Integer', 'Boolean', 'Json'
    ModifiedDate DATETIME NOT NULL
);

-- Default settings
INSERT INTO Settings (Key, Value, Category, DataType, ModifiedDate) VALUES
    ('AI.ApiKey', '', 'AI', 'String', datetime('now')),
    ('AI.Model', 'gpt-4', 'AI', 'String', datetime('now')),
    ('Build.MaxRetries', '5', 'Build', 'Integer', datetime('now')),
    ('Build.TimeoutSeconds', '60', 'Build', 'Integer', datetime('now')),
    ('UI.Theme', 'System', 'UI', 'String', datetime('now')),
    ('UI.ShowPreviewByDefault', '1', 'UI', 'Boolean', datetime('now'));

-- ============================================
-- RECENT PROMPTS (for autocomplete)
-- ============================================
CREATE TABLE RecentPrompts (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Prompt TEXT NOT NULL,
    UsageCount INTEGER DEFAULT 1,
    LastUsedDate DATETIME NOT NULL,
    ProjectId TEXT,
    FOREIGN KEY (ProjectId) REFERENCES Projects(Id) ON DELETE SET NULL
);

CREATE INDEX idx_recent_prompts_date ON RecentPrompts(LastUsedDate DESC);
```

---

### 2.2 Project Graph Database (project_graph.db)

> **SOURCE OF TRUTH**: The schema for the Semantic Graph (Files, Symbols, SyntaxNodes, Edges, XamlBindings) is authoritative in [DATABASE_SCHEMA_SPECIFICATION.md](./DATABASE_SCHEMA_SPECIFICATION.md).
>
> Please refer to that document for the exact table definitions for:
> - `files`
> - `syntax_nodes`
> - `symbols`
> - `symbol_edges`
> - `xaml_bindings`
>
> The `project_graph.db` also includes:

```sql
-- ============================================
-- NUGET PACKAGES (Package Management)
-- ============================================
CREATE TABLE NuGetPackages (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PackageId TEXT NOT NULL,
    Version TEXT NOT NULL,
    IsDirectDependency INTEGER DEFAULT 1,
    AddedDate DATETIME NOT NULL,
    UNIQUE(PackageId, Version)
);

CREATE INDEX idx_nuget_packages_id ON NuGetPackages(PackageId);
```


---

### 2.3 Orchestrator Database (orchestrator.db)

**Purpose**: State machine events, task execution history, retry tracking.

```sql
-- ============================================
-- ORCHESTRATOR STATES
-- ============================================
CREATE TABLE OrchestratorStates (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    State TEXT NOT NULL,                    -- 'IDLE', 'SPEC_PARSED', 'TASK_EXECUTING', etc.
    Timestamp DATETIME NOT NULL,
    Metadata TEXT,                          -- JSON metadata
    PreviousStateId INTEGER,
    FOREIGN KEY (PreviousStateId) REFERENCES OrchestratorStates(Id)
);

CREATE INDEX idx_orchestrator_states_time ON OrchestratorStates(Timestamp DESC);

-- ============================================
-- TASKS TABLE
-- ============================================
CREATE TABLE Tasks (
    Id TEXT PRIMARY KEY,                    -- GUID
    TaskType TEXT NOT NULL,                 -- 'GenerateCode', 'ApplyPatch', 'Build', 'Validate'
    Description TEXT,
    Status TEXT NOT NULL,                   -- 'Pending', 'Running', 'Completed', 'Failed', 'Retrying'
    CreatedDate DATETIME NOT NULL,
    StartedDate DATETIME,
    CompletedDate DATETIME,
    RetryCount INTEGER DEFAULT 0,
    MaxRetries INTEGER DEFAULT 5,
    ParentTaskId TEXT,
    Priority INTEGER DEFAULT 0,
    Payload TEXT,                           -- JSON task payload
    Result TEXT,                            -- JSON task result
    FOREIGN KEY (ParentTaskId) REFERENCES Tasks(Id) ON DELETE CASCADE
);

CREATE INDEX idx_tasks_status ON Tasks(Status);
CREATE INDEX idx_tasks_created ON Tasks(CreatedDate DESC);
CREATE INDEX idx_tasks_parent ON Tasks(ParentTaskId);

-- ============================================
-- TASK EVENTS (Event Sourcing)
-- ============================================
CREATE TABLE TaskEvents (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    TaskId TEXT NOT NULL,
    EventType TEXT NOT NULL,                -- 'Created', 'Started', 'Completed', 'Failed', 'Retrying'
    Timestamp DATETIME NOT NULL,
    EventData TEXT,                         -- JSON event data
    FOREIGN KEY (TaskId) REFERENCES Tasks(Id) ON DELETE CASCADE
);

CREATE INDEX idx_task_events_task ON TaskEvents(TaskId);
CREATE INDEX idx_task_events_time ON TaskEvents(Timestamp DESC);

-- ============================================
-- RETRY HISTORY
-- ============================================
CREATE TABLE RetryHistory (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    TaskId TEXT NOT NULL,
    RetryNumber INTEGER NOT NULL,
    Timestamp DATETIME NOT NULL,
    ErrorType TEXT,
    ErrorMessage TEXT,
    FixAttempt TEXT,                        -- JSON describing what was tried
    FOREIGN KEY (TaskId) REFERENCES Tasks(Id) ON DELETE CASCADE
);

CREATE INDEX idx_retry_history_task ON RetryHistory(TaskId);

-- ============================================
-- SNAPSHOTS REGISTRY
-- ============================================
CREATE TABLE Snapshots (
    Id TEXT PRIMARY KEY,                    -- GUID
    TaskId TEXT,
    FilePath TEXT NOT NULL,                 -- Path to .zip file
    CreatedDate DATETIME NOT NULL,
    SizeBytes INTEGER,
    FileCount INTEGER,
    IsCommitted INTEGER DEFAULT 0,          -- Whether this snapshot represents a successful state
    FOREIGN KEY (TaskId) REFERENCES Tasks(Id) ON DELETE SET NULL
);

CREATE INDEX idx_snapshots_task ON Snapshots(TaskId);
CREATE INDEX idx_snapshots_committed ON Snapshots(IsCommitted);
```

---

### 2.4 Build History Database (build_history.db)

**Purpose**: Build results, error classifications, performance metrics.

```sql
-- ============================================
-- BUILD RESULTS
-- ============================================
CREATE TABLE BuildResults (
    Id TEXT PRIMARY KEY,                    -- GUID
    TaskId TEXT,
    ProjectPath TEXT NOT NULL,
    Configuration TEXT DEFAULT 'Debug',     -- 'Debug' or 'Release'
    Success INTEGER NOT NULL,               -- Boolean
    StartTime DATETIME NOT NULL,
    EndTime DATETIME NOT NULL,
    DurationMs INTEGER NOT NULL,
    ExitCode INTEGER,
    BuildLog TEXT,                          -- Full MSBuild output
    FOREIGN KEY (TaskId) REFERENCES Tasks(Id) ON DELETE SET NULL
);

CREATE INDEX idx_build_results_time ON BuildResults(StartTime DESC);
CREATE INDEX idx_build_results_success ON BuildResults(Success);

-- ============================================
-- BUILD ERRORS
-- ============================================
CREATE TABLE BuildErrors (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    BuildResultId TEXT NOT NULL,
    ErrorCode TEXT,                         -- e.g., 'CS0103', 'XDG1234'
    ErrorType TEXT NOT NULL,                -- 'CSharpCompiler', 'XamlCompiler', 'NuGetRestore', etc.
    Severity TEXT NOT NULL,                 -- 'Error', 'Warning'
    Message TEXT NOT NULL,
    FilePath TEXT,
    LineNumber INTEGER,
    ColumnNumber INTEGER,
    FOREIGN KEY (BuildResultId) REFERENCES BuildResults(Id) ON DELETE CASCADE
);

CREATE INDEX idx_build_errors_result ON BuildErrors(BuildResultId);
CREATE INDEX idx_build_errors_code ON BuildErrors(ErrorCode);
CREATE INDEX idx_build_errors_type ON BuildErrors(ErrorType);

-- ============================================
-- ERROR PATTERNS (for AI learning)
-- ============================================
CREATE TABLE ErrorPatterns (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    ErrorCode TEXT NOT NULL,
    ErrorType TEXT NOT NULL,
    Pattern TEXT NOT NULL,                  -- Regex pattern for matching
    CommonCause TEXT,
    SuggestedFix TEXT,
    OccurrenceCount INTEGER DEFAULT 1,
    LastSeen DATETIME NOT NULL,
    UNIQUE(ErrorCode, Pattern)
);

CREATE INDEX idx_error_patterns_code ON ErrorPatterns(ErrorCode);

-- ============================================
-- PERFORMANCE METRICS
-- ============================================
CREATE TABLE PerformanceMetrics (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    BuildResultId TEXT NOT NULL,
    MetricName TEXT NOT NULL,               -- 'RestoreTime', 'CompileTime', 'LinkTime'
    MetricValue REAL NOT NULL,
    Unit TEXT NOT NULL,                     -- 'ms', 'seconds', 'MB'
    FOREIGN KEY (BuildResultId) REFERENCES BuildResults(Id) ON DELETE CASCADE
);

CREATE INDEX idx_perf_metrics_build ON PerformanceMetrics(BuildResultId);
```

---

## 3. Database Access Layer

### 3.1 Repository Pattern

```csharp
public interface IRepository<T> where T : class
{
    Task<T> GetByIdAsync(object id);
    Task<IEnumerable<T>> GetAllAsync();
    Task<T> AddAsync(T entity);
    Task UpdateAsync(T entity);
    Task DeleteAsync(object id);
}

public class DapperRepository<T> : IRepository<T> where T : class
{
    private readonly IDbConnection _connection;
    
    public DapperRepository(IDbConnection connection)
    {
        _connection = connection;
    }
    
    public async Task<T> GetByIdAsync(object id)
    {
        var tableName = typeof(T).Name + "s";
        var sql = $"SELECT * FROM {tableName} WHERE Id = @Id";
        return await _connection.QuerySingleOrDefaultAsync<T>(sql, new { Id = id });
    }
    
    public async Task<IEnumerable<T>> GetAllAsync()
    {
        var tableName = typeof(T).Name + "s";
        var sql = $"SELECT * FROM {tableName}";
        return await _connection.QueryAsync<T>(sql);
    }
    
    public async Task<T> AddAsync(T entity)
    {
        // Implementation using Dapper.Contrib or custom SQL
        await _connection.InsertAsync(entity);
        return entity;
    }
    
    public async Task UpdateAsync(T entity)
    {
        await _connection.UpdateAsync(entity);
    }
    
    public async Task DeleteAsync(object id)
    {
        var tableName = typeof(T).Name + "s";
        var sql = $"DELETE FROM {tableName} WHERE Id = @Id";
        await _connection.ExecuteAsync(sql, new { Id = id });
    }
}
```

### 3.2 Specialized Repositories

```csharp
public interface IProjectRepository : IRepository<Project>
{
    Task<IEnumerable<Project>> GetRecentProjectsAsync(int count);
    Task<Project> GetByWorkspacePathAsync(string path);
    Task UpdateHealthStatusAsync(string projectId, string healthStatus);
}

public class ProjectRepository : DapperRepository<Project>, IProjectRepository
{
    public ProjectRepository(IDbConnection connection) : base(connection) { }
    
    public async Task<IEnumerable<Project>> GetRecentProjectsAsync(int count)
    {
        var sql = @"
            SELECT * FROM Projects 
            WHERE IsArchived = 0 
            ORDER BY LastOpenedDate DESC 
            LIMIT @Count";
        
        return await _connection.QueryAsync<Project>(sql, new { Count = count });
    }
    
    public async Task<Project> GetByWorkspacePathAsync(string path)
    {
        var sql = "SELECT * FROM Projects WHERE WorkspacePath = @Path";
        return await _connection.QuerySingleOrDefaultAsync<Project>(sql, new { Path = path });
    }
    
    public async Task UpdateHealthStatusAsync(string projectId, string healthStatus)
    {
        var sql = @"
            UPDATE Projects 
            SET HealthStatus = @HealthStatus, ModifiedDate = @Now 
            WHERE Id = @ProjectId";
        
        await _connection.ExecuteAsync(sql, new 
        { 
            ProjectId = projectId, 
            HealthStatus = healthStatus, 
            Now = DateTime.UtcNow 
        });
    }
}
```

---

## 4. Migration Strategy

### 4.1 Migration Framework

```csharp
public interface IMigration
{
    int Version { get; }
    string Description { get; }
    Task UpAsync(IDbConnection connection);
    Task DownAsync(IDbConnection connection);
}

public class MigrationRunner
{
    private readonly IDbConnection _connection;
    private readonly ILogger<MigrationRunner> _logger;
    
    public async Task MigrateAsync()
    {
        // Ensure migrations table exists
        await EnsureMigrationsTableAsync();
        
        // Get current version
        var currentVersion = await GetCurrentVersionAsync();
        
        // Get all migrations
        var migrations = GetAllMigrations()
            .Where(m => m.Version > currentVersion)
            .OrderBy(m => m.Version);
        
        // Apply migrations
        foreach (var migration in migrations)
        {
            _logger.LogInformation("Applying migration {Version}: {Description}", 
                migration.Version, migration.Description);
            
            using var transaction = _connection.BeginTransaction();
            try
            {
                await migration.UpAsync(_connection);
                await RecordMigrationAsync(migration.Version, migration.Description);
                transaction.Commit();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Migration {Version} failed", migration.Version);
                transaction.Rollback();
                throw;
            }
        }
    }
    
    private async Task EnsureMigrationsTableAsync()
    {
        var sql = @"
            CREATE TABLE IF NOT EXISTS Migrations (
                Version INTEGER PRIMARY KEY,
                Description TEXT NOT NULL,
                AppliedDate DATETIME NOT NULL
            )";
        
        await _connection.ExecuteAsync(sql);
    }
    
    private async Task<int> GetCurrentVersionAsync()
    {
        var sql = "SELECT COALESCE(MAX(Version), 0) FROM Migrations";
        return await _connection.QuerySingleAsync<int>(sql);
    }
    
    private async Task RecordMigrationAsync(int version, string description)
    {
        var sql = @"
            INSERT INTO Migrations (Version, Description, AppliedDate) 
            VALUES (@Version, @Description, @Now)";
        
        await _connection.ExecuteAsync(sql, new 
        { 
            Version = version, 
            Description = description, 
            Now = DateTime.UtcNow 
        });
    }
}
```

### 4.2 Example Migration

```csharp
public class Migration_001_InitialSchema : IMigration
{
    public int Version => 1;
    public string Description => "Initial database schema";
    
    public async Task UpAsync(IDbConnection connection)
    {
        // Create Projects table
        await connection.ExecuteAsync(@"
            CREATE TABLE Projects (
                Id TEXT PRIMARY KEY,
                Name TEXT NOT NULL,
                Description TEXT,
                WorkspacePath TEXT NOT NULL UNIQUE,
                CreatedDate DATETIME NOT NULL,
                ModifiedDate DATETIME NOT NULL
            )");
        
        // Create indexes
        await connection.ExecuteAsync(@"
            CREATE INDEX idx_projects_modified ON Projects(ModifiedDate DESC)");
    }
    
    public async Task DownAsync(IDbConnection connection)
    {
        await connection.ExecuteAsync("DROP TABLE IF EXISTS Projects");
    }
}
```

---

## 5. Transaction Management

### 5.1 Unit of Work Pattern

```csharp
public interface IUnitOfWork : IDisposable
{
    IProjectRepository Projects { get; }
    ISymbolRepository Symbols { get; }
    ITaskRepository Tasks { get; }
    
    Task<int> SaveChangesAsync();
    Task BeginTransactionAsync();
    Task CommitAsync();
    Task RollbackAsync();
}

public class UnitOfWork : IUnitOfWork
{
    private readonly IDbConnection _connection;
    private IDbTransaction _transaction;
    
    public IProjectRepository Projects { get; }
    public ISymbolRepository Symbols { get; }
    public ITaskRepository Tasks { get; }
    
    public UnitOfWork(IDbConnection connection)
    {
        _connection = connection;
        Projects = new ProjectRepository(connection);
        Symbols = new SymbolRepository(connection);
        Tasks = new TaskRepository(connection);
    }
    
    public async Task BeginTransactionAsync()
    {
        _transaction = _connection.BeginTransaction();
    }
    
    public async Task CommitAsync()
    {
        _transaction?.Commit();
        _transaction?.Dispose();
        _transaction = null;
    }
    
    public async Task RollbackAsync()
    {
        _transaction?.Rollback();
        _transaction?.Dispose();
        _transaction = null;
    }
    
    public async Task<int> SaveChangesAsync()
    {
        // For Dapper, changes are immediate
        // This method exists for interface compatibility
        return await Task.FromResult(0);
    }
    
    public void Dispose()
    {
        _transaction?.Dispose();
    }
}
```

---

## 6. Backup and Recovery

### 6.1 Backup Strategy

```csharp
public class DatabaseBackupService
{
    public async Task CreateBackupAsync(string databasePath, string backupPath)
    {
        // SQLite backup using VACUUM INTO
        using var connection = new SqliteConnection($"Data Source={databasePath}");
        await connection.OpenAsync();
        
        var command = connection.CreateCommand();
        command.CommandText = $"VACUUM INTO '{backupPath}'";
        await command.ExecuteNonQueryAsync();
    }
    
    public async Task RestoreBackupAsync(string backupPath, string databasePath)
    {
        // Close all connections first
        SqliteConnection.ClearAllPools();
        
        // Copy backup to database location
        File.Copy(backupPath, databasePath, overwrite: true);
    }
    
    public async Task CreateAutoBackupAsync(string projectId)
    {
        var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
        var backupDir = Path.Combine(GetProjectPath(projectId), ".builder", "backups");
        Directory.CreateDirectory(backupDir);
        
        // Backup all databases
        await CreateBackupAsync(
            GetDatabasePath(projectId, "project_graph.db"),
            Path.Combine(backupDir, $"project_graph_{timestamp}.db"));
        
        await CreateBackupAsync(
            GetDatabasePath(projectId, "orchestrator.db"),
            Path.Combine(backupDir, $"orchestrator_{timestamp}.db"));
    }
}
```

---

## 7. Performance Optimization

### 7.1 Indexing Strategy

- **Primary Keys**: All tables have primary keys
- **Foreign Keys**: Indexed automatically
- **Query Patterns**: Indexes on frequently queried columns
- **Composite Indexes**: For multi-column WHERE clauses

### 7.2 Connection Pooling

```csharp
public class DatabaseConnectionFactory
{
    private readonly ConcurrentDictionary<string, SqliteConnection> _connections = new();
    
    public SqliteConnection GetConnection(string databasePath)
    {
        return _connections.GetOrAdd(databasePath, path =>
        {
            var connectionString = new SqliteConnectionStringBuilder
            {
                DataSource = path,
                Mode = SqliteOpenMode.ReadWriteCreate,
                Cache = SqliteCacheMode.Shared,
                Pooling = true
            }.ToString();
            
            return new SqliteConnection(connectionString);
        });
    }
}
```

### 7.3 Query Optimization

```csharp
// Use parameterized queries
var sql = "SELECT * FROM Symbols WHERE FileId = @FileId";
var symbols = await connection.QueryAsync<Symbol>(sql, new { FileId = fileId });

// Use LIMIT for large result sets
var sql = "SELECT * FROM BuildResults ORDER BY StartTime DESC LIMIT 100";

// Use EXISTS instead of COUNT for existence checks
var sql = "SELECT EXISTS(SELECT 1 FROM Projects WHERE Id = @Id)";
```

---

## References

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [ROSLYN_INTEGRATION_SPECIFICATION.md](ROSLYN_INTEGRATION_SPECIFICATION.md) - Symbol indexing
- [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) - State machine persistence
- [BUILD_SYSTEM_SPECIFICATION.md](BUILD_SYSTEM_SPECIFICATION.md) - Build history tracking
