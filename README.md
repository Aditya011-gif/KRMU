# Agri-Score

**AI-powered rural agricultural land intelligence and credit risk assessment.**

## Project Overview
Agri-Score is a comprehensive platform designed to evaluate agricultural land and assess credit risk. It consists of a modern frontend built with Flutter and a robust backend powered by Python and FastAPI, integrating machine learning models and satellite image analysis (via Earth Engine).

## Project Structure
- **/agri_score** - The frontend Flutter web application.
- **/backend** - The backend Python FastAPI service.
- **/supabase** - Supabase configuration and database schemas.

### Frontend (`/agri_score`)
Built with **Flutter (Web)**. Key technologies used:
- **State Management:** Riverpod (`flutter_riverpod`, `riverpod_annotation`)
- **Backend as a Service:** Supabase (`supabase_flutter`)
- **Interactive Maps & Location:** Google Maps Flutter, Geolocator, Geocoding
- **Data Visualization:** fl_chart, percent_indicator

### Backend (`/backend`)
Built with **Python & FastAPI**. Key features include:
- **Core APIs:** Authentication, User Management, and Admin routes.
- **Analysis:** Earth Engine integration for agricultural spatial analysis.
- **Predictions:** Machine learning models (`/ml`, `/models`) and scoring engine (`/score_engine`) for credit risk assessment.
- **Database Tracking:** Supabase backend integration.

## Vercel Deployment
This repository is configured for automatic deployment on **Vercel**:
- `build.sh`: A custom build script that installs the Flutter SDK, builds the `agri_score` web app, and moves the bundled files to the `public/` directory.
- `vercel.json`: Configuration instructing Vercel to use the `bash build.sh` command and deploy the static artifacts.

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Python 3.10+](https://www.python.org/downloads/)
- [Supabase API Keys](https://supabase.com/)

### Running the Frontend
```bash
cd agri_score
flutter pub get
flutter run -d chrome
```

### Running the Backend
```bash
cd backend
python -m venv venv
# On Windows: venv\Scripts\activate
# On Linux/Mac: source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```
*Note: Make sure to configure your `.env` file with the appropriate `SUPABASE_URL` and other required API keys before starting the backend.*
