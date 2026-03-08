# Firebase Firestore Integration

This app now supports remote configuration storage using Firebase Firestore.

## Setup Complete ✅

The following has been configured:

1. **Firebase Dependencies** - Added to `pubspec.yaml`
2. **Firebase Initialization** - Configured in `main.dart`
3. **Firestore Service** - Created `FirebaseConfigurationService`
4. **Repository Integration** - Updated `ConfigurationRepository` with Firebase sync methods
5. **UI Controls** - Added upload/download buttons to Beacon Management screen

## How to Use

### Upload Configuration to Firebase

1. Open the app
2. Go to **Configuration** → **Beacons**
3. Tap the **cloud upload icon** (☁️↑) in the top right
4. Your current configuration (beacons, nodes, routes, map) will be uploaded to Firestore

### Download Configuration from Firebase

1. Open the app
2. Go to **Configuration** → **Beacons**
3. Tap the **cloud download icon** (☁️↓) in the top right
4. Confirm the download (this will replace your local configuration)
5. The configuration from Firebase will be downloaded and saved locally

## Firestore Structure

Your configuration is stored in Firestore at:

```
Collection: navigation_configs
Document: default_config
```

The document contains:
- `mapConfig` - Map layout configuration
- `beacons` - Array of beacon configurations
- `nodes` - Array of navigation nodes
- `routes` - Array of predefined routes
- `updatedAt` - Server timestamp of last update
- `version` - Millisecond timestamp for versioning

## Firebase Console

You can view and manage your configuration data at:
https://console.firebase.google.com/project/beacons-app-fe70a/firestore

## Firestore Security Rules

**IMPORTANT:** Your Firestore is currently in **production mode** with default rules that deny all access.

You need to update your Firestore security rules to allow read/write access:

### Option 1: Public Read/Write (for testing only)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /navigation_configs/{document=**} {
      allow read, write: if true;
    }
  }
}
```

### Option 2: Authenticated Users Only (recommended)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /navigation_configs/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

To update rules:
1. Go to Firebase Console → Firestore Database → Rules
2. Paste the rules above
3. Click "Publish"

## Programmatic Access

You can also use the Firebase methods programmatically:

```dart
// Get the repository
final repository = context.read<ConfigurationRepository>();

// Upload to Firebase
await repository.uploadToFirebase();

// Download from Firebase
await repository.downloadFromFirebase();

// Sync (download if exists, otherwise use local)
await repository.syncWithFirebase();

// Check if Firebase config exists
bool exists = await repository.hasFirebaseConfig();

// Get last update time
DateTime? lastUpdate = await repository.getFirebaseUpdateTime();

// Stream real-time updates
Stream<NavigationConfig?>? stream = repository.streamFirebaseConfig();
```

## Using in Another App

When using this package in another app:

1. **Add your own Firebase project:**
   - Create a Firebase project
   - Add your app to the project
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the appropriate directories

2. **Initialize Firebase in your app:**
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     runApp(MyApp());
   }
   ```

3. **Inject FirebaseConfigurationService:**
   ```dart
   RepositoryProvider<ConfigurationRepository>(
     create: (_) => ConfigurationRepository(
       LocalConfigurationStorageService(),
       firebaseService: FirebaseConfigurationService(
         collectionName: 'navigation_configs',
         documentId: 'my_custom_config', // Optional: customize document ID
       ),
     ),
   ),
   ```

## Troubleshooting

### "Failed to upload to Firebase"
- Check your internet connection
- Verify Firestore security rules allow write access
- Check Firebase Console for error logs

### "Failed to download from Firebase"
- Check your internet connection
- Verify Firestore security rules allow read access
- Ensure the configuration document exists in Firestore

### "No configuration found in Firestore"
- Upload a configuration first using the upload button
- Or create the document manually in Firebase Console

## Next Steps

1. **Update Firestore Security Rules** (see above)
2. **Test Upload** - Upload your current configuration
3. **Test Download** - Download on another device or after clearing local data
4. **Monitor** - Check Firebase Console to see your data
