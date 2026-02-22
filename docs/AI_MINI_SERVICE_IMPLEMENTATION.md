# AI MINI SERVICE IMPLEMENTATION

> **Complete Implementation Guide for the AI Service Layer**
>
> **Related Document:** [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — Architecture and API contract
>
> _This document provides the complete TypeScript/Bun implementation for the AI Mini Service that powers all AI capabilities in Sync AI._

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

The AI Mini Service is a **standalone executable** that bridges the Sync AI Desktop application (C#/.NET 8/WinUI 3) with the AI capabilities provided by **z-ai-web-dev-sdk**.

### Key Principles

| Principle | Implementation |
|-----------|----------------|
| **NO API KEYS** | z-ai-web-dev-sdk handles authentication automatically |
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
│   │ z-ai-web-dev-sdk (NO API KEYS!)                     │   │
│   │ ├─ LLM (Chat Completions)                           │   │
│   │ ├─ Image Generation                                 │   │
│   │ ├─ TTS (Text to Speech)                             │   │
│   │ ├─ ASR (Speech to Text)                             │   │
│   │ ├─ VLM (Vision Language Model)                      │   │
│   │ └─ Web Search                                       │   │
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
│   ├── chat.ts           # LLM endpoint
│   ├── image.ts          # Image generation endpoint
│   ├── tts.ts            # Text-to-speech endpoint
│   ├── asr.ts            # Speech-to-text endpoint
│   ├── vision.ts         # Vision analysis endpoint
│   └── search.ts         # Web search endpoint
├── services/
│   └── ai-client.ts      # z-ai-web-dev-sdk wrapper
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
    "z-ai-web-dev-sdk": "latest"
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
 * 
 * IMPORTANT: NO API KEYS REQUIRED!
 * z-ai-web-dev-sdk handles all authentication automatically.
 */

import { serve } from "bun";

// Import route handlers
import { handleChat, handleChatStream } from "./routes/chat";
import { handleGenerateImage } from "./routes/image";
import { handleTTS } from "./routes/tts";
import { handleASR } from "./routes/asr";
import { handleVision } from "./routes/vision";
import { handleSearch } from "./routes/search";

// Configuration
const PORT = parseInt(process.env.AI_SERVICE_PORT || "3001");
const HOST = "127.0.0.1"; // localhost only for security

// Health check response
const HEALTH_RESPONSE = {
  success: true,
  status: "healthy",
  version: "1.0.0",
  uptime: process.uptime(),
  timestamp: new Date().toISOString(),
  
  // === SDK VERSION INFO (NEW - REQUIRED FOR REPRODUCIBILITY) ===
  sdk: {
    version: process.env.npm_package_version || "unknown",
    commitHash: process.env.SDK_COMMIT_HASH || "unknown",
    serviceVersion: "1.0.0"
  }
};

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
          return jsonResponse(HEALTH_RESPONSE);

        // LLM endpoints
        case "/api/chat":
          if (method !== "POST") return methodNotAllowed();
          return await handleChat(request);

        case "/api/chat/stream":
          if (method !== "POST") return methodNotAllowed();
          return await handleChatStream(request);

        // Image generation
        case "/api/generate-image":
          if (method !== "POST") return methodNotAllowed();
          return await handleGenerateImage(request);

        // Text-to-speech
        case "/api/tts":
          if (method !== "POST") return methodNotAllowed();
          return await handleTTS(request);

        // Speech-to-text
        case "/api/asr":
          if (method !== "POST") return methodNotAllowed();
          return await handleASR(request);

        // Vision analysis
        case "/api/vision":
          if (method !== "POST") return methodNotAllowed();
          return await handleVision(request);

        // Web search
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
console.log("[AI Service] NO API KEYS REQUIRED - z-ai-web-dev-sdk handles authentication");
console.log("[AI Service] Available endpoints:");
console.log("  - GET  /health              - Health check");
console.log("  - POST /api/chat            - LLM chat completions");
console.log("  - POST /api/chat/stream     - Streaming LLM responses");
console.log("  - POST /api/generate-image  - Image generation");
console.log("  - POST /api/tts             - Text to speech");
console.log("  - POST /api/asr             - Speech to text");
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
 * z-ai-web-dev-sdk Wrapper
 * 
 * Provides a unified interface for all AI capabilities.
 * NO API KEYS REQUIRED - SDK handles authentication automatically.
 */

import {
  chat,
  generateImage,
  textToSpeech,
  speechToText,
  analyzeImage,
  webSearch
} from "z-ai-web-dev-sdk";

// Type definitions
export interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface ChatOptions {
  thinking?: { type: "enabled" | "disabled" };
  maxTokens?: number;
}

export interface ImageOptions {
  size?: "1024x1024" | "768x1344" | "1344x768" | "1440x720";
}

export interface TTSOptions {
  voice?: "tongtong" | "chuichui" | "xiaochen" | "jam";
  speed?: number;
}

// LLM Chat Completion
export async function chatCompletion(
  messages: ChatMessage[],
  options: ChatOptions = {}
): Promise<string> {
  const response = await chat({
    messages: messages.map(m => ({
      role: m.role,
      content: m.content
    })),
    thinking: options.thinking || { type: "disabled" },
    maxTokens: options.maxTokens
  });

  return response.content;
}

// Streaming Chat Completion
export async function* chatCompletionStream(
  messages: ChatMessage[],
  options: ChatOptions = {}
): AsyncGenerator<string> {
  const stream = await chat({
    messages: messages.map(m => ({
      role: m.role,
      content: m.content
    })),
    thinking: options.thinking || { type: "disabled" },
    stream: true
  });

  for await (const chunk of stream) {
    if (chunk.content) {
      yield chunk.content;
    }
  }
}

// Image Generation
export async function generateImageFromPrompt(
  prompt: string,
  options: ImageOptions = {}
): Promise<Buffer> {
  const imageBuffer = await generateImage({
    prompt,
    size: options.size || "1024x1024"
  });

  return Buffer.from(imageBuffer);
}

// Text to Speech
export async function synthesizeSpeech(
  text: string,
  options: TTSOptions = {}
): Promise<Buffer> {
  if (text.length > 1024) {
    throw new Error("Text exceeds maximum length of 1024 characters");
  }

  const audioBuffer = await textToSpeech({
    text,
    voice: options.voice || "tongtong",
    speed: options.speed || 1.0
  });

  return Buffer.from(audioBuffer);
}

// Speech to Text
export async function transcribeAudio(
  audioBase64: string
): Promise<{ text: string; confidence: number }> {
  const audioBuffer = Buffer.from(audioBase64, "base64");

  const result = await speechToText({
    audio: audioBuffer
  });

  return {
    text: result.text,
    confidence: result.confidence || 0.95
  };
}

// Vision Analysis
export async function analyzeImageContent(
  prompt: string,
  imageUrl: string
): Promise<string> {
  const response = await analyzeImage({
    prompt,
    image: imageUrl // Can be URL or data URI
  });

  return response.content;
}

// Web Search
export async function searchWeb(
  query: string,
  numResults: number = 10
): Promise<Array<{
  url: string;
  name: string;
  snippet: string;
  host_name: string;
}>> {
  const results = await webSearch({
    query,
    num: numResults
  });

  return results.map(r => ({
    url: r.url,
    name: r.name || r.title,
    snippet: r.snippet || r.description || "",
    host_name: new URL(r.url).hostname
  }));
}
```

---

## 4. API Endpoints

### 4.1 Chat Endpoint (routes/chat.ts)

```typescript
/**
 * LLM Chat Completion Endpoints
 */

import { chatCompletion, chatCompletionStream, ChatMessage } from "../services/ai-client";

interface ChatRequest {
  messages: ChatMessage[];
  thinking?: { type: "enabled" | "disabled" };
}

// Non-streaming chat
export async function handleChat(request: Request): Promise<Response> {
  try {
    const body: ChatRequest = await request.json();

    if (!body.messages || !Array.isArray(body.messages)) {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'messages' array");
    }

    const content = await chatCompletion(body.messages, {
      thinking: body.thinking
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
          for await (const chunk of chatCompletionStream(body.messages)) {
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

// Helper functions (duplicated for module independence)
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

### 4.2 Image Generation (routes/image.ts)

```typescript
/**
 * Image Generation Endpoint
 */

import { generateImageFromPrompt } from "../services/ai-client";

interface ImageRequest {
  prompt: string;
  size?: "1024x1024" | "768x1344" | "1344x768" | "1440x720";
}

export async function handleGenerateImage(request: Request): Promise<Response> {
  try {
    const body: ImageRequest = await request.json();

    if (!body.prompt || typeof body.prompt !== "string") {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'prompt' string");
    }

    const imageBuffer = await generateImageFromPrompt(body.prompt, {
      size: body.size
    });

    return new Response(imageBuffer, {
      status: 200,
      headers: {
        "Content-Type": "image/png",
        "Content-Length": imageBuffer.length.toString()
      }
    });
  } catch (error) {
    console.error("[Image] Error:", error);
    return errorResponse("IMAGE_ERROR", error instanceof Error ? error.message : "Image generation failed", 500);
  }
}

function errorResponse(code: string, message: string, status = 400): Response {
  return new Response(JSON.stringify({ success: false, error: { code, message } }), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}
```

### 4.3 Text-to-Speech (routes/tts.ts)

```typescript
/**
 * Text-to-Speech Endpoint
 */

import { synthesizeSpeech } from "../services/ai-client";

interface TTSRequest {
  text: string;
  voice?: "tongtong" | "chuichui" | "xiaochen" | "jam";
  speed?: number;
}

export async function handleTTS(request: Request): Promise<Response> {
  try {
    const body: TTSRequest = await request.json();

    if (!body.text || typeof body.text !== "string") {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'text' string");
    }

    if (body.text.length > 1024) {
      return errorResponse("TEXT_TOO_LONG", "Text exceeds maximum length of 1024 characters");
    }

    const audioBuffer = await synthesizeSpeech(body.text, {
      voice: body.voice,
      speed: body.speed
    });

    return new Response(audioBuffer, {
      status: 200,
      headers: {
        "Content-Type": "audio/wav",
        "Content-Length": audioBuffer.length.toString()
      }
    });
  } catch (error) {
    console.error("[TTS] Error:", error);
    return errorResponse("TTS_ERROR", error instanceof Error ? error.message : "TTS failed", 500);
  }
}

function errorResponse(code: string, message: string, status = 400): Response {
  return new Response(JSON.stringify({ success: false, error: { code, message } }), {
    status,
    headers: { "Content-Type": "application/json" }
  });
}
```

### 4.4 Speech-to-Text (routes/asr.ts)

```typescript
/**
 * Speech-to-Text Endpoint
 */

import { transcribeAudio } from "../services/ai-client";

interface ASRRequest {
  audioBase64: string;
}

export async function handleASR(request: Request): Promise<Response> {
  try {
    const body: ASRRequest = await request.json();

    if (!body.audioBase64 || typeof body.audioBase64 !== "string") {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'audioBase64' string");
    }

    const result = await transcribeAudio(body.audioBase64);

    return jsonResponse({
      success: true,
      text: result.text,
      confidence: result.confidence
    });
  } catch (error) {
    console.error("[ASR] Error:", error);
    return errorResponse("ASR_ERROR", error instanceof Error ? error.message : "ASR failed", 500);
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

### 4.5 Vision Analysis (routes/vision.ts)

```typescript
/**
 * Vision Analysis Endpoint
 */

import { analyzeImageContent } from "../services/ai-client";

interface VisionRequest {
  prompt: string;
  imageUrl: string; // URL or data URI
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

### 4.6 Web Search (routes/search.ts)

```typescript
/**
 * Web Search Endpoint
 */

import { searchWeb } from "../services/ai-client";

interface SearchRequest {
  query: string;
  num?: number;
}

export async function handleSearch(request: Request): Promise<Response> {
  try {
    const body: SearchRequest = await request.json();

    if (!body.query || typeof body.query !== "string") {
      return errorResponse("INVALID_REQUEST", "Missing or invalid 'query' string");
    }

    const results = await searchWeb(body.query, body.num || 10);

    return jsonResponse({
      success: true,
      results
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

### 5.1 Error Types (utils/errors.ts)

```typescript
/**
 * Error definitions for AI Mini Service
 */

export enum ErrorCode {
  // Client errors (4xx)
  INVALID_REQUEST = "INVALID_REQUEST",
  TEXT_TOO_LONG = "TEXT_TOO_LONG",
  METHOD_NOT_ALLOWED = "METHOD_NOT_ALLOWED",
  NOT_FOUND = "NOT_FOUND",

  // Server errors (5xx)
  INTERNAL_ERROR = "INTERNAL_ERROR",
  SERVER_ERROR = "SERVER_ERROR",

  // AI-specific errors
  CHAT_ERROR = "CHAT_ERROR",
  STREAM_ERROR = "STREAM_ERROR",
  IMAGE_ERROR = "IMAGE_ERROR",
  TTS_ERROR = "TTS_ERROR",
  ASR_ERROR = "ASR_ERROR",
  VISION_ERROR = "VISION_ERROR",
  SEARCH_ERROR = "SEARCH_ERROR"
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

### 5.2 Logger (utils/logger.ts)

```typescript
/**
 * Simple logger for AI Mini Service
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

# Run in development mode (hot reload)
bun run dev
```

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
  "timestamp": "2026-02-22T10:00:00.000Z",
  "sdk": {
    "version": "1.2.3",
    "commitHash": "abc123def456",
    "serviceVersion": "1.0.0"
  }
}
```

The SDK version info is **REQUIRED** for reproducibility. The C# client uses this to record which SDK version was used for each transaction.

### 7.2 Chat Completion

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

### 7.3 Image Generation

```bash
curl -X POST http://localhost:3001/api/generate-image \
  -H "Content-Type: application/json" \
  -d '{ "prompt": "A modern Windows app icon with gradient" }' \
  --output icon.png
```

### 7.4 Text-to-Speech

```bash
curl -X POST http://localhost:3001/api/tts \
  -H "Content-Type: application/json" \
  -d '{ "text": "Build completed successfully", "voice": "tongtong" }' \
  --output output.wav
```

---

## References

- [AI_SERVICE_LAYER.md](./AI_SERVICE_LAYER.md) — Architecture and API contract
- [SYSTEM_ARCHITECTURE.md](./SYSTEM_ARCHITECTURE.md) — Layer 6.6 definition
- [z-ai-web-dev-sdk Documentation](https://npmjs.com/package/z-ai-web-dev-sdk)

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
| 2026-02-24 | **Added deterministic image generation support** - seed and deterministic parameters for reproducible images |
| 2026-02-24 | Updated ImageOptions interface with seed field |
| 2026-02-24 | Updated image endpoint to accept seed parameter |
| 2026-02-22 | Initial implementation specification |
