CRETCOM STUDY APP --> For the Andriod Users 😃
===============================================

I. 📘 Overview
----------------
Cretcom Study App is a structured academic organization system built specifically for semester-based education systems.

This application is not a cloud storage service and not a generic note-taking app.
It functions as a structured academic interface layer on top of each user’s personal Google Drive.

All academic content — including notes, images, PDFs, and question banks — is stored directly in the user’s own Google Drive. The application does not store academic files on any external server or centralized database.

II. 🎯 Core Objective
-----------------------
To provide exam-oriented, unit-wise structured academic organization with minimal user effort and fast revision capability.

III. 🔐 Storage Architecture
------------------------------
1. Users authenticate using Google Sign-In (OAuth).
2. All data is stored inside the user’s personal Google Drive.
3. Folder IDs are managed internally to maintain structure integrity even if folder names are changed.
    This ensures:
            Full data ownership by the user
            No hosting cost 😁
            No dependency on external storage systems 🤓
            High privacy and security
            Personalized Storing of documents
            Can store PDFs, DOCXs, PPTs, Images (jpg, jpeg, png, gif)

IV. 🏗 Academic Structure
--------------------------
The app organizes content in a structured hierarchy:

Academic Level
→ Year
→ Semester
→ Subject (User-created)
→ Units (Auto-generated)
→ Notes / Question Banks / Images / PDFs

When a subject is created, the app automatically generates:
    → Unit I
    → Unit II
    → Unit III
    → Unit IV
    → Unit V

This reduces manual effort and aligns with common semester-based academic patterns. 😇

V. ✍ Features
---------------
    => Google Sign-In Authentication
    => Automatic subject-based unit creation
    => Rich text note storage (supports copy-paste from AI tools)
    => Image uploads (diagrams, handwritten notes)
    => PDF, DOCX, PPTs, Images (jpg, jpeg, png, gif)
    => Structured unit-wise organization
    => Minimal user effort for maximum efficiency
    => Direct integration with Google Drive API

VI. 💡 Motive behind this idea
-------------------------------
Students often struggle to organize academic materials effectively. Notes, PDFs, question banks, and images are usually scattered across file managers, messaging apps, and downloads folders. Managing them manually becomes inefficient, especially during exam preparation.

Many students do not maintain structured folders for years, semesters, subjects, and units. Even when they do, searching and revising content quickly is difficult.

The idea behind Cretcom Study App is to provide a structured, semester-based academic organization system that reduces manual effort and improves revision speed — while ensuring that all data remains securely stored in the student’s own Google Drive.

The goal is to simplify academic organization, make unit-wise revision easier, and create a focused, exam-oriented digital study environment.

VII. 🚀 Future Scope
----------------------
    --> Integration of an AI-based assistant (ChatGPT-like model) for academic support
    --> Unit-wise answer generation and explanation support
    --> Ability to save AI-generated content directly into the respective unit folders in Google Drive