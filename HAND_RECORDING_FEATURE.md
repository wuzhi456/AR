# Hand Motion Recording Feature

## Overview

This feature allows users to record their hand motions during gameplay and replay them later as guidance for subsequent play sessions.

## How to Use

### Recording Hand Motions

1. Launch the HappyBeam game
2. Select "Play Solo" from the start screen
3. Choose your preferred input method (hand gestures or alternative controls)
4. On the recording mode selection screen, select "Record"
5. Play the game as normal - your hand motions will be automatically recorded
6. When the game ends, the recording will be automatically saved to the Documents directory

### Playing Back Recorded Motions

1. Launch the HappyBeam game
2. Select "Play Solo" from the start screen
3. Choose your preferred input method
4. On the recording mode selection screen, select "Playback"
5. A file selector will appear showing all available recordings
6. Select the recording you want to use as guidance
7. During gameplay, you will see visual indicators (yellow/orange spheres) showing the recorded hand positions
8. Follow these visual guides to recreate the recorded gameplay

### Normal Play (No Recording)

1. Launch the HappyBeam game
2. Select "Play Solo" from the start screen
3. Choose your preferred input method
4. On the recording mode selection screen, select "Normal Play"
5. Play the game without any recording or playback functionality

## Technical Details

### File Format

Recordings are saved as JSON files in the following format:
- Filename: `HandPose_YYYYMMDD_HHMMSS.json`
- Location: App's Documents directory
- Structure: Contains timestamped samples of hand joint positions and orientations

### Data Structure

Each recording contains:
- **Version**: Format version number
- **Created At**: Timestamp when recording was created
- **Samples**: Array of hand pose samples, each containing:
  - **Timestamp**: Relative time from recording start
  - **Left Hand Joints**: Array of joint poses for the left hand
  - **Right Hand Joints**: Array of joint poses for the right hand

Each joint pose includes:
- **Name**: Joint identifier (e.g., "thumbTip", "indexFingerTip")
- **Position**: 3D position [x, y, z]
- **Orientation**: Quaternion rotation [ix, iy, iz, r]

### Implementation Components

1. **HandRecordingManager**: Manages recording and playback state
2. **GameModel**: Extended with recording mode options
3. **Lobby View**: UI for selecting recording mode
4. **HappyBeamSpace**: Integration with hand tracking and visualization

## Code Changes

### New Files
- `HappyBeam/Gameplay/HandRecordingManager.swift`: Core recording/playback manager

### Modified Files
- `HappyBeam/GameModel.swift`: Added recording mode state
- `HappyBeam/Views/Lobby.swift`: Added recording mode selection UI
- `HappyBeam/HappyBeamSpace.swift`: Integrated recording and playback visualization
- `HappyBeam.xcodeproj/project.pbxproj`: Added new file to project

## Visual Indicators

During playback mode:
- **Yellow spheres**: Left hand joint positions from recording
- **Orange spheres**: Right hand joint positions from recording

These spheres follow the recorded hand motions in real-time, allowing users to see where they should position their hands.

## Limitations

- Recordings are device-local and cannot be shared between devices
- Playback shows hand positions but doesn't control the game automatically
- Recording mode is only available in solo play mode
- Hand tracking must be authorized for recording to work properly
