# UI GENERATION RULES

> **WinUI 3 XAML Generation Rules: Deterministic Constraints for All Generated UI Code**
>
> **Related Core Documents:**
>
> - [STRUCTURED_SPEC_FORMAT.md](./STRUCTURED_SPEC_FORMAT.md) — AppSpec `navigationGraph` + `features` input
> - [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — App project structure (Pages, Dialogs, Controls, ViewModels)
> - [DATA_LAYER_GENERATION.md](./DATA_LAYER_GENERATION.md) — ViewModel ↔ Repository contract
> - [AI_AGENTS_AND_PLANNING.md](./AI_AGENTS_AND_PLANNING.md) — Frontend Agent that applies these rules

---

## Table of Contents

1. [Overview](#1-overview)
2. [Platform Constraints](#2-platform-constraints)
3. [Shell Layout Rules](#3-shell-layout-rules)
4. [Page Generation Rules](#4-page-generation-rules)
5. [Dialog Generation Rules](#5-dialog-generation-rules)
6. [Control Library Rules](#6-control-library-rules)
7. [ViewModel Generation Rules](#7-viewmodel-generation-rules)
8. [MVVM Binding Rules](#8-mvvm-binding-rules)
9. [Icon and Visual Asset Rules](#9-icon-and-visual-asset-rules)
10. [Theme and Styling Rules](#10-theme-and-styling-rules)
11. [Accessibility Rules](#11-accessibility-rules)
12. [Banned XAML Patterns](#12-banned-xaml-patterns)
13. [Common Generation Examples](#13-common-generation-examples)

---

## 1. Overview

The **Frontend Agent** uses these rules deterministically when generating all XAML, C# code-behind, and ViewModels in the `{AppName}.App` project. Rules here take absolute precedence over any AI-inferred patterns.

### Layers of Generated UI

```text
MainWindow.xaml (Shell)
    └── NavigationView / TabView
            └── Frame (content host)
                    ├── {PageName}Page.xaml      ← Generated per spec.navigationGraph.pages
                    │       └── DataContext = {PageName}ViewModel
                    └── {DialogName}Dialog.xaml  ← Generated per page.dialogs
                            └── DataContext = {DialogName}ViewModel
```

---

## 2. Platform Constraints

| Constraint          | Value                                                         |
| ------------------- | ------------------------------------------------------------- |
| UI Framework        | WinUI 3 (Windows App SDK 1.5+)                                |
| XAML Dialect        | WinUI 3 XAML (not WPF, not UWP, not Maui)                     |
| Min Windows Version | Windows 10 22621 (22H2)                                       |
| Design System       | WinUI 3 built-in Fluent Design — NO external CSS or HTML      |
| Chart Library       | `CommunityToolkit.WinUI.UI.Controls` or `LiveCharts2` (WinUI) |
| MVVM Helpers        | `CommunityToolkit.Mvvm` (RelayCommand, ObservableObject)      |
| No WebView          | `WebView2` is forbidden - use native WinUI controls instead    |
| No Electron/CEF     | Forbidden                                                     |

---

## 3. Shell Layout Rules

### NavigationView (3+ sections)

```xml
<!-- MainWindow.xaml — NavigationView shell -->
<NavigationView x:Name="NavView"
                IsSettingsVisible="False"
                SelectionChanged="NavView_SelectionChanged">
    <NavigationView.MenuItems>
        <!-- One item per spec.navigationGraph.pages[isInNavMenu=true] -->
        <NavigationViewItem Content="{page.title}"
                            Tag="{page.route}"
                            Icon="{page.icon (Segoe Fluent Icon)}"/>
    </NavigationView.MenuItems>
    <Frame x:Name="ContentFrame"
           IsNavigationStackEnabled="False"/>
</NavigationView>
```

### TabView (2–3 peer sections)

```xml
<!-- MainWindow.xaml — TabView shell -->
<TabView x:Name="MainTabView"
         IsAddTabButtonVisible="False">
    <!-- One TabViewItem per spec.navigationGraph.pages[isInNavMenu=true] -->
    <TabViewItem Header="{page.title}" IsClosable="False">
        <Frame/>
    </TabViewItem>
</TabView>
```

### Navigation Code-Behind Pattern

```csharp
// MainWindow.xaml.cs
private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
{
    if (args.SelectedItemContainer?.Tag is string tag)
    {
        var pageType = tag switch
        {
            "expenses"   => typeof(ExpensesPage),
            "categories" => typeof(CategoriesPage),
            "report"     => typeof(ReportPage),
            _            => null
        };
        if (pageType != null)
            ContentFrame.Navigate(pageType);
    }
}
```

---

## 4. Page Generation Rules

### Page Layout Template

```xml
<!-- {PageName}Page.xaml -->
<Page x:Class="{AppName}.{PageName}Page"
      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:local="using:{AppName}"
      Background="{ThemeResource ApplicationPageBackgroundThemeBrush}">
    <Grid RowDefinitions="Auto,*">

        <!-- Row 0: Page header + action buttons -->
        <Grid Grid.Row="0" Padding="24,16" ColumnDefinitions="*,Auto">
            <TextBlock Grid.Column="0"
                       Text="{page.title}"
                       Style="{ThemeResource TitleTextBlockStyle}"/>
            <!-- Add button (for CRUD features) -->
            <Button Grid.Column="1"
                    x:Name="AddButton"
                    Content="Add"
                    Style="{ThemeResource AccentButtonStyle}"
                    Click="AddButton_Click"/>
        </Grid>

        <!-- Row 1: Content (ListView, DataGrid, Chart — see Rule 6) -->
        <Grid Grid.Row="1" Padding="24,0,24,24">
            <!-- Loading overlay -->
            <ProgressRing x:Name="LoadingRing"
                          IsActive="{x:Bind ViewModel.IsLoading, Mode=OneWay}"
                          HorizontalAlignment="Center"
                          VerticalAlignment="Center"/>

            <!-- Main content — hidden while loading -->
            <!-- See Control Library Rules for content control selection -->
        </Grid>

    </Grid>
</Page>
```

### Page Rules

| Rule                     | Description                                                                                      |
| ------------------------ | ------------------------------------------------------------------------------------------------ |
| **Single Grid root**     | Top-level layout is always `<Grid>`, never `<StackPanel>` or `<Canvas>`                          |
| **Row 0 = Header**       | Page title + primary action buttons                                                              |
| **Row 1 = Content**      | Main data display control                                                                        |
| **LoadingRing**          | Every page must have a `ProgressRing` bound to `ViewModel.IsLoading`                             |
| **No code-behind logic** | Code-behind only `InitializeComponent()`, `DataContext = ViewModel`, and event-to-command wiring |
| **Padding**              | Standard page padding is `24,16` for header, `24,0,24,24` for content                            |

---

## 5. Dialog Generation Rules

### Dialog Template

```xml
<!-- {DialogName}Dialog.xaml -->
<ContentDialog x:Class="{AppName}.Dialogs.{DialogName}Dialog"
               xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
               xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
               Title="{dialog.purpose}"
               PrimaryButtonText="Save"
               CloseButtonText="Cancel"
               DefaultButton="Primary"
               PrimaryButtonClick="ContentDialog_PrimaryButtonClick">
    <StackPanel Spacing="12" MinWidth="340">
        <!-- One input control per editable field (see Control Library Rules) -->
    </StackPanel>
</ContentDialog>
```

### Dialog Invocation Pattern

```csharp
// In Page code-behind — triggered by button click or row double-tap
private async void AddButton_Click(object sender, RoutedEventArgs e)
{
    var dialog = new AddExpenseDialog { XamlRoot = XamlRoot };
    var result = await dialog.ShowAsync();
    if (result == ContentDialogResult.Primary)
        await ViewModel.LoadAsync(); // Refresh list after save
}
```

### Dialog ViewModel Pattern

```csharp
public partial class AddExpenseDialogViewModel : ObservableObject
{
    [ObservableProperty]
    private string _title = string.Empty;

    [ObservableProperty]
    private double _amount;

    [ObservableProperty]
    private DateTime _date = DateTime.Today;

    [ObservableProperty]
    private Guid _categoryId;

    public ObservableCollection<Category> Categories { get; } = [];

    public async Task LoadAsync()
    {
        var categories = await _categoryService.GetAllAsync();
        Categories.Clear();
        foreach (var c in categories) Categories.Add(c);
    }

    public async Task<bool> SaveAsync()
    {
        if (string.IsNullOrWhiteSpace(Title) || Amount <= 0) return false;
        var expense = new Expense
        {
            Title = Title,
            Amount = Amount,
            Date = Date,
            CategoryId = CategoryId
        };
        await _expenseService.AddAsync(expense);
        return true;
    }
}
```

### Dialog Rules

| Rule                             | Description                                                                          |
| -------------------------------- | ------------------------------------------------------------------------------------ |
| **ContentDialog only**           | All dialogs must use WinUI 3 `ContentDialog`. No custom `Window` popups.             |
| **XamlRoot must be set**         | Before calling `ShowAsync()`, set `dialog.XamlRoot = this.XamlRoot`                  |
| **PrimaryButtonClick validates** | Dialog validates input in `PrimaryButtonClick`; if invalid, set `args.Cancel = true` |
| **MaxWidth**                     | Dialog content max width is 480px                                                    |
| **No nested dialogs**            | A dialog must not open another dialog                                                |

---

## 6. Control Library Rules

The Frontend Agent selects UI controls based on feature type and field type using the following decision tables.

### 6.1 List/Data Display Control Selection

| Feature Category | Data Volume   | Selected Control                       |
| ---------------- | ------------- | -------------------------------------- |
| `CRUD`           | < 500 rows    | `ListView` with `DataTemplate`         |
| `CRUD`           | 500+ rows     | `DataGrid` (CommunityToolkit)          |
| `Report`         | Chart data    | `BarChart` or `PieChart` (LiveCharts2) |
| `Dashboard`      | Summary cards | `GridView` of `InfoCard` templates     |
| `Report`         | Tabular data  | `DataGrid` (read-only)                 |

### 6.2 Input Control Selection by Field Type

| Field Type                           | `isRequired` | Selected Control                              |
| ------------------------------------ | ------------ | --------------------------------------------- |
| `string` (short, ≤ 100 chars)        | any          | `TextBox`                                     |
| `string` (long, > 100 chars / notes) | any          | `TextBox` (AcceptsReturn=True, MaxHeight=120) |
| `double` or `int`                    | any          | `NumberBox`                                   |
| `DateTime`                           | any          | `CalendarDatePicker`                          |
| `bool`                               | any          | `ToggleSwitch`                                |
| `Guid` (FK to another entity)        | any          | `ComboBox` bound to collection of that entity |
| `byte[]` (image)                     | any          | `Image` + `Button` (Pick file)                |
| `enum` (from spec)                   | any          | `ComboBox` with enum values                   |
| `string` (color)                     | any          | `ColorPicker` (WinUI 3 built-in)              |

### 6.3 Action Controls

| Action                               | Control                                                       |
| ------------------------------------ | ------------------------------------------------------------- |
| Primary action (Add, Save, Generate) | `Button` with `AccentButtonStyle`                             |
| Secondary action (Cancel, Reset)     | `Button` (default style)                                      |
| Destructive action (Delete)          | `Button` with `x:Name` + confirm dialog before execution      |
| Toggle state                         | `ToggleButton` or `ToggleSwitch`                              |
| Navigation                           | `HyperlinkButton` if inline; `NavigationViewItem` if nav menu |

### 6.4 Feedback Controls

| Feedback Type             | Control                                              |
| ------------------------- | ---------------------------------------------------- |
| Loading state             | `ProgressRing` (indeterminate)                       |
| Progress with known total | `ProgressBar`                                        |
| Success toast             | `Microsoft.Windows.AppNotifications` (local toast)   |
| Error message             | `InfoBar` with `Severity="Error"` in the page layout |
| Empty state               | `TextBlock` + icon visible when collection is empty  |

---

## 7. ViewModel Generation Rules

### Base Class

All ViewModels must inherit from `CommunityToolkit.Mvvm.ComponentModel.ObservableObject`:

```csharp
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

public partial class {PageName}ViewModel : ObservableObject
{
    // ...
}
```

> **Rule**: Using `partial class` is mandatory to support CommunityToolkit.Mvvm source generators.

### Required ViewModel Properties

```csharp
// Every ViewModel must have:

[ObservableProperty]
private bool _isLoading;

// List-page ViewModels additionally require:
public ObservableCollection<{Entity}> Items { get; } = [];

// CRUD ViewModels additionally require:
[RelayCommand]
private async Task AddAsync() { ... }

[RelayCommand]
private async Task DeleteAsync({Entity} item) { ... }

// Load method called from page OnNavigatedTo:
public async Task LoadAsync()
{
    IsLoading = true;
    try
    {
        Items.Clear();
        var items = await _service.GetAllAsync();
        foreach (var item in items) Items.Add(item);
    }
    finally
    {
        IsLoading = false;
    }
}
```

### ViewModel Constructor Rules

```csharp
// ✅ CORRECT — Constructor receives services via DI
public {PageName}ViewModel(I{Entity}Service {entity}Service)
{
    _{entity}Service = {entity}Service;
}

// ❌ FORBIDDEN — ViewModel creating its own service instances
public {PageName}ViewModel()
{
    _service = new ExpenseService(...); // ← FORBIDDEN
}
```

---

## 8. MVVM Binding Rules

### x:Bind vs. Binding

| Scenario                        | Use                                                 |
| ------------------------------- | --------------------------------------------------- |
| Binding to ViewModel properties | `{x:Bind ViewModel.Property, Mode=OneWay}`          |
| Simple one-time text            | `{x:Bind ViewModel.Title}` (defaults to OneTime)    |
| User-editable fields in dialogs | `{x:Bind ViewModel.Property, Mode=TwoWay}`          |
| Complex converters needed       | `{Binding Property, Converter={...}}` (fallback)    |
| Events wired to commands        | `<Button Command="{x:Bind ViewModel.AddCommand}"/>` |

### Binding Mode Rules

| Direction                         | Mode               |
| --------------------------------- | ------------------ |
| Read-only display                 | `OneWay`           |
| User-editable input               | `TwoWay`           |
| Static text set once              | `OneTime`          |
| Writable from ViewModel side only | `OneWay` (default) |

### Command Binding

```xml
<!-- ✅ CORRECT — RelayCommand binding -->
<Button Content="Add Expense"
        Command="{x:Bind ViewModel.AddCommand}"
        Style="{ThemeResource AccentButtonStyle}"/>

<!-- ✅ CORRECT — Command with parameter -->
<Button Content="Delete"
        Command="{x:Bind ViewModel.DeleteCommand}"
        CommandParameter="{x:Bind item}"/>
```

---

## 9. Icon and Visual Asset Rules

### Required Asset Files

All generated apps must have the following asset files placed in `{AppName}.App/Assets/`:

| File                         | Size    | Purpose            |
| ---------------------------- | ------- | ------------------ |
| `AppIcon.scale-100.png`      | 44×44   | Icon at 100% DPI   |
| `AppIcon.scale-125.png`      | 56×56   | Icon at 125% DPI   |
| `AppIcon.scale-150.png`      | 66×66   | Icon at 150% DPI   |
| `AppIcon.scale-200.png`      | 88×88   | Icon at 200% DPI   |
| `AppIcon.scale-400.png`      | 176×176 | Icon at 400% DPI   |
| `SplashScreen.scale-100.png` | 620×300 | Splash screen      |
| `WideLogo.scale-100.png`     | 310×150 | Wide tile          |
| `StoreLogo.png`              | 50×50   | Store listing icon |

### Asset Generation Rules

- All assets are **AI-generated** using the `iconIntent` and `splashIntent` fields from `AppSpec.appIdentity`.
- Assets are generated by the **Frontend Agent** using the Image Generation capability of the AI Service Layer.
- No static templates or placeholders are used. Every icon is generated from scratch.
- The `primaryColor` from `AppSpec.appIdentity` is guaranteed to appear as the dominant color in all icons.
- Icons must have a **transparent background** (PNG with alpha channel).

### Segoe Fluent Icons for Navigation

Navigation icons in `NavigationViewItem` use Segoe Fluent Icons glyphs. The Frontend Agent selects icons based on `page.icon` from the spec:

| Spec Icon Name | Segoe Glyph | Unicode |
| -------------- | ----------- | ------- |
| `Money`        | ``          | `E8C7`  |
| `Tag`          | ``          | `E8EC`  |
| `BarChart`     | ``          | `E9D2`  |
| `Settings`     | ``          | `E713`  |
| `Home`         | ``          | `E80F`  |
| `Calendar`     | ``          | `E787`  |
| `Search`       | ``          | `E721`  |
| `Person`       | ``          | `E77B`  |
| `Folder`       | ``          | `E8B7`  |
| `Mail`         | ``          | `E715`  |

```xml
<!-- Example NavigationViewItem with Segoe Fluent Icon -->
<NavigationViewItem Content="Expenses" Tag="expenses">
    <NavigationViewItem.Icon>
        <FontIcon Glyph="&#xE8C7;"/>
    </NavigationViewItem.Icon>
</NavigationViewItem>
```

---

## 10. Theme and Styling Rules

### Implicit Theme Support

All generated apps support light/dark/system themes automatically by using WinUI 3 `ThemeResource` brushes exclusively. No hardcoded color values in XAML.

```xml
<!-- ✅ CORRECT -->
<Grid Background="{ThemeResource ApplicationPageBackgroundThemeBrush}"/>
<TextBlock Foreground="{ThemeResource TextFillColorPrimaryBrush}"/>

<!-- ❌ FORBIDDEN — hardcoded colors -->
<Grid Background="#FFFFFF"/>
<TextBlock Foreground="Black"/>
```

### App.xaml Global Styles

```xml
<!-- App.xaml — define app-wide resources -->
<Application.Resources>
    <ResourceDictionary>
        <ResourceDictionary.MergedDictionaries>
            <XamlControlsResources xmlns="using:Microsoft.UI.Xaml.Controls"/>
        </ResourceDictionary.MergedDictionaries>

        <!-- App accent color from spec.appIdentity.primaryColor -->
        <Color x:Key="SystemAccentColor">{primaryColor}</Color>
    </ResourceDictionary>
</Application.Resources>
```

### Typography Rules

| Text Role                 | WinUI 3 Style            |
| ------------------------- | ------------------------ |
| Page title                | `TitleTextBlockStyle`    |
| Section heading           | `SubtitleTextBlockStyle` |
| Body text                 | `BodyTextBlockStyle`     |
| Caption / secondary       | `CaptionTextBlockStyle`  |
| Card value / large number | `DisplayTextBlockStyle`  |

---

## 11. Accessibility Rules

| Rule                          | Requirement                                                                               |
| ----------------------------- | ----------------------------------------------------------------------------------------- |
| **AutomationProperties.Name** | Every interactive control must have `AutomationProperties.Name` set                       |
| **Keyboard navigation**       | Tab order must follow visual reading order; no tab traps                                  |
| **Contrast ratio**            | Custom colors must maintain WCAG AA (4.5:1 ratio minimum)                                 |
| **ProgressRing label**        | `IsIndeterminate="True"` rings must have `AutomationProperties.Name="Loading"`            |
| **Error messages**            | Error `InfoBar` must have `IsOpen` bound to an error state property; not shown by default |
| **Button accessible names**   | Icon-only buttons must set `ToolTipService.ToolTip` and `AutomationProperties.Name`       |

---

## 12. Banned XAML Patterns

The following patterns are **explicitly forbidden** in the generated UI:

| Forbidden Pattern                               | Reason                              | Replacement                                 |
| ----------------------------------------------- | ----------------------------------- | ------------------------------------------- |
| `WebView2`                                      | Constraint — no web content | Use native WinUI 3 controls                 |
| Code-behind business logic                      | Violates MVVM                       | Move to ViewModel                           |
| `Thread.Sleep()` or `Task.Delay()` in UI thread | Blocks UI                           | Use async/await                             |
| Hardcoded colors and sizes                      | Breaks theme support                | Use `ThemeResource`                         |
| `StackPanel` as page root                       | Poor resize behavior                | Use `Grid`                                  |
| Direct `DbContext` usage in pages/dialogs       | Violates layering                   | Use service via ViewModel                   |
| `Window` for dialogs                            | WinUI 3 anti-pattern                | Use `ContentDialog`                         |
| `Canvas` with absolute positioning              | Breaks responsive layout            | Use `Grid`/`StackPanel`/`RelativePanel`     |
| Binding errors ignored                          | Silent data corruption              | All bindings must be validated              |
| `Dispatcher.RunAsync` (UWP API)                 | Not available in WinUI 3            | Use `DispatcherQueue.TryEnqueue()`          |
| Regex for XAML parsing                          | Unsafe and brittle for XML syntax   | Use XML/AST manipulation (e.g. `XDocument`) |

---

## 13. Common Generation Examples

### Example A: CRUD List Page (Expenses)

```xml
<!-- ExpensesPage.xaml -->
<Page ...>
    <Grid RowDefinitions="Auto,Auto,*">

        <!-- Header -->
        <Grid Grid.Row="0" Padding="24,16" ColumnDefinitions="*,Auto">
            <TextBlock Grid.Column="0" Text="Expenses"
                       Style="{ThemeResource TitleTextBlockStyle}"/>
            <Button Grid.Column="1"
                    Content="Add Expense"
                    Style="{ThemeResource AccentButtonStyle}"
                    Click="AddButton_Click"
                    AutomationProperties.Name="Add Expense"/>
        </Grid>

        <!-- Error InfoBar -->
        <InfoBar Grid.Row="1"
                 x:Name="ErrorBar"
                 Severity="Error"
                 IsOpen="{x:Bind ViewModel.HasError, Mode=OneWay}"
                 Message="{x:Bind ViewModel.ErrorMessage, Mode=OneWay}"
                 IsClosable="True"
                 Margin="24,0"/>

        <!-- Content -->
        <Grid Grid.Row="2" Padding="24,8,24,24">
            <ProgressRing IsActive="{x:Bind ViewModel.IsLoading, Mode=OneWay}"
                          HorizontalAlignment="Center"
                          VerticalAlignment="Center"
                          AutomationProperties.Name="Loading"/>

            <!-- Empty state -->
            <StackPanel HorizontalAlignment="Center"
                        VerticalAlignment="Center"
                        Spacing="8"
                        Visibility="{x:Bind ViewModel.IsEmpty, Mode=OneWay,
                                     Converter={StaticResource BoolToVisibilityConverter}}">
                <FontIcon Glyph="&#xE8C7;" FontSize="48"
                          Foreground="{ThemeResource TextFillColorSecondaryBrush}"/>
                <TextBlock Text="No expenses yet. Add your first one!"
                           Style="{ThemeResource BodyTextBlockStyle}"
                           Foreground="{ThemeResource TextFillColorSecondaryBrush}"/>
            </StackPanel>

            <!-- Data list -->
            <ListView ItemsSource="{x:Bind ViewModel.Expenses, Mode=OneWay}"
                      SelectionMode="None"
                      Visibility="{x:Bind ViewModel.IsNotEmpty, Mode=OneWay,
                                   Converter={StaticResource BoolToVisibilityConverter}}">
                <ListView.ItemTemplate>
                    <DataTemplate x:DataType="models:Expense">
                        <Grid ColumnDefinitions="*,Auto,Auto" Padding="0,8">
                            <StackPanel Grid.Column="0" Spacing="2">
                                <TextBlock Text="{x:Bind Title}"
                                           Style="{ThemeResource BodyStrongTextBlockStyle}"/>
                                <TextBlock Text="{x:Bind Category.Name}"
                                           Style="{ThemeResource CaptionTextBlockStyle}"
                                           Foreground="{ThemeResource TextFillColorSecondaryBrush}"/>
                            </StackPanel>
                            <TextBlock Grid.Column="1"
                                       Text="{x:Bind Amount, Converter={StaticResource CurrencyConverter}}"
                                       Style="{ThemeResource BodyStrongTextBlockStyle}"
                                       Margin="16,0"/>
                            <Button Grid.Column="2"
                                    Content="Delete"
                                    Command="{x:Bind DataContext.DeleteCommand,
                                              ElementName=ExpensesPageRoot}"
                                    CommandParameter="{x:Bind}"
                                    AutomationProperties.Name="Delete expense"/>
                        </Grid>
                    </DataTemplate>
                </ListView.ItemTemplate>
            </ListView>
        </Grid>
    </Grid>
</Page>
```

### Example B: ObservableObject ViewModel (Expenses Page)

```csharp
// ExpensesPageViewModel.cs
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using System.Collections.ObjectModel;

public partial class ExpensesPageViewModel : ObservableObject
{
    private readonly IExpenseService _expenseService;

    public ExpensesPageViewModel(IExpenseService expenseService)
        => _expenseService = expenseService;

    [ObservableProperty]
    private bool _isLoading;

    [ObservableProperty]
    private bool _hasError;

    [ObservableProperty]
    private string _errorMessage = string.Empty;

    public ObservableCollection<Expense> Expenses { get; } = [];

    public bool IsEmpty => !Expenses.Any();
    public bool IsNotEmpty => Expenses.Any();

    public async Task LoadAsync()
    {
        IsLoading = true;
        HasError = false;
        try
        {
            Expenses.Clear();
            var items = await _expenseService.GetAllAsync();
            foreach (var item in items) Expenses.Add(item);
            OnPropertyChanged(nameof(IsEmpty));
            OnPropertyChanged(nameof(IsNotEmpty));
        }
        catch (Exception ex)
        {
            HasError = true;
            ErrorMessage = $"Failed to load expenses: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    private async Task DeleteAsync(Expense expense)
    {
        await _expenseService.DeleteAsync(expense.Id);
        Expenses.Remove(expense);
        OnPropertyChanged(nameof(IsEmpty));
        OnPropertyChanged(nameof(IsNotEmpty));
    }
}
```

---

## Change Log

| Date       | Change                                                    |
| ---------- | --------------------------------------------------------- |
| 2026-03-03 | Initial creation — complete WinUI 3 XAML generation rules |

---

## References

- [STRUCTURED_SPEC_FORMAT.md](./STRUCTURED_SPEC_FORMAT.md) — AppSpec navigation + feature input
- [TARGET_APP_ARCHITECTURE.md](./TARGET_APP_ARCHITECTURE.md) — App project structure
- [DATA_LAYER_GENERATION.md](./DATA_LAYER_GENERATION.md) — Data layer (ViewModel consumes services from here)
- [REPAIR_PATTERNS.md](./REPAIR_PATTERNS.md) — WinUI 3 XAML + MVVM build error repair strategies
- [PLATFORM_REQUIREMENTS_ENGINE.md](./PLATFORM_REQUIREMENTS_ENGINE.md) — Asset file requirements
- [BRANDING_INFERENCE_HEURISTICS.md](./BRANDING_INFERENCE_HEURISTICS.md) — Icon and color derivation
