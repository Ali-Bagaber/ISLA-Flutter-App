# Chapter 3: System Design

## 3.2 Use Case Diagram

### Overview
This section presents the use case diagram and detailed descriptions for the ISLA (Intelligent Study and Learning Assistant) system, showing all possible interactions between the student user and the system.

---

## Use Case Diagram

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                                                             │
                    │                    ISLA SYSTEM                              │
                    │                                                             │
                    │  ┌────────────────────────────────────────────────────┐    │
                    │  │                                                    │    │
                    │  │  UC01: Login/Register                              │    │
┌──────────┐        │  │                                                    │    │
│          │◄───────┼──┤  UC02: Upload Study Documents                     │    │
│          │        │  │                                                    │    │
│ Student  │        │  │  UC03: Generate Summary (TextRank)                │    │
│  (User)  │◄───────┼──┤                                                    │    │
│          │        │  │  UC04: Generate Flashcards (RAKE/YAKE)            │    │
│          │        │  │                                                    │    │
│          │◄───────┼──┤  UC05: Generate Quiz Questions                    │    │
└──────────┘        │  │                                                    │    │
                    │  │  UC06: Create Task                                 │    │
                    │  │                                                    │    │
                    │  │  UC07: Update Task                                 │    │
                    │  │                                                    │    │
                    │  │  UC08: Delete Task                                 │    │
                    │  │                                                    │    │
                    │  │  UC09: View Tasks Calendar                         │    │
                    │  │                                                    │    │
                    │  │  UC10: Start Study Session (Pomodoro)              │    │
                    │  │                                                    │    │
                    │  │  UC11: View Study Statistics                       │    │
                    │  │                                                    │    │
                    │  │  UC12: Calculate GPA/CGPA                          │    │
                    │  │                                                    │    │
                    │  │  UC13: View Performance Analytics                  │    │
                    │  │                                                    │    │
                    │  │  UC14: Toggle Theme (Dark/Light)                   │    │
                    │  │                                                    │    │
                    │  │  UC15: View Document Library                       │    │
                    │  │                                                    │    │
                    │  └────────────────────────────────────────────────────┘    │
                    │                                                             │
                    └─────────────────────────────────────────────────────────────┘
```

---

## Use Case Descriptions

### UC01: Login/Register

**Use Case ID:** UC01  
**Use Case Name:** Login/Register  
**Actor:** Student  
**Description:** Student authenticates themselves to access the ISLA system or creates a new account.

**Preconditions:**
- Student has internet connection
- Firebase Authentication service is available

**Postconditions:**
- Student is authenticated and logged into the system
- Session token is generated and stored

**Main Flow:**
1. Student opens the ISLA application
2. System displays login screen
3. Student enters email and password
4. Student clicks "Login" button
5. System validates credentials with Firebase Authentication
6. Firebase returns authentication success
7. System loads user profile and navigates to Home screen
8. Use case ends

**Alternative Flow 1: Registration**
1. At step 3, student clicks "Register" link
2. System displays registration form
3. Student enters name, email, password, and confirms password
4. Student clicks "Register" button
5. System validates input fields
6. System creates new account in Firebase Authentication
7. System creates user profile in Cloud Firestore
8. System navigates to Home screen
9. Use case ends

**Exception Flow 1: Invalid Credentials**
1. At step 6, Firebase returns authentication failure
2. System displays error message "Invalid email or password"
3. Return to step 2

**Exception Flow 2: Network Error**
1. At step 5, network connection fails
2. System displays error message "Unable to connect. Please check your internet connection"
3. Return to step 2

---

### UC02: Upload Study Documents

**Use Case ID:** UC02  
**Use Case Name:** Upload Study Documents  
**Actor:** Student  
**Description:** Student uploads study materials (PDF, PPTX, DOCX) to the system for AI processing.

**Preconditions:**
- Student is logged in
- Student has document file to upload

**Postconditions:**
- Document is stored in Firebase Storage
- Document metadata is saved in Cloud Firestore
- Document appears in student's document library

**Main Flow:**
1. Student navigates to Documents screen
2. Student clicks "Upload" button
3. System displays file picker dialog
4. Student selects document file (PDF/PPTX/DOCX)
5. System validates file type and size
6. System displays upload progress indicator
7. System uploads file to Firebase Storage
8. System extracts document metadata (title, pages, file size)
9. System saves metadata to Cloud Firestore
10. System displays success message
11. Document appears in library list
12. Use case ends

**Alternative Flow 1: Upload Multiple Documents**
1. At step 4, student selects multiple files
2. System uploads files sequentially
3. Continue to step 6 for each file

**Exception Flow 1: Invalid File Type**
1. At step 5, system detects unsupported file type
2. System displays error "Only PDF, PPTX, and DOCX files are supported"
3. Return to step 3

**Exception Flow 2: File Too Large**
1. At step 5, system detects file exceeds 10MB limit
2. System displays error "File size must be less than 10MB"
3. Return to step 3

**Exception Flow 3: Upload Failed**
1. At step 7, network error occurs during upload
2. System displays error "Upload failed. Please try again"
3. Return to step 2

---

### UC03: Generate Summary (TextRank)

**Use Case ID:** UC03  
**Use Case Name:** Generate Summary  
**Actor:** Student  
**Description:** Student generates an extractive summary of a study document using TextRank algorithm.

**Preconditions:**
- Student is logged in
- At least one document is uploaded
- Document text can be extracted

**Postconditions:**
- Summary is generated and displayed
- Summary is saved in Cloud Firestore for future access

**Main Flow:**
1. Student navigates to Documents screen
2. Student selects a document from library
3. System displays document detail screen
4. Student clicks "Generate Summary" button
5. System displays processing indicator
6. System retrieves document from Firebase Storage
7. System extracts text from document
8. System applies TextRank algorithm to extract key sentences
9. System ranks sentences by importance
10. System generates summary (top 5-10 sentences)
11. System saves generated summary to Cloud Firestore
12. System displays summary in readable format
13. Use case ends

**Alternative Flow 1: View Existing Summary**
1. At step 4, if summary already exists
2. System retrieves saved summary from Cloud Firestore
3. Skip to step 12

**Exception Flow 1: Text Extraction Failed**
1. At step 7, system cannot extract text from document
2. System displays error "Unable to process this document. Please ensure it contains readable text"
3. Use case ends

**Exception Flow 2: Document Too Short**
1. At step 8, document contains fewer than 5 sentences
2. System displays message "Document is too short to summarize"
3. Use case ends

---

### UC04: Generate Flashcards (RAKE/YAKE)

**Use Case ID:** UC04  
**Use Case Name:** Generate Flashcards  
**Actor:** Student  
**Description:** Student generates flashcards from document using RAKE/YAKE keyword extraction algorithms.

**Preconditions:**
- Student is logged in
- At least one document is uploaded
- Document contains extractable keywords

**Postconditions:**
- Flashcards are generated and displayed
- Flashcards are saved in Cloud Firestore

**Main Flow:**
1. Student navigates to Documents screen
2. Student selects a document
3. System displays document detail screen
4. Student clicks "Generate Flashcards" button
5. System displays processing indicator
6. System retrieves document from Firebase Storage
7. System extracts text from document
8. System applies RAKE algorithm to identify keyword phrases
9. System applies YAKE algorithm for enhanced keyword scoring
10. System creates flashcards (Front: keyword, Back: context/definition)
11. System saves flashcards to Cloud Firestore
12. System displays flashcards in study mode
13. Use case ends

**Alternative Flow 1: Review Existing Flashcards**
1. At step 4, if flashcards already exist
2. System retrieves saved flashcards
3. Skip to step 12

**Alternative Flow 2: Customize Number of Flashcards**
1. At step 4, student selects number of flashcards (10/20/30)
2. System generates specified number of flashcards
3. Continue to step 5

**Exception Flow 1: Insufficient Keywords**
1. At step 8-9, system finds fewer than 5 keywords
2. System displays message "Not enough content to generate flashcards"
3. Use case ends

---

### UC05: Generate Quiz Questions

**Use Case ID:** UC05  
**Use Case Name:** Generate Quiz Questions  
**Actor:** Student  
**Description:** Student generates multiple-choice quiz questions from document content.

**Preconditions:**
- Student is logged in
- At least one document is uploaded

**Postconditions:**
- Quiz questions are generated and displayed
- Quiz is saved in Cloud Firestore
- Student can attempt the quiz

**Main Flow:**
1. Student navigates to Documents screen
2. Student selects a document
3. System displays document detail screen
4. Student clicks "Generate Quiz" button
5. System displays processing indicator
6. System retrieves document from Firebase Storage
7. System extracts text and identifies key concepts
8. System generates multiple-choice questions using keyword extraction
9. System creates 3 distractor options for each question
10. System saves quiz to Cloud Firestore
11. System displays quiz interface
12. Student answers questions
13. System calculates and displays score
14. Use case ends

**Alternative Flow 1: Retake Existing Quiz**
1. At step 4, if quiz already exists
2. System retrieves saved quiz
3. System resets previous answers
4. Skip to step 11

**Exception Flow 1: Content Insufficient for Quiz**
1. At step 7, system cannot identify enough concepts
2. System displays message "Document content is insufficient for quiz generation"
3. Use case ends

---

### UC06: Create Task

**Use Case ID:** UC06  
**Use Case Name:** Create Task  
**Actor:** Student  
**Description:** Student creates a new study task (assignment, exam, revision).

**Preconditions:**
- Student is logged in

**Postconditions:**
- Task is created and saved in Cloud Firestore
- Task appears in planner view

**Main Flow:**
1. Student navigates to Planner screen
2. Student clicks "Add Task" button (FAB)
3. System displays task creation form
4. Student enters task details:
   - Task title
   - Subject code (e.g., BCS2033)
   - Task type (Assignment/Exam/Revision)
   - Due date
   - Priority (High/Medium/Low)
   - Description (optional)
5. Student clicks "Save" button
6. System validates input fields
7. System saves task to Cloud Firestore
8. System displays success message
9. Task appears in list and calendar views
10. Use case ends

**Alternative Flow 1: Set Reminder**
1. At step 4, student enables reminder toggle
2. Student selects reminder time (1 day before, 1 week before, etc.)
3. Continue to step 5

**Exception Flow 1: Missing Required Fields**
1. At step 6, required fields are empty
2. System highlights missing fields
3. System displays error "Please fill all required fields"
4. Return to step 4

---

### UC07: Update Task

**Use Case ID:** UC07  
**Use Case Name:** Update Task  
**Actor:** Student  
**Description:** Student modifies an existing task's details or marks it as complete.

**Preconditions:**
- Student is logged in
- At least one task exists

**Postconditions:**
- Task is updated in Cloud Firestore
- Changes are reflected in planner view

**Main Flow:**
1. Student navigates to Planner screen
2. Student views task list
3. Student taps on a task
4. System displays task details
5. Student clicks "Edit" button
6. System displays editable task form
7. Student modifies task details
8. Student clicks "Save" button
9. System validates input
10. System updates task in Cloud Firestore
11. System displays success message
12. Updated task appears in list
13. Use case ends

**Alternative Flow 1: Mark as Complete**
1. At step 3, student taps checkbox on task
2. System marks task as completed
3. System updates completion status in Cloud Firestore
4. Task moves to completed section
5. Use case ends

**Alternative Flow 2: Unmark Complete**
1. At step 3, student taps checkbox on completed task
2. System marks task as pending
3. Task moves back to pending section
4. Use case ends

---

### UC08: Delete Task

**Use Case ID:** UC08  
**Use Case Name:** Delete Task  
**Actor:** Student  
**Description:** Student removes a task from the system.

**Preconditions:**
- Student is logged in
- At least one task exists

**Postconditions:**
- Task is deleted from Cloud Firestore
- Task is removed from planner view

**Main Flow:**
1. Student navigates to Planner screen
2. Student views task list
3. Student long-presses on a task OR taps delete icon
4. System displays confirmation dialog "Are you sure you want to delete this task?"
5. Student clicks "Delete" button
6. System deletes task from Cloud Firestore
7. System displays success message "Task deleted"
8. Task disappears from list
9. Use case ends

**Alternative Flow 1: Cancel Deletion**
1. At step 5, student clicks "Cancel" button
2. Dialog closes
3. Use case ends

---

### UC09: View Tasks Calendar

**Use Case ID:** UC09  
**Use Case Name:** View Tasks Calendar  
**Actor:** Student  
**Description:** Student views tasks in calendar format to see upcoming deadlines.

**Preconditions:**
- Student is logged in

**Postconditions:**
- Calendar view displays tasks organized by due dates

**Main Flow:**
1. Student navigates to Planner screen
2. Student switches to "Calendar" tab
3. System retrieves all tasks from Cloud Firestore
4. System displays monthly calendar
5. System marks dates with tasks using colored indicators
6. Student selects a date
7. System displays tasks for selected date
8. Student can view task details or mark as complete
9. Use case ends

**Alternative Flow 1: Navigate to Different Month**
1. At step 5, student swipes to previous/next month
2. System updates calendar display
3. Continue to step 6

---

### UC10: Start Study Session (Pomodoro)

**Use Case ID:** UC10  
**Use Case Name:** Start Study Session  
**Actor:** Student  
**Description:** Student starts a timed study session using Pomodoro technique (25 min work, 5 min break).

**Preconditions:**
- Student is logged in

**Postconditions:**
- Study session is tracked and recorded
- Session data is saved to Cloud Firestore
- Study statistics are updated

**Main Flow:**
1. Student navigates to Timer screen
2. Student selects subject (e.g., BCS2033)
3. Student clicks "Start" button
4. System starts 25-minute countdown timer
5. System displays current time and progress
6. Timer counts down to 0:00
7. System plays notification sound
8. System displays "Break Time" message
9. System starts 5-minute break timer
10. Break timer completes
11. System records session data (subject, duration, date)
12. System saves session to Cloud Firestore
13. System updates daily/weekly statistics
14. Use case ends

**Alternative Flow 1: Pause Session**
1. At step 5, student clicks "Pause" button
2. System pauses timer
3. Student clicks "Resume" button
4. System resumes timer
5. Continue to step 6

**Alternative Flow 2: Stop Session Early**
1. At step 5, student clicks "Stop" button
2. System displays confirmation dialog
3. Student confirms stop
4. System records partial session
5. Continue to step 11

**Alternative Flow 3: Skip Break**
1. At step 9, student clicks "Skip Break" button
2. System stops break timer
3. Continue to step 11

---

### UC11: View Study Statistics

**Use Case ID:** UC11  
**Use Case Name:** View Study Statistics  
**Actor:** Student  
**Description:** Student views their study time statistics and patterns.

**Preconditions:**
- Student is logged in
- At least one study session has been completed

**Postconditions:**
- Statistics are displayed in graphical format

**Main Flow:**
1. Student navigates to Timer or Dashboard screen
2. System retrieves study session data from Cloud Firestore
3. System calculates statistics:
   - Total study time (today/this week/this month)
   - Study time per subject
   - Study streak (consecutive days)
   - Most productive time of day
   - Average session length
4. System displays statistics with charts:
   - Bar chart (weekly study hours)
   - Pie chart (time distribution by subject)
   - Line chart (study trend over time)
5. Student can filter by date range or subject
6. Use case ends

**Alternative Flow 1: No Data Available**
1. At step 2, no study sessions found
2. System displays message "No study data yet. Start your first study session!"
3. Use case ends

---

### UC12: Calculate GPA/CGPA

**Use Case ID:** UC12  
**Use Case Name:** Calculate GPA/CGPA  
**Actor:** Student  
**Description:** Student enters their grades and the system calculates GPA and CGPA.

**Preconditions:**
- Student is logged in

**Postconditions:**
- Grades are saved in Cloud Firestore
- GPA and CGPA are calculated and displayed

**Main Flow:**
1. Student navigates to Dashboard screen
2. Student clicks "GPA Calculator" card
3. System displays GPA calculator form
4. Student enters grade information for each subject:
   - Subject code (e.g., BCS2033)
   - Grade (A+, A, A-, B+, B, B-, C+, C, D, F)
   - Credit hours (1-4)
5. Student clicks "Add Subject" to add more subjects
6. Student clicks "Calculate" button
7. System converts letter grades to grade points:
   - A+ = 4.00, A = 4.00, A- = 3.67
   - B+ = 3.33, B = 3.00, B- = 2.67
   - C+ = 2.33, C = 2.00
   - D = 1.67, F = 0.00
8. System calculates GPA: (Σ grade points × credit hours) / Σ credit hours
9. System calculates CGPA if previous semesters exist
10. System saves grades to Cloud Firestore
11. System displays GPA and CGPA with visual indicators
12. Use case ends

**Alternative Flow 1: View Grade Trend**
1. At step 11, student clicks "View Trend" button
2. System displays semester-by-semester GPA chart
3. Use case ends

---

### UC13: View Performance Analytics

**Use Case ID:** UC13  
**Use Case Name:** View Performance Analytics  
**Actor:** Student  
**Description:** Student views comprehensive performance dashboard with study metrics and academic progress.

**Preconditions:**
- Student is logged in

**Postconditions:**
- Dashboard displays all performance metrics

**Main Flow:**
1. Student navigates to Dashboard screen
2. System retrieves data from Cloud Firestore:
   - Current GPA/CGPA
   - Total study time (this week)
   - Number of completed tasks
   - Number of study sessions
   - Document count
   - Quiz attempts
3. System calculates performance indicators:
   - Study time by subject (progress bars)
   - Daily activity (bar chart for past 7 days)
   - Task completion rate
   - GPA trend (increase/decrease)
4. System displays dashboard with:
   - Summary cards (GPA, study time, sessions, documents)
   - Subject progress bars
   - Weekly activity chart
   - Quick action buttons
5. Student can tap cards for detailed views
6. Use case ends

---

### UC14: Toggle Theme (Dark/Light)

**Use Case ID:** UC14  
**Use Case Name:** Toggle Theme  
**Actor:** Student  
**Description:** Student switches between dark and light theme for comfortable viewing.

**Preconditions:**
- Student is using the application

**Postconditions:**
- Theme preference is applied across all screens
- Preference is saved locally

**Main Flow:**
1. Student views any screen in the app
2. Student taps theme toggle icon (sun/moon) in header
3. System switches theme:
   - Dark theme → Light theme (or vice versa)
4. System applies new theme colors:
   - Background colors
   - Card colors
   - Text colors
5. System saves preference to local storage
6. Theme persists across app sessions
7. Use case ends

---

### UC15: View Document Library

**Use Case ID:** UC15  
**Use Case Name:** View Document Library  
**Actor:** Student  
**Description:** Student views all uploaded documents with filtering and search capabilities.

**Preconditions:**
- Student is logged in

**Postconditions:**
- Document library is displayed with all available documents

**Main Flow:**
1. Student navigates to Documents screen
2. System retrieves document metadata from Cloud Firestore
3. System displays document list with:
   - Document title
   - Subject tag
   - File type icon (PDF/PPTX/DOCX)
   - Upload date
   - Thumbnail (if available)
4. Student can filter documents by:
   - Subject (All/BCS2033/BCS3012/etc.)
   - File type (All/PDF/PPTX/DOCX)
5. Student can search by document name
6. Student taps document to view details
7. Use case ends

**Alternative Flow 1: Empty Library**
1. At step 2, no documents found
2. System displays empty state with "Upload your first document" message
3. Student can click "Upload" button
4. Continue to UC02

**Alternative Flow 2: Delete Document**
1. At step 6, student taps delete icon
2. System displays confirmation dialog
3. Student confirms deletion
4. System deletes document from Firebase Storage and metadata from Cloud Firestore
5. Document removed from list
6. Use case ends

---

## Use Case Priority

### High Priority (Must Have - MVP):
- UC01: Login/Register
- UC02: Upload Study Documents
- UC03: Generate Summary
- UC10: Start Study Session (Pomodoro)
- UC13: View Performance Analytics
- UC15: View Document Library

### Medium Priority (Should Have):
- UC04: Generate Flashcards
- UC05: Generate Quiz Questions
- UC06: Create Task
- UC07: Update Task
- UC11: View Study Statistics

### Low Priority (Nice to Have):
- UC08: Delete Task
- UC09: View Tasks Calendar
- UC12: Calculate GPA/CGPA
- UC14: Toggle Theme

---

## Use Case Relationships

### Includes:
- UC03, UC04, UC05 → **include** → UC02 (requires document to be uploaded first)
- UC11 → **include** → UC10 (statistics depend on study sessions)
- UC13 → **include** → UC10, UC06, UC12 (dashboard aggregates data from multiple sources)

### Extends:
- UC07 → **extends** → UC06 (updating task is an extension of task management)
- UC08 → **extends** → UC06 (deleting task is an extension of task management)

---

## Actor-Use Case Matrix

| Actor | UC01 | UC02 | UC03 | UC04 | UC05 | UC06 | UC07 | UC08 | UC09 | UC10 | UC11 | UC12 | UC13 | UC14 | UC15 |
|-------|------|------|------|------|------|------|------|------|------|------|------|------|------|------|------|
| Student | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Firebase | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | - | ✓ |

---

## Notes

1. **NLP Processing is Internal**: All use cases involving AI (UC03, UC04, UC05) use internal lightweight NLP algorithms (TextRank, RAKE, YAKE) implemented in Dart. No external AI APIs are called.

2. **Offline Capability**: UC03, UC04, UC05 can work offline after initial document download, as NLP processing happens locally.

3. **Firebase Dependency**: Most use cases require Firebase for data persistence, but core NLP functionality is independent.

4. **User Experience Focus**: All use cases are designed for mobile-first experience with responsive design principles.
