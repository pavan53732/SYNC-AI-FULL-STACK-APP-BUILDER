docs: Architectual specifications enhancements for stability and reproducibility

Deleted README.md as project docs have been centralized.

Significant enhancements to the orchestrator and automation designs:
- ORCHESTRATION_ENGINE.md: Enforced single active transaction model. Configured AI Failure Recovery scenarios with new BuilderStates (AI_SERVICE_UNAVAILABLE, AI_SERVICE_DEGRADED). Included SDK version tracking in ConstructionTransaction for asset determinacy. Implemented Trace ID propagation, granular operation timeouts, and an E2E test plan for the AI mini-service. Added package integrity and Authenticode signature rules for the AI service.
- BRANDING_INFERENCE_HEURISTICS.md: Transitioned to a deterministic image generation approach via IntentHash-to-Seed mechanism and cache storage.
- WINDOWS_PACKAGING_AND_PERMISSION_AUTOMATION.md: Ensured version numbers only increment on Kernel-Confirmed mutation events. 
- AI_MINI_SERVICE_IMPLEMENTATION.md: Added deterministic seed param to image gen and defined SDK version payloads to health endpoint.
- PLATFORM_REQUIREMENTS_ENGINE.md: Synced and linked BuilderState derivations strictly to the orchestrator central dictionary.
