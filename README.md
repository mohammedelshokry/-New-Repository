# PitchUp Platform

This is a production-ready template for the PitchUp platform, containing a Node.js Backend, a Next.js Web Dashboard, and a Flutter Mobile App.

## 1. Backend (Node.js + Express + SQLite)
The backend provides REST APIs for pitches, bookings, and match requests. It uses SQLite for local ease-of-use without requiring Docker.

**To run the backend:**
```bash
cd backend
npm install
npx prisma db push
npm run seed
npm run dev
```
The backend will run on `http://localhost:3001`.

## 2. Web Dashboard (Next.js + Tailwind CSS)
The web dashboard is for Pitch Owners to manage their pitches, bookings, and view earnings.

**To run the dashboard:**
```bash
cd web-dashboard
npm install
npm run dev
```
The dashboard will run on `http://localhost:3000`.

## 3. Mobile App (Flutter)
The mobile app is built with Flutter and uses Riverpod for state management. 

**To run the mobile app:**
You need to have Flutter SDK installed.
```bash
cd mobile-app
flutter pub get
flutter run
```
*Note: The API base URL is currently set to `http://10.0.2.2:3001/api` in `lib/providers/api_provider.dart` for Android Emulators. If you are running on iOS Simulator or a physical device, change this to your computer's local IP address (e.g. `192.168.1.x`).*
