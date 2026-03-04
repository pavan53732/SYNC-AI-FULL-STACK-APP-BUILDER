# AI MINI SERVICE IMPLEMENTATION

> **Complete Implementation Guide for the AI Service Layer**
>
> **Related Document:** [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — Architecture and API contract
>
> _This document provides the complete TypeScript/Bun implementation for the AI Mini Service that powers all AI capabilities in Sync AI. Uses the `openai` npm SDK with user-configured providers._

---

## Table of Contents

1. [Overview](#1-overview)
2. [Project Setup](#2-project-setup)
3. [Service Implementation](#3-service-implementation)
4. [API Endpoints](#4-api-endpoints)
5. [Error Handling](#5-error-handling)
6. [Build & Deployment](#6-build--deployment)
7. [Testing](#7-testing)

---

## 1. Overview

### Purpose

The AI Mini Service is a **standalone executable** that bridges the Sync AI Desktop application (C#/.NET 8/WinUI 3) with AI capabilities provided by **user-configured OpenAI-compatible providers** via the `openai` npm SDK.

### Key Principles

| Principle | Implementation |
|-----------|----------------|
| **User-Configured Providers** | Users set model name, base URL, and API key for each slot |
| **Three Model Slots** | Primary (code/chat), Vision (UI analysis), Image Generation (icons) |
| **Single Executable** | Compile with `bun build --compile` for clean deployment |
| **Hidden Background Process** | Runs completely invisible to the user |
| **Auto-Start** | Desktop app starts this service automatically on launch |
| **Localhost Only** | Binds to 127.0.0.1 for security |

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│           SYNC AI DESKTOP (C# / .NET 8 / WinUI 3)           │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ AIMiniServiceManager                                 │   │
│   │ ├─ StartServiceAsync()     → Starts ai-service.exe  │   │
│   │ ├─ IsHealthyAsync()        → GET /health            │   │
│   │ ├─ ConfigureAsync()        → POST /api/config       │   │
│   │ └─ StopService()           → Terminate process      │   │
│   └─────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           │ HTTP (localhost:3001)           │
│                           ▼                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│           ai-service.exe (Compiled Bun Service)              │
│                                                              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ openai SDK (user-configured providers)              │   │
│   │                                                     │   │
│   │ ┌─────────────┐ ┌──────────────┐ ┌──────────────┐ │   │
│   │ │primaryClient│ │ visionClient │ │ imageClient  │ │   │
│   │ │ Code & Chat │ │ UI Analysis  │ │ Icon/Splash  │ │   │
│   │ └─────────────┘ └──────────────┘ └──────────────┘ │   │
│   │                                                     │   │
│   │ Endpoints:                                          │   │
│   │ ├─ POST /api/config          (receive settings)    │   │
│   │ ├─ POST /api/chat            (LLM completions)     │   │
│   │ ├─ POST /api/chat/stream     (streaming LLM)       │   │
│   │ ├─ POST /api/generate-image  (image generation)    │   │
│   │ ├─ POST /api/vision          (vision analysis)     │   │
│   │ └─ POST /api/search          (web search)          │   │
│   └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Project Setup

### 2.1 Directory Structure

```
ai-mini-service/
├── index.ts              # Main entry point
├── package.json          # Dependencies
├── tsconfig.json         # TypeScript configuration
├── routes/
│   ├── config.ts         # Configuration endpoint (receives AI settings)
│   ├── chat.ts           # LLM endpoint (uses primaryClient)
│   ├── image.ts          # Image generation endpoint (uses imageClient)
│   ├── vision.ts         # Vision analysis endpoint (uses visionClient)
│   └── search.ts         # Web search endpoint (uses primaryClient)
├── services/
│   └── ai-client.ts      # openai SDK wrapper — triple-client pattern
└── utils/
    ├── logger.ts         # Logging utilities
    └── errors.ts         # Error definitions
```

### 2.2 package.json

```json
{
  "name": "sync-ai-mini-service",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "bun --hot run index.ts",
    "start": "bun run index.ts",
    "build": "bun build ./index.ts --compile --outfile ai-service.exe"
  },
  "dependencies": {
    "openai": "^4.50.0"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "typescript": "^5.0.0"
  }
}
```

### 2.3 tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "outDir": "./dist",
    "rootDir": "."
  },
  "include": ["**/*.ts"],
  "exclude": ["node_modules"]
}
```

---

## 3. Service Implementation

### 3.1 Main Entry Point (index.ts)

```typescript
/**
 * AI Mini Service - Main Entry Point
 *
 * This service provides AI capabilities to Sync AI Desktop via HTTP API.
 * Uses the openai npm SDK with user-configured providers.
 *
 * Three model slots:
 *   - Primary (code/chat)
 *   - Vision (UI analysis)
 *   - Image Generation (icons/splash)
 */

import { serve } from "bun";

// Import route handlers
import { handleConfig } from "./routes/config";
import { handleChat, handleChatStream } from "./routes/chat";
import { handleGenerateImage } from "./routes/image";
import { handleVision } from "./routes/vision";
import { handleSearch } from "./routes/search";

// Configuration
const PORT = parseInt(process.env.AI_SERVICE_PORT || "3001");
const HOST = "127.0.0.1"; // localhost only for security

// CORS headers for local development
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "http://localhost:*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type"
};

// Main server
const server = serve({
  port: PORT,
  hostname: HOST,

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const method = request.method;

    // Handle CORS preflight
    if (method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    // Route handling
    try {
      switch (url.pathname) {
        // Health check
        case "/health":
          return jsonResponse({
            success: true,
            status: "healthy",
            version: "1.0.0",
            protocol: "sync-ai-ai-bridge-v1",
            uptime: process.uptime(),
            timestamp: new Date().toISOString(),
            configured: {
              primary: isPrimaryConfigured(),
              vision: isVisionConfigured(),
              imageGen: isImageConfigured(),
              validated: globalConfig.validated
            }
          });

        // Configuration (receives settings from desktop app)
        case "/api/config":
          if (method !== "POST") return methodNotAllowed();
          return await handleConfig(request);

        // LLM endpoints (uses primaryClient)
        case "/api/chat":
          if (method !== "POST") return methodNotAllowed();
          return await handleChat(request);

        case "/api/chat/stream":
          if (method !== "POST") return methodNotAllowed();
          return await handleChatStream(request);

        // Image generation (uses imageClient)
        case "/api/generate-image":
          if (method !== "POST") return methodNotAllowed();
          return await handleGenerateImage(request);

        // Vision analysis (uses visionClient)
        case "/api/vision":
          if (method !== "POST") return methodNotAllowed();
          return await handleVision(request);

        // Web search (uses primaryClient)
        case "/api/search":
          if (method !== "POST") return methodNotAllowed();
          return await handleSearch(request);

        // 404 for unknown routes
        default:
          return notFound();
      }
    } catch (error) {
      console.error("[AI Service] Unhandled error:", error);
      return errorResponse("INTERNAL_ERROR", "An unexpected error occurred", 500);
    }
  },

  error(error: Error): Response {
    console.error("[AI Service] Server error:", error);
    return errorResponse("SERVER_ERROR", error.message, 500);
  }
});

// Import config status helpers
import { isPrimaryConfigured, isVisionConfigured, isImageConfigured } from "./services/ai-client";

// Helper functions
function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS
    }
  });
}

function errorResponse(code: string, message: string, status = 400): Response {
  return jsonResponse(
    {
      success: false,
      error: { code, message, retryable: status >= 500 }
    },
    status
  );
}

function methodNotAllowed(): Response {
  return errorResponse("METHOD_NOT_ALLOWED", "HTTP method not allowed", 405);
}

function notFound(): Response {
  return errorResponse("NOT_FOUND", "Endpoint not found", 404);
}

// Startup message
console.log(`[AI Service] Starting on http://${HOST}:${PORT}`);
console.log("[AI Service] Waiting for configuration from desktop app via POST /api/config");
console.log("[AI Service] Available endpoints:");
console.log("  - GET  /health              - Health check");
console.log("  - POST /api/config          - Receive AI provider settings");
console.log("  - POST /api/chat            - LLM chat completions");
console.log("  - POST /api/chat/stream     - Streaming LLM responses");
console.log("  - POST /api/generate-image  - Image generation");
console.log("  - POST /api/vision          - Image analysis");
console.log("  - POST /api/search          - Web search");

// Graceful shutdown
process.on("SIGTERM", () => {
  console.log("[AI Service] Received SIGTERM, shutting down...");
  server.stop();
  process.exit(0);
});

process.on("SIGINT", () => {
  console.log("[AI Service] Received SIGINT, shutting down...");
  server.stop();
  process.exit(0);
});
```

### 3.2 AI Client Service (services/ai-client.ts)

```typescript
/**
 * OpenAI SDK Wrapper — Triple-Client Pattern
 *
 * Manages three independent OpenAI client instances:
 *   - primaryClient: Code generation & chat (uses Primary Model config)
 *   - visionClient:  UI analysis & image understanding (uses Vision Model config)
 *   - imageClient:   App icons & splash screen generation (uses Image Gen config)
 *
 * Each client is configured via POST /api/config from the desktop app.
 */

import OpenAI from "openai";

// Provider configuration (received from desktop app)
interface ProviderConfig {
  modelName: string;
  baseUrl: string;
  apiKey: string;
}

// Internal state — three client slots
let primaryClient: OpenAI | null = null;
let primaryModel: string = "";

let visionClient: OpenAI | null = null;
let visionModel: string = "";

let imageClient: OpenAI | null = null;
let imageModel: string = "";

// ── Configuration ──────────────────────────────────────────

export function configurePrimary(config: ProviderConfig): void {
  primaryClient = new OpenAI({
    apiKey: config.apiKey,
    baseURL: config.baseUrl
  });
  primaryModel = config.modelName;
  console.log(`[AI Client] Primary model configured: ${config.modelName} @ ${config.baseUrl}`);
}

export function configureVision(config: ProviderConfig): void {
  visionClient = new OpenAI({
    apiKey: config.apiKey,
    baseURL: config.baseUrl
  });
  visionModel = config.modelName;
  console.log(`[AI Client] Vision model configured: ${config.modelName} @ ${config.baseUrl}`);
}

export function configureImage(config: ProviderConfig): void {
  imageClient = new OpenAI({
    apiKey: config.apiKey,
    baseURL: config.baseUrl
  });
  imageModel = config.modelName;
  console.log(`[AI Client] Image model configured: ${config.modelName} @ ${config.baseUrl}`);
}

// Status helpers
export function isPrimaryConfigured(): boolean { return primaryClient !== null; }
export function isVisionConfigured(): boolean { return visionClient !== null; }
export function isImageConfigured(): boolean { return imageClient !== null; }

// ── Chat Completion (Primary) ──────────────────────────────

export interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string | Array<{ type: string; text?: string; image_url?: { url: string } }>;
}

export interface ChatOptions {
  maxTokens?: number;
  temperature?: number;
}

// TokenBudget enforcement - LOCKED parameters per SYSTEM_ARCHITECTURE.md §3.Z
const LOCKED_PARAMS = {
  temperature: 0.0,      // Deterministic output
  top_p: 1.0,            // Full probability distribution
  presence_penalty: 0.0, // No repetition penalty
  frequency_penalty: 0.0 // No frequency penalty
};

export async function chatCompletion(
  messages: ChatMessage[],
  options: ChatOptions = {}
): Promise<string> {
  if (!primaryClient) {
    throw new Error("Primary model not configured. Send config via POST /api/config first.");
  }

  // TokenBudget enforcement: Use min of requested tokens or default limit
  const effectiveMaxTokens = Math.min(
    options.maxTokens ?? globalConfig.defaultTokenLimit,
    globalConfig.defaultTokenLimit
  );

  // Explicit TokenBudget → SDK mapping
  const response = await primaryClient.chat.completions.create({
    model: primaryModel,
    messages: messages as any,
    
    // TokenBudget enforcement: explicit max_tokens from AgentExecutionContext
    max_tokens: effectiveMaxTokens,
    
    // Deterministic AI parameters - LOCKED (per §3.Z)
    temperature: LOCKED_PARAMS.temperature,
    top_p: LOCKED_PARAMS.top_p,
    presence_penalty: LOCKED_PARAMS.presence_penalty,
    frequency_penalty: LOCKED_PARAMS.frequency_penalty
  });

  return response.choices[0]?.message?.content || "";
}

// ── Streaming Chat Completion (Primary) ────────────────────

export async function* chatCompletionStream(
  messages: ChatMessage[],
  options: ChatOptions = {}
): AsyncGenerator<string> {
  if (!primaryClient) {
    throw new Error("Primary model not configured. Send config via POST /api/config first.");
  }

  // TokenBudget enforcement: Use min of requested tokens or default limit
  const effectiveMaxTokens = Math.min(
    options.maxTokens ?? globalConfig.defaultTokenLimit,
    globalConfig.defaultTokenLimit
  );

  const stream = await primaryClient.chat.completions.create({
    model: primaryModel,
    messages: messages as any,
    
    // TokenBudget enforcement
    max_tokens: effectiveMaxTokens,
    
    // Deterministic AI parameters - LOCKED (per §3.Z)
    // These are enforced even for streaming - caller cannot override
    temperature: LOCKED_PARAMS.temperature,
    top_p: LOCKED_PARAMS.top_p,
    presence_penalty: LOCKED_PARAMS.presence_penalty,
    frequency_penalty: LOCKED_PARAMS.frequency_penalty,
    
    stream: true
  });

  for await (const chunk of stream) {
    const content = chunk.choices[0]?.delta?.content;
    if (content) {
      yield content;
    }
  }
}

// ── Image Generation (Image Client) ───────────────────────

export interface ImageOptions {
  size?: "1024x1024" | "512x512" | "256x256";
  seed?: number;           // Deterministic seed for reproducible images
  deterministic?: boolean; // When true with seed, ensures reproducible results
}

export async function generateImageFromPrompt(
  prompt: string,
  options: ImageOptions = {}
): Promise<string> {
  if (!imageClient) {
    throw new Error("Image model not configured. Send config via POST /api/config first.");
  }

  // Build image generation request
  const requestParams: any = {
    model: imageModel,
    prompt,
    size: options.size || "1024x1024",
    n: 1,
    response_format: "b64_json"
  };

  // Add seed for deterministic generation (if provider supports it)
  // See BRANDING_INFERENCE_HEURISTICS.md §11 for IntentHash → Seed mechanism
  if (options.seed !== undefined) {
    requestParams.seed = options.seed;
  }

  const response = await imageClient.images.generate(requestParams);

  const b64 = response.data[0]?.b64_json;
  if (!b64) throw new Error("No image data returned");
  return b64;
}

// ── Vision Analysis (Vision Client) ───────────────────────

export async function analyzeImageContent(
  prompt: string,
  imageUrl: string // URL or data URI (data:image/png;base64,...)
): Promise<string> {
  if (!visionClient) {
    throw new Error("Vision model not configured. Send config via POST /api/config first.");
  }

  const response = await visionClient.chat.completions.create({
    model: visionModel,
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: prompt },
          { type: "image_url", image_url: { url: imageUrl } }
        ]
      }
    ],
    max_tokens: 4096
  });

  return response.choices[0]?.message?.content || "";
}

// ── Web Search (Primary Client) ───────────────────────────

export async function searchWeb(
  query: string
): Promise<string> {
  // Web search is implemented as a chat completion with search-like prompt
  // User's primary model handles this via its own capabilities
  if (!primaryClient) {
    throw new Error("Primary model not configured. Send config via POST /api/config first.");
  }

  const response = await primaryClient.chat.completions.create({
    model: primaryModel,
    messages: [
      {
        role: "system",
        content: "You are a search assistant. Provide accurate, factual information about the user's query. Include relevant technical details, code examples, and documentation references when applicable."
      },
      { role: "user", content: query }
    ],
    max_tokens: 2048
  });

  return response.choices[0]?.message?.content || "";
}
```

---

## 4. API Endpoints

### 4.1 Configuration Endpoint (routes/config.ts)

```typescript
/**
 * Configuration Endpoint
 *
 * Receives AI provider settings from the Sync AI Desktop app.
 * Called on startup and whenever user changes Settings > AI Settings.
 */

import {
  configurePrimary,
  configureVision,
  configureImage,
  isPrimaryConfigured,
  isVisionConfigured,
  isImageConfigured
} from "../services/ai-client";

interface ConfigRequest {
  primary?: {
    modelName: string;
    baseUrl: string;
    apiKey: string;
  };
  vision?: {
    modelName: string;
    baseUrl: string;
    apiKey: string;
  };
  imageGen?: {
    modelName: string;
    baseUrl: string;
    apiKey: string;
  };
}

export async function handleConfig(request: Request): Promise<Response> {
  try {
    const body: ConfigRequest = await request.json();

    // Configure each slot if provided
    if (body.primary?.modelName && body.primary?.baseUrl && body.primary?.apiKey) {
      configurePrimary(body.primary);
    }

    if (body.vision?.modelName && body.vision?.baseUrl && body.vision?.apiKey) {
      configureVision(body.vision);
    }

    if (body.imageGen?.modelName && body.imageGen?.baseUrl && body.imageGen?.apiKey) {
      configureImage(body.imageGen);
    }

    return jsonResponse({
      success: true,
      configured: {
        primary: isPrimaryConfigured(),
        vision: isVisionConfigured(),
        imageGen: isImageConfigured()
      }
    });
  } catch (error) {
    console.error("[Config] Error:", error);
    return errorResponse(
      "CONFIG_ERROR",
      error instanceof Error ? error.message : "Configuration failed",
      500
    );
  }
}

// Helper functions
function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}

function errorResponse(code: string, message: string, status = 400): Response {
  return jsonResponse(
    { success: false, error: { code, message, retryable: status >= 500 } },
    status
  );
}
```

### 4.2 Chat Endpoint (routes/chat.ts)

```typescript
/**
 * LLM Chat Completion Endpoints (uses primaryClient)
 */

import { chatCompletion, chatCompletionStream, ChatMessage } from "../services/ai-client";

interface ChatRequest {
  messages: ChatMessage[];
  maxTokens?: number;
  temperature?: number;
}

// Non-streaming chat
export async function handleChat(request: Request): Promise<Response> {
  try {
    const body: ChatRequest = await request.json();

    if (!body.messages || !Array.isArray(body.messages)) {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'messages' array");
    }

    const content = await chatCompletion(body.messages, {
      maxTokens: body.maxTokens,
      temperature: body.temperature
    });

    return jsonResponse({
      success: true,
      content,
      usage: { totalTokens: Math.floor(content.length / 4) } // Rough estimate
    });
  } catch (error) {
    console.error("[Chat] Error:", error);
    return errorResponse("CHAT_ERROR", error instanceof Error ? error.message : "Chat failed", 500);
  }
}

// Streaming chat
export async function handleChatStream(request: Request): Promise<Response> {
  try {
    const body: ChatRequest = await request.json();

    if (!body.messages || !Array.isArray(body.messages)) {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'messages' array");
    }

    const stream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder();

        try {
          for await (const chunk of chatCompletionStream(body.messages, {
            maxTokens: body.maxTokens,
            temperature: body.temperature
          })) {
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({ content: chunk })}\n\n`));
          }
          controller.enqueue(encoder.encode("data: [DONE]\n\n"));
          controller.close();
        } catch (error) {
          controller.error(error);
        }
      }
    });

    return new Response(stream, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive"
      }
    });
  } catch (error) {
    console.error("[Chat Stream] Error:", error);
    return errorResponse("STREAM_ERROR", error instanceof Error ? error.message : "Stream failed", 500);
  }
}

// Helper functions
function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}

function errorResponse(code: string, message: string, status = 400): Response {
  return jsonResponse(
    { success: false, error: { code, message, retryable: status >= 500 } },
    status
  );
}
```

### 4.3 Image Generation (routes/image.ts)

```typescript
/**
 * Image Generation Endpoint (uses imageClient)
 *
 * Supports deterministic image generation via seed parameter.
 * See BRANDING_INFERENCE_HEURISTICS.md §11 for IntentHash → Seed mechanism.
 */

import { generateImageFromPrompt } from "../services/ai-client";

interface ImageRequest {
  prompt: string;
  size?: "1024x1024" | "512x512" | "256x256";
  seed?: number;           // Optional: Deterministic seed for reproducible images
  deterministic?: boolean; // Optional: When true with seed, ensures reproducible results
}

export async function handleGenerateImage(request: Request): Promise<Response> {
  try {
    const body: ImageRequest = await request.json();

    if (!body.prompt || typeof body.prompt !== "string") {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'prompt' string");
    }

    const b64Image = await generateImageFromPrompt(body.prompt, {
      size: body.size,
      seed: body.seed,
      deterministic: body.deterministic
    });

    return jsonResponse({
      success: true,
      imageBase64: b64Image
    });
  } catch (error) {
    console.error("[Image] Error:", error);
    return errorResponse("IMAGE_ERROR", error instanceof Error ? error.message : "Image generation failed", 500);
  }
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}

function errorResponse(code: string, message: string, status = 400): Response {
  return jsonResponse({ success: false, error: { code, message } }, status);
}
```

### 4.4 Vision Analysis (routes/vision.ts)

```typescript
/**
 * Vision Analysis Endpoint (uses visionClient)
 */

import { analyzeImageContent } from "../services/ai-client";

interface VisionRequest {
  prompt: string;
  imageUrl: string; // URL or data URI (data:image/png;base64,...)
}

export async function handleVision(request: Request): Promise<Response> {
  try {
    const body: VisionRequest = await request.json();

    if (!body.prompt || typeof body.prompt !== "string") {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'prompt' string");
    }

    if (!body.imageUrl || typeof body.imageUrl !== "string") {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'imageUrl' string");
    }

    const content = await analyzeImageContent(body.prompt, body.imageUrl);

    return jsonResponse({
      success: true,
      content
    });
  } catch (error) {
    console.error("[Vision] Error:", error);
    return errorResponse("VISION_ERROR", error instanceof Error ? error.message : "Vision analysis failed", 500);
  }
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}

function errorResponse(code: string, message: string, status = 400): Response {
  return jsonResponse({ success: false, error: { code, message } }, status);
}
```

### 4.5 Web Search (routes/search.ts)

```typescript
/**
 * Web Search Endpoint (uses primaryClient)
 */

import { searchWeb } from "../services/ai-client";

interface SearchRequest {
  query: string;
}

export async function handleSearch(request: Request): Promise<Response> {
  try {
    const body: SearchRequest = await request.json();

    if (!body.query || typeof body.query !== "string") {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'query' string");
    }

    const content = await searchWeb(body.query);

    return jsonResponse({
      success: true,
      content
    });
  } catch (error) {
    console.error("[Search] Error:", error);
    return errorResponse("SEARCH_ERROR", error instanceof Error ? error.message : "Search failed", 500);
  }
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}

function errorResponse(code: string, message: string, status = 400): Response {
  return jsonResponse({ success: false, error: { code, message } }, status);
}
```

---

## 5. Error Handling

### 5.0 Health Contract & Failure Thresholds

> **The Mini-Service health is formally defined to enable deterministic failure modeling.**

#### Health States

| State | Meaning | Orchestrator Action |
|-------|---------|-------------------|
| `healthy` | All model slots configured and validated | Continue normal operation |
| `degraded` | One or more slots failed, but service responds | Retry with exponential backoff |
| `unhealthy` | Service not responding or crashed | Restart mini-service |

#### Health Check Response

```json
{
  "success": true,
  "status": "healthy",
  "version": "1.0.0",
  "protocol": "sync-ai-ai-bridge-v1",
  "uptime": 123.45,
  "timestamp": "2026-02-23T00:00:00.000Z",
  "configured": {
    "primary": true,
    "vision": true,
    "imageGen": false,
    "validated": true
  },
  "health": {
    "primary": "ok",
    "vision": "ok",
    "imageGen": "not_configured"
  }
}
```

#### Timeout Thresholds

| Operation | Timeout | Failure Action |
|-----------|---------|---------------|
| Health check | 5s | Mark unhealthy, restart |
| Chat (simple) | 30s | Return error, allow retry |
| Chat (complex) | 60s | Return error, allow retry |
| Image generation | 120s | Return error, allow retry |
| Vision analysis | 30s | Return error, allow retry |

#### Rate Limit Handling (429 Response)

| Scenario | Action |
|----------|--------|
| 429 received | Exponential backoff (2s, 4s, 8s, max 30s) |
| 3 consecutive 429s | Transition to DEGRADED state |
| 10 consecutive 429s | Transition to UNHEALTHY, restart service |

#### Retry Backoff Strategy

```typescript
function calculateBackoff(attempt: number): number {
  // Exponential backoff: 2s, 4s, 8s, 16s, 30s (cap)
  return Math.min(2 * Math.pow(2, attempt), 30000);
}
```

### 5.1 Error Types (utils/errors.ts)

```typescript
/**
 * Error definitions for AI Mini Service
 */

export enum ErrorCode {
  // Client errors (4xx)
  INVALID_REQUEST = "INVALID_REQUEST",
  METHOD_NOT_ALLOWED = "METHOD_NOT_ALLOWED",
  NOT_FOUND = "NOT_FOUND",
  NOT_CONFIGURED = "NOT_CONFIGURED",
  AI_CONFIG_NOT_VALIDATED = "AI_CONFIG_NOT_VALIDATED",
  TOKEN_LIMIT_EXCEEDED = "TOKEN_LIMIT_EXCEEDED",

  // Server errors (5xx)
  INTERNAL_ERROR = "INTERNAL_ERROR",
  SERVER_ERROR = "SERVER_ERROR",

  // AI-specific errors
  CHAT_ERROR = "CHAT_ERROR",
  STREAM_ERROR = "STREAM_ERROR",
  IMAGE_ERROR = "IMAGE_ERROR",
  VISION_ERROR = "VISION_ERROR",
  SEARCH_ERROR = "SEARCH_ERROR",
  CONFIG_ERROR = "CONFIG_ERROR"
}

export class AIServiceError extends Error {
  constructor(
    public code: ErrorCode,
    message: string,
    public retryable: boolean = false
  ) {
    super(message);
    this.name = "AIServiceError";
  }
}
```

### 5.2 Global Config State

```typescript
// Global configuration state
interface GlobalConfig {
  primaryClient: OpenAI | null;
  primaryModel: string;
  visionClient: OpenAI | null;
  visionModel: string;
  imageClient: OpenAI | null;
  imageModel: string;
  defaultTokenLimit: number;
  validated: boolean;
}

let globalConfig: GlobalConfig = {
  primaryClient: null,
  primaryModel: "",
  visionClient: null,
  visionModel: "",
  imageClient: null,
  imageModel: "",
  defaultTokenLimit: 8000,
  validated: false
};

// ENFORCEMENT: Reject requests if config not validated
function requireValidatedConfig() {
  if (!globalConfig.validated) {
    throw new Error("AI_CONFIG_NOT_VALIDATED");
  }
}
```

### 5.2 Logger (utils/logger.ts)

```typescript
/**
 * Simple logger for AI Mini Service
 *
 * IMPORTANT: Never log API keys or other sensitive data.
 */

const LOG_LEVELS = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3
} as const;

const LOG_LEVEL = LOG_LEVELS[process.env.LOG_LEVEL as keyof typeof LOG_LEVELS] ?? LOG_LEVELS.INFO;

function formatTimestamp(): string {
  return new Date().toISOString();
}

export const logger = {
  debug(message: string, ...args: unknown[]) {
    if (LOG_LEVEL <= LOG_LEVELS.DEBUG) {
      console.debug(`[${formatTimestamp()}] [DEBUG] ${message}`, ...args);
    }
  },

  info(message: string, ...args: unknown[]) {
    if (LOG_LEVEL <= LOG_LEVELS.INFO) {
      console.log(`[${formatTimestamp()}] [INFO] ${message}`, ...args);
    }
  },

  warn(message: string, ...args: unknown[]) {
    if (LOG_LEVEL <= LOG_LEVELS.WARN) {
      console.warn(`[${formatTimestamp()}] [WARN] ${message}`, ...args);
    }
  },

  error(message: string, ...args: unknown[]) {
    if (LOG_LEVEL <= LOG_LEVELS.ERROR) {
      console.error(`[${formatTimestamp()}] [ERROR] ${message}`, ...args);
    }
  }
};
```

---

## 6. Build & Deployment

### 6.1 Development

```bash
# Install dependencies
bun install

# Run in development mode (with auto-reload on file changes)
bun run dev
```

**Note**: This is Bun's development mode with file watching, NOT the builder's Hot Reload feature. Hot Reload / Edit and Continue for generated WinUI 3 apps is a **future enhancement** (see [PREVIEW_SYSTEM.md](./PREVIEW_SYSTEM.md) §11 - Future Enhancements).

### 6.2 Production Build

```bash
# Compile to standalone executable
bun run build

# Output: ai-service.exe
```

### 6.3 Build Output

The `ai-service.exe` is a **self-contained executable** that:
- Requires NO Node.js/Bun installation
- Can be embedded directly in MSIX package
- Runs completely hidden (no console window)
- Starts automatically by Sync AI Desktop

### 6.4 Integration with Sync AI Desktop

Place the compiled executable in:
```
SyncAI.Desktop/
└── Assets/
    └── ai-service.exe   ← Embedded in MSIX package
```

---

## 7. Testing

### 7.1 Health Check

```bash
curl http://localhost:3001/health
```

Expected response:
```json
{
  "success": true,
  "status": "healthy",
  "version": "1.0.0",
  "uptime": 12.345,
  "timestamp": "2026-02-23T00:00:00.000Z",
  "configured": {
    "primary": false,
    "vision": false,
    "imageGen": false
  }
}
```

### 7.2 Configure AI Providers

```bash
curl -X POST http://localhost:3001/api/config \
  -H "Content-Type: application/json" \
  -d '{
    "primary": {
      "modelName": "openai/gpt-4o",
      "baseUrl": "https://openrouter.ai/api/v1",
      "apiKey": "sk-or-..."
    },
    "vision": {
      "modelName": "openai/gpt-4o",
      "baseUrl": "https://openrouter.ai/api/v1",
      "apiKey": "sk-or-..."
    },
    "imageGen": {
      "modelName": "dall-e-3",
      "baseUrl": "https://api.openai.com/v1",
      "apiKey": "sk-..."
    }
  }'
```

### 7.3 Chat Completion

```bash
curl -X POST http://localhost:3001/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      { "role": "system", "content": "You are a helpful code assistant." },
      { "role": "user", "content": "Write a C# Hello World program" }
    ]
  }'
```

### 7.4 Image Generation

```bash
curl -X POST http://localhost:3001/api/generate-image \
  -H "Content-Type: application/json" \
  -d '{ "prompt": "A modern Windows app icon with gradient" }'
```

### 7.5 Vision Analysis

```bash
curl -X POST http://localhost:3001/api/vision \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Describe this UI screenshot",
    "imageUrl": "data:image/png;base64,iVBOR..."
  }'
```

---

## References

- [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — Architecture and API contract
- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — Layer 6.6 definition
- [openai npm SDK](https://www.npmjs.com/package/openai) — Official OpenAI Node.js client

---

## Document Status

- **Status:** 🔴 CRITICAL - Implementation Required
- **Complexity:** Medium (TypeScript/Bun service)
- **Risk:** HIGH if missing (no AI capabilities)
- **Maintainer:** AI Team

---

## Change Log

| Date | Change |
|------|--------|
| 2026-03-03 | **Clarified Hot Reload distinction** - Bun dev mode has file watching, but WinUI 3 Hot Reload / Edit and Continue is a future enhancement (not yet implemented) |
| 2026-02-23 | **BREAKING: Complete rewrite** — replaced z-ai-web-dev-sdk with openai SDK |
| 2026-02-23 | **Added /api/config endpoint** — receives AI settings from desktop app |
| 2026-02-23 | **Triple-client pattern** — primaryClient, visionClient, imageClient |
| 2026-02-23 | **Removed TTS/ASR endpoints** — no longer supported |
| 2026-02-22 | Initial implementation specification |
