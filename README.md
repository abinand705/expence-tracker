# MoneyTrack

MoneyTrack is a powerful Flutter application for tracking expenses and managing finances. It features an automated SMS synchronization engine that parses bank messages and securely stores transactions in Firebase Firestore.

## Features
- **Automated SMS Sync**: Automatically reads and parses financial SMS messages (debits/credits).
- **Manual Transactions**: Add custom expenses and income.
- **Budgeting**: Set and monitor budget limits by category.
- **Recurring Expenses**: Manage subscriptions and repeating bills.
- **Categorization**: Auto-categorize SMS transactions based on merchant names.
- **Analytics**: Beautiful charts to visualize spending trends.
- **Multi-device Sync**: Real-time cloud sync powered by Firebase.

## Architecture
MoneyTrack follows a clean architecture using the Repository pattern with Firebase as the backend.
- **UI Layer**: Flutter widgets, using StreamBuilders for real-time updates.
- **Service Layer**: Business logic for SMS parsing (`ExpenseParser`, `SmsTransactionImporter`), analytics, and recurring expenses.
- **Repository Layer**: Abstraction over Firestore collections (`TransactionRepository`, `UserRepository`, etc.).
- **Data Models**: Strongly typed Dart classes representing Firestore documents.

## Firebase Setup
1. Create a Firebase project.
2. Enable **Authentication** (Google / Email).
3. Enable **Firestore Database** and create a database instance named `moneytrack`.
4. Deploy the Firestore rules from `firestore.rules`.
5. Run `flutterfire configure` to generate `firebase_options.dart`.

## Firestore Structure
Data is strictly isolated per user under the `users/{userId}` path:
- `users/{uid}`: User profile data
  - `transactions/{txId}`: Individual transactions (manual & SMS)
  - `accounts/{accountId}`: User accounts/cards
  - `categories/{categoryId}`: Custom categories
  - `budgets/{budgetId}`: Budget definitions
  - `recurring_expenses/{id}`: Recurring bills

## Authentication
Authentication is handled via Firebase Auth. The `AuthWrapper` widget automatically manages the lifecycle, seamlessly transitioning users between the `SplashLoginScreen` and `MainLayout`. When a user logs out, all data streams are detached, ensuring no cross-user data leakage in memory or UI.

## SMS Sync
The SMS Sync engine reads messages and identifies financial transactions.
1. `ExpenseParser` analyzes the message text using Regular Expressions, safely escaping literals (like `dr\.` and `cr\.`).
2. A deterministic SHA-256 fingerprint is generated for each parsed message: `sms_{fingerprint}`.
3. This fingerprint acts as the Firestore Document ID, ensuring that repeated syncing is purely idempotent and never duplicates transactions.

## Security
Security is enforced strictly at the database level using Firestore Security Rules:
```javascript
match /databases/{database}/documents {
  match /users/{userId} {
    allow read, write: if request.auth != null && request.auth.uid == userId;
    // Nested collections inherit this uid matching requirement.
  }
}
```
Client-side repositories always use `FirebaseAuth.instance.currentUser.uid` for path generation.

## Testing
To run the comprehensive test suite (Unit and Integration):
```bash
flutter test
```
To analyze the codebase for linting issues:
```bash
flutter analyze
```

## Android Build Instructions
To build the debug APK for testing on an Android device:
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

## Known Limitations
- SMS sync requires explicit Android SMS permissions.
- iOS does not support background SMS reading due to platform restrictions; SMS sync is Android-only.
- The `ExpenseParser` relies on known Indian banking message formats and might need regex adjustments for other regions.
