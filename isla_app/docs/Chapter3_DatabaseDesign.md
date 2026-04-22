# Chapter 3: System Design

## 3.5 Database Design

### Overview

This section presents the database design for the ISLA (Intelligent Study and Learning Assistant) system, including the Entity Relationship Diagram (ERD), database dictionary, and asset management structure. The system uses Firebase Cloud Firestore as the NoSQL database solution for data persistence and real-time synchronization.

---

## 3.5.1 Entity Relationship Diagram (ERD)

### Database Architecture Overview

ISLA uses **Firebase Cloud Firestore**, a NoSQL document-oriented database that organizes data into collections and documents. Unlike traditional relational databases, Firestore uses references and subcollections to establish relationships between entities.

### ERD - Main Collections and Relationships

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ISLA FIREBASE FIRESTORE ERD                       │
└─────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│       USERS          │
│ (Root Collection)    │
├──────────────────────┤
│ userId (PK)          │◄──────────┐
│ email                │           │
│ name                 │           │ References
│ studentId            │           │ (userId)
│ faculty              │           │
│ year                 │           │
│ semester             │           │
│ profileImageUrl      │           │
│ createdAt            │           │
│ lastLogin            │           │
└──────────────────────┘           │
          │                        │
          │ 1:N                    │
          │                        │
          ▼                        │
┌──────────────────────┐           │
│     DOCUMENTS        │           │
│ (Root Collection)    │           │
├──────────────────────┤           │
│ documentId (PK)      │           │
│ userId (FK)          │───────────┘
│ title                │
│ subject              │
│ fileType             │           ┌──────────────────────┐
│ fileUrl              │           │    STUDY_AIDS        │
│ fileSizeBytes        │           │ (Root Collection)    │
│ uploadDate           │           ├──────────────────────┤
│ lastAccessed         │           │ studyAidId (PK)      │
│ pageCount            │◄──────────│ documentId (FK)      │
│ textExtracted        │ 1:N       │ userId (FK)          │───┐
└──────────────────────┘           │ type                 │   │
          │                        │  - summary           │   │
          │ 1:N                    │  - flashcards        │   │
          │                        │  - quiz              │   │
          ▼                        │ content (JSON)       │   │
┌──────────────────────┐           │ generatedAt          │   │
│   STUDY_SESSIONS     │           │ algorithm            │   │
│ (Root Collection)    │           │  - TextRank          │   │
├──────────────────────┤           │  - RAKE              │   │
│ sessionId (PK)       │           │  - YAKE              │   │
│ userId (FK)          │───────┐   └──────────────────────┘   │
│ documentId (FK)      │───────┼────────────────────────────┐ │
│ subject              │       │                            │ │
│ startTime            │       │                            │ │
│ endTime              │       │                            │ │
│ duration             │       │                            │ │
│ sessionType          │       │                            │ │
│  - focus             │       │   ┌──────────────────────┐ │ │
│  - break             │       │   │    QUIZ_RESULTS      │ │ │
│ completed            │       │   │ (Root Collection)    │ │ │
└──────────────────────┘       │   ├──────────────────────┤ │ │
                               │   │ resultId (PK)        │ │ │
          ┌────────────────────┤   │ studyAidId (FK)      │─┘ │
          │                    │   │ userId (FK)          │───┘
          ▼                    │   │ score                │
┌──────────────────────┐       │   │ totalQuestions       │
│       TASKS          │       │   │ correctAnswers       │
│ (Root Collection)    │       │   │ attemptDate          │
├──────────────────────┤       │   │ timeSpent            │
│ taskId (PK)          │       │   │ answers (Array)      │
│ userId (FK)          │───────┘   └──────────────────────┘
│ title                │
│ subject              │
│ taskType             │               ┌──────────────────────┐
│  - assignment        │               │      COURSES         │
│  - exam              │               │ (Root Collection)    │
│  - revision          │               ├──────────────────────┤
│ dueDate              │               │ courseId (PK)        │
│ priority             │               │ userId (FK)          │───┐
│  - high              │               │ courseCode           │   │
│  - medium            │               │ courseName           │   │
│  - low               │               │ credits              │   │
│ description          │               │ grade                │   │
│ completed            │               │  - A, A-, B+, etc    │   │
│ completedDate        │               │ semester             │   │
│ createdAt            │               │ year                 │   │
└──────────────────────┘               └──────────────────────┘   │
                                                                  │
                                       ┌──────────────────────┐   │
                                       │    ANALYTICS         │   │
                                       │ (Root Collection)    │   │
                                       ├──────────────────────┤   │
                                       │ analyticsId (PK)     │   │
                                       │ userId (FK)          │───┘
                                       │ date                 │
                                       │ totalStudyTime       │
                                       │ sessionCount         │
                                       │ documentsUploaded    │
                                       │ quizzesAttempted     │
                                       │ subjectBreakdown     │
                                       │  (Map)               │
                                       │ weeklyActivity       │
                                       │  (Array)             │
                                       │ currentGPA           │
                                       │ currentCGPA          │
                                       └──────────────────────┘

Legend:
PK = Primary Key (Document ID in Firestore)
FK = Foreign Key (Reference to another document)
1:N = One-to-Many Relationship
─► = References/Relationship
```

---

## 3.5.2 Database Dictionary

### Collection 1: USERS

**Purpose:** Stores user authentication and profile information for all registered students.

| Field Name      | Data Type | Size/Format | Constraints          | Description                                |
| --------------- | --------- | ----------- | -------------------- | ------------------------------------------ |
| **userId**      | String    | 28 chars    | PK, NOT NULL, UNIQUE | Firebase Auth UID (auto-generated)         |
| email           | String    | 255 chars   | NOT NULL, UNIQUE     | Student's email address                    |
| name            | String    | 100 chars   | NOT NULL             | Full name of the student                   |
| studentId       | String    | 20 chars    | NOT NULL, UNIQUE     | University student ID (e.g., CB21088)      |
| faculty         | String    | 50 chars    | NOT NULL             | Faculty/School name (e.g., FKOM)           |
| year            | Integer   | 1-5         | NOT NULL             | Current academic year                      |
| semester        | Integer   | 1-2         | NOT NULL             | Current semester                           |
| profileImageUrl | String    | 500 chars   | NULLABLE             | URL to profile picture in Firebase Storage |
| createdAt       | Timestamp | ISO 8601    | NOT NULL             | Account creation date                      |
| lastLogin       | Timestamp | ISO 8601    | NOT NULL             | Last login timestamp                       |

**Primary Key:** userId  
**Indexes:** email (for login), studentId (for search)

---

### Collection 2: DOCUMENTS

**Purpose:** Stores metadata for all uploaded study documents (PDF, PPTX, DOCX).

| Field Name     | Data Type | Size/Format | Constraints          | Description                              |
| -------------- | --------- | ----------- | -------------------- | ---------------------------------------- |
| **documentId** | String    | 28 chars    | PK, NOT NULL, UNIQUE | Auto-generated document ID               |
| userId         | String    | 28 chars    | FK, NOT NULL         | References USERS.userId (document owner) |
| title          | String    | 200 chars   | NOT NULL             | Document title                           |
| subject        | String    | 50 chars    | NOT NULL             | Course code (BCS2033, BCS3012, etc.)     |
| fileType       | String    | 10 chars    | NOT NULL             | File format: PDF, PPTX, DOCX             |
| fileUrl        | String    | 500 chars   | NOT NULL             | Firebase Storage download URL            |
| fileSizeBytes  | Integer   | -           | NOT NULL             | File size in bytes                       |
| uploadDate     | Timestamp | ISO 8601    | NOT NULL             | Upload timestamp                         |
| lastAccessed   | Timestamp | ISO 8601    | NULLABLE             | Last time document was opened            |
| pageCount      | Integer   | -           | NULLABLE             | Number of pages/slides                   |
| textExtracted  | Boolean   | -           | NOT NULL             | Whether text extraction succeeded        |

**Primary Key:** documentId  
**Foreign Keys:** userId → USERS.userId  
**Indexes:** userId, subject, uploadDate (desc)

---

### Collection 3: STUDY_AIDS

**Purpose:** Stores generated study aids (summaries, flashcards, quizzes) created from documents using NLP.

| Field Name     | Data Type | Size/Format | Constraints          | Description                                  |
| -------------- | --------- | ----------- | -------------------- | -------------------------------------------- |
| **studyAidId** | String    | 28 chars    | PK, NOT NULL, UNIQUE | Auto-generated study aid ID                  |
| documentId     | String    | 28 chars    | FK, NOT NULL         | References DOCUMENTS.documentId              |
| userId         | String    | 28 chars    | FK, NOT NULL         | References USERS.userId (owner)              |
| type           | String    | 20 chars    | NOT NULL             | Type: summary, flashcards, quiz              |
| content        | Map/JSON  | -           | NOT NULL             | Study aid content (structure varies by type) |
| generatedAt    | Timestamp | ISO 8601    | NOT NULL             | Generation timestamp                         |
| algorithm      | String    | 20 chars    | NOT NULL             | NLP algorithm used: TextRank, RAKE, YAKE     |

**Primary Key:** studyAidId  
**Foreign Keys:**

- documentId → DOCUMENTS.documentId
- userId → USERS.userId

**Content Structure by Type:**

**Summary:**

```json
{
  "keyPoints": [
    "Key sentence 1",
    "Key sentence 2",
    ...
  ],
  "wordCount": 450
}
```

**Flashcards:**

```json
{
  "cards": [
    {
      "front": "Question text",
      "back": "Answer text"
    },
    ...
  ],
  "totalCards": 10
}
```

**Quiz:**

```json
{
  "questions": [
    {
      "question": "Question text",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctAnswer": 0
    },
    ...
  ],
  "totalQuestions": 10
}
```

---

### Collection 4: STUDY_SESSIONS

**Purpose:** Records all study sessions conducted using the Pomodoro timer.

| Field Name    | Data Type | Size/Format | Constraints          | Description                            |
| ------------- | --------- | ----------- | -------------------- | -------------------------------------- |
| **sessionId** | String    | 28 chars    | PK, NOT NULL, UNIQUE | Auto-generated session ID              |
| userId        | String    | 28 chars    | FK, NOT NULL         | References USERS.userId                |
| documentId    | String    | 28 chars    | FK, NULLABLE         | Document being studied (if applicable) |
| subject       | String    | 50 chars    | NOT NULL             | Course code (BCS2033, etc.)            |
| startTime     | Timestamp | ISO 8601    | NOT NULL             | Session start time                     |
| endTime       | Timestamp | ISO 8601    | NULLABLE             | Session end time (null if in progress) |
| duration      | Integer   | minutes     | NULLABLE             | Total study duration in minutes        |
| sessionType   | String    | 10 chars    | NOT NULL             | Type: focus (25 min) or break (5 min)  |
| completed     | Boolean   | -           | NOT NULL             | Whether session completed normally     |

**Primary Key:** sessionId  
**Foreign Keys:**

- userId → USERS.userId
- documentId → DOCUMENTS.documentId

**Indexes:** userId, startTime (desc), subject

---

### Collection 5: TASKS

**Purpose:** Stores academic tasks, assignments, and exam schedules created by students.

| Field Name    | Data Type | Size/Format | Constraints          | Description                      |
| ------------- | --------- | ----------- | -------------------- | -------------------------------- |
| **taskId**    | String    | 28 chars    | PK, NOT NULL, UNIQUE | Auto-generated task ID           |
| userId        | String    | 28 chars    | FK, NOT NULL         | References USERS.userId          |
| title         | String    | 200 chars   | NOT NULL             | Task title                       |
| subject       | String    | 50 chars    | NOT NULL             | Course code                      |
| taskType      | String    | 20 chars    | NOT NULL             | Type: assignment, exam, revision |
| dueDate       | Timestamp | ISO 8601    | NOT NULL             | Task deadline                    |
| priority      | String    | 10 chars    | NOT NULL             | Priority: high, medium, low      |
| description   | String    | 1000 chars  | NULLABLE             | Task details                     |
| completed     | Boolean   | -           | NOT NULL             | Completion status                |
| completedDate | Timestamp | ISO 8601    | NULLABLE             | Date task was completed          |
| createdAt     | Timestamp | ISO 8601    | NOT NULL             | Task creation date               |

**Primary Key:** taskId  
**Foreign Keys:** userId → USERS.userId  
**Indexes:** userId, dueDate (asc), completed, priority

---

### Collection 6: QUIZ_RESULTS

**Purpose:** Records quiz attempt results and student performance metrics.

| Field Name     | Data Type | Size/Format | Constraints          | Description                      |
| -------------- | --------- | ----------- | -------------------- | -------------------------------- |
| **resultId**   | String    | 28 chars    | PK, NOT NULL, UNIQUE | Auto-generated result ID         |
| studyAidId     | String    | 28 chars    | FK, NOT NULL         | References STUDY_AIDS.studyAidId |
| userId         | String    | 28 chars    | FK, NOT NULL         | References USERS.userId          |
| score          | Integer   | 0-100       | NOT NULL             | Score percentage                 |
| totalQuestions | Integer   | -           | NOT NULL             | Number of questions in quiz      |
| correctAnswers | Integer   | -           | NOT NULL             | Number of correct answers        |
| attemptDate    | Timestamp | ISO 8601    | NOT NULL             | Date of quiz attempt             |
| timeSpent      | Integer   | seconds     | NOT NULL             | Time taken to complete quiz      |
| answers        | Array     | -           | NOT NULL             | Array of user answers (indices)  |

**Primary Key:** resultId  
**Foreign Keys:**

- studyAidId → STUDY_AIDS.studyAidId
- userId → USERS.userId

**Indexes:** userId, attemptDate (desc), studyAidId

---

### Collection 7: COURSES

**Purpose:** Stores course information for GPA/CGPA calculation.

| Field Name   | Data Type | Size/Format | Constraints          | Description                          |
| ------------ | --------- | ----------- | -------------------- | ------------------------------------ |
| **courseId** | String    | 28 chars    | PK, NOT NULL, UNIQUE | Auto-generated course ID             |
| userId       | String    | 28 chars    | FK, NOT NULL         | References USERS.userId              |
| courseCode   | String    | 20 chars    | NOT NULL             | Course code (BCS2033)                |
| courseName   | String    | 200 chars   | NOT NULL             | Full course name                     |
| credits      | Integer   | 1-6         | NOT NULL             | Credit hours                         |
| grade        | String    | 5 chars     | NOT NULL             | Grade: A, A-, B+, B, B-, C+, C, D, F |
| semester     | Integer   | 1-2         | NOT NULL             | Semester taken                       |
| year         | Integer   | 1-5         | NOT NULL             | Year taken                           |

**Primary Key:** courseId  
**Foreign Keys:** userId → USERS.userId  
**Indexes:** userId, semester, year

**Grade Points Mapping:**

- A = 4.00
- A- = 3.67
- B+ = 3.33
- B = 3.00
- B- = 2.67
- C+ = 2.33
- C = 2.00
- D = 1.00
- F = 0.00

---

### Collection 8: ANALYTICS

**Purpose:** Stores aggregated study analytics and performance metrics for dashboard display.

| Field Name        | Data Type | Size/Format | Constraints          | Description                        |
| ----------------- | --------- | ----------- | -------------------- | ---------------------------------- |
| **analyticsId**   | String    | 28 chars    | PK, NOT NULL, UNIQUE | Auto-generated analytics ID        |
| userId            | String    | 28 chars    | FK, NOT NULL         | References USERS.userId            |
| date              | Timestamp | ISO 8601    | NOT NULL             | Date of analytics record           |
| totalStudyTime    | Integer   | minutes     | NOT NULL             | Total study time for period        |
| sessionCount      | Integer   | -           | NOT NULL             | Number of study sessions           |
| documentsUploaded | Integer   | -           | NOT NULL             | Documents uploaded count           |
| quizzesAttempted  | Integer   | -           | NOT NULL             | Quizzes attempted count            |
| subjectBreakdown  | Map       | -           | NOT NULL             | Study time per subject (key-value) |
| weeklyActivity    | Array     | -           | NOT NULL             | Daily study hours [Mon-Sun]        |
| currentGPA        | Float     | 0.00-4.00   | NOT NULL             | Current semester GPA               |
| currentCGPA       | Float     | 0.00-4.00   | NOT NULL             | Cumulative GPA                     |

**Primary Key:** analyticsId  
**Foreign Keys:** userId → USERS.userId  
**Indexes:** userId, date (desc)

**SubjectBreakdown Structure:**

```json
{
  "BCS2033": 120, // minutes
  "BCS3012": 95,
  "BCS3123": 80
}
```

**WeeklyActivity Structure:**

```json
[30, 45, 60, 50, 40, 0, 20] // Minutes for Mon-Sun
```

---

## 3.5.3 Database Relationships Summary

| Parent Collection | Child Collection | Relationship Type | Foreign Key |
| ----------------- | ---------------- | ----------------- | ----------- |
| USERS             | DOCUMENTS        | One-to-Many       | userId      |
| USERS             | STUDY_SESSIONS   | One-to-Many       | userId      |
| USERS             | TASKS            | One-to-Many       | userId      |
| USERS             | COURSES          | One-to-Many       | userId      |
| USERS             | ANALYTICS        | One-to-Many       | userId      |
| DOCUMENTS         | STUDY_AIDS       | One-to-Many       | documentId  |
| DOCUMENTS         | STUDY_SESSIONS   | One-to-Many       | documentId  |
| STUDY_AIDS        | QUIZ_RESULTS     | One-to-Many       | studyAidId  |

---

## 3.5.4 Assets Management

### Digital Assets Structure

The ISLA system utilizes various digital assets stored in organized directories for UI components, icons, and images.

#### Asset Directory Structure

```
isla_app/
└── assets/
    ├── icons/
    │   ├── app_icon.png              (1024x1024)
    │   ├── icon_summary.png          (256x256)
    │   ├── icon_flashcards.png       (256x256)
    │   ├── icon_quiz.png             (256x256)
    │   ├── icon_document.png         (256x256)
    │   ├── icon_task.png             (256x256)
    │   └── icon_timer.png            (256x256)
    │
    └── images/
        ├── logo_light.png            (512x512)
        ├── logo_dark.png             (512x512)
        ├── empty_state_documents.png (400x400)
        ├── empty_state_tasks.png     (400x400)
        └── splash_screen.png         (1920x1080)
```

#### Asset Registry

| Asset Name                | Type  | Size      | Format | Purpose                            |
| ------------------------- | ----- | --------- | ------ | ---------------------------------- |
| app_icon.png              | Icon  | 1024x1024 | PNG    | Application launcher icon          |
| logo_light.png            | Image | 512x512   | PNG    | ISLA logo for light theme          |
| logo_dark.png             | Image | 512x512   | PNG    | ISLA logo for dark theme           |
| icon_summary.png          | Icon  | 256x256   | PNG    | Summary generation button          |
| icon_flashcards.png       | Icon  | 256x256   | PNG    | Flashcards generation button       |
| icon_quiz.png             | Icon  | 256x256   | PNG    | Quiz generation button             |
| icon_document.png         | Icon  | 256x256   | PNG    | Document list items                |
| icon_task.png             | Icon  | 256x256   | PNG    | Task list items                    |
| icon_timer.png            | Icon  | 256x256   | PNG    | Timer screen icon                  |
| empty_state_documents.png | Image | 400x400   | PNG    | Empty document library placeholder |
| empty_state_tasks.png     | Image | 400x400   | PNG    | Empty task list placeholder        |
| splash_screen.png         | Image | 1920x1080 | PNG    | App loading screen                 |

#### Icon Libraries Used

The system also utilizes Material Design Icons from Flutter's built-in icon library:

- **Navigation:** home, description, event, timer, dashboard
- **Actions:** add, edit, delete, upload, download, search, filter
- **Study Aids:** lightbulb (summary), style (flashcards), quiz
- **Status:** check_circle, error, pending, done
- **Profile:** person, settings, logout
- **Academic:** school, grade, book, calculate

---

## 3.5.5 Database Creation Process

### Phase 1: Firebase Project Setup

**Step 1: Create Firebase Project**

1. Navigate to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Enter project name: "ISLA-FYP"
4. Disable Google Analytics (optional for prototype)
5. Click "Create Project"

**Step 2: Register Flutter App**

1. Select "Flutter" platform
2. Register app with package name: `com.fyp.isla_app`
3. Download `google-services.json` (Android)
4. Download `GoogleService-Info.plist` (iOS)
5. Follow platform-specific setup instructions

**Step 3: Install Firebase SDK**
Add dependencies to `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_storage: ^11.6.0
```

Run command:

```bash
flutter pub get
```

---

### Phase 2: Firebase Authentication Setup

**Step 1: Enable Authentication Methods**

1. Navigate to Firebase Console → Authentication
2. Click "Get Started"
3. Enable "Email/Password" sign-in method
4. Configure email templates (optional)

**Step 2: Initialize Firebase in Flutter**
Create `lib/services/firebase_service.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';

Future<void> initializeFirebase() async {
  await Firebase.initializeApp();
}
```

Update `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(MyApp());
}
```

---

### Phase 3: Cloud Firestore Database Setup

**Step 1: Create Database**

1. Navigate to Firebase Console → Firestore Database
2. Click "Create Database"
3. Select "Start in Test Mode" (for development)
4. Choose location: asia-southeast1 (Singapore)
5. Click "Enable"

**Step 2: Configure Security Rules (Development)**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Test mode - Allow all reads and writes
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2026, 6, 1);
    }
  }
}
```

**Step 3: Configure Security Rules (Production)**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users collection - users can only access their own data
    match /users/{userId} {
      allow read, update, delete: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null;
    }

    // Documents collection
    match /documents/{documentId} {
      allow read, delete: if request.auth != null &&
                            resource.data.userId == request.auth.uid;
      allow create: if request.auth != null;
      allow update: if request.auth != null &&
                      resource.data.userId == request.auth.uid;
    }

    // Study Aids collection
    match /study_aids/{studyAidId} {
      allow read, delete: if request.auth != null &&
                            resource.data.userId == request.auth.uid;
      allow create, update: if request.auth != null;
    }

    // Study Sessions collection
    match /study_sessions/{sessionId} {
      allow read, write: if request.auth != null &&
                           resource.data.userId == request.auth.uid;
    }

    // Tasks collection
    match /tasks/{taskId} {
      allow read, write: if request.auth != null &&
                           resource.data.userId == request.auth.uid;
    }

    // Courses collection
    match /courses/{courseId} {
      allow read, write: if request.auth != null &&
                           resource.data.userId == request.auth.uid;
    }

    // Quiz Results collection
    match /quiz_results/{resultId} {
      allow read, write: if request.auth != null &&
                           resource.data.userId == request.auth.uid;
    }

    // Analytics collection
    match /analytics/{analyticsId} {
      allow read, write: if request.auth != null &&
                           resource.data.userId == request.auth.uid;
    }
  }
}
```

**Step 4: Create Indexes**

Navigate to Firestore Console → Indexes, create composite indexes:

1. **Documents by User and Date:**
   - Collection: `documents`
   - Fields: `userId` (Ascending), `uploadDate` (Descending)

2. **Tasks by User and Due Date:**
   - Collection: `tasks`
   - Fields: `userId` (Ascending), `dueDate` (Ascending), `completed` (Ascending)

3. **Study Sessions by User and Start Time:**
   - Collection: `study_sessions`
   - Fields: `userId` (Ascending), `startTime` (Descending)

4. **Quiz Results by User and Date:**
   - Collection: `quiz_results`
   - Fields: `userId` (Ascending), `attemptDate` (Descending)

---

### Phase 4: Firebase Storage Setup

**Step 1: Enable Firebase Storage**

1. Navigate to Firebase Console → Storage
2. Click "Get Started"
3. Accept default security rules
4. Choose location: asia-southeast1 (Singapore)

**Step 2: Create Storage Structure**

```
isla-fyp.appspot.com/
├── documents/
│   └── {userId}/
│       └── {documentId}.{ext}
│
├── profile_images/
│   └── {userId}/
│       └── profile.jpg
│
└── temp/
    └── {processing files}
```

**Step 3: Configure Storage Security Rules**

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Documents - only owner can read/write
    match /documents/{userId}/{documentId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow delete: if request.auth != null && request.auth.uid == userId;
    }

    // Profile images - only owner can write, anyone can read
    match /profile_images/{userId}/{fileName} {
      allow read: if request.auth != null;
      allow write, delete: if request.auth != null && request.auth.uid == userId;
    }

    // Temp folder for processing
    match /temp/{allFiles=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

### Phase 5: Database Service Layer Implementation

**Step 1: Create Database Service**
Create `lib/services/firestore_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get userId => _auth.currentUser?.uid;

  // CRUD operations for each collection
  // Users
  Future<void> createUser(Map<String, dynamic> userData) async {
    await _db.collection('users').doc(userId).set(userData);
  }

  Future<DocumentSnapshot> getUser() async {
    return await _db.collection('users').doc(userId).get();
  }

  Future<void> updateUser(Map<String, dynamic> updates) async {
    await _db.collection('users').doc(userId).update(updates);
  }

  // Documents
  Future<String> addDocument(Map<String, dynamic> docData) async {
    docData['userId'] = userId;
    DocumentReference ref = await _db.collection('documents').add(docData);
    return ref.id;
  }

  Stream<QuerySnapshot> getDocuments() {
    return _db.collection('documents')
              .where('userId', isEqualTo: userId)
              .orderBy('uploadDate', descending: true)
              .snapshots();
  }

  Future<void> deleteDocument(String documentId) async {
    await _db.collection('documents').doc(documentId).delete();
  }

  // Tasks
  Future<void> addTask(Map<String, dynamic> taskData) async {
    taskData['userId'] = userId;
    await _db.collection('tasks').add(taskData);
  }

  Stream<QuerySnapshot> getTasks() {
    return _db.collection('tasks')
              .where('userId', isEqualTo: userId)
              .orderBy('dueDate')
              .snapshots();
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    await _db.collection('tasks').doc(taskId).update(updates);
  }

  Future<void> deleteTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).delete();
  }

  // Study Sessions
  Future<void> recordSession(Map<String, dynamic> sessionData) async {
    sessionData['userId'] = userId;
    await _db.collection('study_sessions').add(sessionData);
  }

  // Quiz Results
  Future<void> saveQuizResult(Map<String, dynamic> resultData) async {
    resultData['userId'] = userId;
    await _db.collection('quiz_results').add(resultData);
  }

  // Analytics
  Future<void> updateAnalytics(Map<String, dynamic> analyticsData) async {
    analyticsData['userId'] = userId;
    await _db.collection('analytics')
             .doc('${userId}_${DateTime.now().toIso8601String().split('T')[0]}')
             .set(analyticsData, SetOptions(merge: true));
  }
}
```

---

### Phase 6: Testing and Validation

**Step 1: Manual Testing**

1. Create test user account
2. Upload sample document
3. Create tasks
4. Record study session
5. Verify data in Firestore Console

**Step 2: Data Migration (From Mock to Production)**

1. Export mock data structure
2. Create Firestore batch writes
3. Import data to Firestore collections
4. Validate all relationships

**Step 3: Performance Monitoring**

1. Enable Firebase Performance Monitoring
2. Track query performance
3. Optimize indexes based on usage patterns
4. Monitor storage usage

---

## 3.5.6 Current Implementation Status

### Prototype Phase (Current)

- ✅ Database schema designed
- ✅ ERD documented
- ✅ Collections defined
- ✅ Security rules planned
- ⏳ Using **mock data** in local Flutter state
- ⏳ No actual Firebase connection
- ⏳ Data not persisted between sessions

### Data Flow (Prototype):

```
User Action → Flutter Widget → Local State (List/Map) → UI Update
```

### Production Phase (Future - Phase 2)

- ⏳ Firebase project creation
- ⏳ Firestore database setup
- ⏳ Security rules implementation
- ⏳ Storage bucket configuration
- ⏳ Service layer implementation
- ⏳ Real-time data synchronization
- ⏳ Offline data caching

### Data Flow (Production):

```
User Action → Flutter Widget → FirestoreService → Cloud Firestore → UI Update (Stream)
```

---

## 3.5.7 Database Backup and Recovery Strategy

### Backup Plan

1. **Automated Daily Backups:**
   - Firebase automatic backups (retain 7 days)
   - Export to Cloud Storage weekly

2. **Export Formats:**
   - JSON format for all collections
   - CSV format for analytics data

3. **Recovery Procedures:**
   - Restore from Firebase backup
   - Re-import from Cloud Storage exports
   - Manual data reconstruction from logs

---

## 3.5.8 Enhanced Database Specification (Detailed Version)

To address evaluation feedback that the database appears too basic, this section extends the core schema with:

- richer operational fields (status, quality, timestamps, ownership)
- learning analytics fields (streaks, completion rate, focus quality)
- governance fields (audit, soft-delete, versioning)
- additional entities for goals, reminders, settings, and activity logging

The original eight core tables are retained, but each is expanded with implementation-level attributes.

### A. Enhanced Core Tables (Revised Tables 3.17 - 3.24)

#### Table 3.17 User (Enhanced)

| Attribute       | Data Type | Key | Description                                    |
| --------------- | --------- | --- | ---------------------------------------------- |
| userId          | String    | PK  | Unique identifier for each user (Firebase UID) |
| name            | String    | -   | Student full name                              |
| email           | String    | -   | Student email address                          |
| studentId       | String    | -   | University student ID                          |
| faculty         | String    | -   | Faculty or school                              |
| program         | String    | -   | Program or degree name                         |
| year            | Integer   | -   | Current academic year                          |
| semester        | Integer   | -   | Current semester                               |
| profileImageUrl | String    | -   | Profile image URL                              |
| accountStatus   | String    | -   | active, suspended, archived                    |
| createdAt       | DateTime  | -   | Account creation timestamp                     |
| updatedAt       | DateTime  | -   | Last profile update timestamp                  |
| lastLoginAt     | DateTime  | -   | Last successful login timestamp                |

#### Table 3.18 Document (Enhanced)

| Attribute        | Data Type | Key | Description                         |
| ---------------- | --------- | --- | ----------------------------------- |
| documentId       | String    | PK  | Unique document identifier          |
| userId           | String    | FK  | References User.userId              |
| title            | String    | -   | Document title                      |
| subject          | String    | -   | Course code                         |
| fileType         | String    | -   | PDF, PPTX, DOCX                     |
| fileUrl          | String    | -   | Storage download URL                |
| storagePath      | String    | -   | Internal cloud storage path         |
| fileSizeBytes    | Integer   | -   | File size in bytes                  |
| checksum         | String    | -   | Duplicate detection hash            |
| uploadDate       | DateTime  | -   | Date uploaded                       |
| lastViewedAt     | DateTime  | -   | Last access timestamp               |
| processingStatus | String    | -   | pending, processing, ready, failed  |
| extractedTextRef | String    | -   | Reference to extracted text payload |
| isArchived       | Boolean   | -   | Soft archive flag                   |

#### Table 3.19 Study Aid (Enhanced)

| Attribute       | Data Type | Key | Description                    |
| --------------- | --------- | --- | ------------------------------ |
| studyAidId      | String    | PK  | Unique study aid identifier    |
| documentId      | String    | FK  | References Document.documentId |
| userId          | String    | FK  | References User.userId         |
| type            | String    | -   | Summary, Flashcard, Quiz       |
| content         | Text/JSON | -   | Generated study content        |
| generatedDate   | DateTime  | -   | Date generated                 |
| generationModel | String    | -   | Model or algorithm identifier  |
| sourceVersion   | Integer   | -   | Source document version        |
| difficultyLevel | String    | -   | easy, medium, hard             |
| qualityScore    | Float     | -   | Quality rating (0.0 to 1.0)    |
| isFavorited     | Boolean   | -   | Saved by user for quick access |
| status          | String    | -   | active, deprecated, deleted    |

#### Table 3.20 Quiz Result (Enhanced)

| Attribute        | Data Type | Key | Description                       |
| ---------------- | --------- | --- | --------------------------------- |
| resultId         | String    | PK  | Unique quiz attempt ID            |
| studyAidId       | String    | FK  | References StudyAid.studyAidId    |
| userId           | String    | FK  | References User.userId            |
| score            | Integer   | -   | Quiz score percentage             |
| totalQuestions   | Integer   | -   | Total question count              |
| correctAnswers   | Integer   | -   | Number of correct answers         |
| wrongAnswers     | Integer   | -   | Number of wrong answers           |
| unansweredCount  | Integer   | -   | Unanswered question count         |
| attemptDate      | DateTime  | -   | Attempt date                      |
| timeSpentSeconds | Integer   | -   | Time spent in seconds             |
| attemptNo        | Integer   | -   | User attempt number for this quiz |
| feedbackSummary  | String    | -   | Generated feedback text           |

#### Table 3.21 Task (Enhanced)

| Attribute        | Data Type | Key | Description                                |
| ---------------- | --------- | --- | ------------------------------------------ |
| taskId           | String    | PK  | Unique task identifier                     |
| userId           | String    | FK  | References User.userId                     |
| title            | String    | -   | Task title                                 |
| subject          | String    | -   | Course code or category                    |
| taskType         | String    | -   | assignment, revision, quiz, exam           |
| description      | Text      | -   | Task details                               |
| dueDate          | DateTime  | -   | Task deadline                              |
| priority         | String    | -   | low, medium, high                          |
| status           | String    | -   | notStarted, inProgress, completed, overdue |
| estimatedMinutes | Integer   | -   | Planned effort in minutes                  |
| reminderAt       | DateTime  | -   | Reminder datetime                          |
| completed        | Boolean   | -   | Completed or not                           |
| completedAt      | DateTime  | -   | Task completion timestamp                  |
| createdAt        | DateTime  | -   | Task creation timestamp                    |
| updatedAt        | DateTime  | -   | Last update timestamp                      |

#### Table 3.22 Study Session (Enhanced)

| Attribute          | Data Type | Key | Description                               |
| ------------------ | --------- | --- | ----------------------------------------- |
| sessionId          | String    | PK  | Unique session ID                         |
| userId             | String    | FK  | References User.userId                    |
| subject            | String    | -   | Subject studied                           |
| documentId         | String    | FK  | Optional reference to Document.documentId |
| sessionMode        | String    | -   | focus, pomodoro, deepWork, review         |
| startTime          | DateTime  | -   | Session start timestamp                   |
| endTime            | DateTime  | -   | Session end timestamp                     |
| plannedMinutes     | Integer   | -   | Planned study time                        |
| actualMinutes      | Integer   | -   | Actual study time                         |
| breakMinutes       | Integer   | -   | Total break time                          |
| interruptionsCount | Integer   | -   | Number of interruptions                   |
| checklistDone      | Integer   | -   | Completed checklist items                 |
| checklistTotal     | Integer   | -   | Total checklist items                     |
| focusScore         | Integer   | -   | Computed session focus score              |
| completed          | Boolean   | -   | Session finished successfully             |
| createdAt          | DateTime  | -   | Record creation timestamp                 |

#### Table 3.23 Course (Enhanced)

| Attribute    | Data Type | Key | Description                       |
| ------------ | --------- | --- | --------------------------------- |
| courseId     | String    | PK  | Unique course ID                  |
| userId       | String    | FK  | References User.userId            |
| courseCode   | String    | -   | Course code                       |
| courseName   | String    | -   | Course title                      |
| credits      | Integer   | -   | Credit hours                      |
| grade        | String    | -   | Grade obtained                    |
| gradePoint   | Float     | -   | Numeric value for GPA calculation |
| semester     | Integer   | -   | Semester number                   |
| year         | Integer   | -   | Academic year                     |
| lecturerName | String    | -   | Lecturer or instructor name       |
| createdAt    | DateTime  | -   | Creation timestamp                |
| updatedAt    | DateTime  | -   | Update timestamp                  |

#### Table 3.24 Analytics (Enhanced)

| Attribute           | Data Type | Key | Description                      |
| ------------------- | --------- | --- | -------------------------------- |
| analyticsId         | String    | PK  | Unique analytics record          |
| userId              | String    | FK  | References User.userId           |
| periodType          | String    | -   | daily, weekly, monthly, semester |
| periodStart         | DateTime  | -   | Period start date                |
| periodEnd           | DateTime  | -   | Period end date                  |
| totalStudyTime      | Integer   | -   | Total study time in minutes      |
| sessionsCount       | Integer   | -   | Number of sessions               |
| documentsCount      | Integer   | -   | Uploaded documents count         |
| completedTasksCount | Integer   | -   | Completed tasks count            |
| completionRate      | Float     | -   | Percentage of completed tasks    |
| averageFocusScore   | Float     | -   | Mean session focus score         |
| strongestSubject    | String    | -   | Subject with best performance    |
| weakestSubject      | String    | -   | Subject needing improvement      |
| currentGPA          | Float     | -   | Current GPA                      |
| currentCGPA         | Float     | -   | Current CGPA                     |
| generatedAt         | DateTime  | -   | Snapshot generation timestamp    |

### B. Additional Supporting Tables (New)

#### Table 3.25 User Settings

| Attribute        | Data Type | Key | Description                     |
| ---------------- | --------- | --- | ------------------------------- |
| settingId        | String    | PK  | Unique settings record          |
| userId           | String    | FK  | References User.userId          |
| themeMode        | String    | -   | light, dark, system             |
| language         | String    | -   | Preferred app language          |
| reminderEnabled  | Boolean   | -   | Global reminders toggle         |
| dailyGoalMinutes | Integer   | -   | User target daily study minutes |
| weekStartDay     | Integer   | -   | First day of week (1-7)         |
| updatedAt        | DateTime  | -   | Last settings update            |

#### Table 3.26 Study Goal

| Attribute     | Data Type | Key | Description                     |
| ------------- | --------- | --- | ------------------------------- |
| goalId        | String    | PK  | Unique goal identifier          |
| userId        | String    | FK  | References User.userId          |
| title         | String    | -   | Goal title                      |
| description   | Text      | -   | Goal details                    |
| targetType    | String    | -   | minutes, sessions, tasks, score |
| targetValue   | Integer   | -   | Goal target value               |
| progressValue | Integer   | -   | Current progress                |
| startDate     | DateTime  | -   | Goal start date                 |
| endDate       | DateTime  | -   | Goal end date                   |
| status        | String    | -   | active, achieved, expired       |

#### Table 3.27 Notification Log

| Attribute         | Data Type | Key | Description                   |
| ----------------- | --------- | --- | ----------------------------- |
| notificationId    | String    | PK  | Unique notification ID        |
| userId            | String    | FK  | References User.userId        |
| channel           | String    | -   | inApp, push, email            |
| title             | String    | -   | Notification title            |
| body              | String    | -   | Notification body             |
| type              | String    | -   | reminder, milestone, warning  |
| relatedEntityType | String    | -   | task, session, quiz, document |
| relatedEntityId   | String    | -   | Linked record identifier      |
| isRead            | Boolean   | -   | Read status                   |
| sentAt            | DateTime  | -   | Sent timestamp                |
| readAt            | DateTime  | -   | Read timestamp                |

#### Table 3.28 Session Checklist Template

| Attribute  | Data Type | Key | Description            |
| ---------- | --------- | --- | ---------------------- |
| templateId | String    | PK  | Checklist template ID  |
| userId     | String    | FK  | References User.userId |
| subject    | String    | -   | Subject scope          |
| title      | String    | -   | Template name          |
| isDefault  | Boolean   | -   | Default template flag  |
| createdAt  | DateTime  | -   | Creation timestamp     |
| updatedAt  | DateTime  | -   | Last update timestamp  |

#### Table 3.29 Session Checklist Item

| Attribute   | Data Type | Key | Description                                    |
| ----------- | --------- | --- | ---------------------------------------------- |
| itemId      | String    | PK  | Checklist item ID                              |
| templateId  | String    | FK  | References SessionChecklistTemplate.templateId |
| sessionId   | String    | FK  | Optional link to StudySession.sessionId        |
| itemText    | String    | -   | Checklist statement                            |
| itemOrder   | Integer   | -   | Display order                                  |
| isCompleted | Boolean   | -   | Completion status                              |
| completedAt | DateTime  | -   | Completion timestamp                           |

#### Table 3.30 Document Tag

| Attribute | Data Type | Key | Description                    |
| --------- | --------- | --- | ------------------------------ |
| tagId     | String    | PK  | Tag identifier                 |
| userId    | String    | FK  | References User.userId         |
| tagName   | String    | -   | Tag text (example: final exam) |
| colorHex  | String    | -   | Visual color code              |
| createdAt | DateTime  | -   | Tag creation timestamp         |

#### Table 3.31 Document Tag Map

| Attribute  | Data Type | Key | Description                    |
| ---------- | --------- | --- | ------------------------------ |
| mapId      | String    | PK  | Mapping record ID              |
| documentId | String    | FK  | References Document.documentId |
| tagId      | String    | FK  | References DocumentTag.tagId   |
| createdAt  | DateTime  | -   | Mapping creation timestamp     |

#### Table 3.32 Activity Log

| Attribute  | Data Type | Key | Description                                     |
| ---------- | --------- | --- | ----------------------------------------------- |
| logId      | String    | PK  | Activity record identifier                      |
| userId     | String    | FK  | References User.userId                          |
| action     | String    | -   | createTask, uploadDocument, finishSession, etc. |
| entityType | String    | -   | task, document, session, studyAid               |
| entityId   | String    | -   | Related entity identifier                       |
| metadata   | Map       | -   | Additional context payload                      |
| createdAt  | DateTime  | -   | Action timestamp                                |

### C. Enhanced Relationship Summary

- User 1:N Document, Task, StudySession, Course, Analytics, StudyGoal, NotificationLog, ActivityLog
- Document 1:N StudyAid
- Document N:N DocumentTag via DocumentTagMap
- StudyAid 1:N QuizResult
- StudySession 1:N SessionChecklistItem
- SessionChecklistTemplate 1:N SessionChecklistItem

### D. Firestore Collection Mapping (Implementation)

Suggested physical collections:

- users
- documents
- study_aids
- quiz_results
- tasks
- sessions
- courses
- analytics
- user_settings
- study_goals
- notifications
- checklist_templates
- checklist_items
- document_tags
- document_tag_map
- activity_logs

### E. Recommended Composite Indexes for Expanded Schema

1. tasks: userId ASC, status ASC, dueDate ASC
2. tasks: userId ASC, priority DESC, createdAt DESC
3. sessions: userId ASC, startTime DESC
4. sessions: userId ASC, subject ASC, startTime DESC
5. analytics: userId ASC, periodType ASC, periodEnd DESC
6. study_aids: userId ASC, type ASC, generatedDate DESC
7. notifications: userId ASC, isRead ASC, sentAt DESC
8. activity_logs: userId ASC, createdAt DESC

---

## Conclusion

The ISLA database design uses Firebase Cloud Firestore to provide:

- **Scalable NoSQL structure** for flexible data modeling
- **Real-time synchronization** for instant updates across devices
- **Secure access control** with user-specific data isolation
- **Efficient querying** with composite indexes
- **Offline support** for uninterrupted user experience

The current prototype uses mock data to demonstrate functionality, while the production implementation will integrate full Firebase services for persistent, cloud-based data management.
