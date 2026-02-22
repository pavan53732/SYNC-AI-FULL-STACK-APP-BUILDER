# Branding Inference Heuristics

> **Intelligent Brand Derivation from User Intent**
>
> **Related Core Document:** [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) — Zero-template approach
>
> **Related Core Document:** [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — AI Construction Engine vs Runtime Safety Kernel
>
> _The AI derives branding from intent, NOT from templates._

---

## Table of Contents

1. [Overview](#1-overview)
2. [Brand Inference Pipeline](#2-brand-inference-pipeline)
3. [Domain-Based Color Psychology](#3-domain-based-color-psychology)
4. [Complexity-Based Style Derivation](#4-complexity-based-style-derivation)
5. [App Name Analysis](#5-app-name-analysis)
6. [Icon Generation Heuristics](#6-icon-generation-heuristics)
7. [Typography Derivation](#7-typography-derivation)
8. [Complete Implementation](#8-complete-implementation)
9. [Integration Points](#9-integration-points)
10. [Fallback Strategy When Inference Fails](#10-fallback-strategy-when-inference-fails)

---

## 1. Overview

### Purpose

The Branding Inference Heuristics system derives visual identity (colors, styles, icons) from:
- **User intent** (app description, features)
- **Domain classification** (finance, health, gaming, etc.)
- **Complexity analysis** (simple, medium, complex)
- **App name semantics** (word analysis, emotional tone)

### Key Principle

> **NO TEMPLATES.** 
> 
> The system does NOT use pre-defined color palettes or icon templates.
> Instead, it uses **semantic inference** to derive brand identity from first principles.

### What Gets Inferred

| Brand Element | Inference Source | Example |
|--------------|------------------|---------|
| **Primary Color** | Domain + semantics | Finance → Blue (#0078D4) |
| **Secondary Color** | Primary + harmony rules | Blue → Light Blue (#429CE3) |
| **Logo Style** | Complexity + domain | Simple + Finance → "minimal, professional" |
| **Icon Shape** | App name + domain | "TaskMaster" → Checkmark shape |
| **Typography** | Complexity + domain | Simple → Segoe UI Variable |
| **Splash Style** | All above | Domain-appropriate layout |

---

## 2. Brand Inference Pipeline

### Complete Flow

```
USER PROMPT: "Build a finance tracker with charts and dark mode"
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│ 1. INTENT PARSING (AI Construction Engine)                   │
│                                                              │
│    AppName: "FinanceTracker"                                 │
│    Domain: "finance"                                         │
│    Features: ["charts", "data", "sqlite", "dark mode"]      │
│    ComplexityLevel: MEDIUM                                   │
│    UserPreferences: ["dark mode"]                            │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. DOMAIN CLASSIFICATION                                     │
│                                                              │
│    Primary Domain: FINANCE (confidence: 0.95)               │
│    Secondary Domains: PRODUCTIVITY (0.6), DATA (0.4)        │
│                                                              │
│    Classification sources:                                   │
│    - App name keywords: "finance", "tracker"                │
│    - Feature keywords: "charts", "data"                     │
│    - Prompt analysis: "finance" explicitly mentioned        │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. COLOR PSYCHOLOGY DERIVATION                               │
│                                                              │
│    Domain → Base Color:                                      │
│    FINANCE → Blue (#0078D4) [trust, stability]              │
│                                                              │
│    User Preference Override:                                 │
│    "dark mode" → Dark theme enabled                         │
│                                                              │
│    Color Harmony:                                            │
│    Primary: #0078D4 (Blue)                                   │
│    Secondary: #005A9E (Darker Blue)                          │
│    Accent: #FFB900 (Gold - finance accent)                   │
│    Background: #1A1A1A (Dark - user requested)              │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. STYLE DERIVATION                                          │
│                                                              │
│    Complexity: MEDIUM → "balanced"                          │
│    Domain: FINANCE → "professional"                          │
│    Features: "charts" → "data-focused"                       │
│                                                              │
│    Combined Style: "balanced, professional, data-focused"    │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. ICON GENERATION PROMPT BUILDING                           │
│                                                              │
│    App Icon Prompt:                                          │
│    "App icon for 'FinanceTracker', balanced, professional,  │
│     data-focused, blue color scheme (#0078D4),              │
│     dark theme support, chart elements,                     │
│     clean geometric design, Windows 11 Fluent style,        │
│     44x44px"                                                │
│                                                              │
│    Sent to: POST /api/generate-image                        │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. OUTPUT: BrandManifest                                     │
│                                                              │
│    {                                                         │
│      "primaryColor": "#0078D4",                              │
│      "secondaryColor": "#005A9E",                            │
│      "accentColor": "#FFB900",                               │
│      "backgroundColor": "#1A1A1A",                           │
│      "textColor": "#FFFFFF",                                 │
│      "style": "balanced, professional, data-focused",        │
│      "typography": {                                         │
│        "primary": "Segoe UI Variable",                       │
│        "code": "Cascadia Code"                               │
│      },                                                      │
│      "iconStyle": "geometric, chart-inspired",               │
│      "splashStyle": "centered-logo, gradient-background"     │
│    }                                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Domain-Based Color Psychology

### Domain Color Mapping

Each domain has associated color psychology based on industry research and user expectations:

```csharp
public static class DomainColorPsychology
{
    /// <summary>
    /// Maps domains to their psychologically appropriate colors.
    /// Based on color psychology research and industry conventions.
    /// </summary>
    public static readonly Dictionary<string, DomainColorProfile> Profiles = new()
    {
        ["finance"] = new DomainColorProfile
        {
            PrimaryColor = "#0078D4",        // Blue - Trust, Stability
            PrimaryRationale = "Blue conveys trust, stability, and professionalism. "
                            + "Widely used in finance (banks, investment apps).",
            SecondaryColor = "#005A9E",      // Darker Blue
            AccentColor = "#FFB900",          // Gold - Wealth, Premium
            AccentRationale = "Gold accent suggests wealth and premium quality.",
            Mood = "trustworthy, secure, professional",
            IconElements = new[] { "chart", "graph", "coin", "shield" }
        },
        
        ["health"] = new DomainColorProfile
        {
            PrimaryColor = "#107C10",        // Green - Health, Growth
            PrimaryRationale = "Green represents health, growth, and wellness. "
                            + "Universally recognized in healthcare.",
            SecondaryColor = "#0B5C0B",      // Darker Green
            AccentColor = "#FFFFFF",          // White - Clean, Pure
            AccentRationale = "White accent represents cleanliness and purity.",
            Mood = "healthy, clean, natural",
            IconElements = new[] { "heart", "cross", "leaf", "pulse" }
        },
        
        ["education"] = new DomainColorProfile
        {
            PrimaryColor = "#881798",        // Purple - Wisdom, Creativity
            PrimaryRationale = "Purple represents wisdom, creativity, and learning. "
                            + "Associated with academic institutions.",
            SecondaryColor = "#5C0D66",      // Darker Purple
            AccentColor = "#FFFFFF",          // White - Clarity
            AccentRationale = "White provides clarity and readability.",
            Mood = "creative, intelligent, friendly",
            IconElements = new[] { "book", "graduation cap", "pencil", "lightbulb" }
        },
        
        ["productivity"] = new DomainColorProfile
        {
            PrimaryColor = "#FF8C00",        // Orange - Energy, Efficiency
            PrimaryRationale = "Orange conveys energy, enthusiasm, and productivity. "
                            + "Stands out in task management apps.",
            SecondaryColor = "#CC7000",      // Darker Orange
            AccentColor = "#0078D4",          // Blue - Focus
            AccentRationale = "Blue accent suggests focus and reliability.",
            Mood = "energetic, efficient, motivating",
            IconElements = new[] { "checkmark", "clock", "list", "target" }
        },
        
        ["social"] = new DomainColorProfile
        {
            PrimaryColor = "#E8117D",        // Pink/Magenta - Social, Vibrant
            PrimaryRationale = "Pink/magenta represents social connection, vibrancy, "
                            + "and modern communication.",
            SecondaryColor = "#B50D63",      // Darker Pink
            AccentColor = "#0078D4",          // Blue - Trust
            AccentRationale = "Blue accent adds trust to social interaction.",
            Mood = "vibrant, connected, modern",
            IconElements = new[] { "speech bubble", "people", "heart", "share" }
        },
        
        ["gaming"] = new DomainColorProfile
        {
            PrimaryColor = "#00B294",        // Teal - Gaming, Modern
            PrimaryRationale = "Teal is modern and distinctive. "
                            + "Popular in gaming interfaces.",
            SecondaryColor = "#007561",      // Darker Teal
            AccentColor = "#FFB900",          // Gold/Yellow - Achievement
            AccentRationale = "Gold accent suggests achievement and rewards.",
            Mood = "dynamic, immersive, exciting",
            IconElements = new[] { "controller", "trophy", "star", "crosshair" }
        },
        
        ["media"] = new DomainColorProfile
        {
            PrimaryColor = "#D13438",        // Red - Media, Entertainment
            PrimaryRationale = "Red represents excitement, passion, and entertainment. "
                            + "Used by major media platforms.",
            SecondaryColor = "#A4282B",      // Darker Red
            AccentColor = "#FFFFFF",          // White - Contrast
            AccentRationale = "White provides high contrast for media content.",
            Mood = "exciting, dynamic, passionate",
            IconElements = new[] { "play button", "film", "music note", "camera" }
        },
        
        ["travel"] = new DomainColorProfile
        {
            PrimaryColor = "#00CC6A",        // Green - Travel, Adventure
            PrimaryRationale = "Green represents adventure, nature, and exploration.",
            SecondaryColor = "#009E52",      // Darker Green
            AccentColor = "#0078D4",          // Blue - Sky, Travel
            AccentRationale = "Blue accent suggests sky and travel.",
            Mood = "adventurous, fresh, exploring",
            IconElements = new[] { "airplane", "map pin", "compass", "globe" }
        },
        
        ["food"] = new DomainColorProfile
        {
            PrimaryColor = "#FF6B00",        // Orange/Red - Food, Appetite
            PrimaryRationale = "Orange/red stimulates appetite and warmth. "
                            + "Used in food delivery apps.",
            SecondaryColor = "#CC5500",      // Darker Orange
            AccentColor = "#107C10",          // Green - Fresh
            AccentRationale = "Green accent suggests freshness and natural ingredients.",
            Mood = "warm, appetizing, fresh",
            IconElements = new[] { "fork", "plate", "chef hat", "apple" }
        },
        
        ["fitness"] = new DomainColorProfile
        {
            PrimaryColor = "#FF4343",        // Red - Energy, Action
            PrimaryRationale = "Red represents energy, action, and intensity. "
                            + "Commonly used in fitness apps.",
            SecondaryColor = "#CC3636",      // Darker Red
            AccentColor = "#107C10",          // Green - Progress
            AccentRationale = "Green accent suggests progress and achievement.",
            Mood = "energetic, strong, motivating",
            IconElements = new[] { "dumbbell", "running figure", "heart rate", "muscle" }
        }
    };
    
    /// <summary>
    /// Default color profile when domain cannot be determined.
    /// </summary>
    public static readonly DomainColorProfile Default = new()
    {
        PrimaryColor = "#0078D4",        // Windows Blue
        PrimaryRationale = "Windows default blue is familiar and professional.",
        SecondaryColor = "#005A9E",
        AccentColor = "#00B7C3",          // Cyan accent
        AccentRationale = "Cyan provides modern accent without specific domain association.",
        Mood = "modern, professional, clean",
        IconElements = new[] { "abstract", "geometric" }
    };
}

public record DomainColorProfile
{
    public string PrimaryColor { get; init; }
    public string PrimaryRationale { get; init; }
    public string SecondaryColor { get; init; }
    public string AccentColor { get; init; }
    public string AccentRationale { get; init; }
    public string Mood { get; init; }
    public string[] IconElements { get; init; }
}
```

### Color Harmony Rules

```csharp
public static class ColorHarmony
{
    /// <summary>
    /// Generates a harmonious color palette from a primary color.
    /// Uses color theory principles (complementary, analogous, triadic).
    /// </summary>
    public static ColorPalette GeneratePalette(string primaryHex, HarmonyScheme scheme = HarmonyScheme.COMPLEMENTARY)
    {
        var primary = HexToHsv(primaryHex);
        
        return scheme switch
        {
            HarmonyScheme.COMPLEMENTARY => new ColorPalette
            {
                Primary = primaryHex,
                Secondary = HsvToHex(ShiftHue(primary, 180)),  // Opposite on color wheel
                Accent = HsvToHex(ShiftHue(primary, 30)),      // Near-primary accent
                Background = DeriveBackgroundColor(primary)
            },
            
            HarmonyScheme.ANALOGOUS => new ColorPalette
            {
                Primary = primaryHex,
                Secondary = HsvToHex(ShiftHue(primary, 30)),   // Adjacent colors
                Accent = HsvToHex(ShiftHue(primary, -30)),
                Background = DeriveBackgroundColor(primary)
            },
            
            HarmonyScheme.TRIADIC => new ColorPalette
            {
                Primary = primaryHex,
                Secondary = HsvToHex(ShiftHue(primary, 120)),  // 120° apart
                Accent = HsvToHex(ShiftHue(primary, 240)),
                Background = DeriveBackgroundColor(primary)
            },
            
            HarmonyScheme.MONOCHROMATIC => new ColorPalette
            {
                Primary = primaryHex,
                Secondary = AdjustBrightness(primaryHex, -20),  // Darker shade
                Accent = AdjustBrightness(primaryHex, +30),     // Lighter tint
                Background = DeriveBackgroundColor(primary)
            },
            
            _ => GeneratePalette(primaryHex, HarmonyScheme.COMPLEMENTARY)
        };
    }
    
    /// <summary>
    /// Derives appropriate background color based on primary color luminosity.
    /// </summary>
    private static string DeriveBackgroundColor(HsvColor primary)
    {
        // Light primary → dark background (contrast)
        // Dark primary → light background (contrast)
        return primary.V > 0.6 
            ? "#1A1A1A"   // Dark background
            : "#F5F5F5";  // Light background
    }
}

public enum HarmonyScheme
{
    COMPLEMENTARY,   // High contrast, vibrant
    ANALOGOUS,       // Harmonious, cohesive
    TRIADIC,         // Balanced, colorful
    MONOCHROMATIC    // Clean, minimal
}

public record ColorPalette
{
    public string Primary { get; init; }
    public string Secondary { get; init; }
    public string Accent { get; init; }
    public string Background { get; init; }
}
```

---

## 4. Complexity-Based Style Derivation

### Style Complexity Matrix

```csharp
public static class ComplexityStyleMapper
{
    /// <summary>
    /// Derives visual style based on application complexity.
    /// </summary>
    public static StyleProfile DeriveStyle(AppIntent intent)
    {
        var complexity = intent.ComplexityLevel;
        var domain = intent.Domain?.ToLowerInvariant() ?? "default";
        var featureCount = intent.Features?.Count ?? 0;
        
        // Base style from complexity
        var baseStyle = complexity switch
        {
            ComplexityLevel.SIMPLE => new StyleProfile
            {
                VisualComplexity = "minimal",
                IconDetail = "outline",
                ColorCount = 2,
                ShadowDepth = "none",
                AnimationLevel = "subtle",
                CornerStyle = "rounded",
                LayoutDensity = "spacious"
            },
            
            ComplexityLevel.MEDIUM => new StyleProfile
            {
                VisualComplexity = "balanced",
                IconDetail = "filled-outline",
                ColorCount = 3,
                ShadowDepth = "subtle",
                AnimationLevel = "moderate",
                CornerStyle = "rounded-sharp",
                LayoutDensity = "comfortable"
            },
            
            ComplexityLevel.COMPLEX => new StyleProfile
            {
                VisualComplexity = "detailed",
                IconDetail = "filled",
                ColorCount = 4,
                ShadowDepth = "elevated",
                AnimationLevel = "rich",
                CornerStyle = "sharp",
                LayoutDensity = "compact"
            },
            
            _ => DeriveStyle(intent with { ComplexityLevel = ComplexityLevel.MEDIUM })
        };
        
        // Domain overlay
        baseStyle = ApplyDomainStyle(baseStyle, domain);
        
        // Feature overlay
        baseStyle = ApplyFeatureStyles(baseStyle, intent.Features);
        
        // User preference overlay
        baseStyle = ApplyUserPreferences(baseStyle, intent.UserPreferences);
        
        return baseStyle;
    }
    
    private static StyleProfile ApplyDomainStyle(StyleProfile baseStyle, string domain)
    {
        // Domain-specific style adjustments
        return domain switch
        {
            "finance" => baseStyle with
            {
                Mood = "professional, trustworthy, secure",
                IconStyle = "geometric, structured",
                TypographyWeight = "regular",  // Professional, not heavy
                ColorIntensity = "muted"       // Not too vibrant for finance
            },
            
            "gaming" => baseStyle with
            {
                Mood = "dynamic, immersive, exciting",
                IconStyle = "vibrant, dynamic",
                TypographyWeight = "bold",
                ColorIntensity = "vibrant",
                AnimationLevel = "rich"
            },
            
            "health" => baseStyle with
            {
                Mood = "clean, calming, trustworthy",
                IconStyle = "organic, soft",
                TypographyWeight = "regular",
                ColorIntensity = "soft"
            },
            
            "education" => baseStyle with
            {
                Mood = "friendly, approachable, engaging",
                IconStyle = "playful, rounded",
                TypographyWeight = "medium",
                ColorIntensity = "bright"
            },
            
            _ => baseStyle with
            {
                Mood = "modern, professional, clean",
                IconStyle = "geometric",
                TypographyWeight = "regular",
                ColorIntensity = "balanced"
            }
        };
    }
    
    private static StyleProfile ApplyFeatureStyles(StyleProfile baseStyle, List<string> features)
    {
        // Adjust style based on specific features
        if (features?.Contains("charts") == true || features?.Contains("data") == true)
        {
            baseStyle = baseStyle with
            {
                Mood = $"{baseStyle.Mood}, data-focused",
                IconStyle = $"{baseStyle.IconStyle}, chart-inspired"
            };
        }
        
        if (features?.Contains("real-time") == true)
        {
            baseStyle = baseStyle with
            {
                AnimationLevel = "moderate",  // Show live updates
                VisualComplexity = "dynamic"
            };
        }
        
        if (features?.Contains("collaboration") == true)
        {
            baseStyle = baseStyle with
            {
                Mood = $"{baseStyle.Mood}, collaborative",
                IconStyle = $"{baseStyle.IconStyle}, connected"
            };
        }
        
        return baseStyle;
    }
    
    private static StyleProfile ApplyUserPreferences(StyleProfile baseStyle, List<string> preferences)
    {
        // User preference overrides (highest priority)
        if (preferences?.Contains("dark mode") == true)
        {
            baseStyle = baseStyle with
            {
                Theme = "dark",
                BackgroundStyle = "dark",
                ContrastLevel = "high"
            };
        }
        
        if (preferences?.Contains("minimal") == true)
        {
            baseStyle = baseStyle with
            {
                VisualComplexity = "minimal",
                AnimationLevel = "subtle",
                ShadowDepth = "none"
            };
        }
        
        return baseStyle;
    }
}

public record StyleProfile
{
    public string VisualComplexity { get; init; }      // minimal, balanced, detailed
    public string IconDetail { get; init; }           // outline, filled-outline, filled
    public int ColorCount { get; init; }
    public string ShadowDepth { get; init; }          // none, subtle, elevated
    public string AnimationLevel { get; init; }       // subtle, moderate, rich
    public string CornerStyle { get; init; }          // rounded, rounded-sharp, sharp
    public string LayoutDensity { get; init; }        // spacious, comfortable, compact
    public string Mood { get; init; }
    public string IconStyle { get; init; }
    public string TypographyWeight { get; init; }
    public string ColorIntensity { get; init; }
    public string Theme { get; init; } = "light";
    public string BackgroundStyle { get; init; } = "light";
    public string ContrastLevel { get; init; } = "normal";
}
```

---

## 5. App Name Analysis

### Semantic Analysis of App Names

```csharp
public static class AppNameAnalyzer
{
    /// <summary>
    /// Analyzes app name to extract semantic meaning for branding.
    /// </summary>
    public static AppNameSemantics Analyze(string appName)
    {
        if (string.IsNullOrWhiteSpace(appName))
            return AppNameSemantics.Default;
        
        var normalized = appName.Trim();
        var words = ExtractWords(normalized);
        
        return new AppNameSemantics
        {
            OriginalName = appName,
            NormalizedName = normalized,
            Words = words,
            PrimaryKeyword = ExtractPrimaryKeyword(words),
            DomainHints = ExtractDomainHints(words),
            EmotionalTone = AnalyzeEmotionalTone(words),
            ShapeSuggestions = SuggestShapes(words),
            Abbreviation = GenerateAbbreviation(normalized)
        };
    }
    
    private static List<string> ExtractWords(string name)
    {
        // Split camelCase, PascalCase, and spaces
        var result = new List<string>();
        var currentWord = new StringBuilder();
        
        foreach (var c in name)
        {
            if (char.IsUpper(c) && currentWord.Length > 0)
            {
                result.Add(currentWord.ToString().ToLowerInvariant());
                currentWord.Clear();
            }
            
            if (!char.IsWhiteSpace(c))
                currentWord.Append(c);
        }
        
        if (currentWord.Length > 0)
            result.Add(currentWord.ToString().ToLowerInvariant());
        
        return result;
    }
    
    private static string ExtractPrimaryKeyword(List<string> words)
    {
        // Return most significant word (usually the first or most descriptive)
        var significantWords = words
            .Where(w => !IsCommonWord(w))
            .ToList();
        
        return significantWords.FirstOrDefault() ?? words.FirstOrDefault() ?? "";
    }
    
    private static List<string> ExtractDomainHints(List<string> words)
    {
        // Map words to domain hints
        var hints = new List<string>();
        
        var wordToDomain = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["finance"] = "finance",
            ["bank"] = "finance",
            ["money"] = "finance",
            ["budget"] = "finance",
            ["tracker"] = "productivity",
            ["task"] = "productivity",
            ["todo"] = "productivity",
            ["manager"] = "productivity",
            ["health"] = "health",
            ["fitness"] = "fitness",
            ["workout"] = "fitness",
            ["exercise"] = "fitness",
            ["game"] = "gaming",
            ["play"] = "gaming",
            ["social"] = "social",
            ["chat"] = "social",
            ["connect"] = "social",
            ["learn"] = "education",
            ["study"] = "education",
            ["course"] = "education"
        };
        
        foreach (var word in words)
        {
            if (wordToDomain.TryGetValue(word, out var domain))
                hints.Add(domain);
        }
        
        return hints.Distinct().ToList();
    }
    
    private static EmotionalTone AnalyzeEmotionalTone(List<string> words)
    {
        // Analyze emotional tone from word choice
        var positiveWords = new[] { "happy", "joy", "bright", "sunny", "smile", "love", "care" };
        var professionalWords = new[] { "pro", "business", "enterprise", "office", "work", "manage" };
        var playfulWords = new[] { "fun", "play", "game", "kid", "toy", "pet", "cute" };
        var seriousWords = new[] { "secure", "safe", "guard", "protect", "defense", "shield" };
        
        if (words.Any(w => positiveWords.Contains(w)))
            return EmotionalTone.POSITIVE;
        
        if (words.Any(w => professionalWords.Contains(w)))
            return EmotionalTone.PROFESSIONAL;
        
        if (words.Any(w => playfulWords.Contains(w)))
            return EmotionalTone.PLAYFUL;
        
        if (words.Any(w => seriousWords.Contains(w)))
            return EmotionalTone.SERIOUS;
        
        return EmotionalTone.NEUTRAL;
    }
    
    private static List<string> SuggestShapes(List<string> words)
    {
        var shapes = new List<string>();
        
        // Shape suggestions based on keywords
        if (words.Any(w => new[] { "task", "check", "complete", "done" }.Contains(w)))
            shapes.Add("checkmark");
        
        if (words.Any(w => new[] { "chart", "graph", "data", "analytics" }.Contains(w)))
            shapes.Add("chart");
        
        if (words.Any(w => new[] { "chat", "message", "social", "connect" }.Contains(w)))
            shapes.Add("speech-bubble");
        
        if (words.Any(w => new[] { "security", "shield", "protect", "guard" }.Contains(w)))
            shapes.Add("shield");
        
        if (words.Any(w => new[] { "play", "music", "video", "media" }.Contains(w)))
            shapes.Add("play-button");
        
        // Default geometric shapes if no matches
        if (!shapes.Any())
            shapes.AddRange(new[] { "circle", "square", "hexagon" });
        
        return shapes;
    }
    
    private static string GenerateAbbreviation(string name)
    {
        // Generate 1-2 letter abbreviation for icons
        var words = ExtractWords(name);
        
        if (words.Count == 1)
        {
            // Single word: use first 1-2 characters
            return words[0].Length >= 2 
                ? words[0].Substring(0, 2).ToUpperInvariant() 
                : words[0].ToUpperInvariant();
        }
        
        // Multiple words: use first letter of each significant word
        var initials = words
            .Where(w => !IsCommonWord(w))
            .Take(2)
            .Select(w => char.ToUpperInvariant(w[0]))
            .ToArray();
        
        return new string(initials);
    }
    
    private static bool IsCommonWord(string word)
    {
        var commonWords = new[] { "the", "app", "for", "and", "with", "my", "a", "an" };
        return commonWords.Contains(word.ToLowerInvariant());
    }
}

public record AppNameSemantics
{
    public string OriginalName { get; init; }
    public string NormalizedName { get; init; }
    public List<string> Words { get; init; }
    public string PrimaryKeyword { get; init; }
    public List<string> DomainHints { get; init; }
    public EmotionalTone EmotionalTone { get; init; }
    public List<string> ShapeSuggestions { get; init; }
    public string Abbreviation { get; init; }
    
    public static AppNameSemantics Default => new()
    {
        OriginalName = "App",
        NormalizedName = "App",
        Words = new List<string> { "app" },
        PrimaryKeyword = "app",
        DomainHints = new List<string>(),
        EmotionalTone = EmotionalTone.NEUTRAL,
        ShapeSuggestions = new List<string> { "circle" },
        Abbreviation = "A"
    };
}

public enum EmotionalTone
{
    POSITIVE,
    PROFESSIONAL,
    PLAYFUL,
    SERIOUS,
    NEUTRAL
}
```

---

## 6. Icon Generation Heuristics

### Icon Prompt Construction

```csharp
public class IconPromptBuilder
{
    /// <summary>
    /// Builds an AI image generation prompt for app icons.
    /// </summary>
    public static string BuildIconPrompt(
        AppNameSemantics nameAnalysis,
        DomainColorProfile colorProfile,
        StyleProfile styleProfile,
        AssetRequirement requirement)
    {
        var sb = new StringBuilder();
        
        // 1. Base context
        sb.Append($"App icon for '{nameAnalysis.OriginalName}', ");
        
        // 2. Style from complexity
        sb.Append($"{styleProfile.VisualComplexity} design, ");
        sb.Append($"{styleProfile.Mood}, ");
        
        // 3. Domain-specific elements
        if (colorProfile.IconElements?.Any() == true)
        {
            var element = colorProfile.IconElements.First();
            sb.Append($"featuring {element} element, ");
        }
        
        // 4. Shape suggestions from name analysis
        if (nameAnalysis.ShapeSuggestions?.Any() == true)
        {
            var shape = nameAnalysis.ShapeSuggestions.First();
            sb.Append($"{shape} shape, ");
        }
        
        // 5. Color scheme
        sb.Append($"{colorProfile.PrimaryColor} primary color, ");
        
        // 6. Emotional tone
        sb.Append($"{nameAnalysis.EmotionalTone.ToString().ToLowerInvariant()} feel, ");
        
        // 7. Detail level
        sb.Append($"{styleProfile.IconDetail} style, ");
        
        // 8. Platform style
        sb.Append("Windows 11 Fluent Design, ");
        sb.Append("clean background, ");
        
        // 9. Size
        sb.Append($"{requirement.Width}x{requirement.Height}px");
        
        return sb.ToString();
    }
    
    /// <summary>
    /// Builds prompt for tile logos (larger, more detailed).
    /// </summary>
    public static string BuildTileLogoPrompt(
        AppNameSemantics nameAnalysis,
        DomainColorProfile colorProfile,
        StyleProfile styleProfile,
        AssetRequirement requirement)
    {
        var sb = new StringBuilder();
        
        // Tile logos have more space for detail
        sb.Append($"Windows tile logo for '{nameAnalysis.OriginalName}', ");
        sb.Append($"{styleProfile.VisualComplexity} design, ");
        
        // Tiles can show more elements
        if (colorProfile.IconElements?.Length >= 2)
        {
            sb.Append($"combining {colorProfile.IconElements[0]} and {colorProfile.IconElements[1]}, ");
        }
        
        // Background color for tile
        sb.Append($"{colorProfile.PrimaryColor} background, ");
        sb.Append("white foreground icon, ");
        
        // Tile-specific style
        sb.Append("Windows 11 Start Menu style, ");
        sb.Append("centered composition, ");
        
        // Size
        sb.Append($"{requirement.Width}x{requirement.Height}px");
        
        return sb.ToString();
    }
    
    /// <summary>
    /// Builds prompt for splash screens.
    /// </summary>
    public static string BuildSplashScreenPrompt(
        AppNameSemantics nameAnalysis,
        DomainColorProfile colorProfile,
        StyleProfile styleProfile,
        AssetRequirement requirement)
    {
        var sb = new StringBuilder();
        
        sb.Append($"Splash screen for '{nameAnalysis.OriginalName}' app, ");
        sb.Append($"{styleProfile.Mood} atmosphere, ");
        
        // Splash screens use gradient backgrounds
        sb.Append($"gradient from {colorProfile.PrimaryColor} to {colorProfile.SecondaryColor}, ");
        
        // Centered logo
        sb.Append("centered logo, ");
        sb.Append($"{nameAnalysis.Abbreviation} letter mark, ");
        
        // Clean, professional
        sb.Append("clean design, ");
        sb.Append("minimal elements, ");
        sb.Append("professional appearance, ");
        
        // Size
        sb.Append($"{requirement.Width}x{requirement.Height}px");
        
        return sb.ToString();
    }
}
```

### Example Prompts Generated

| App Name | Domain | Generated Icon Prompt |
|----------|--------|----------------------|
| FinanceTracker | finance | "App icon for 'FinanceTracker', balanced design, trustworthy, secure, professional, featuring chart element, checkmark shape, #0078D4 primary color, professional feel, filled-outline style, Windows 11 Fluent Design, clean background, 44x44px" |
| WorkoutPro | fitness | "App icon for 'WorkoutPro', balanced design, energetic, strong, motivating, featuring dumbbell element, circle shape, #FF4343 primary color, professional feel, filled-outline style, Windows 11 Fluent Design, clean background, 44x44px" |
| LearnSmart | education | "App icon for 'LearnSmart', balanced design, friendly, approachable, engaging, featuring book element, hexagon shape, #881798 primary color, positive feel, filled-outline style, Windows 11 Fluent Design, clean background, 44x44px" |

---

## 7. Typography Derivation

### Font Selection Rules

```csharp
public static class TypographyDerivation
{
    /// <summary>
    /// Derives typography settings based on app characteristics.
    /// </summary>
    public static TypographyProfile DeriveTypography(AppIntent intent, StyleProfile style)
    {
        return new TypographyProfile
        {
            PrimaryFont = SelectPrimaryFont(style, intent.Domain),
            CodeFont = "Cascadia Code",  // Always Cascadia for code
            BaseSize = SelectBaseSize(intent.ComplexityLevel),
            LineHeight = SelectLineHeight(style.LayoutDensity),
            FontWeight = SelectFontWeight(style.TypographyWeight),
            LetterSpacing = SelectLetterSpacing(style.LayoutDensity)
        };
    }
    
    private static string SelectPrimaryFont(StyleProfile style, string domain)
    {
        // Windows 11 uses Segoe UI Variable as the primary system font
        // This is the recommended choice for all Windows apps
        
        return domain?.ToLowerInvariant() switch
        {
            "gaming" => "Segoe UI Variable",  // Clean, modern for gaming
            "education" => "Segoe UI Variable",  // Friendly, readable
            _ => "Segoe UI Variable"  // Default for all Windows apps
        };
        
        // Note: Segoe UI Variable has optical sizes (Small, Text, Display, etc.)
        // The system automatically selects the appropriate size based on font size
    }
    
    private static int SelectBaseSize(ComplexityLevel complexity)
    {
        return complexity switch
        {
            ComplexityLevel.SIMPLE => 16,    // Larger, more spacious
            ComplexityLevel.MEDIUM => 14,   // Balanced
            ComplexityLevel.COMPLEX => 13,  // Compact, fits more content
            _ => 14
        };
    }
    
    private static double SelectLineHeight(string density)
    {
        return density switch
        {
            "spacious" => 1.6,
            "comfortable" => 1.5,
            "compact" => 1.4,
            _ => 1.5
        };
    }
    
    private static string SelectFontWeight(string weight)
    {
        return weight?.ToLowerInvariant() switch
        {
            "light" => "Light",
            "regular" => "Regular",
            "medium" => "Medium",
            "semibold" => "SemiBold",
            "bold" => "Bold",
            _ => "Regular"
        };
    }
    
    private static double SelectLetterSpacing(string density)
    {
        return density switch
        {
            "spacious" => 0.02,    // Slightly more spacing
            "comfortable" => 0.0,  // Normal
            "compact" => -0.01,   // Slightly tighter
            _ => 0.0
        };
    }
}

public record TypographyProfile
{
    public string PrimaryFont { get; init; }
    public string CodeFont { get; init; }
    public int BaseSize { get; init; }
    public double LineHeight { get; init; }
    public string FontWeight { get; init; }
    public double LetterSpacing { get; init; }
}
```

---

## 8. Complete Implementation

### BrandManifest Service

```csharp
/// <summary>
/// Central service for deriving complete brand identity from user intent.
/// This is the main entry point for branding inference.
/// </summary>
public class BrandingInferenceService : IBrandingInferenceService
{
    private readonly ILogger<BrandingInferenceService> _logger;
    
    public BrandingInferenceService(ILogger<BrandingInferenceService> logger)
    {
        _logger = logger;
    }
    
    /// <summary>
    /// Derives complete brand manifest from user intent.
    /// NO TEMPLATES - everything is computed from first principles.
    /// </summary>
    public async Task<BrandManifest> DeriveBrandManifestAsync(AppIntent intent)
    {
        _logger.LogInformation("Deriving brand manifest for '{AppName}'", intent.AppName);
        
        // Step 1: Analyze app name
        var nameAnalysis = AppNameAnalyzer.Analyze(intent.AppName);
        _logger.LogDebug("Name analysis: PrimaryKeyword={Keyword}, DomainHints=[{Hints}]", 
            nameAnalysis.PrimaryKeyword, 
            string.Join(", ", nameAnalysis.DomainHints));
        
        // Step 2: Determine domain (from intent or inferred)
        var domain = DetermineDomain(intent, nameAnalysis);
        _logger.LogDebug("Determined domain: {Domain}", domain);
        
        // Step 3: Get color profile for domain
        var colorProfile = GetColorProfile(domain);
        
        // Step 4: Derive style from complexity and domain
        var styleProfile = ComplexityStyleMapper.DeriveStyle(intent);
        
        // Step 5: Generate color palette with harmony
        var colorPalette = ColorHarmony.GeneratePalette(
            colorProfile.PrimaryColor, 
            HarmonyScheme.COMPLEMENTARY);
        
        // Step 6: Apply user preferences (dark mode, etc.)
        colorPalette = ApplyUserColorPreferences(colorPalette, intent.UserPreferences);
        
        // Step 7: Derive typography
        var typography = TypographyDerivation.DeriveTypography(intent, styleProfile);
        
        // Step 8: Build final manifest
        var manifest = new BrandManifest
        {
            AppName = intent.AppName,
            Domain = domain,
            
            Colors = new ColorScheme
            {
                Primary = colorPalette.Primary,
                Secondary = colorPalette.Secondary,
                Accent = colorProfile.AccentColor,
                Background = colorPalette.Background,
                Text = DetermineTextColor(colorPalette.Background),
                Success = "#107C10",
                Warning = "#FFB900",
                Error = "#D13438"
            },
            
            Style = styleProfile,
            
            Typography = typography,
            
            IconGuidance = new IconGuidance
            {
                Style = styleProfile.IconStyle,
                Mood = colorProfile.Mood,
                SuggestedElements = colorProfile.IconElements,
                SuggestedShapes = nameAnalysis.ShapeSuggestions,
                Abbreviation = nameAnalysis.Abbreviation,
                PrimaryColor = colorPalette.Primary
            },
            
            SplashGuidance = new SplashGuidance
            {
                BackgroundGradient = new[] { colorPalette.Primary, colorPalette.Secondary },
                LogoPosition = "center",
                Style = styleProfile.VisualComplexity
            }
        };
        
        _logger.LogInformation("Brand manifest derived: PrimaryColor={Primary}, Style={Style}", 
            manifest.Colors.Primary, 
            manifest.Style.Mood);
        
        return manifest;
    }
    
    private string DetermineDomain(AppIntent intent, AppNameSemantics nameAnalysis)
    {
        // Priority: Explicit domain > Name hints > Feature hints > Default
        
        if (!string.IsNullOrWhiteSpace(intent.Domain))
            return intent.Domain.ToLowerInvariant();
        
        if (nameAnalysis.DomainHints?.Any() == true)
            return nameAnalysis.DomainHints.First();
        
        // Infer from features
        var featureKeywords = new Dictionary<string, string[]>
        {
            ["finance"] = new[] { "budget", "expense", "transaction", "bank" },
            ["productivity"] = new[] { "task", "todo", "schedule", "calendar" },
            ["health"] = new[] { "health", "medical", "wellness" },
            ["fitness"] = new[] { "workout", "exercise", "gym", "fitness" },
            ["social"] = new[] { "chat", "message", "friend", "social" },
            ["education"] = new[] { "learn", "course", "quiz", "study" }
        };
        
        foreach (var feature in intent.Features ?? new List<string>())
        {
            foreach (var (domain, keywords) in featureKeywords)
            {
                if (keywords.Any(k => feature.Contains(k, StringComparison.OrdinalIgnoreCase)))
                    return domain;
            }
        }
        
        return "default";
    }
    
    private DomainColorProfile GetColorProfile(string domain)
    {
        return DomainColorPsychology.Profiles.TryGetValue(domain, out var profile)
            ? profile
            : DomainColorProfile.Default;
    }
    
    private ColorPalette ApplyUserColorPreferences(ColorPalette palette, List<string> preferences)
    {
        if (preferences?.Contains("dark mode") == true)
        {
            return palette with { Background = "#1A1A1A" };
        }
        
        return palette;
    }
    
    private string DetermineTextColor(string backgroundColor)
    {
        // Simple luminance check
        var hex = backgroundColor.TrimStart('#');
        var r = int.Parse(hex.Substring(0, 2), NumberStyles.HexNumber);
        var g = int.Parse(hex.Substring(2, 2), NumberStyles.HexNumber);
        var b = int.Parse(hex.Substring(4, 2), NumberStyles.HexNumber);
        
        var luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
        
        return luminance > 0.5 ? "#1A1A1A" : "#FFFFFF";
    }
}

public record BrandManifest
{
    public string AppName { get; init; }
    public string Domain { get; init; }
    public ColorScheme Colors { get; init; }
    public StyleProfile Style { get; init; }
    public TypographyProfile Typography { get; init; }
    public IconGuidance IconGuidance { get; init; }
    public SplashGuidance SplashGuidance { get; init; }
}

public record ColorScheme
{
    public string Primary { get; init; }
    public string Secondary { get; init; }
    public string Accent { get; init; }
    public string Background { get; init; }
    public string Text { get; init; }
    public string Success { get; init; }
    public string Warning { get; init; }
    public string Error { get; init; }
}

public record IconGuidance
{
    public string Style { get; init; }
    public string Mood { get; init; }
    public string[] SuggestedElements { get; init; }
    public string[] SuggestedShapes { get; init; }
    public string Abbreviation { get; init; }
    public string PrimaryColor { get; init; }
}

public record SplashGuidance
{
    public string[] BackgroundGradient { get; init; }
    public string LogoPosition { get; init; }
    public string Style { get; init; }
}
```

---

## 9. Integration Points

### Integration with Platform Requirements Engine

```csharp
// In PlatformRequirementsEngine.cs

public class PlatformRequirementsEngine : IPlatformRequirementsEngine
{
    private readonly IBrandingInferenceService _brandingService;
    
    public async Task<RequirementsManifest> EvaluateRequirementsAsync(AppIntent intent)
    {
        // ... existing requirement evaluation ...
        
        // Get branding guidance (NEW)
        var brandingManifest = await _brandingService.DeriveBrandManifestAsync(intent);
        
        // Inject branding into asset requirements
        foreach (var asset in requirements.Assets)
        {
            asset.BrandingContext = brandingManifest;
        }
        
        return requirements;
    }
}
```

### Integration with Frontend Agent

```csharp
// In AI Construction Engine

public class FrontendAgent
{
    private readonly IBrandingInferenceService _brandingService;
    private readonly IImageGenerationService _imageGen;
    
    public async Task<FrontendResult> GenerateAsync(AppIntent intent, ArchitectureBlueprint blueprint)
    {
        // Derive branding (NO TEMPLATES)
        var branding = await _brandingService.DeriveBrandManifestAsync(intent);
        
        // Generate icons with branding guidance
        var icons = await GenerateIconsAsync(intent, branding);
        
        // Generate UI with derived colors
        var xaml = await GenerateXamlAsync(blueprint, branding);
        
        return new FrontendResult
        {
            XamlFiles = xaml,
            Assets = icons,
            BrandManifest = branding
        };
    }
    
    private async Task<List<GeneratedAsset>> GenerateIconsAsync(
        AppIntent intent, 
        BrandManifest branding)
    {
        var assets = new List<GeneratedAsset>();
        
        var iconRequirements = new[]
        {
            (Id: "Square44x44Logo", Width: 44, Height: 44),
            (Id: "Square150x150Logo", Width: 150, Height: 150),
            (Id: "SplashScreen", Width: 620, Height: 300),
            (Id: "StoreLogo", Width: 50, Height: 50)
        };
        
        foreach (var (id, width, height) in iconRequirements)
        {
            var prompt = id switch
            {
                "SplashScreen" => IconPromptBuilder.BuildSplashScreenPrompt(
                    AppNameAnalyzer.Analyze(intent.AppName),
                    DomainColorPsychology.Profiles.GetValueOrDefault(branding.Domain, DomainColorProfile.Default),
                    branding.Style,
                    new AssetRequirement { Width = width, Height = height }),
                
                var tileId when tileId.Contains("150") || tileId.Contains("310") =>
                    IconPromptBuilder.BuildTileLogoPrompt(
                        AppNameAnalyzer.Analyze(intent.AppName),
                        DomainColorPsychology.Profiles.GetValueOrDefault(branding.Domain, DomainColorProfile.Default),
                        branding.Style,
                        new AssetRequirement { Width = width, Height = height }),
                
                _ => IconPromptBuilder.BuildIconPrompt(
                    AppNameAnalyzer.Analyze(intent.AppName),
                    DomainColorPsychology.Profiles.GetValueOrDefault(branding.Domain, DomainColorProfile.Default),
                    branding.Style,
                    new AssetRequirement { Width = width, Height = height })
            };
            
            var imageData = await _imageGen.GenerateImageAsync(prompt, width, height);
            
            assets.Add(new GeneratedAsset
            {
                Id = id,
                Width = width,
                Height = height,
                Data = imageData,
                Prompt = prompt
            });
        }
        
        return assets;
    }
}
```

---

## 10. Fallback Strategy When Inference Fails

### When Fallback Is Needed

The branding inference may fail in these scenarios:

| Failure Scenario | Cause | Fallback Strategy |
|-----------------|-------|-------------------|
| **App Name Empty** | User didn't provide app name | Use "App" as default name |
| **Domain Unknown** | No recognizable keywords | Use Default color profile |
| **Complexity Indeterminate** | No features detected | Default to MEDIUM complexity |
| **Color Psychology Missing** | Domain not in mapping | Use Windows Blue (#0078D4) |
| **Image Generation Fails** | AI service unavailable | Use placeholder icons |

### Default Brand Manifest

When all inference fails, use this guaranteed-safe fallback:

```csharp
public static class DefaultBranding
{
    /// <summary>
    /// Guaranteed-safe fallback when all inference fails.
    /// This ALWAYS succeeds and produces valid branding.
    /// </summary>
    public static BrandManifest CreateDefault()
    {
        return new BrandManifest
        {
            AppName = "App",
            Domain = "default",
            Colors = new ColorScheme
            {
                Primary = "#0078D4",      // Windows Blue
                Secondary = "#005A9E",    // Darker Blue
                Accent = "#00B7C3",       // Cyan
                Background = "#FFFFFF",   // White
                Text = "#1A1A1A",         // Dark gray
                Success = "#107C10",      // Green
                Warning = "#FFB900",      // Gold
                Error = "#D13438"         // Red
            },
            Style = new StyleProfile
            {
                VisualComplexity = "balanced",
                IconDetail = "filled-outline",
                Mood = "modern, professional, clean",
                IconStyle = "geometric",
                Theme = "light"
            },
            Typography = new TypographyProfile
            {
                PrimaryFont = "Segoe UI Variable",
                CodeFont = "Cascadia Code",
                BaseSize = 14,
                LineHeight = 1.5,
                FontWeight = "Regular",
                LetterSpacing = 0.0
            },
            IconGuidance = new IconGuidance
            {
                Style = "geometric, minimal",
                Mood = "professional",
                SuggestedElements = new[] { "abstract", "geometric" },
                SuggestedShapes = new[] { "circle", "square" },
                Abbreviation = "A",
                PrimaryColor = "#0078D4"
            },
            SplashGuidance = new SplashGuidance
            {
                BackgroundGradient = new[] { "#0078D4", "#005A9E" },
                LogoPosition = "center",
                Style = "minimal"
            }
        };
    }
}
```

### Fallback Flow

```
BRANDING INFERENCE REQUEST
         │
         ▼
┌────────────────────────────────┐
│ Attempt Full Inference          │
│ - App name analysis             │
│ - Domain classification         │
│ - Color psychology              │
│ - Style derivation              │
└────────────────────────────────┘
         │
         ├── SUCCESS ──────────────────────→ Return BrandManifest
         │
         └── PARTIAL FAILURE ──────────────┐
                                             │
                                             ▼
                              ┌────────────────────────────────┐
                              │ Apply Fallbacks:               │
                              │ - Missing name? → Use "App"    │
                              │ - Unknown domain? → Use default│
                              │ - No style? → Use "balanced"   │
                              └────────────────────────────────┘
                                             │
                                             ├── SUCCESS ──→ Return BrandManifest
                                             │
                                             └── ALL FAILED ──→ Return DefaultBranding.CreateDefault()
```

### Error Logging

When fallback is used, log the reason for debugging:

```csharp
public class BrandingInferenceService
{
    private void LogFallbackUsage(string reason, string field, string fallbackValue)
    {
        _logger.LogWarning(
            "Branding inference fallback used: {Reason}. Field: {Field}, Fallback: {Fallback}",
            reason, field, fallbackValue);
    }
    
    public async Task<BrandManifest> DeriveBrandManifestAsync(AppIntent intent)
    {
        if (string.IsNullOrWhiteSpace(intent.AppName))
        {
            LogFallbackUsage("App name was empty", "AppName", "App");
            intent = intent with { AppName = "App" };
        }
        
        // ... rest of inference with similar fallback handling
    }
}
```

---

## References

- [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) — Zero-template approach
- [AI_RUNTIME_MODEL.md](./AI_RUNTIME_MODEL.md) — AI Construction Engine
- [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Frontend Agent uses Image Gen
- [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — Image Generation API
- [UI_IMPLEMENTATION.md](./UI_IMPLEMENTATION.md) — Typography and color definitions

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-23 | Added Section 10: Fallback Strategy When Inference Fails |
