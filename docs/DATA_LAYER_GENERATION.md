# DATA LAYER GENERATION

> **EF Core + SQLite Code Generation Rules: Deterministic Rules for Data Layer Construction**
>
> **Related Core Documents:**
>
> - [STRUCTURED_SPEC_FORMAT.md](./STRUCTURED_SPEC_FORMAT.md) — AppSpec `domainModel` input
> - [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — `{AppName}.Data` project structure
> - [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Schema Agent that applies these rules

---

## Table of Contents

1. [Overview](#1-overview)
2. [Platform Constraints](#2-platform-constraints)
3. [Entity Model Generation](#3-entity-model-generation)
4. [EF Core DbContext Generation](#4-ef-core-dbcontext-generation)
5. [Relationship Mapping Rules](#5-relationship-mapping-rules)
6. [Repository Pattern Rules](#6-repository-pattern-rules)
7. [Migration Rules](#7-migration-rules)
8. [Database Initialization Rules](#8-database-initialization-rules)
9. [ViewModel ↔ Repository Contract](#9-viewmodel--repository-contract)
10. [Banned Patterns](#10-banned-patterns)
11. [Common Generation Examples](#11-common-generation-examples)

---

## 1. Overview

The **Schema Agent** uses these rules deterministically to generate all C# code in the `{AppName}.Data` and `{AppName}.Core/Models` directories. Rules here take absolute precedence over any AI-inferred patterns. When a conflict arises between a rule below and an AI suggestion, the rule wins.

### Responsibility Split

| Component                                            | Owner Project    | Responsibility                                 |
| ---------------------------------------------------- | ---------------- | ---------------------------------------------- |
| Model classes (`{Entity}.cs`)                        | `{AppName}.Core` | Plain C# domain objects (no EF attributes)     |
| `AppDbContext.cs`                                    | `{AppName}.Data` | EF Core configuration, DbSets, OnModelCreating |
| Repository interfaces (`I{Entity}Repository.cs`)     | `{AppName}.Core` | Contracts for data access                      |
| Repository implementations (`{Entity}Repository.cs`) | `{AppName}.Data` | EF Core-backed implementations                 |
| Migrations                                           | `{AppName}.Data` | EF Core auto-generated migration files         |

---

## 2. Platform Constraints

| Constraint        | Value                                             | Rationale                                 |
| ----------------- | ------------------------------------------------- | ----------------------------------------- |
| Database engine   | SQLite only                                       | Local-first, no server dependency         |
| ORM               | EF Core 8.x only                                  | Consistent migration tooling              |
| Connection string | File path in `LocalApplicationData`               | Data persists per-user, per-machine       |
| Schema migrations | EF Core Migrations (code-first)                   | Deterministic schema upgrades             |
| Connection mode   | Single connection, WAL mode enabled               | Prevents locking issues on Windows        |
| Raw SQL           | Forbidden (except in special aggregation queries) | Prevents injection and portability issues |

### SQLite File Path Rule

```csharp
// ALWAYS use this path pattern for the SQLite database file
var dbPath = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
    "{AppName}",   // ← must match AppSpec.appIdentity.name exactly
    "app.db"       // ← always named app.db
);
Directory.CreateDirectory(Path.GetDirectoryName(dbPath)!);
```

---

## 3. Entity Model Generation

### Rule 1: Fluent API Only (No Data Annotations)

> **CRITICAL**: Models in `{AppName}.Core/Models` must contain **zero** EF Core attributes.
> All EF Core configuration goes in `AppDbContext.OnModelCreating()` using Fluent API.

```csharp
// ✅ CORRECT — Clean model, no EF attributes
public class Category
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public double BudgetAmount { get; set; }
    public string? ColorHex { get; set; }
    public List<Expense> Expenses { get; set; } = [];
}

// ❌ FORBIDDEN — Data Annotations on model
public class Category
{
    [Key]                // ← FORBIDDEN
    [Required]           // ← FORBIDDEN
    public Guid Id { get; set; }
    ...
}
```

### Rule 2: Primary Key Format

| Condition                                   | Generated Code                                                      |
| ------------------------------------------- | ------------------------------------------------------------------- |
| Field `isPrimaryKey: true` and `type: Guid` | `public Guid Id { get; set; } = Guid.NewGuid();`                    |
| Field `isPrimaryKey: true` and `type: int`  | `public int Id { get; set; }` (EF Core uses identity/autoincrement) |

### Rule 3: Nullable Reference Types

| Spec Field                               | C# Property                                        |
| ---------------------------------------- | -------------------------------------------------- |
| `isRequired: true`, `type: string`       | `public string Name { get; set; } = string.Empty;` |
| `isRequired: false`, `type: string`      | `public string? Notes { get; set; }`               |
| `isRequired: true`, `type: Guid` (FK)    | `public Guid CategoryId { get; set; }`             |
| `isRequired: false`, `type: Guid` (FK)   | `public Guid? CategoryId { get; set; }`            |
| `isRequired: true`, `type: DateTime`     | `public DateTime Date { get; set; }`               |
| `isRequired: false`, `type: DateTime`    | `public DateTime? Date { get; set; }`              |
| `isRequired: false`, `defaultValue: 0.0` | `public double BudgetAmount { get; set; } = 0.0;`  |
| `type: byte[]` (image/binary)            | `public byte[]? ImageData { get; set; }`           |

### Rule 4: Navigation Properties

```csharp
// OneToMany (parent side — Category has many Expenses)
public List<Expense> Expenses { get; set; } = [];

// OneToMany (child side — Expense belongs to Category)
public Guid CategoryId { get; set; }
public Category? Category { get; set; }

// ManyToMany (both sides use ICollection)
public ICollection<Tag> Tags { get; set; } = [];
```

---

## 4. EF Core DbContext Generation

### DbContext Template

```csharp
namespace {AppName}.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    // One DbSet per entity — property name is plural of entity name
    public DbSet<Category> Categories { get; set; } = null!;
    public DbSet<Expense> Expenses { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Entity configurations — see Rule 5 (Relationship Mapping)
        modelBuilder.Entity<Category>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(200);
            entity.Property(e => e.BudgetAmount).HasDefaultValue(0.0);
            entity.HasIndex(e => e.Name).IsUnique();
        });

        modelBuilder.Entity<Expense>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title).IsRequired().HasMaxLength(500);
            entity.Property(e => e.Amount).IsRequired();
            entity.Property(e => e.Date).IsRequired();
        });
    }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        if (!optionsBuilder.IsConfigured)
        {
            // Fallback for design-time migration tooling
            var fallbackPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "{AppName}", "app.db");
            optionsBuilder.UseSqlite($"Data Source={fallbackPath}");
        }
    }
}
```

### DbSet Pluralization Rules

| Entity Name | DbSet Property Name |
| ----------- | ------------------- |
| `Category`  | `Categories`        |
| `Expense`   | `Expenses`          |
| `Person`    | `People`            |
| `Inventory` | `Inventories`       |
| `Tax`       | `Taxes`             |
| `Status`    | `Statuses`          |

> **Rule**: AI must apply English pluralization correctly. Irregular nouns must be detected (Person → People, etc.). When in doubt, append `List` suffix (e.g., `StatusList`) and add a code comment.

### DI Registration for DbContext

```csharp
// In App.xaml.cs ConfigureServices()
services.AddDbContext<AppDbContext>(options =>
{
    options.UseSqlite($"Data Source={dbPath}");
    // Enable Write-Ahead Logging for SQLite performance + reliability
    options.UseSqlite($"Data Source={dbPath}", sqliteOptions =>
    {
        sqliteOptions.CommandTimeout(30);
    });
});
```

### WAL Mode Initialization

```csharp
// After DI container is built and before first use, call:
using var scope = _serviceProvider.CreateScope();
var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
await db.Database.MigrateAsync(); // Apply all pending migrations
// Enable WAL mode for SQLite
await db.Database.ExecuteSqlRawAsync("PRAGMA journal_mode=WAL;");
```

---

## 5. Relationship Mapping Rules

### 5.1 OneToMany

```csharp
// Spec: Category (1) → Expense (many)
modelBuilder.Entity<Expense>()
    .HasOne(e => e.Category)
    .WithMany(c => c.Expenses)
    .HasForeignKey(e => e.CategoryId)
    .OnDelete(DeleteBehavior.Cascade); // ← ALWAYS Cascade for OneToMany
```

### 5.2 OneToOne

```csharp
// Spec: UserProfile (1) → UserSettings (1)
modelBuilder.Entity<UserProfile>()
    .HasOne(p => p.Settings)
    .WithOne(s => s.UserProfile)
    .HasForeignKey<UserSettings>(s => s.UserProfileId)
    .OnDelete(DeleteBehavior.Cascade);
```

### 5.3 ManyToMany

For ManyToMany, the Schema Agent generates an explicit **join entity**:

```csharp
// Spec: Task (many) ↔ Tag (many)
// Generated join entity:
public class TaskTag
{
    public Guid TaskId { get; set; }
    public Guid TagId { get; set; }
    public Task Task { get; set; } = null!;
    public Tag Tag { get; set; } = null!;
}

// DbContext configuration:
modelBuilder.Entity<TaskTag>()
    .HasKey(tt => new { tt.TaskId, tt.TagId });

modelBuilder.Entity<TaskTag>()
    .HasOne(tt => tt.Task)
    .WithMany(t => t.TaskTags)
    .HasForeignKey(tt => tt.TaskId)
    .OnDelete(DeleteBehavior.Cascade);

modelBuilder.Entity<TaskTag>()
    .HasOne(tt => tt.Tag)
    .WithMany(t => t.TaskTags)
    .HasForeignKey(tt => tt.TagId)
    .OnDelete(DeleteBehavior.Restrict);
```

### 5.4 Delete Behavior Rules

| Relationship                 | Parent Delete Behavior |
| ---------------------------- | ---------------------- |
| OneToMany (strong ownership) | `Cascade`              |
| OneToMany (weak reference)   | `Restrict`             |
| OneToOne                     | `Cascade`              |
| ManyToMany (primary side)    | `Cascade`              |
| ManyToMany (secondary side)  | `Restrict`             |

> **Rule**: AI must infer ownership from entity names and feature context. When ambiguous, use `Restrict` and add a `// TODO: verify delete behavior` comment.

---

## 6. Repository Pattern Rules

### Interface Contract

```csharp
namespace {AppName}.Core.Services;

public interface I{EntityName}Repository
{
    // Required — all repositories must have these 5 methods
    Task<IEnumerable<{EntityName}>> GetAllAsync();
    Task<{EntityName}?> GetByIdAsync(Guid id);
    Task AddAsync({EntityName} entity);
    Task UpdateAsync({EntityName} entity);
    Task DeleteAsync(Guid id);

    // Optional — added only if feature requires it
    // (e.g., for Report/Search features)
    Task<IEnumerable<{EntityName}>> GetByAsync(Expression<Func<{EntityName}, bool>> predicate);
    Task<int> CountAsync();
    Task<double> SumAsync(Expression<Func<{EntityName}, double>> selector);
}
```

### Implementation Rules

| Rule                        | Description                                                                          |
| --------------------------- | ------------------------------------------------------------------------------------ |
| **No tracking on reads**    | All read queries use `.AsNoTracking()`                                               |
| **Single SaveChangesAsync** | Each write operation calls `SaveChangesAsync()` exactly once                         |
| **No direct SQL**           | Use LINQ/EF Core only (no `FromSqlRaw` except for aggregate fallbacks)               |
| **Null safety**             | GetByIdAsync returns nullable; callers must null-check                               |
| **Error bubbling**          | Repositories do NOT catch exceptions; let them bubble to ViewModel                   |
| **Include on demand**       | Navigation properties are only `.Include()`'d when the feature explicitly needs them |

### Include Rules

```csharp
// ✅ CORRECT — Include only when the feature needs related data
public async Task<IEnumerable<Expense>> GetAllWithCategoryAsync()
    => await _context.Expenses
        .AsNoTracking()
        .Include(e => e.Category)
        .OrderByDescending(e => e.Date)
        .ToListAsync();

// ❌ FORBIDDEN — Eager loading everything by default
public async Task<IEnumerable<Expense>> GetAllAsync()
    => await _context.Expenses
        .Include(e => e.Category)   // ← ONLY add Include if feature needs it
        .AsNoTracking()
        .ToListAsync();
```

---

## 7. Migration Rules

### Rule 1: Initial Migration

The Schema Agent generates an initial migration named `InitialCreate` which creates all tables from the initial spec:

```bash
# EF Core migration command (run by the build pipeline, not manually)
dotnet ef migrations add InitialCreate --project {AppName}.Data --startup-project {AppName}.App
```

### Rule 2: Migration on Spec Amendment

When the AppSpec is amended during a retry cycle (e.g., a new entity is added), a new migration is generated:

```bash
dotnet ef migrations add {YYYYMMDDHHmm}_SpecAmendment_{change_summary}
```

Examples:

- `20260303063000_SpecAmendment_AddNoteField`
- `20260303070000_SpecAmendment_AddTagEntity`

### Rule 3: Never Edit Migration Files After Generation

> **CRITICAL**: Once a migration file is generated and applied, it must never be manually edited. Schema changes must always go through new migration generation.

### Rule 4: Migration Application at Runtime

```csharp
// Applied programmatically in App.xaml.cs during startup, not via CLI
await dbContext.Database.MigrateAsync();
```

This ensures the user's local database is always on the latest schema version automatically.

---

## 8. Database Initialization Rules

### Startup Sequence

```text
App.xaml.cs OnLaunched()
    ↓
1. Build DI container
    ↓
2. Resolve AppDbContext
    ↓
3. db.Database.MigrateAsync()   ← Apply pending migrations
    ↓
4. PRAGMA journal_mode=WAL      ← Enable WAL mode
    ↓
5. Navigate to MainPage
```

### Seed Data Rules

- AI may generate **optional seed data** only if the AppSpec feature list includes a feature with `category: Settings` and the user's description implies default presets (e.g., "default categories").
- Seed data is inserted using EF Core's `HasData()` in `OnModelCreating`, using **fixed GUIDs** (not `Guid.NewGuid()`) to ensure idempotency across migrations.
- Seed data must never include sensitive data.

```csharp
// ✅ Example seed data with fixed GUIDs
modelBuilder.Entity<Category>().HasData(
    new Category { Id = new Guid("10000000-0000-0000-0000-000000000001"), Name = "Food", BudgetAmount = 500 },
    new Category { Id = new Guid("10000000-0000-0000-0000-000000000002"), Name = "Transport", BudgetAmount = 200 }
);
```

---

## 9. ViewModel ↔ Repository Contract

ViewModels in `{AppName}.App/ViewModels` interact with the data layer **only through service interfaces**, never directly through repositories or DbContext.

```text
ViewModel (App project)
    ↓ calls
Service Interface (Core project)
    ↓ implemented by
Service Implementation (Core project)
    ↓ calls
Repository Interface (Core project)
    ↓ implemented by
Repository Implementation (Data project)
    ↓ queries
AppDbContext → SQLite
```

### Async Patterns in ViewModel

```csharp
// ✅ CORRECT — async load triggered from page OnNavigatedTo
public async Task LoadAsync()
{
    IsLoading = true;
    try
    {
        var items = await _expenseService.GetAllAsync();
        Expenses = new ObservableCollection<Expense>(items);
    }
    finally
    {
        IsLoading = false;
    }
}
```

---

## 10. Banned Patterns

The following patterns are **explicitly forbidden** in the generated data layer:

| Pattern                                                    | Reason                                       |
| ---------------------------------------------------------- | -------------------------------------------- |
| `context.Database.ExecuteSqlRawAsync(...)` with user input | SQL injection risk                           |
| `context.SaveChanges()` (sync)                             | Blocks UI thread                             |
| `new AppDbContext(...)` outside DI                         | Bypasses connection management               |
| Storing connection strings in source files                 | Security violation                           |
| Using `dynamic` or `object` types in repository methods    | Breaks type safety                           |
| Catching `DbUpdateException` in repositories               | Let it bubble to ViewModel for user feedback |
| `context.ChangeTracker.QueryTrackingBehavior = TrackAll`   | Performance anti-pattern                     |
| Nested DbContexts                                          | EF Core lifetime conflict                    |

---

## 11. Common Generation Examples

### Example A: CRUD Repository (Full)

```csharp
// {AppName}.Data/Repositories/ExpenseRepository.cs
namespace ExpenseTracker.Data.Repositories;

public class ExpenseRepository : IExpenseRepository
{
    private readonly AppDbContext _context;

    public ExpenseRepository(AppDbContext context) => _context = context;

    public async Task<IEnumerable<Expense>> GetAllAsync()
        => await _context.Expenses
            .AsNoTracking()
            .Include(e => e.Category)
            .OrderByDescending(e => e.Date)
            .ToListAsync();

    public async Task<Expense?> GetByIdAsync(Guid id)
        => await _context.Expenses
            .Include(e => e.Category)
            .FirstOrDefaultAsync(e => e.Id == id);

    public async Task AddAsync(Expense expense)
    {
        _context.Expenses.Add(expense);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(Expense expense)
    {
        _context.Expenses.Update(expense);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid id)
    {
        var expense = await _context.Expenses.FindAsync(id);
        if (expense is not null)
        {
            _context.Expenses.Remove(expense);
            await _context.SaveChangesAsync();
        }
    }

    public async Task<double> SumByMonthAsync(int year, int month)
        => await _context.Expenses
            .Where(e => e.Date.Year == year && e.Date.Month == month)
            .SumAsync(e => e.Amount);
}
```

### Example B: Fluent API Relationship in OnModelCreating

```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    // Category configuration
    modelBuilder.Entity<Category>(entity =>
    {
        entity.HasKey(e => e.Id);
        entity.Property(e => e.Name).IsRequired().HasMaxLength(200);
        entity.Property(e => e.BudgetAmount).HasDefaultValue(0.0);
        entity.HasIndex(e => e.Name).IsUnique();
    });

    // Expense configuration + relationship
    modelBuilder.Entity<Expense>(entity =>
    {
        entity.HasKey(e => e.Id);
        entity.Property(e => e.Title).IsRequired().HasMaxLength(500);
        entity.Property(e => e.Amount).IsRequired();
        entity.Property(e => e.Date).IsRequired();

        entity.HasOne(e => e.Category)
            .WithMany(c => c.Expenses)
            .HasForeignKey(e => e.CategoryId)
            .OnDelete(DeleteBehavior.Cascade);
    });
}
```

---

## Change Log

| Date       | Change                                                                   |
| ---------- | ------------------------------------------------------------------------ |
| 2026-03-03 | Initial creation — complete EF Core + SQLite data layer generation rules |

---

## References

- [STRUCTURED_SPEC_FORMAT.md](./STRUCTURED_SPEC_FORMAT.md) — Domain model input
- [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — Project structure
- [UI_GENERATION_RULES.md](./UI_GENERATION_RULES.md) — XAML generation (parallel layer)
- [REPAIR_PATTERNS.md](./REPAIR_PATTERNS.md) — How to fix EF Core + SQLite build/runtime errors
- [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Schema Agent that applies these rules
