# Chapter 3: System Design

## 3.1 Context Diagram

### Overview

The Context Diagram represents the highest-level view of the ISLA (Intelligent Study and Learning Assistant) system, showing the system boundary and its interactions with external entities.

### System Boundary

The ISLA system is a mobile-first study assistant application designed for university students, particularly those from FKOM, UMPSA.

---

## Context Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                         External Environment                        │
│                                                                     │
│   ┌──────────────┐                                                  │
│   │              │                                                  │
│   │   Student    │────────┐                                         │
│   │   (User)     │        │                                         │
│   │              │        │  Login/Register                         │
│   └──────────────┘        │  Upload Documents                       │
│                           │  Create Tasks                           │
│                           │  Start Study Timer                      │
│                           │  View Performance                       │
│                           │                                         │
│                           ▼                                         │
│   ┌─────────────────────────────────────────────────────────┐      │
│   │                                                         │      │
│   │                  ISLA SYSTEM                            │      │
│   │  (Intelligent Study & Learning Assistant)              │      │
│   │                                                         │      │
│   │  ┌─────────────────────────────────────────────────┐   │      │
│   │  │  Core Functions:                               │   │      │
│   │  │  • Authentication Management                   │   │      │
│   │  │  • Document Management                         │   │      │
│   │  │  • Lightweight NLP Processing (Internal)       │   │      │
│   │  │    - Text Summarization (TextRank)             │   │      │
│   │  │    - Flashcard Generation (RAKE/YAKE)          │   │      │
│   │  │    - Quiz Generation (Keyword Extraction)      │   │      │
│   │  │  • Study Planning & Scheduling                 │   │      │
│   │  │  • Pomodoro Timer                              │   │      │
│   │  │  • Performance Analytics                       │   │      │
│   │  └─────────────────────────────────────────────────┘   │      │
│   │                                                         │      │
│   └─────────────────────────────────────────────────────────┘      │
│                           │                                         │
│                           │  Store/Retrieve Data                    │
│                           │  User Information                       │
│                           │  Documents & Study Materials            │
│                           │  Study Sessions & Tasks                 │
│                           │  Generated Study Aids                   │
│                           ▼                                         │
│   ┌─────────────────────────────────────────────────────────┐      │
│   │                                                         │      │
│   │           Firebase Backend Services                     │      │
│   │                                                         │      │
│   │  • Firebase Authentication                             │      │
│   │  • Cloud Firestore (Database)                          │      │
│   │  • Firebase Storage (Documents)                        │      │
│   │                                                         │      │
│   └─────────────────────────────────────────────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## External Entities

### 1. Student (User)

**Description:** The primary user of the ISLA system - undergraduate students from FKOM, UMPSA.

**Interactions with System:**

- **Input to System:**
  - Authentication credentials (email, password)
  - Study documents (PDF, PPTX, DOCX)
  - Task information (assignments, exams, revision)
  - Study session data (timer usage, subject selection)
  - Grade information (for GPA calculation)

- **Output from System:**
  - Access granted/denied
  - AI-generated summaries
  - Flashcards for revision
  - Quiz questions
  - Task reminders
  - Study time analytics
  - Performance reports
  - GPA/CGPA calculations

### 2. Firebase Backend Services

**Description:** Google's Backend-as-a-Service platform providing authentication, database, and storage.

**Interactions with System:**

- **Input to System:**
  - Authentication verification results
  - Stored user data
  - Retrieved documents and study materials
  - Saved tasks and schedules
  - Historical study session data

- **Output from System:**
  - User registration data
  - Document uploads
  - Study material metadata
  - Task and schedule information
  - Study session records
  - Performance metrics

---

## Data Flows

### Primary Data Flows (All Through ISLA System):

1. **Authentication Flow**
   - Student → ISLA System (login credentials)
   - ISLA System → Firebase Authentication (verification request)
   - Firebase Authentication → ISLA System (auth status)
   - ISLA System → Student (access granted/denied)

2. **Document Management Flow**
   - Student → ISLA System (upload document)
   - ISLA System → Firebase Storage (store document)
   - Firebase Storage → ISLA System (storage confirmation)
   - ISLA System → Student (upload success)

3. **Study Aid Generation Flow** (Internal NLP Processing)
   - Student → ISLA System (request summary/flashcards/quiz)
   - ISLA System → Firebase Storage (retrieve document)
   - Firebase Storage → ISLA System (document data)
   - **ISLA System (Internal Processing):**
     - Extract text from document
     - Apply NLP algorithms (TextRank, RAKE, YAKE)
     - Generate summaries, flashcards, quiz questions
   - ISLA System → Cloud Firestore (save generated study aids)
   - ISLA System → Student (display study aids)

4. **Task Management Flow**
   - Student → ISLA System (create/update task)
   - ISLA System → Cloud Firestore (store task data)
   - Cloud Firestore → ISLA System (confirmation)
   - ISLA System → Student (task saved, reminders scheduled)

5. **Study Timer Flow**
   - Student → ISLA System (start/stop timer)
   - ISLA System → Cloud Firestore (record session data)
   - Cloud Firestore → ISLA System (session stored)
   - ISLA System → Student (timer status, statistics updated)

6. **Performance Analytics Flow**
   - Student → ISLA System (request analytics)
   - ISLA System → Cloud Firestore (retrieve study sessions, grades, tasks)
   - Cloud Firestore → ISLA System (historical data)
   - ISLA System (processes & calculates metrics)
   - ISLA System → Student (performance reports, charts, GPA)

### Important Note:

**All data flows pass through the ISLA System.** Firebase services never communicate directly with the student. The ISLA system acts as the intermediary, orchestrator, and business logic layer. **All AI-powered study aid generation happens internally within ISLA** using lightweight extractive NLP algorithms (TextRank, RAKE, YAKE).

---

## System Boundary

**Inside the System Boundary:**

- User interface (mobile-first responsive design)
- Authentication module
- Document management module
- **Internal NLP processing module:**
  - TextRank algorithm (summarization)
  - RAKE/YAKE algorithms (keyword extraction)
  - Flashcard generation engine
  - Quiz question generation engine
- Study planner module
- Pomodoro timer module
- Performance dashboard
- GPA calculator
- Business logic and data processing

**Outside the System Boundary:**

- End users (students)
- Firebase backend infrastructure (Authentication, Firestore, Storage)
- User devices (smartphones, tablets, computers)
- Network infrastructure

---

## Key System Characteristics

1. **Input Processing:**
   - User authentication data
   - Study documents (multiple formats)
   - Task and schedule information
   - Study session data
   - Grade information

2. **Processing:**
   - Document parsing and storage
   - AI-powered content generation
   - Task scheduling and reminders
   - Time tracking and analytics
   - Performance calculations

3. **Output Generation:**
   - Personalized study materials
   - Task notifications
   - Study time reports
   - Performance analytics
   - GPA calculations

4. **Data Storage:**
   - User profiles
   - Document repository
   - Generated study materials
   - Task lists and schedules
   - Study session history
   - Performance metrics

---

## Context Diagram - Simplified Visual

```
                     ┌───────────┐
                     │           │
                     │  Student  │
                     │   (User)  │
                     │           │
                     └─────┬─────┘
                           │
                           │ Inputs:
                           │ • Login/Register
                           │ • Upload Documents
                           │ • Request Summaries/Flashcards/Quizzes
                           │ • Manage Tasks & Schedules
                           │ • Start Study Sessions (Pomodoro)
                           │ • View Performance Analytics
                           │
                           ▼
      ┌────────────────────────────────────────────────────────┐
      │                                                        │
      │            ISLA SYSTEM (Central Hub)                   │
      │     (Intelligent Study & Learning Assistant)           │
      │                                                        │
      │  ┌──────────────────────────────────────────────┐     │
      │  │  Core Processing Modules:                    │     │
      │  │                                              │     │
      │  │  • Authentication Management                 │     │
      │  │  • Document Management                       │     │
      │  │  • Lightweight NLP Processing (Internal):    │     │
      │  │    - TextRank (Summarization)                │     │
      │  │    - RAKE/YAKE (Keyword Extraction)          │     │
      │  │    - Flashcard & Quiz Generation             │     │
      │  │  • Study Planning & Scheduling               │     │
      │  │  • Pomodoro Timer                            │     │
      │  │  • Performance Analytics & GPA Calculator    │     │
      │  │  • Business Logic & Data Processing          │     │
      │  │                                              │     │
      │  └──────────────────────────────────────────────┘     │
      │                                                        │
      └─────────────────────┬──────────────────────────────────┘
                            │
                            │ Store/Retrieve:
                            │ • User Authentication Data
                            │ • Study Documents (PDF/PPTX/DOCX)
                            │ • Generated Study Aids (Summaries/Flashcards/Quizzes)
                            │ • Tasks & Schedules
                            │ • Study Session Records
                            │ • Performance Metrics
                            │
                            ▼
                   ┌─────────────────┐
                   │                 │
                   │    Firebase     │
                   │    Services     │
                   │                 │
                   │ • Authentication│
                   │ • Firestore DB  │
                   │ • Storage       │
                   │                 │
                   └─────────────────┘
                            │
                            │ Returns:
                            │ • Auth Status (Success/Failure)
                            │ • Stored Data (Tasks, Sessions, Grades)
                            │ • Retrieved Documents
                            │
                            ▼
                   (Back to ISLA System)
                            │
                            │ ISLA Processes & Formats Data
                            │
                            ▼
                     ┌─────────────┐
                     │   Student   │ Outputs:
                     │  Receives:  │ • Generated Summaries
                     │             │ • Flashcards
                     │             │ • Quiz Questions
                     │             │ • Task Reminders
                     │             │ • Study Statistics
                     │             │ • Performance Reports
                     └─────────────┘
```

### Key Architecture Principles:

1. **Self-Contained NLP Processing** - All AI-powered features (summarization, flashcards, quizzes) are processed **internally within the ISLA system** using lightweight extractive NLP algorithms implemented in Dart. No external AI APIs required.

2. **Offline-Capable** - Since NLP processing is done locally, the app can generate study aids even without internet connection (after initial document upload).

3. **Cost-Effective** - No API costs for AI processing. Uses open-source NLP algorithms (TextRank, RAKE, YAKE).

4. **Firebase as Data Layer Only** - Firebase handles authentication and data persistence. ISLA handles all business logic and NLP processing.

---

## Notes

1. **Prototype Scope:** The current prototype focuses on frontend UI/UX with mock data. Backend integration with Firebase and internal NLP processing will be implemented in future phases.

2. **Single User Role:** The system currently supports only one type of user (Student). No administrative or instructor roles are required.

3. **Internal NLP Implementation:** AI-powered features (summarization, flashcards, quiz generation) use **lightweight extractive NLP algorithms** implemented in Dart:
   - **TextRank** for text summarization
   - **RAKE (Rapid Automatic Keyword Extraction)** for keyword identification
   - **YAKE (Yet Another Keyword Extractor)** for enhanced keyword extraction
   - These algorithms run **within the ISLA app itself**, requiring no external AI services or API calls.

4. **Offline Capability:** The app is designed with offline-first principles. Study aid generation can occur locally without internet connection. Firebase is only needed for data synchronization and backup.

5. **Cost-Effectiveness:** By using internal NLP processing instead of cloud AI APIs, the system incurs no per-request AI costs, making it sustainable for student use.

6. **Security:** User authentication and data storage follow Firebase security best practices with proper authentication and authorization rules.
