# OpenAI API Configuration for Ollama

This setup uses the OpenAI API compatibility layer provided by Ollama to interface with local LLM models.

## Why OpenAI API?

Many tools and applications are built to work with the OpenAI API format. Ollama provides an OpenAI-compatible API endpoint, allowing these tools to work with locally-hosted models without modification.

## Required Environment Variables

Set these as **User Environment Variables** in Windows:

```
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_API_KEY=ollama
OPENAI_MODEL=qwen2.5-coder:32b-5090
```

### Setting Environment Variables

1. Press `Win + X` and select "System"
2. Click "Advanced system settings"
3. Click "Environment Variables"
4. Under "User variables", click "New"
5. Add each variable name and value

## Model Configuration

The configured model for this RTX-powered machine is:
- **Model:** `qwen2.5-coder:32b-5090`

This model is optimized for this system's RTX GPU capabilities.

## Verifying Setup

After setting the variables, restart any terminals or applications, then verify Ollama is running:

```powershell
ollama list
```

## API Endpoint

The OpenAI-compatible endpoint is available at:
- **Base URL:** `http://localhost:11434/v1`
- **Chat Completions:** `http://localhost:11434/v1/chat/completions`
- **Models:** `http://localhost:11434/v1/models`
