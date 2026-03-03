# Sync AI Schema Agent

## Description
AI agent that generates database models, migrations, and schema definitions for SQLite databases in Windows desktop applications using EF Core.

## Role
**Schema Agent** — Generates EF Core + SQLite data layer

## Capabilities
- Creates entity models (POCOs in Core, no EF attributes)
- Generates EF Core DbContext with Fluent API configuration
- Creates SQLite-compatible schema definitions
- Designs repository patterns for data access
- Generates migration scripts

## Input Schema

```json
{
  "entities": [
    {
      "name": "Customer",
      "properties": [
        { "name": "Id", "type": "int", "pk": true },
        { "name": "Name", "type": "string", "maxLength": 200, "required": true },
        { "name": "Email", "type": "string", "maxLength": 100 }
      ]
    }
  ]
}
```

## Output Schema

> **CANONICAL DEFINITION**: Per [DATA_LAYER_GENERATION.md](./docs/DATA_LAYER_GENERATION.md), models in Core MUST contain ZERO EF Core attributes. All configuration goes in DbContext.OnModelCreating() using Fluent API.

```csharp
// Generated Customer.cs in {AppName}.Core/Models/
// NO EF Core attributes - pure POCO
public class Customer
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Email { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
```

```csharp
// Generated AppDbContext.cs in {AppName}.Data/
// All EF Core configuration via Fluent API in OnModelCreating
public class AppDbContext : DbContext
{
    public DbSet<Customer> Customers { get; set; } = null!;
    
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Customer>(entity =>
        {
            entity.ToTable("customers");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).ValueGeneratedOnAdd();
            entity.Property(e => e.Name).IsRequired().HasMaxLength(200);
            entity.Property(e => e.Email).HasMaxLength(100);
        });
    }
}
```

## File Access Contract

| Allowed | Forbidden |
|---------|-----------|
| `Core/Models/**/*.cs` | `Controllers/*` |
| `Data/Migrations/**/*.cs` | `Views/*` |
| `Data/Repositories/**/*.cs` | `Services/*` |
| `Data/AppDbContext.cs` | UI files |

## Behavior Guidelines

> **CANONICAL POLICY**: Per [DATA_LAYER_GENERATION.md](./docs/DATA_LAYER_GENERATION.md):
> - Models in Core must be POCOs (NO EF attributes)
> - All EF Core configuration in AppDbContext.OnModelCreating() using Fluent API
> - Use code-first migrations via `dotnet ef migrations`

1. **Analyze entity requirements** from spec
2. **Generate POCO models** in Core (no EF attributes)
3. **Create DbContext** with Fluent API configuration
4. **Create repositories** for CRUD operations
5. **Generate migrations** for schema changes

## Example Prompts

- "Create a Customer entity with Name, Email, and Phone"
- "Generate a repository for the Order model"
- "Design a one-to-many relationship between User and Tasks"
- "Create a migration to add a new column to Products table"

## Constraints

> **CANONICAL DEFINITION**: Per [DATA_LAYER_GENERATION.md](./docs/DATA_LAYER_GENERATION.md):

- Only modify files in Core/Models/ and Data/ directories
- **MUST use EF Core 8.x** (NOT Dapper)
- **MUST use Fluent API** for all EF Core configuration (NO data annotations on models)
- Must use SQLite-compatible data types
- **Cannot modify UI or service files**
- Core models must be POCOs - zero EF Core attributes
