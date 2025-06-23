# SmartSoak Flutter Controller

This is a Flutter-based mobile application designed to control the SmartSoak irrigation system. It provides a user-friendly interface to manage water sources, irrigation lanes, and monitor system status in real-time.

## Features

- **Dual Connection Modes:** Connect to the ESP8266 controller via local WiFi (HTTP) or remotely from anywhere using an internet connection (MQTT).
- **Dynamic Theming:** The app uses the device's system colors (Material You) and supports both light and dark modes for a personalized experience.
- **Real-Time Status Monitoring:** Get live updates on water source status (Bore Motor, Main Water, Tank Level), active irrigation lanes, soil moisture, and connection status.
- **Comprehensive Controls:**
    - Manually start/stop the bore motor.
    - Open/close the main water valve.
    - Individually control up to 3 irrigation lanes.
    - Quick controls to turn all lanes on or off simultaneously.
- **Safety First:** An emergency stop button is available to immediately halt all system operations.
- **Responsive UI:** The interface is designed to be intuitive and provides instant feedback for all control actions.

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Android Studio](https://developer.android.com/studio) or [Visual Studio Code](https://code.visualstudio.com/)
- An Android Emulator or a physical Android device.

### Installation

1.  **Clone the repository:**
    ```sh
    git clone <your-repository-url>
    cd SmartSoak/AndroidApp/smart_soak
    ```

2.  **Install dependencies:**
    ```sh
    flutter pub get
    ```

3.  **Run the app:**
    - Open the project in Android Studio or VS Code.
    - Select your target device (emulator or physical device).
    - Run the `main.dart` file.

## Configuration

### HTTP (Local) Mode

1.  Connect your phone to the same WiFi network as your ESP8266.
2.  In the app, select "Local (HTTP)" mode.
3.  Enter the IP address of your ESP8266 in the configuration card and press "Set".

### MQTT (Remote) Mode

1.  Ensure your MQTT broker credentials in `lib/main.dart` are correctly configured.
2.  Select "Remote (MQTT)" mode in the app.
3.  The app will connect to the broker to send and receive commands.
