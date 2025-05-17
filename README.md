<div align="center">
  <img src="assets/images/logo.svg" alt="Netrai Logo" width="180"/>
  <p><em>Empowering the visually impaired with real-time AI and caregiver assistance</em></p>
  <p>
    <a href="https://github.com/0xSyam/Netrai/actions"><img src="https://img.shields.io/github/actions/workflow/status/0xSyam/Netrai/ci.yml?branch=main&label=CI&logo=github" alt="CI Status"></a>
    <a href="https://github.com/0xSyam/Netrai/blob/main/LICENSE"><img src="https://img.shields.io/github/license/0xSyam/Netrai?color=blue" alt="License"></a>
  </p>
</div>

## 📱 Overview

Netrai is a cross-platform mobile application designed to assist visually impaired users in daily life with the help of AI and caregiver support. It combines real-time location tracking, WebRTC video streaming, and large language models for intelligent assistance.

Netrai serves two main user roles:

- **Visually Impaired Users** – receive help via AI and real-time communication
- **Caregivers (Supporters)** – monitor, navigate, and assist their loved ones remotely

---

## ✨ Key Features

- 🧭 **Role Selection:** Choose between "I Need Visual Assistance" or "I'm Supporting a Loved One"
- 🔐 **Authentication:** Google Sign-In via Firebase Authentication
- 🗺️ **Caregiver Dashboard:**
  - Real-time location tracking of visually impaired users
  - Navigation support using Google Maps Direction API
  - Location sync via Firebase Realtime Database
- 👁️‍🗨️ **Visually Impaired Dashboard:**
  - Live video streaming using LiveKit (WebRTC)
  - AI-powered voice and vision interaction using Gemini API
  - Backend Python agent for AI processing

---

## 🛠️ Tech Stack

**Frontend**

- Flutter (cross-platform app framework)
- Firebase Authentication (user login)
- Firebase Realtime Database (location updates)
- Google Maps API & Direction API (navigation & maps)
- LiveKit (WebRTC for video communication)
- Gemini API (Google's LLM for voice & video analysis)

**Backend**

- Python (custom agent for AI processing)
- LiveKit Server SDK
- Google Gemini API

---

## 📂 Repository Structure

```
Netrai/
├── assets/               # Project assets and images
├── android/              # Android-specific configuration
├── ios/                  # iOS-specific configuration
├── lib/                  # Flutter application code
│   ├── screens/          # UI screens
│   ├── services/         # Business logic and services
│   ├── utils/            # Utility functions
│   ├── widgets/          # Reusable UI components
│   └── main.dart         # Application entry point
├── web/                  # Web platform files
├── macos/                # macOS-specific configuration
├── test/                 # Test directory
├── Backend/                # Backend code (Python AI agent)
│   ├── main.py           # Backend entry point
│   ├── handlers/         # Gemini & LiveKit logic
│   ├── .env              # Env variables (not committed)
│   └── requirements.txt  # Python dependencies
├── firebase.json         # Firebase configuration
├── pubspec.yaml          # Flutter dependencies
└── README.md             # Project documentation
```

---

## 🚀 Getting Started

### Frontend

1. **Clone the repository:**

   ```bash
   git clone https://github.com/0xSyam/Netrai.git
   cd netrai
   ```

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Set up Firebase:**

   - Enable Google Sign-In in Firebase Auth
   - Configure `firebase.json` with your project settings
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to your project

4. **Run the app:**
   ```bash
   flutter run
   ```

#### Map Permissions

- Ensure location permissions are set in your `AndroidManifest.xml` and `Info.plist` for map and tracking features.

---

## 🧠 Running the Backend

### Prerequisites

- Python 3.8+
- LiveKit Cloud project
- Google Gemini API Key

### Setup

1. **Navigate to the Backend directory:**

   ```bash
   cd Backend
   ```

2. **Create a `.env` file and fill in:**

   ```
   LIVEKIT_URL=
   LIVEKIT_API_KEY=
   LIVEKIT_API_SECRET=
   GOOGLE_API_KEY=
   ```

3. **Set up a virtual environment and install dependencies:**

   ```bash
   python -m venv .venv
   source .venv/bin/activate  # or .venv\Scripts\activate on Windows
   pip install -r requirements.txt
   ```

4. **Run the backend service:**
   ```bash
   python main.py dev
   ```

---

## 🤖 LiveKit-Gemini-AI Synergy

Netrai leverages LiveKit for real-time video streaming and Google Gemini for advanced AI-powered voice and vision assistance, enabling seamless collaboration between visually impaired users and their caregivers.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

- [Flutter](https://flutter.dev/)
- [Firebase](https://firebase.google.com/)
- [LiveKit](https://livekit.io/)
- [Google Gemini](https://ai.google.dev/)
- All the amazing open-source libraries used in this project

---
