# Liquid Glass Implementation Guide

A comprehensive guide to implementing the **iOS 26-style Liquid Glass** effect in Flutter using the `liquid_glass_easy` package. This guide includes real-world examples from the Liquid Glass Photos app.

---

## Table of Contents

1. [Installation](#installation)
2. [Core Concepts](#core-concepts)
3. [Use Cases with Examples](#use-cases-with-examples)
   - [Navigation Bar](#1-navigation-bar)
   - [Floating Buttons](#2-floating-buttons)
   - [Context Menus](#3-context-menus)
   - [Dialogs & Overlays](#4-dialogs--overlays)
   - [Cards](#5-cards)
4. [Customizable Parameters](#customizable-parameters)
5. [Best Practices](#best-practices)
6. [Common Issues & Solutions](#common-issues--solutions)

---

## Installation

Add to `pubspec.yaml`:
```yaml
dependencies:
  liquid_glass_easy: ^1.1.1
```

Run:
```bash
flutter pub get
```

Import:
```dart
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
```

---

## Core Concepts

### The Two-Component Architecture

Liquid Glass requires **two** components working together:

```
┌──────────────────────────────────────────────────────┐
│  LiquidGlassView (Container)                         │
│  ┌─────────────────────────────────────────────────┐ │
│  │ backgroundWidget: Your screen content           │ │
│  │ (photos, lists, text - what shows behind glass) │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  children: [                                         │
│    ┌──────────────────────┐                          │
│    │ LiquidGlass (Lens)   │ ← Floating glass overlay │
│    │ - blur effect        │                          │
│    │ - distortion         │                          │
│    │ - your UI content    │                          │
│    └──────────────────────┘                          │
│  ]                                                   │
└──────────────────────────────────────────────────────┘
```

### LiquidGlassView (Container)

Wraps your entire screen. Everything visible "behind" the glass goes in `backgroundWidget`.

```dart
LiquidGlassView(
  backgroundWidget: YourScrollableContent(), // What's behind the glass
  realTimeCapture: true,                      // For scrolling content
  children: [
    // LiquidGlass widgets go here
  ],
)
```

### LiquidGlass (Lens)

The actual glass element that creates the effect on content behind it.

```dart
LiquidGlass(
  width: 300,
  height: 80,
  blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
  color: Colors.white.withOpacity(0.1),
  shape: RoundedRectangleShape(cornerRadius: 24),
  position: LiquidGlassAlignPosition(alignment: Alignment.center),
  child: YourContent(),
)
```

---

## Use Cases with Examples

### 1. Navigation Bar

A floating bottom navigation bar with liquid glass effect.

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: YourPageContent(),
        realTimeCapture: true,
        children: [
          // Navigation Bar
          LiquidGlass(
            width: MediaQuery.of(context).size.width - 48,
            height: 70,
            blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
            color: Colors.black.withOpacity(0.1),
            chromaticAberration: 0.0,
            shape: RoundedRectangleShape(cornerRadius: 35),
            position: LiquidGlassAlignPosition(
              alignment: Alignment.bottomCenter,
              margin: const EdgeInsets.only(bottom: 24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(icon: Icons.home, label: 'Home', isSelected: true),
                _NavItem(icon: Icons.search, label: 'Search'),
                _NavItem(icon: Icons.person, label: 'Profile'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Key settings for navigation bars:**
- `blur: LiquidGlassBlur(sigmaX: 10, sigmaY: 10)` - Light blur
- `color: Colors.black.withOpacity(0.1)` - Subtle tint
- `cornerRadius: 35` - Pill shape
- `chromaticAberration: 0.0` - No rainbow effect (cleaner look)

---

### 2. Floating Buttons

Reusable button component with liquid glass styling.

```dart
class LiquidButton extends LiquidGlass {
  const LiquidButton({
    required Widget child,
    required LiquidGlassPosition position,
    double width = 80,
    double height = 36,
  }) : super(
         child: child,
         width: width,
         height: height,
         position: position,
         blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
         color: const Color(0x1AFFFFFF), // white at 10% opacity
         chromaticAberration: 0.0,
         shape: const RoundedRectangleShape(cornerRadius: 18),
       );
}

// Usage in LiquidGlassView.children:
LiquidButton(
  position: LiquidGlassAlignPosition(
    alignment: Alignment.topRight,
    margin: EdgeInsets.only(top: 60, right: 16),
  ),
  child: Center(child: Text('Select', style: TextStyle(color: Colors.white))),
),
```

**Key settings for buttons:**
- `cornerRadius: 18` - Rounded but not pill-shaped
- Smaller blur values for compact elements
- Use `LiquidGlassAlignPosition` for alignment-based positioning

---

### 3. Context Menus

Popup menu that appears near a tap location with liquid glass effect.

```dart
// In your state class
MediaItem? _contextMenuItem;
Offset? _contextMenuPosition;

// In LiquidGlassView.children:
if (_contextMenuItem != null)
  _buildContextMenuGlass(screenSize),

// Method to build the context menu
LiquidGlass _buildContextMenuGlass(Size screenSize) {
  final menuWidth = 280.0;
  final menuHeight = 200.0;
  final pos = _contextMenuPosition ?? Offset(screenSize.width / 2, screenSize.height / 2);
  
  // Calculate position (prefer above tap point)
  double left = pos.dx - menuWidth / 2;
  double top = pos.dy - menuHeight - 20;
  
  // Bounds checking
  if (left < 16) left = 16;
  if (left + menuWidth > screenSize.width - 16) left = screenSize.width - menuWidth - 16;
  if (top < 60) top = pos.dy + 20; // Below if no room above
  
  return LiquidGlass(
    position: LiquidGlassOffsetPosition(left: left, top: top),
    width: menuWidth,
    height: menuHeight,
    blur: const LiquidGlassBlur(sigmaX: 15, sigmaY: 15),
    color: Colors.white.withOpacity(0.1),
    shape: RoundedRectangleShape(cornerRadius: 24),
    chromaticAberration: 0.0,
    distortion: 0.05,
    child: Column(
      children: [
        ListTile(leading: Icon(Icons.share), title: Text('Share'), onTap: () {}),
        ListTile(leading: Icon(Icons.delete), title: Text('Delete'), onTap: () {}),
      ],
    ),
  );
}
```

**Key settings for context menus:**
- Use `LiquidGlassOffsetPosition` for pixel-perfect positioning
- Higher blur (15) for more prominent overlay
- Add a dark scrim behind the menu:

```dart
// In backgroundWidget's Stack:
if (_contextMenuItem != null)
  Positioned.fill(
    child: GestureDetector(
      onTap: () => setState(() => _contextMenuItem = null),
      behavior: HitTestBehavior.opaque,
      child: Container(color: Colors.black.withOpacity(0.4)),
    ),
  ),
```

---

### 4. Dialogs & Overlays

Centered confirmation dialogs with liquid glass effect.

```dart
// In your state class
bool _showDeleteConfirm = false;
MediaItem? _deleteItem;

// In LiquidGlassView.children:
if (_showDeleteConfirm)
  _buildDeleteDialog(),

// Dialog builder method
LiquidGlass _buildDeleteDialog() {
  return LiquidGlass(
    position: LiquidGlassAlignPosition(
      alignment: Alignment.center, // Centered on screen
    ),
    width: 280,
    height: 200,
    blur: const LiquidGlassBlur(sigmaX: 15, sigmaY: 15),
    color: Colors.white.withOpacity(0.1),
    shape: RoundedRectangleShape(cornerRadius: 24),
    chromaticAberration: 0.0,
    distortion: 0.05,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline, color: Colors.redAccent, size: 32),
          SizedBox(height: 12),
          Text('Delete Photo?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('This action cannot be undone.', style: TextStyle(color: Colors.white70, fontSize: 13)),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showDeleteConfirm = false),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text('Cancel', style: TextStyle(color: Colors.white))),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () { /* delete logic */ },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

**Why not use showDialog()?**
`showDialog()` creates a separate route that's outside the `LiquidGlassView` widget tree. To get the true liquid glass effect, dialogs must be `LiquidGlass` children within the same `LiquidGlassView`.

---

### 5. Cards

Glass-styled cards for content display.

```dart
LiquidGlass(
  position: LiquidGlassOffsetPosition(left: 16, top: 100),
  width: MediaQuery.of(context).size.width - 32,
  height: 120,
  blur: const LiquidGlassBlur(sigmaX: 8, sigmaY: 8),
  color: Colors.white.withOpacity(0.08),
  shape: RoundedRectangleShape(cornerRadius: 20),
  chromaticAberration: 0.0,
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('User Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('user@email.com', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    ),
  ),
),
```

---

## Customizable Parameters

### LiquidGlassView Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `backgroundWidget` | Widget | **required** | Content visible behind the glass |
| `children` | List<LiquidGlass> | **required** | Glass lenses to render |
| `realTimeCapture` | bool | `true` | Continuously capture background (for scrolling) |
| `pixelRatio` | double | `1.0` | Lower = better performance |

### LiquidGlass Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `width` | double | `200` | Width of glass lens |
| `height` | double | `100` | Height of glass lens |
| `blur` | LiquidGlassBlur | none | Frosted glass blur |
| `color` | Color | transparent | Glass tint color |
| `distortion` | double | `0.125` | Edge refraction (0.0-0.2) |
| `chromaticAberration` | double | `0.003` | Rainbow edge effect (0 = none) |
| `shape` | LiquidGlassShape | RoundedRectangle | Shape of glass |
| `position` | LiquidGlassPosition | **required** | Positioning |
| `child` | Widget? | null | Content on top of glass |

### Position Types

```dart
// Alignment-based (relative positioning)
LiquidGlassAlignPosition(
  alignment: Alignment.bottomCenter,
  margin: EdgeInsets.only(bottom: 24),
)

// Offset-based (pixel positioning)
LiquidGlassOffsetPosition(
  left: 20,
  top: 100,
)
```

### Shapes

```dart
RoundedRectangleShape(cornerRadius: 24)  // Standard rounded corners
SuperellipseShape(curveExponent: 4)      // Squircle shape
```

---

## Best Practices

### 1. Always Use Dark Scrim for Overlays

When showing context menus or dialogs, add a dark overlay to the background:

```dart
// In backgroundWidget's Stack:
if (_showOverlay)
  Positioned.fill(
    child: GestureDetector(
      onTap: () => setState(() => _showOverlay = false),
      behavior: HitTestBehavior.opaque,
      child: Container(color: Colors.black.withOpacity(0.4)),
    ),
  ),
```

### 2. Recommended Settings for iOS 26 Style

```dart
LiquidGlass(
  blur: const LiquidGlassBlur(sigmaX: 10, sigmaY: 10),
  color: Colors.white.withOpacity(0.1),  // or Colors.black.withOpacity(0.1)
  chromaticAberration: 0.0,               // Disable rainbow effect
  distortion: 0.05,                       // Subtle edge distortion
  shape: RoundedRectangleShape(cornerRadius: 24),
)
```

### 3. Performance Tips

- Use `realTimeCapture: false` for static backgrounds
- Lower `pixelRatio` (0.5-0.8) on low-end devices
- Minimize number of active LiquidGlass lenses
- Avoid excessive blur values (>25)

### 4. Text Styling in Glass Elements

Always use white or light colors for text on glass:

```dart
TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w500,
  decoration: TextDecoration.none, // Prevents yellow underline outside Material
)
```

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| **Overflow errors** | Increase `height` of LiquidGlass |
| **Yellow underline on text** | Wrap in `Material(color: transparent)` or add `decoration: TextDecoration.none` |
| **Blur covers whole screen** | Use `LiquidGlass` inside `LiquidGlassView.children`, not `BackdropFilter` |
| **Dialog outside glass effect** | Don't use `showDialog()`. Use state-based overlay with `LiquidGlass` |
| **Laggy scrolling** | Lower `pixelRatio`, use `realTimeCapture: false` for static content |
| **Glass not visible** | Ensure background has colorful/varied content behind lens position |
| **Effect looks too intense** | Lower `distortion`, `blur`, and `chromaticAberration` values |

---

## Complete App Structure Example

```dart
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedTab = 0;
  bool _showDialog = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        backgroundWidget: Stack(
          children: [
            // Main content
            _buildPageContent(),
            
            // Scrim for dialog
            if (_showDialog)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showDialog = false),
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.black.withOpacity(0.4)),
                ),
              ),
          ],
        ),
        realTimeCapture: true,
        children: [
          // Navigation bar
          _buildNavBar(),
          
          // Floating action button
          _buildFab(),
          
          // Dialog (when visible)
          if (_showDialog)
            _buildDialog(),
        ],
      ),
    );
  }
}
```

---

## Resources

- **Package**: [liquid_glass_easy on pub.dev](https://pub.dev/packages/liquid_glass_easy)
- **iOS 26 Design Reference**: Apple WWDC 2025 - Liquid Glass Design Guidelines
