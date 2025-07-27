# NoteAI Technology Stack

## Architecture Overview
NoteAIは、フロントエンド（Next.js）、バックエンド（Google Cloud Run）、データベース（Firebase）の3層アーキテクチャを採用しています。

## Frontend Technology

### Core Framework
- **Next.js**: React-based full-stack framework
- **React**: Component-based UI library
- **TypeScript**: Type-safe JavaScript development
- **Tailwind CSS**: Utility-first CSS framework

### Audio Processing
- **Web Audio API**: ブラウザネイティブ音声録音
- **MediaStream API**: リアルタイム音声キャプチャ
- **WebRTC**: 音声データの配信・処理

### State Management
- **React Context**: グローバル状態管理
- **React Hooks**: コンポーネント状態管理

## Backend Technology

### Cloud Infrastructure
- **Google Cloud Run**: サーバーレスコンテナ実行環境
- **Docker**: コンテナ化されたアプリケーション
- **Python**: バックエンド開発言語

### Audio Processing Libraries
- **librosa**: 音声信号処理
- **scipy**: 科学計算ライブラリ
- **numpy**: 数値計算ライブラリ
- **pyaudio**: 音声入出力処理

### AI/ML Services
- **Google Speech-to-Text API**: 音声文字起こし
- **OpenAI Whisper**: オープンソース音声認識
- **カスタム話者分離モデル**: 機械学習による話者識別

## Database & Storage

### Firebase Services
- **Firestore**: NoSQLドキュメントデータベース
- **Firebase Storage**: 音声ファイル保存
- **Firebase Authentication**: ユーザー認証
- **Firebase Hosting**: フロントエンドホスティング

### Data Structure
```javascript
// User document
{
  userId: string,
  email: string,
  displayName: string,
  voiceProfile: object,
  apiKeys: object,
  createdAt: timestamp
}

// Audio document
{
  audioId: string,
  userId: string,
  title: string,
  audioUrl: string,
  transcription: string,
  speakers: array,
  status: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

## Development Environment

### Local Development
```bash
# Frontend development
npm run dev          # Next.js development server (port 3000)
npm run build        # Production build
npm run lint         # ESLint code checking

# Backend development
python main.py       # Local Flask server (port 8080)
docker build .       # Build container image
docker run -p 8080:8080 # Run container locally
```

### Environment Variables
```env
# Frontend (.env.local)
NEXT_PUBLIC_FIREBASE_CONFIG=
NEXT_PUBLIC_API_BASE_URL=

# Backend (.env)
GOOGLE_APPLICATION_CREDENTIALS=
OPENAI_API_KEY=
FIREBASE_PROJECT_ID=
```

## Deployment

### Frontend Deployment
- **Firebase Hosting**: `firebase deploy --only hosting`
- **Build Process**: Next.js static export
- **CDN**: Global content distribution

### Backend Deployment
- **Google Cloud Run**: `gcloud run deploy`
- **Container Registry**: Google Container Registry
- **Auto-scaling**: 0-1000 instances

### CI/CD Pipeline
- **GitHub Actions**: Automated testing and deployment
- **ESLint + Prettier**: Code quality enforcement
- **Jest**: Unit testing framework

## Security

### Authentication
- **Firebase Auth**: JWT token-based authentication
- **API Key Management**: Secure key storage in Firestore
- **CORS Configuration**: Cross-origin request handling

### Data Protection
- **HTTPS Only**: All communications encrypted
- **Firestore Rules**: Database access control
- **File Upload Validation**: Audio file type/size limits

## Monitoring & Analytics

### Performance Monitoring
- **Firebase Performance**: Frontend performance tracking
- **Google Cloud Monitoring**: Backend metrics
- **Error Reporting**: Automatic error tracking

### Development Tools
- **Firebase Emulator**: Local development environment
- **Cloud Run Local**: Local container testing
- **React DevTools**: Component debugging