# TrainPlannerAI (Project doAI)

An intelligent task management application powered by Natural Language Processing (NLP), designed to simplify daily task planning through conversational interaction.

The project consists of two parts:
1. **iOS Client (`TrainPlanner/`)**: A native mobile app built with SwiftUI, featuring card-based interaction, gestures, and iCloud synchronization.
2. **Backend Server (`todo-backend/`)**: A Node.js/Express backend service that provides AI command parsing capabilities (currently standalone and not yet fully integrated with the iOS client).

## 📱 iOS Client Features

- **Natural Language Interaction**: Simply type "Remind me to pay the electricity bill tomorrow morning at 9", and the AI automatically parses the time, priority, and tags.
- **Card UI**: Elegant daily view cards with smooth left/right swipe gestures to switch dates.
- **Local-First**: Data is stored locally (UserDefaults) with support for iCloud Key-Value synchronization.
- **Smart Parsing**: Built-in `AIService` directly integrates OpenAI Function Calling.

## 🛠 Backend Features

- **Tech Stack**: Node.js, Express, TypeScript, Better-SQLite3.
- **AI Agent**: Encapsulates OpenAI interfaces to parse natural language commands into database operations (CRUD).
- **REST API**: Provides the `/nl/command` endpoint to handle natural language instructions.

## 🚀 Getting Started

### 1. iOS App
1. Open `TrainPlanner.xcodeproj`.
2. Ensure you have an OpenAI API Key.
3. Configure the API Key in the App settings or directly in the code (refer to the `AIConfig` class).
4. Run on a Simulator or a physical device.

### 2. Backend Server
```bash
cd todo-backend
npm install
# Configure .env file (refer to .env.example or process.env usage in code)
npm run dev
```

## 🔮 Future Roadmap

- **Architecture Unification**: Currently, the iOS client requests OpenAI directly, leaving the backend service idle. It is recommended to proxy AI requests from the iOS client through the backend to hide the API Key and centralize business logic.
- **Data Synchronization**: Upgrade the iOS iCloud sync to a full database synchronization with the backend for true cross-platform support.
