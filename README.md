# FoodLink 🍲

FoodLink is a modern Flutter application designed to bridge the gap between food surplus providers (hotels, restaurants, wedding halls, caterers) and receivers (NGOs, orphanages, charities, food banks) to systematically reduce food waste.

The application contains an integrated Machine Learning prediction engine. Before posting any food item, the provider must run a shelf-life prediction. If the ML model warns that the food's remaining consumable time is under **4 hours**, the post is blocked for food safety reasons.

---

## Project Structure

The project has been restructured into a clean, modular layout:

*   **`backend/`**: Lightweight FastAPI prediction server wraps the Scikit-Learn `RandomForestRegressor` model.
    *   `app/main.py`: REST API endpoints (`/predict`, `/metadata`).
    *   `app/ml_utils.py`: Preprocessing mapping and model inference logic.
    *   `model/`: Production model binaries (`realistic_food_model.pkl`, `realistic_model_columns.pkl`).
    *   `data/`: Clean training dataset preserved for future validation/retraining.
*   **`food_link/`**: Flutter application using Material 3 UI and Provider state management.
*   **`archive/`**: Safely backed-up older models, datasets, and experiment notebooks.

---

## 🚀 Running the Python FastAPI Backend

### Prerequisites
Make sure you have Python 3.10+ installed.

### 1. Install Dependencies
Navigate to the `backend` directory and install the necessary libraries:
```bash
cd backend
pip install -r requirements.txt
```

### 2. Start the API Server
Run the provided batch file to start the development server:
```bash
run.bat
```
*(Alternatively, run `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`)*

The server will start on `http://localhost:8000`. You can visit `http://localhost:8000/docs` to see the interactive Swagger documentation.

---

## 📱 Setting Up the Flutter Application

### Prerequisites
Make sure you have the Flutter SDK installed and configured.

### 1. Install Packages
Navigate to the `food_link` directory and download the packages:
```bash
cd food_link
flutter pub get
```

*Note: If you run into a symlink or plugin warning on Windows, please enable **Developer Mode** in your Windows settings (Settings -> Update & Security -> For developers -> Developer Mode) and try again.*

### 2. Configuration (Required for Production)

#### A. Firebase Setup
By default, the application runs on a **local in-memory mock database** if Firebase configurations are missing, allowing you to test login, registration, shelf-life verification, posting, mapping, and claiming immediately.

To connect it to your production Firebase instance:
1. Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Authentication** (Email/Password), **Cloud Firestore**, and **Firebase Storage**.
3. Register your platforms (Android, iOS, Web) and download:
    *   Android: `google-services.json` (place in `food_link/android/app/`)
    *   iOS: `GoogleService-Info.plist` (place in `food_link/ios/Runner/`)
4. Firebase will automatically initialize and link on startup.

#### B. Google Maps Integration
To enable map rendering on mobile platforms:
1. Acquire a Google Maps API Key from the Google Cloud Console.
2. Enable the Google Maps SDK for Android & iOS.
3. Configure the key:
    *   Android: Add to `AndroidManifest.xml` (located in `food_link/android/app/src/main/`):
        ```xml
        <meta-data android:name="com.google.android.geo.API_KEY"
                   android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
        ```
    *   iOS: Set in `AppDelegate.swift` (located in `food_link/ios/Runner/`):
        ```swift
        GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
        ```

### 3. Run the App
Launch the app on your connected device, emulator, or browser:
```bash
flutter run
```

*   **Android Emulator**: Connects to the backend automatically via `http://10.0.2.2:8000`.
*   **Web/Chrome/Windows**: Connects via `http://localhost:8000`.

---

## 🛡️ Food Safety & Strict ML Enforcement
For safety reasons:
*   The Flutter app **strictly requires** a successful HTTP response from the FastAPI prediction server to allow a posting.
*   If the backend is down or unreachable, a clear error dialog will prevent the user from making approximate submissions.
*   If the predicted remaining shelf life of food falls below **4.0 hours**, posting is disabled.
