# Settings Page - New Year Theme Stitch Prompt

## Overview
Transform the Settings page into a festive New Year 2026 themed interface using winter/holiday assets and Lottie animations from the `assets/new_year/` folder.

## Current Structure
The Settings page (`lib/src/features/settings/presentation/settings_page.dart`) contains:
- Premium Section (if not premium)
- Quick Actions (History, Gallery Report)
- Theme Selection (Light/Dark/System)
- Language Selection (Turkish/English/Spanish)
- Sound Volume Control
- Rate App Section
- Version Info

## New Year Theme Requirements

### 1. Background Effects
- **Snowing Animation**: Add `assets/new_year/Snowing.json` Lottie animation as a full-screen background
  - Use `Positioned.fill` to cover the entire screen
  - Apply `Opacity(0.3)` for subtle effect
  - Use `ColorFiltered` with `BlendMode.srcATop` and `AppColors.white` to make snow white
  - Set `repeat: true` for continuous animation

### 2. Header Section
- **Remove**: Any existing header images like `new-year.png`
- **Create**: A festive "Happy New Year 2026" header card at the top
  - Use gradient background: `primary` and `error` colors with opacity
  - Include Santa Claus icon (`assets/new_year/santa-claus.png`) on the left (60x60 container)
  - Display "Happy New Year 2026" as main title (large, bold)
  - Display "Settings" as subtitle
  - Add decorative elements:
    - Christmas wreath (`assets/new_year/christmas-wreath.png`) at top-right (80x80, opacity 0.4)
    - Christmas tree (`assets/new_year/christmas-tree.png`) at bottom-right (60x60, opacity 0.3)
  - Use rounded corners (24px), border with primary color, and shadow effects

### 3. Container Styling
Each settings container should:
- Use New Year themed gradient backgrounds (primary, error, or success colors with opacity 0.12-0.06)
- Have rounded corners (20px)
- Include borders with themed colors (opacity 0.25, width 1.5)
- Have shadow effects matching the theme color
- Include decorative images positioned at bottom-right (55x55, opacity 0.25)

### 4. Quick Actions Container
- **Icon**: Use `assets/new_year/christmas-tree.png` (18x18) in a gradient container
- **Color Theme**: Error color (red) theme
- **Background Gradient**: Error colors with opacity 0.12-0.06
- **Border**: Error color with opacity 0.25
- **Decorative Image**: Gift box (`assets/new_year/gift-box.png`) at bottom-right
- **Title**: "Quick Actions" in error color, bold, 15px

### 5. Theme Selection Container
- **Icon**: Use `assets/new_year/gift-box.png` (18x18) in a gradient container
- **Color Theme**: Primary color theme
- **Background Gradient**: Primary colors with opacity 0.12-0.06
- **Border**: Primary color with opacity 0.25
- **Decorative Image**: Christmas wreath (`assets/new_year/christmas-wreath.png`) at bottom-right
- **Title**: Theme label in primary color, bold, 15px

### 6. Language Selection Container
- **Icon**: Use `assets/new_year/candy-cane.png` (18x18) in a gradient container
- **Color Theme**: Success color (green) theme
- **Background Gradient**: Success colors with opacity 0.12-0.06
- **Border**: Success color with opacity 0.25
- **Decorative Image**: Santa Claus (`assets/new_year/santa-claus.png`) at bottom-right
- **Title**: Language label in success color, bold, 15px

### 7. Sound Volume Container
- **Icon**: Use `assets/new_year/gift-box.png` (18x18) in a gradient container
- **Color Theme**: Primary color theme
- **Background Gradient**: Primary colors with opacity 0.12-0.06
- **Border**: Primary color with opacity 0.25
- **Decorative Image**: Snowman (`assets/new_year/snowman.png`) at bottom-right
- **Title**: "Sound Volume" in primary color, bold, 15px

### 8. Premium Section (if not premium)
- Keep existing structure but enhance with New Year theme
- Consider adding subtle snowflake or holiday decorations

### 9. Rate App Section
- Keep existing structure but can add subtle New Year touches
- Maintain the warning color theme (yellow/orange)

## Implementation Details

### Stack Structure
Each themed container should use:
```dart
Stack(
  clipBehavior: Clip.hardEdge,
  children: [
    Container(
      // Main container with gradient, border, shadow
    ),
    Positioned(
      right: 10,
      bottom: 10,
      child: Opacity(
        opacity: 0.25,
        child: Image.asset(
          'assets/new_year/[image-name].png',
          width: 55,
          height: 55,
          fit: BoxFit.contain,
        ),
      ),
    ),
  ],
)
```

### Icon Container Style
```dart
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        [themeColor].withOpacity(0.3),
        [themeColor].withOpacity(0.2),
      ],
    ),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(
      color: [themeColor].withOpacity(0.4),
      width: 1.5,
    ),
  ),
  child: Image.asset(
    'assets/new_year/[icon-name].png',
    width: 18,
    height: 18,
    fit: BoxFit.contain,
  ),
)
```

### Color Themes
- **Quick Actions**: `AppColors.error` (red)
- **Theme Selection**: `theme.colorScheme.primary`
- **Language Selection**: `AppColors.success` (green)
- **Sound Volume**: `theme.colorScheme.primary`

## Assets to Use
- `assets/new_year/Snowing.json` - Background snow animation
- `assets/new_year/santa-claus.png` - Santa icon and decorative element
- `assets/new_year/christmas-tree.png` - Tree icon and decorative element
- `assets/new_year/christmas-wreath.png` - Wreath decorative element
- `assets/new_year/gift-box.png` - Gift box icon
- `assets/new_year/candy-cane.png` - Candy cane icon
- `assets/new_year/snowman.png` - Snowman decorative element

## Visual Hierarchy
1. **Top**: Happy New Year 2026 header card (most prominent)
2. **Middle**: Themed containers with icons and decorative images
3. **Background**: Subtle snowing animation throughout

## Notes
- All decorative images should have low opacity (0.25-0.4) to not interfere with content
- Maintain readability of all text and interactive elements
- Use consistent spacing (16px padding, 12px gaps)
- Ensure all containers are accessible and functional
- Keep the festive theme subtle and elegant, not overwhelming

