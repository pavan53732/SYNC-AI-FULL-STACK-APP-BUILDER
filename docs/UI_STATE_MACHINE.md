# UI State Machine Specification

**Purpose**: Define the user-visible state system that abstracts backend complexity into calm, understandable states.  
**Framework**: WinUI 3, MVVM pattern  
**Philosophy**: Lovable-style UX - powerful internally, simple externally

---

## Core Principle

> **UI state ≠ Orchestrator state**
> 
> The UI abstracts complexity by mapping many backend states into few calm visual states.

**Backend Reality**: 15+ orchestrator states (IDLE, SPEC_PARSED, TASK_GRAPH_READY, TASK_EXECUTING, VALIDATING, RETRYING, COMPLETED, FAILED, etc.)

**User Experience**: 7 simple states

---

## 1. The 7 User-Visible States

### 🔷 State 1: FIRST_LAUNCH

**Trigger**:
- App installed for the first time
- No projects exist in database

**UI Presentation**:
```xaml
<StackPanel VerticalAlignment="Center" HorizontalAlignment="Center" MaxWidth="720">
    <TextBlock Text="What would you like to build?"
               FontSize="28" FontWeight="Semibold"/>
    
    <!-- Suggestion Chips -->
    <ItemsControl ItemsSource="{x:Bind SuggestionChips}">
        <!-- CRM system, Inventory tracker, Task manager, etc. -->
    </ItemsControl>
    
    <TextBlock Text="Describe your app in plain English."
               FontSize="14" Foreground="Secondary"/>
</StackPanel>
```

**Psychology**:
- Communicates: "You can just describe your idea"
- Removes: Setup anxiety, configuration fear
- Avoids: "Welcome wizard", SDK configuration, technical onboarding

**Transition**:
- → `EMPTY_IDLE` (after first project created)

---

### 🔷 State 2: EMPTY_IDLE

**Trigger**:
- Project exists
- No active generation
- Orchestrator state: `IDLE`

**UI Presentation**:
- Prompt box centered and active
- Generate button enabled (accent color)
- Status dot: Gray (static)
- Preview area: Empty or showing last result

**Available Actions**:
- Type in prompt
- Click Generate
- Browse history

**Transitions**:
- → `TYPING` (prompt field focused/changed)
- → `BUILDING` (Generate button clicked)

---

### 🔷 State 3: TYPING

**Trigger**:
- Prompt field focused or text changed

**UI Micro-Behavior**:
```csharp
private void OnPromptChanged(object sender, TextChangedEventArgs e)
{
    CurrentState = UIState.TYPING;
    
    // Subtle UI changes
    GenerateButton.Opacity = 1.0; // Full accent
    HelperHint.Opacity = 0.0; // Fade out
    SuggestionChips.Opacity = 0.5; // Dim
}
```

**Psychology**:
- Provides immediate feedback
- Focuses attention on prompt
- Prepares user for action

**Transitions**:
- → `BUILDING` (Generate clicked)
- → `EMPTY_IDLE` (input cleared)

---

### 🔷 State 4: BUILDING

**Trigger**:
- Orchestrator enters execution phase
- Maps from: `SPEC_PARSED`, `TASK_GRAPH_READY`, `TASK_EXECUTING`, `VALIDATING`, `RETRYING` (attempts 1-3)

**UI Presentation**:
```xaml
<StackPanel>
    <!-- Generate button transforms -->
    <Button Content="Building…" IsEnabled="False">
        <ProgressBar IsIndeterminate="True" Height="4"/>
    </Button>
    
    <!-- Status dot pulses blue -->
    <Ellipse Fill="Blue" Width="12" Height="12">
        <!-- 1.5s pulse animation -->
    </Ellipse>
    
    <!-- Preview slightly blurred (if exists) -->
    <Grid Opacity="0.6">
        <!-- Previous preview -->
    </Grid>
</StackPanel>
```

**What User Sees**:
- "Building…" text
- Blue pulsing status dot
- Soft animated shimmer
- Slightly blurred preview (if exists)

**What User Does NOT See**:
- ❌ Task names ("Generating MainViewModel.cs")
- ❌ Retry counter ("Attempt 2 of 10")
- ❌ File operations ("Writing to disk")
- ❌ Orchestrator state transitions

**Transitions**:
- → `PREVIEW_READY` (build succeeded)
- → `SOFT_RECOVERY` (retry attempt 4+)
- → `HARD_FAILURE` (retry budget exhausted)

**Critical**: Remain in `BUILDING` state during retries 1-3 (silent recovery)

---

### 🔷 State 5: PREVIEW_READY

**Trigger**:
- Successful build
- Orchestrator state: `COMPLETED`

**UI Presentation**:
```csharp
private async void TransitionToPreviewReady()
{
    // 1. Status dot green flash (300ms)
    await ShowSuccessFlash();
    
    // 2. Render preview
    PreviewPanel.Content = await _previewService.RenderAsync(projectPath);
    
    // 3. Subtle success checkmark animation
    await ShowSuccessCheckmark();
    
    // 4. Show action buttons
    ImproveButton.Visibility = Visibility.Visible;
    ExportButton.Visibility = Visibility.Visible;
    ViewCodeButton.Visibility = Visibility.Visible;
}
```

**Available Actions**:
- "Improve this app" (refine with new prompt)
- "Export" (save to custom location)
- "View Code" (show generated files)
- "Add Feature" (incremental generation)

**Transitions**:
- → `BUILDING` (new prompt submitted)
- → `EMPTY_IDLE` (project deleted)

---

### 🔷 State 6: SOFT_RECOVERY

**Trigger**:
- Build failed but retries ongoing (attempts 4+)
- Orchestrator state: `RETRYING` (after silent retry budget)

**UI Presentation**:
```xaml
<InfoBar Severity="Informational"
         IsOpen="True"
         Message="Optimizing build…">
    <InfoBar.ActionButton>
        <Button Content="Cancel" Click="{x:Bind CancelBuild}"/>
    </InfoBar.ActionButton>
</InfoBar>
```

**What User Sees**:
- Banner at top: "Optimizing build…"
- Blue color (not red)
- Cancel button available
- Building animation continues

**What User Does NOT See**:
- Error details
- Retry count
- Technical diagnostics

**Transitions**:
- → `PREVIEW_READY` (retry succeeded)
- → `HARD_FAILURE` (retry budget exhausted)
- → `EMPTY_IDLE` (user clicked Cancel)

---

### 🔷 State 7: HARD_FAILURE

**Trigger**:
- Retry budget exhausted
- Orchestrator state: `FAILED`

**UI Presentation**:
```xaml
<Grid VerticalAlignment="Center" HorizontalAlignment="Center">
    <Border Background="{ThemeResource LayerFillColorDefault}"
            CornerRadius="12"
            Padding="32"
            MaxWidth="480">
        <StackPanel Spacing="16">
            <!-- Warning icon (not error) -->
            <FontIcon Glyph="&#xE7BA;" FontSize="48" 
                      Foreground="{ThemeResource SystemFillColorCritical}"/>
            
            <!-- Calm message -->
            <TextBlock Text="We couldn't complete this build."
                       Style="{StaticResource SubtitleTextBlockStyle}"
                       HorizontalAlignment="Center"/>
            
            <!-- User-friendly reason -->
            <TextBlock Text="{x:Bind FriendlyErrorMessage}"
                       TextWrapping="Wrap"
                       HorizontalAlignment="Center"/>
            
            <!-- Actions -->
            <StackPanel Orientation="Horizontal" Spacing="8" HorizontalAlignment="Center">
                <Button Content="Retry" Style="{StaticResource AccentButtonStyle}"/>
                <Button Content="Modify Prompt"/>
            </StackPanel>
            
            <!-- Technical details (collapsed) -->
            <Expander Header="Show Technical Details">
                <!-- Error code, file, retry attempts, snapshot ID -->
            </Expander>
        </StackPanel>
    </Border>
</Grid>
```

**Psychology**:
- Neutral gray card (not red overlay)
- Small warning icon (not error icon)
- Gentle language: "We couldn't complete" (not "Build failed")
- Technical details collapsed by default

**Transitions**:
- → `BUILDING` (Retry clicked)
- → `TYPING` (Modify Prompt clicked)

---

## 2. State Transition Diagram

```
┌─────────────┐
│FIRST_LAUNCH │ (No projects)
└──────┬──────┘
       │ Create first project
       ↓
┌─────────────┐
│ EMPTY_IDLE  │ (Project exists, idle)
└──────┬──────┘
       │ Focus prompt
       ↓
┌─────────────┐
│   TYPING    │ (Prompt active)
└──────┬──────┘
       │ Click Generate
       ↓
┌─────────────┐
│  BUILDING   │ (Orchestrator executing)
└──────┬──────┘
       │
       ├─────────────┬──────────────┐
       │ Success     │ Retry 4+     │ Retry exhausted
       ↓             ↓              ↓
┌──────────────┐ ┌────────────┐ ┌──────────────┐
│PREVIEW_READY │ │SOFT_RECOVERY│ │HARD_FAILURE  │
└──────────────┘ └────────────┘ └──────────────┘
       │             │              │
       │             ├──────────────┘
       │             │ Success
       └─────────────┴──> Back to BUILDING (new prompt)
```

---

## 3. UI State to Orchestrator State Mapping

| UI State | Orchestrator States (Backend) |
|----------|-------------------------------|
| `FIRST_LAUNCH` | N/A (no orchestrator instance) |
| `EMPTY_IDLE` | `IDLE` |
| `TYPING` | `IDLE` (no backend change) |
| `BUILDING` | `SPEC_PARSED`, `TASK_GRAPH_READY`, `TASK_EXECUTING`, `VALIDATING`, `RETRYING` (attempts 1-3) |
| `PREVIEW_READY` | `COMPLETED` |
| `SOFT_RECOVERY` | `RETRYING` (attempts 4+) |
| `HARD_FAILURE` | `FAILED` |

**Implementation**:
```csharp
private UIState MapToUIState(OrchestratorState orchestratorState, int retryCount)
{
    return orchestratorState switch
    {
        OrchestratorState.IDLE => UIState.EMPTY_IDLE,
        OrchestratorState.SPEC_PARSED => UIState.BUILDING,
        OrchestratorState.TASK_GRAPH_READY => UIState.BUILDING,
        OrchestratorState.TASK_EXECUTING => UIState.BUILDING,
        OrchestratorState.VALIDATING => UIState.BUILDING,
        OrchestratorState.RETRYING when retryCount <= 3 => UIState.BUILDING,
        OrchestratorState.RETRYING when retryCount > 3 => UIState.SOFT_RECOVERY,
        OrchestratorState.COMPLETED => UIState.PREVIEW_READY,
        OrchestratorState.FAILED => UIState.HARD_FAILURE,
        _ => UIState.EMPTY_IDLE
    };
}
```

---

## 4. Onboarding Psychology Design

### First Launch Experience

**❌ What NOT to Show**:
- "Welcome to Sync AI Full Stack Builder"
- "Let's configure your SDK"
- "Setup .NET path"
- Multi-step wizard
- Feature tour
- Settings screen

**✅ What TO Show**:
```
┌────────────────────────────────────┐
│                                    │
│   What would you like to build?   │
│                                    │
│   [                              ] │
│                                    │
│         [ Generate ]               │
│                                    │
│   [CRM] [Inventory] [Task Manager] │
│                                    │
│   Describe your app in plain      │
│   English.                         │
│                                    │
└────────────────────────────────────┘
```

**Psychological Goals**:
1. **Power**: "I can build anything"
2. **Simplicity**: "Just describe it"
3. **Safety**: "No setup required"

---

### First Successful Build Celebration

After first successful generation:

```csharp
private async void CelebrateFirstSuccess()
{
    // Small animated toast
    var toast = new TeachingTip
    {
        Title = "Your app is ready!",
        Subtitle = "You can now preview, export, or improve it.",
        IsLightDismissEnabled = true
    };
    
    await toast.ShowAsync();
    
    // Subtle scale animation on preview
    await PreviewPanel.ScaleAsync(1.0, 1.05, duration: 200);
    await PreviewPanel.ScaleAsync(1.05, 1.0, duration: 200);
}
```

**Reinforces**: "I can actually build software"

---

### Empty Project State

If user opens new project with no code:

```xaml
<StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
    <FontIcon Glyph="&#xE8F1;" FontSize="64" Opacity="0.3"/>
    
    <TextBlock Text="This project doesn't have any features yet."
               FontSize="16" Margin="0,16,0,8"/>
    
    <TextBlock Text="Describe what you'd like to add."
               FontSize="14" Foreground="Secondary"/>
    
    <Button Content="Add a Feature" Margin="0,16,0,0"/>
</StackPanel>
```

**Avoids**: Blankness anxiety

---

### Failure Psychology

**❌ Never Use**:
- "Build failed"
- "Unhandled exception"
- "Compilation error"
- Red backgrounds
- Blame language
- Technical overload

**✅ Always Use**:
- "We couldn't complete this request"
- Neutral gray card
- Small warning icon
- Gentle language
- Clear next steps

---

### Progressive Mastery

After user builds **3+ projects**:

```csharp
private void UnlockAdvancedFeatures()
{
    if (_projectService.GetProjectCount() >= 3)
    {
        // Subtle unlock
        HistoryTab.Visibility = Visibility.Visible;
        DiffViewTooltip.IsEnabled = true;
        
        // Show one-time hint
        ShowTeachingTip("Advanced features unlocked! Check Settings for Developer Mode.");
    }
}
```

**Do NOT expose complexity early**

---

## 5. Emotional Design Goals

### User Should Feel:
- ✅ Empowered ("I can build this")
- ✅ In control ("I can retry, modify, cancel")
- ✅ Not judged ("Gentle error messages")
- ✅ Not overwhelmed ("Only 7 states, not 15")
- ✅ Not confused ("Clear next steps")
- ✅ Not intimidated ("Plain English prompts")

### Even Though Backend Is:
- Complex orchestrator with 15+ states
- Roslyn indexing ASTs
- Patch engine running diffs
- Retry loops with exponential backoff
- Snapshot management
- Build validation

**All hidden from user**

---

## 6. Implementation Guide

### ViewModel Structure

```csharp
public class MainViewModel : ObservableObject
{
    private UIState _currentState = UIState.FIRST_LAUNCH;
    private readonly IOrchestrator _orchestrator;
    private int _retryCount;
    
    public UIState CurrentState
    {
        get => _currentState;
        set
        {
            if (SetProperty(ref _currentState, value))
            {
                OnStateChanged(value);
            }
        }
    }
    
    public MainViewModel(IOrchestrator orchestrator)
    {
        _orchestrator = orchestrator;
        
        // Subscribe to orchestrator events
        _orchestrator.StateChanged += OnOrchestratorStateChanged;
        _orchestrator.RetryAttempt += OnRetryAttempt;
        
        // Initialize state
        CurrentState = DetermineInitialState();
    }
    
    private UIState DetermineInitialState()
    {
        var projectCount = _projectService.GetProjectCount();
        return projectCount == 0 ? UIState.FIRST_LAUNCH : UIState.EMPTY_IDLE;
    }
    
    private void OnOrchestratorStateChanged(object sender, StateChangedEvent e)
    {
        CurrentState = MapToUIState(e.NewState, _retryCount);
    }
    
    private void OnRetryAttempt(object sender, RetryEvent e)
    {
        _retryCount = e.AttemptNumber;
        
        // Update UI state based on retry count
        if (_retryCount > 3)
        {
            CurrentState = UIState.SOFT_RECOVERY;
        }
    }
    
    private void OnStateChanged(UIState newState)
    {
        // Update UI elements based on state
        UpdateGenerateButton(newState);
        UpdateStatusDot(newState);
        UpdatePreviewPanel(newState);
        TriggerStateAnimation(newState);
    }
}
```

---

## 7. Final Philosophy

**Internally**: Deterministic state machine + strict safety

**Externally**: Calm conversational builder

**Lovable feels magical because**:
> The UI reduces perceived system depth

**You must do the same**

---

## References

- [UI_SPECIFICATION.md](./UI_SPECIFICATION.md) - Pixel-perfect measurements
- [DESIGN_PHILOSOPHY.md](./DESIGN_PHILOSOPHY.md) - Lovable-style principles
- [ORCHESTRATOR_SPECIFICATION.md](./ORCHESTRATOR_SPECIFICATION.md) - Backend states
- [ERROR_HANDLING_SPECIFICATION.md](./ERROR_HANDLING_SPECIFICATION.md) - Failure handling
