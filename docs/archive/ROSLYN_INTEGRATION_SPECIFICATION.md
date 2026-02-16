# Roslyn Integration Specification - Safe Code Mutation Layer

**Purpose:** Define safe code mutation layer using Roslyn for AST-based code changes.  
**Scope:** Code parsing, symbol indexing, structured patching, and conflict detection.  
**Framework:** Microsoft.CodeAnalysis (Roslyn), .NET 8

---

## 1. Responsibilities

The Roslyn Integration Layer is responsible for:

* **Parse C# files into SyntaxTree** - Convert source code to Abstract Syntax Tree
* **Build Symbol Graph** - Create semantic model of codebase
* **Provide reference lookup** - Find usages and dependencies
* **Apply structured patches** - Modify code via AST transformations
* **Validate syntax before write** - Ensure changes are syntactically valid
* **Format code after mutation** - Maintain consistent code style
* **Detect patch conflicts** - Identify when patches cannot be applied
* **Index XAML bindings** - Track XAML-to-C# connections

---

## 2. Core Principle: No Raw File Writes

### ❌ FORBIDDEN Operations

```csharp
// ❌ NEVER DO THIS - String replacement
var code = File.ReadAllText("MyClass.cs");
code = code.Replace("oldMethod", "newMethod");
File.WriteAllText("MyClass.cs", code);

// ❌ NEVER DO THIS - Regex replacement
var code = File.ReadAllText("MyClass.cs");
code = Regex.Replace(code, pattern, replacement);
File.WriteAllText("MyClass.cs", code);

// ❌ NEVER DO THIS - Direct file overwrite
File.WriteAllText("MyClass.cs", llmGeneratedCode);
```

### ✅ REQUIRED Approach

```csharp
// ✅ ALWAYS DO THIS - Roslyn AST transformation
var tree = CSharpSyntaxTree.ParseText(File.ReadAllText("MyClass.cs"));
var root = await tree.GetRootAsync();

// Apply transformation
var newRoot = root.ReplaceNode(oldNode, newNode);

// Format and write
var formatted = Formatter.Format(newRoot, workspace);
File.WriteAllText("MyClass.cs", formatted.ToFullString());
```

---

## 3. Indexing Requirements

### What Must Be Indexed

The Roslyn service must index and store:

* **Classes** - Name, namespace, base class, interfaces
* **Methods** - Signature, parameters, return type, accessibility
* **Properties** - Type, getter/setter, accessibility
* **Fields** - Type, accessibility, initializer
* **Interfaces** - Members, inheritance
* **Inheritance graph** - Class hierarchy
* **Dependency graph** - File-to-file dependencies
* **XAML binding references** - x:Name, Binding paths

### SQLite Schema

Schema Definition: The Roslyn service reads and writes to the Semantic Graph defined in `DATABASE_SCHEMA_SPECIFICATION.md`. It specifically populates the `syntax_nodes`, `symbols`, and `symbol_edges` tables.

---

## 4. Patch Engine Rules

### Allowed Patch Operations

LLM must NOT return full files. Only structured patch operations are allowed:

```csharp
public enum PatchOperationType
{
    ADD_CLASS,
    ADD_METHOD,
    ADD_PROPERTY,
    ADD_FIELD,
    MODIFY_METHOD_BODY,
    MODIFY_PROPERTY,
    INSERT_USING,
    REMOVE_MEMBER,
    UPDATE_XAML_NODE,
    ADD_XAML_ELEMENT,
    MODIFY_XAML_ATTRIBUTE
}
```

### Patch Operation Structure

```csharp
public class PatchOperation
{
    /// <summary>
    /// Type of patch operation.
    /// </summary>
    public PatchOperationType OperationType { get; set; }
    
    /// <summary>
    /// Target file path (relative to workspace).
    /// </summary>
    public string TargetFile { get; set; }
    
    /// <summary>
    /// Operation-specific payload.
    /// </summary>
    public object Payload { get; set; }
    
    /// <summary>
    /// Expected file hash before applying patch (for conflict detection).
    /// </summary>
    public string ExpectedFileHash { get; set; }
}
```

### Patch Payloads

#### ADD_CLASS

```csharp
public class AddClassPayload
{
    public string Namespace { get; set; }
    public string ClassName { get; set; }
    public string BaseClass { get; set; }
    public string[] Interfaces { get; set; }
    public string Accessibility { get; set; } = "public";
    public bool IsStatic { get; set; }
    public bool IsAbstract { get; set; }
}
```

#### ADD_METHOD

```csharp
public class AddMethodPayload
{
    public string TargetClass { get; set; }
    public string MethodName { get; set; }
    public string ReturnType { get; set; }
    public MethodParameter[] Parameters { get; set; }
    public string MethodBody { get; set; }
    public string Accessibility { get; set; } = "public";
    public bool IsStatic { get; set; }
    public bool IsAsync { get; set; }
}

public class MethodParameter
{
    public string Type { get; set; }
    public string Name { get; set; }
    public string DefaultValue { get; set; }
}
```

#### MODIFY_METHOD_BODY

```csharp
public class ModifyMethodBodyPayload
{
    public string TargetClass { get; set; }
    public string MethodName { get; set; }
    public string MethodSignature { get; set; } // For overload resolution
    public string NewMethodBody { get; set; }
}
```

#### ADD_PROPERTY

```csharp
public class AddPropertyPayload
{
    public string TargetClass { get; set; }
    public string PropertyName { get; set; }
    public string PropertyType { get; set; }
    public string Accessibility { get; set; } = "public";
    public bool HasGetter { get; set; } = true;
    public bool HasSetter { get; set; } = true;
    public string InitialValue { get; set; }
}
```

---

## 5. Patch Engine Implementation

### IPatchEngine Interface

```csharp
public interface IPatchEngine
{
    /// <summary>
    /// Applies a patch operation to a file.
    /// </summary>
    Task<PatchResult> ApplyPatchAsync(PatchOperation patch);
    
    /// <summary>
    /// Validates a patch without applying it.
    /// </summary>
    Task<PatchValidationResult> ValidatePatchAsync(PatchOperation patch);
    
    /// <summary>
    /// Applies multiple patches atomically (all or nothing).
    /// </summary>
    Task<BatchPatchResult> ApplyPatchBatchAsync(PatchOperation[] patches);
}
```

### PatchEngine Class

```csharp
public class PatchEngine : IPatchEngine
{
    private readonly ILogger<PatchEngine> _logger;
    private readonly ICodeIndexer _indexer;
    private readonly AdhocWorkspace _workspace;
    
    public PatchEngine(
        ILogger<PatchEngine> logger,
        ICodeIndexer indexer)
    {
        _logger = logger;
        _indexer = indexer;
        _workspace = new AdhocWorkspace();
    }
    
    public async Task<PatchResult> ApplyPatchAsync(PatchOperation patch)
    {
        try
        {
            // 1. Validate patch
            var validation = await ValidatePatchAsync(patch);
            if (!validation.IsValid)
            {
                return new PatchResult
                {
                    Success = false,
                    Error = PatchErrorType.ValidationFailed,
                    ErrorMessage = validation.ErrorMessage
                };
            }
            
            // 2. Load file
            var filePath = Path.Combine(_workspace.CurrentSolution.FilePath, patch.TargetFile);
            var sourceText = await File.ReadAllTextAsync(filePath);
            
            // 3. Check file hash for conflicts
            var currentHash = ComputeFileHash(sourceText);
            if (patch.ExpectedFileHash != null && currentHash != patch.ExpectedFileHash)
            {
                return new PatchResult
                {
                    Success = false,
                    Error = PatchErrorType.FileHashMismatch,
                    ErrorMessage = "File has been modified since patch was created"
                };
            }
            
            // 4. Parse to syntax tree
            var tree = CSharpSyntaxTree.ParseText(sourceText);
            var root = await tree.GetRootAsync();
            
            // 5. Apply transformation based on operation type
            var newRoot = patch.OperationType switch
            {
                PatchOperationType.ADD_CLASS => ApplyAddClass(root, patch.Payload as AddClassPayload),
                PatchOperationType.ADD_METHOD => ApplyAddMethod(root, patch.Payload as AddMethodPayload),
                PatchOperationType.MODIFY_METHOD_BODY => ApplyModifyMethodBody(root, patch.Payload as ModifyMethodBodyPayload),
                PatchOperationType.ADD_PROPERTY => ApplyAddProperty(root, patch.Payload as AddPropertyPayload),
                _ => throw new NotSupportedException($"Operation type {patch.OperationType} not supported")
            };
            
            // 6. Validate syntax
            var diagnostics = newRoot.GetDiagnostics();
            if (diagnostics.Any(d => d.Severity == DiagnosticSeverity.Error))
            {
                return new PatchResult
                {
                    Success = false,
                    Error = PatchErrorType.SyntaxError,
                    ErrorMessage = string.Join("; ", diagnostics.Select(d => d.GetMessage()))
                };
            }
            
            // 7. Format code
            var formatted = Formatter.Format(newRoot, _workspace);
            
            // 8. Write atomically
            var newContent = formatted.ToFullString();
            await File.WriteAllTextAsync(filePath, newContent);
            
            // 9. Re-index file
            await _indexer.IndexFileAsync(filePath);
            
            _logger.LogInformation("Successfully applied patch to {FilePath}", filePath);
            
            return new PatchResult
            {
                Success = true,
                NewFileHash = ComputeFileHash(newContent)
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to apply patch");
            return new PatchResult
            {
                Success = false,
                Error = PatchErrorType.UnexpectedException,
                ErrorMessage = ex.Message
            };
        }
    }
    
    private SyntaxNode ApplyAddClass(SyntaxNode root, AddClassPayload payload)
    {
        // Find namespace declaration
        var namespaceDecl = root.DescendantNodes()
            .OfType<NamespaceDeclarationSyntax>()
            .FirstOrDefault(n => n.Name.ToString() == payload.Namespace);
        
        if (namespaceDecl == null)
        {
            throw new InvalidOperationException($"Namespace {payload.Namespace} not found");
        }
        
        // Build class declaration
        var classDecl = SyntaxFactory.ClassDeclaration(payload.ClassName)
            .AddModifiers(SyntaxFactory.Token(SyntaxKind.PublicKeyword));
        
        if (payload.BaseClass != null)
        {
            classDecl = classDecl.AddBaseListTypes(
                SyntaxFactory.SimpleBaseType(SyntaxFactory.ParseTypeName(payload.BaseClass)));
        }
        
        if (payload.Interfaces != null)
        {
            foreach (var iface in payload.Interfaces)
            {
                classDecl = classDecl.AddBaseListTypes(
                    SyntaxFactory.SimpleBaseType(SyntaxFactory.ParseTypeName(iface)));
            }
        }
        
        // Add class to namespace
        var newNamespace = namespaceDecl.AddMembers(classDecl);
        return root.ReplaceNode(namespaceDecl, newNamespace);
    }
    
    private SyntaxNode ApplyAddMethod(SyntaxNode root, AddMethodPayload payload)
    {
        // Find target class
        var classDecl = root.DescendantNodes()
            .OfType<ClassDeclarationSyntax>()
            .FirstOrDefault(c => c.Identifier.Text == payload.TargetClass);
        
        if (classDecl == null)
        {
            throw new InvalidOperationException($"Class {payload.TargetClass} not found");
        }
        
        // Build method declaration
        var methodDecl = SyntaxFactory.MethodDeclaration(
            SyntaxFactory.ParseTypeName(payload.ReturnType),
            payload.MethodName);
        
        // Add modifiers
        var modifiers = new List<SyntaxToken>
        {
            SyntaxFactory.Token(ParseAccessibility(payload.Accessibility))
        };
        
        if (payload.IsStatic)
            modifiers.Add(SyntaxFactory.Token(SyntaxKind.StaticKeyword));
        
        if (payload.IsAsync)
            modifiers.Add(SyntaxFactory.Token(SyntaxKind.AsyncKeyword));
        
        methodDecl = methodDecl.AddModifiers(modifiers.ToArray());
        
        // Add parameters
        if (payload.Parameters != null)
        {
            var parameters = payload.Parameters.Select(p =>
                SyntaxFactory.Parameter(SyntaxFactory.Identifier(p.Name))
                    .WithType(SyntaxFactory.ParseTypeName(p.Type)));
            
            methodDecl = methodDecl.AddParameterListParameters(parameters.ToArray());
        }
        
        // Add method body
        var body = SyntaxFactory.ParseStatement(payload.MethodBody);
        methodDecl = methodDecl.WithBody(SyntaxFactory.Block(body));
        
        // Add method to class
        var newClass = classDecl.AddMembers(methodDecl);
        return root.ReplaceNode(classDecl, newClass);
    }
    
    private SyntaxNode ApplyModifyMethodBody(SyntaxNode root, ModifyMethodBodyPayload payload)
    {
        // Find target method
        var methodDecl = root.DescendantNodes()
            .OfType<MethodDeclarationSyntax>()
            .FirstOrDefault(m => 
                m.Identifier.Text == payload.MethodName &&
                m.Ancestors().OfType<ClassDeclarationSyntax>()
                    .Any(c => c.Identifier.Text == payload.TargetClass));
        
        if (methodDecl == null)
        {
            throw new InvalidOperationException(
                $"Method {payload.MethodName} not found in class {payload.TargetClass}");
        }
        
        // Parse new body
        var newBody = SyntaxFactory.ParseStatement(payload.NewMethodBody);
        var newMethod = methodDecl.WithBody(SyntaxFactory.Block(newBody));
        
        return root.ReplaceNode(methodDecl, newMethod);
    }
    
    private SyntaxNode ApplyAddProperty(SyntaxNode root, AddPropertyPayload payload)
    {
        // Find target class
        var classDecl = root.DescendantNodes()
            .OfType<ClassDeclarationSyntax>()
            .FirstOrDefault(c => c.Identifier.Text == payload.TargetClass);
        
        if (classDecl == null)
        {
            throw new InvalidOperationException($"Class {payload.TargetClass} not found");
        }
        
        // Build property declaration
        var propertyDecl = SyntaxFactory.PropertyDeclaration(
            SyntaxFactory.ParseTypeName(payload.PropertyType),
            payload.PropertyName);
        
        // Add accessibility modifier
        propertyDecl = propertyDecl.AddModifiers(
            SyntaxFactory.Token(ParseAccessibility(payload.Accessibility)));
        
        // Add accessors
        var accessors = new List<AccessorDeclarationSyntax>();
        
        if (payload.HasGetter)
        {
            accessors.Add(SyntaxFactory.AccessorDeclaration(
                SyntaxKind.GetAccessorDeclaration)
                .WithSemicolonToken(SyntaxFactory.Token(SyntaxKind.SemicolonToken)));
        }
        
        if (payload.HasSetter)
        {
            accessors.Add(SyntaxFactory.AccessorDeclaration(
                SyntaxKind.SetAccessorDeclaration)
                .WithSemicolonToken(SyntaxFactory.Token(SyntaxKind.SemicolonToken)));
        }
        
        propertyDecl = propertyDecl.WithAccessorList(
            SyntaxFactory.AccessorList(SyntaxFactory.List(accessors)));
        
        // Add initializer if provided
        if (payload.InitialValue != null)
        {
            propertyDecl = propertyDecl.WithInitializer(
                SyntaxFactory.EqualsValueClause(
                    SyntaxFactory.ParseExpression(payload.InitialValue)))
                .WithSemicolonToken(SyntaxFactory.Token(SyntaxKind.SemicolonToken));
        }
        
        // Add property to class
        var newClass = classDecl.AddMembers(propertyDecl);
        return root.ReplaceNode(classDecl, newClass);
    }
    
    private SyntaxKind ParseAccessibility(string accessibility)
    {
        return accessibility.ToLower() switch
        {
            "public" => SyntaxKind.PublicKeyword,
            "private" => SyntaxKind.PrivateKeyword,
            "protected" => SyntaxKind.ProtectedKeyword,
            "internal" => SyntaxKind.InternalKeyword,
            _ => SyntaxKind.PublicKeyword
        };
    }
    
    private string ComputeFileHash(string content)
    {
        using var sha256 = SHA256.Create();
        var hash = sha256.ComputeHash(Encoding.UTF8.GetBytes(content));
        return Convert.ToBase64String(hash);
    }
    
    public async Task<PatchValidationResult> ValidatePatchAsync(PatchOperation patch)
    {
        // Validate target file exists
        var filePath = Path.Combine(_workspace.CurrentSolution.FilePath, patch.TargetFile);
        if (!File.Exists(filePath))
        {
            return new PatchValidationResult
            {
                IsValid = false,
                ErrorMessage = $"Target file not found: {patch.TargetFile}"
            };
        }
        
        // Validate payload
        if (patch.Payload == null)
        {
            return new PatchValidationResult
            {
                IsValid = false,
                ErrorMessage = "Patch payload is null"
            };
        }
        
        // Operation-specific validation
        var validationError = patch.OperationType switch
        {
            PatchOperationType.ADD_METHOD => ValidateAddMethod(patch.Payload as AddMethodPayload),
            PatchOperationType.ADD_CLASS => ValidateAddClass(patch.Payload as AddClassPayload),
            _ => null
        };
        
        if (validationError != null)
        {
            return new PatchValidationResult
            {
                IsValid = false,
                ErrorMessage = validationError
            };
        }
        
        return new PatchValidationResult { IsValid = true };
    }
    
    private string ValidateAddMethod(AddMethodPayload payload)
    {
        if (string.IsNullOrEmpty(payload?.TargetClass))
            return "TargetClass is required";
        
        if (string.IsNullOrEmpty(payload.MethodName))
            return "MethodName is required";
        
        if (string.IsNullOrEmpty(payload.ReturnType))
            return "ReturnType is required";
        
        return null;
    }
    
    private string ValidateAddClass(AddClassPayload payload)
    {
        if (string.IsNullOrEmpty(payload?.ClassName))
            return "ClassName is required";
        
        if (string.IsNullOrEmpty(payload.Namespace))
            return "Namespace is required";
        
        return null;
    }
}
```

---

## 6. Conflict Detection

### Patch Failure Scenarios

A patch fails if:

* **Target node not found** - Class, method, or property doesn't exist
* **Signature mismatch** - Method signature has changed
* **File hash changed** - File was modified since patch was created
* **Syntax invalid** - Generated code has syntax errors
* **Duplicate member** - Adding a member that already exists

### PatchResult Class

```csharp
public class PatchResult
{
    public bool Success { get; set; }
    public PatchErrorType? Error { get; set; }
    public string ErrorMessage { get; set; }
    public string NewFileHash { get; set; }
}

public enum PatchErrorType
{
    ValidationFailed,
    FileHashMismatch,
    TargetNotFound,
    SignatureMismatch,
    SyntaxError,
    DuplicateMember,
    UnexpectedException
}
```

---

## 7. Code Indexer Implementation

### ICodeIndexer Interface

```csharp
public interface ICodeIndexer
{
    /// <summary>
    /// Indexes a single file.
    /// </summary>
    Task IndexFileAsync(string filePath);
    
    /// <summary>
    /// Indexes an entire project.
    /// </summary>
    Task IndexProjectAsync(string projectPath);
    
    /// <summary>
    /// Finds all references to a symbol.
    /// </summary>
    Task<List<SymbolReference>> FindReferencesAsync(string symbolName);
    
    /// <summary>
    /// Gets the dependency graph for a file.
    /// </summary>
    Task<FileDependencyGraph> GetDependencyGraphAsync(string filePath);
}
```

### CodeIndexer Class

```csharp
public class CodeIndexer : ICodeIndexer
{
    private readonly IDbConnection _db;
    private readonly ILogger<CodeIndexer> _logger;
    
    public async Task IndexFileAsync(string filePath)
    {
        var sourceText = await File.ReadAllTextAsync(filePath);
        var tree = CSharpSyntaxTree.ParseText(sourceText);
        var root = await tree.GetRootAsync();
        
        // Compute file hash
        var fileHash = ComputeFileHash(sourceText);
        
        // Insert or update file record
        var fileId = await UpsertFileAsync(filePath, fileHash);
        
        // Delete existing symbols for this file
        await _db.ExecuteAsync(
            "DELETE FROM Symbols WHERE FileId = @FileId", 
            new { FileId = fileId });
        
        // Index classes
        var classes = root.DescendantNodes().OfType<ClassDeclarationSyntax>();
        foreach (var classDecl in classes)
        {
            await IndexClassAsync(fileId, classDecl);
        }
        
        // Index methods
        var methods = root.DescendantNodes().OfType<MethodDeclarationSyntax>();
        foreach (var methodDecl in methods)
        {
            await IndexMethodAsync(fileId, methodDecl);
        }
        
        // Index properties
        var properties = root.DescendantNodes().OfType<PropertyDeclarationSyntax>();
        foreach (var propertyDecl in properties)
        {
            await IndexPropertyAsync(fileId, propertyDecl);
        }
        
        _logger.LogInformation("Indexed file: {FilePath}", filePath);
    }
    
    private async Task<int> UpsertFileAsync(string filePath, string fileHash)
    {
        var existing = await _db.QueryFirstOrDefaultAsync<int?>(
            "SELECT Id FROM Files WHERE FilePath = @FilePath",
            new { FilePath = filePath });
        
        if (existing.HasValue)
        {
            await _db.ExecuteAsync(
                "UPDATE Files SET FileHash = @FileHash, LastIndexed = @Now WHERE Id = @Id",
                new { Id = existing.Value, FileHash = fileHash, Now = DateTime.UtcNow });
            
            return existing.Value;
        }
        else
        {
            return await _db.QuerySingleAsync<int>(
                @"INSERT INTO Files (FilePath, FileHash, LastIndexed, FileType) 
                  VALUES (@FilePath, @FileHash, @Now, 'CSharp') 
                  RETURNING Id",
                new { FilePath = filePath, FileHash = fileHash, Now = DateTime.UtcNow });
        }
    }
    
    private async Task IndexClassAsync(int fileId, ClassDeclarationSyntax classDecl)
    {
        var namespaceName = classDecl.Ancestors()
            .OfType<NamespaceDeclarationSyntax>()
            .FirstOrDefault()?.Name.ToString();
        
        var fullyQualifiedName = $"{namespaceName}.{classDecl.Identifier.Text}";
        
        await _db.ExecuteAsync(
            @"INSERT INTO Symbols (FileId, SymbolType, Name, FullyQualifiedName, Namespace, LineNumber, Accessibility)
              VALUES (@FileId, 'Class', @Name, @FQN, @Namespace, @Line, @Access)",
            new
            {
                FileId = fileId,
                Name = classDecl.Identifier.Text,
                FQN = fullyQualifiedName,
                Namespace = namespaceName,
                Line = classDecl.GetLocation().GetLineSpan().StartLinePosition.Line,
                Access = GetAccessibility(classDecl.Modifiers)
            });
    }
    
    private string GetAccessibility(SyntaxTokenList modifiers)
    {
        if (modifiers.Any(SyntaxKind.PublicKeyword))
            return "Public";
        if (modifiers.Any(SyntaxKind.PrivateKeyword))
            return "Private";
        if (modifiers.Any(SyntaxKind.ProtectedKeyword))
            return "Protected";
        if (modifiers.Any(SyntaxKind.InternalKeyword))
            return "Internal";
        
        return "Private"; // Default
    }
}
```

---

## 8. XAML Integration

### XAML Binding Indexer

```csharp
public class XamlBindingIndexer
{
    public async Task IndexXamlFileAsync(string xamlPath)
    {
        var xamlContent = await File.ReadAllTextAsync(xamlPath);
        var doc = XDocument.Parse(xamlContent);
        
        // Find all elements with x:Name
        var namedElements = doc.Descendants()
            .Where(e => e.Attribute(XName.Get("Name", "http://schemas.microsoft.com/winfx/2006/xaml")) != null);
        
        foreach (var element in namedElements)
        {
            var name = element.Attribute(XName.Get("Name", "http://schemas.microsoft.com/winfx/2006/xaml")).Value;
            
            // Store in database
            await StoreXamlBindingAsync(xamlPath, name, element);
        }
        
        // Find all Binding expressions
        var bindings = doc.Descendants()
            .SelectMany(e => e.Attributes())
            .Where(a => a.Value.Contains("{Binding"));
        
        foreach (var binding in bindings)
        {
            var bindingPath = ExtractBindingPath(binding.Value);
            await StoreXamlBindingAsync(xamlPath, null, bindingPath);
        }
    }
    
    private string ExtractBindingPath(string bindingExpression)
    {
        // Extract path from {Binding PropertyName} or {Binding Path=PropertyName}
        var match = Regex.Match(bindingExpression, @"\{Binding\s+(?:Path=)?([^,}]+)");
        return match.Success ? match.Groups[1].Value.Trim() : null;
    }
}
```

---

## 9. Testing Strategy

### Unit Tests

```csharp
[TestClass]
public class PatchEngineTests
{
    [TestMethod]
    public async Task ApplyPatch_AddMethod_Success()
    {
        // Arrange
        var patchEngine = new PatchEngine(Mock.Of<ILogger<PatchEngine>>(), Mock.Of<ICodeIndexer>());
        var patch = new PatchOperation
        {
            OperationType = PatchOperationType.ADD_METHOD,
            TargetFile = "MyClass.cs",
            Payload = new AddMethodPayload
            {
                TargetClass = "MyClass",
                MethodName = "NewMethod",
                ReturnType = "void",
                MethodBody = "Console.WriteLine(\"Hello\");"
            }
        };
        
        // Act
        var result = await patchEngine.ApplyPatchAsync(patch);
        
        // Assert
        Assert.IsTrue(result.Success);
    }
    
    [TestMethod]
    public async Task ApplyPatch_FileHashMismatch_Fails()
    {
        // Arrange
        var patch = new PatchOperation
        {
            ExpectedFileHash = "old_hash",
            // ... other properties
        };
        
        // Act
        var result = await patchEngine.ApplyPatchAsync(patch);
        
        // Assert
        Assert.IsFalse(result.Success);
        Assert.AreEqual(PatchErrorType.FileHashMismatch, result.Error);
    }
}
```

---

## 10. Performance Optimization

### Caching Strategies

* **Cache SyntaxTrees** - Avoid re-parsing unchanged files
* **Incremental indexing** - Only re-index modified files
* **Lazy symbol resolution** - Load symbols on-demand
* **Batch patch operations** - Apply multiple patches in single transaction

---

## References

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [BUILD_SYSTEM_SPECIFICATION.md](BUILD_SYSTEM_SPECIFICATION.md) - Build integration
- [ORCHESTRATOR_SPECIFICATION.md](ORCHESTRATOR_SPECIFICATION.md) - Orchestrator contract
