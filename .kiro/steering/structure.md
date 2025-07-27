# NoteAI Project Structure

## Root Directory Structure
```
NoteAI/
├── .firebase/                 # Firebase deployment cache
├── .github/workflows/         # GitHub Actions CI/CD
├── .next/                     # Next.js build output
├── cloud-run/                 # Backend Python application
├── functions/                 # Firebase Functions (if used)
├── out/                       # Static export output
├── src/ or app/              # Frontend application source
├── public/                    # Static assets
├── components.json           # shadcn/ui configuration
├── .firebaserc              # Firebase project configuration
├── firebase.json            # Firebase hosting configuration
├── firestore.rules          # Firestore security rules
├── firestore.indexes.json   # Firestore database indexes
├── package.json             # Frontend dependencies
├── next.config.js           # Next.js configuration
├── tailwind.config.js       # Tailwind CSS configuration
└── tsconfig.json            # TypeScript configuration
```

## Frontend Structure (src/ or app/)
```
src/
├── components/              # Reusable UI components
│   ├── ui/                 # shadcn/ui base components
│   ├── audio/              # Audio recording components
│   ├── transcription/      # Text editing components
│   └── navigation/         # Navigation components
├── pages/ or app/          # Next.js pages/routes
│   ├── api/               # API routes (if any)
│   ├── auth/              # Authentication pages
│   ├── dashboard/         # Main application pages
│   └── settings/          # User settings pages
├── lib/                   # Utility libraries
│   ├── firebase.ts        # Firebase configuration
│   ├── audio.ts           # Audio processing utilities
│   └── api.ts             # API client functions
├── hooks/                 # Custom React hooks
│   ├── useAudio.ts        # Audio recording hook
│   ├── useAuth.ts         # Authentication hook
│   └── useTranscription.ts # Transcription hook
├── types/                 # TypeScript type definitions
│   ├── audio.ts           # Audio-related types
│   ├── user.ts            # User-related types
│   └── api.ts             # API response types
└── styles/                # CSS styles
    ├── globals.css        # Global styles
    └── components.css     # Component-specific styles
```

## Backend Structure (cloud-run/)
```
cloud-run/
├── src/                   # Python source code
│   ├── audio_processor.py # Audio processing logic
│   ├── speaker_separation.py # Speaker separation
│   ├── transcription_apis.py # API integrations
│   ├── voice_learning.py  # Voice profile learning
│   └── utils/             # Utility functions
├── tests/                 # Unit tests
├── requirements.txt       # Python dependencies
├── Dockerfile            # Container configuration
├── main.py               # Flask application entry point
├── cloudbuild.yaml       # Google Cloud Build
├── deploy.sh             # Deployment script
└── .env.example          # Environment variables template
```

## Configuration Files

### Firebase Configuration
- **`.firebaserc`**: Project aliases and configurations
- **`firebase.json`**: Hosting, functions, and rules configuration
- **`firestore.rules`**: Database security rules
- **`firestore.indexes.json`**: Query optimization indexes

### Next.js Configuration
- **`next.config.js`**: Build and runtime configuration
- **`package.json`**: Dependencies and scripts
- **`tsconfig.json`**: TypeScript compiler options

### Styling Configuration
- **`tailwind.config.js`**: Tailwind CSS customization
- **`components.json`**: shadcn/ui component configuration

## Naming Conventions

### Files and Directories
- **Components**: PascalCase (`AudioRecorder.tsx`)
- **Pages**: kebab-case (`voice-notes.tsx`)
- **Utilities**: camelCase (`audioProcessor.ts`)
- **Types**: PascalCase (`AudioFile.ts`)
- **Constants**: UPPER_SNAKE_CASE (`API_ENDPOINTS.ts`)

### Code Conventions
- **React Components**: PascalCase function declarations
- **Functions**: camelCase
- **Variables**: camelCase
- **Constants**: UPPER_SNAKE_CASE
- **Types/Interfaces**: PascalCase with descriptive names

### Database Collections
- **Users**: `users/{userId}`
- **Audio Files**: `audioFiles/{audioId}`
- **Transcriptions**: `transcriptions/{transcriptionId}`
- **Voice Profiles**: `voiceProfiles/{userId}`

## Development Scripts

### Frontend Scripts
```json
{
  "dev": "next dev",
  "build": "next build",
  "start": "next start",
  "lint": "next lint",
  "export": "next export",
  "type-check": "tsc --noEmit"
}
```

### Backend Scripts
```bash
# Development
python main.py                    # Local development server
python -m pytest tests/          # Run unit tests

# Deployment
docker build -t noteai-backend .  # Build container
gcloud run deploy                 # Deploy to Cloud Run
```

## Environment Management

### Development Environment
- **Local Firebase Emulator**: `firebase emulators:start`
- **Local Backend**: `python main.py` (port 8080)
- **Local Frontend**: `npm run dev` (port 3000)

### Production Environment
- **Frontend**: Firebase Hosting
- **Backend**: Google Cloud Run
- **Database**: Firestore Production

## Code Organization Principles

### Component Structure
- One component per file
- Props interface defined above component
- Custom hooks for complex logic
- Styled with Tailwind CSS classes

### API Route Structure
- RESTful endpoints
- Consistent error handling
- Input validation
- Rate limiting implementation

### Database Design
- Normalized document structure
- Efficient query patterns
- Proper indexing strategy
- Security rules enforcement