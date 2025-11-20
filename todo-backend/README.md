# Todo Backend API

A task management backend service built with Node.js and TypeScript, featuring LLM (Large Language Model) integration for parsing natural language commands.

## Core Features

- **NLP Parsing**: `/nl/command` accepts natural language text and parses it into structured JSON.
- **Task Management**: Standard CRUD operations (Create, Read, Update, Delete).
- **SQLite**: Lightweight local database storage.

## Development Guide

### Install Dependencies
```bash
npm install
```

### Start Development Server
```bash
npm run dev
```

### Environment Variables
Create a `.env` file in the root directory:
```
PORT=3000
OPENAI_API_KEY=sk-...
```
