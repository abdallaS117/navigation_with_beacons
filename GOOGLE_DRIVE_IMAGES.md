# Google Drive Image Integration

Your app now supports using Google Drive images for map backgrounds!

## How It Works

The app can display map images from:
1. **Local files** - Traditional file paths
2. **Google Drive URLs** - Direct links from your public folder
3. **Any web URL** - Standard HTTP/HTTPS image URLs

## Your Public Google Drive Folder

Folder URL: https://drive.google.com/drive/folders/1Oe9toMK9XOX6glncT7srbEe6wBO3tjys

## How to Use Google Drive Images

### Step 1: Upload Image to Google Drive

1. Go to your public folder: https://drive.google.com/drive/folders/1Oe9toMK9XOX6glncT7srbEe6wBO3tjys
2. Click **New** → **File upload**
3. Upload your map image (PNG, JPG, etc.)

### Step 2: Get the Shareable Link

1. Right-click on the uploaded image
2. Click **Get link** or **Share**
3. Make sure it's set to **Anyone with the link can view**
4. Copy the link (it will look like this):
   ```
   https://drive.google.com/file/d/1ABC123xyz/view?usp=sharing
   ```

### Step 3: Use in Configuration

You have two options:

#### Option A: Use the shareable link directly
Just paste the Google Drive link into the `imagePath` field in your configuration. The app will automatically convert it to a direct link.

#### Option B: Convert to direct link manually
Use the `GoogleDriveService` to convert:

```dart
import 'package:beacon_navigation/features/configuration/data/services/google_drive_service.dart';

// From shareable link
String shareableLink = 'https://drive.google.com/file/d/1ABC123xyz/view?usp=sharing';
String? directLink = GoogleDriveService.convertToDirectLink(shareableLink);

// Or from file ID
String fileId = '1ABC123xyz';
String directLink = GoogleDriveService.generateDirectLink(fileId);
```

### Step 4: Save to Firebase

The Google Drive link will be saved to Firebase along with your configuration and automatically synced to all devices.

## Updating Map Configuration

### Via Code:
```dart
final mapConfig = MapLayoutConfig(
  id: 'hospital_floor_1',
  name: 'Hospital Floor 1',
  imagePath: 'https://drive.google.com/file/d/YOUR_FILE_ID/view',
  width: 1000,
  height: 800,
);

await configurationCubit.updateMapConfig(mapConfig);
```

### Via Firebase Console:
1. Go to Firestore: https://console.firebase.google.com/project/beacons-app-fe70a/firestore
2. Navigate to `navigation_configs/default_config`
3. Edit the `mapConfig.imagePath` field
4. Paste your Google Drive link
5. Save

The app will automatically load the image from Google Drive on next startup!

## Floor-Specific Images

You can also set different images for each floor:

```dart
final floorConfig = FloorConfig(
  floorNumber: 1,
  name: 'Ground Floor',
  imagePath: 'https://drive.google.com/file/d/FLOOR1_FILE_ID/view',
);
```

## SmartMapImage Widget

The app uses `SmartMapImage` widget which automatically detects the image source:

```dart
SmartMapImage(
  imagePath: 'https://drive.google.com/file/d/123/view', // Google Drive
  width: 800,
  height: 600,
  fit: BoxFit.cover,
)
```

Features:
- ✅ Automatic source detection (local file vs URL)
- ✅ Google Drive link conversion
- ✅ Loading indicator
- ✅ Error handling with fallback UI
- ✅ Works with `Network.image` for remote images

## Supported Link Formats

The app recognizes these Google Drive link formats:

1. **Shareable link**: `https://drive.google.com/file/d/FILE_ID/view?usp=sharing`
2. **Open link**: `https://drive.google.com/open?id=FILE_ID`
3. **Direct link**: `https://drive.google.com/uc?export=view&id=FILE_ID`
4. **File ID only**: `FILE_ID`

All formats are automatically converted to the direct link format for `Network.image`.

## Benefits

✅ **No local storage** - Images stored in the cloud  
✅ **Easy updates** - Just replace the image in Drive  
✅ **Multi-device sync** - All devices use the same image  
✅ **Bandwidth efficient** - Images loaded on demand  
✅ **Public access** - No authentication needed  

## Troubleshooting

### Image not loading?
- Check that the Drive link is set to "Anyone with the link can view"
- Verify the file ID is correct
- Check your internet connection
- Look for error messages in the console

### Wrong image displayed?
- Clear app cache
- Verify the correct link in Firebase configuration
- Check that you uploaded the right image to Drive

### Slow loading?
- Large images take time to download
- Consider compressing your map images
- Use appropriate image dimensions (not too large)

## Example Workflow

1. **Design your map** in any tool (Photoshop, Figma, etc.)
2. **Export as PNG/JPG** (recommended: 1000-2000px width)
3. **Upload to Google Drive** public folder
4. **Get shareable link** from Drive
5. **Update configuration** with the link
6. **Save to Firebase** using the upload button
7. **All devices** automatically get the new map!

## Next Steps

- Upload your hospital floor plans to the Drive folder
- Update your configuration with the Drive links
- Save to Firebase
- Test on multiple devices to verify sync

Your map images are now cloud-based and automatically synced across all devices! 🎉
