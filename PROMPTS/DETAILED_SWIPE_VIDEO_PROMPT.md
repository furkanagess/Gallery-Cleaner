# Detailed Video Prompt: Swipe Left to Delete, Swipe Right to Keep

## Video Specifications
- **Format**: Vertical (9:16 aspect ratio)
- **Duration**: 5 seconds per clip (can be combined into 30-second montage)
- **Resolution**: 1080x1920 (Full HD vertical)
- **Frame Rate**: 60fps for smooth animations
- **Style**: Modern, premium, minimalist mobile app demonstration
- **Color Palette**: 
  - Primary: #5D9CEC (Blue)
  - Delete/Left: #EF4444 (Red)
  - Keep/Right: #22C55E (Green)
  - Background: Dark (#191C24) or Light gradient

---

## CLIP 1: Introduction - The Swipe Gesture (0-5 seconds)

### Visual Composition
- **Shot**: Close-up of a premium smartphone (iPhone 15 Pro or equivalent) floating against a dark gradient background
- **Phone State**: Screen is on, showing a colorful photo card in the center of the Gallery Cleaner app
- **Photo Card Details**:
  - Rounded corners (20px border radius)
  - Full-screen photo (can be a landscape, portrait, or cityscape)
  - Subtle gradient overlay at the bottom (black 22% opacity, fading upward)
  - A second photo card is visible slightly behind the main card, creating depth

### Animation Sequence (Frame-by-Frame)
- **0.0-0.5s**: Hand enters from the bottom of the frame, thumb approaching the screen
- **0.5-1.0s**: Thumb hovers over the center of the photo card
- **1.0-1.5s**: Subtle neon glow trail appears following the thumb position (turquoise #A5F1E9)
- **1.5-2.0s**: Thumb touches screen - subtle haptic feedback ripple effect appears on screen
- **2.0-3.0s**: Card begins to move slightly, following the thumb movement
- **3.0-4.0s**: Card rotates slightly (max 15 degrees) as thumb moves left
- **4.0-5.0s**: Freeze frame with text overlay appears

### Text Overlays
- **4.0s**: Text fades in smoothly
- **Text**: "SWIPE LEFT → DELETE" (left side, red #EF4444)
- **Font**: Bold, modern sans-serif, white with red shadow
- **Position**: Left side of screen, vertically centered
- **Animation**: Fade in + slide from left (200ms ease-out)

### Sound Design
- Ambient electronic pop music starts (low volume)
- Subtle "whoosh" sound as thumb approaches
- Light haptic "tap" sound when thumb touches screen

### Technical Details
- Camera: Smooth dolly movement, slightly rotating around the phone
- Lighting: Soft studio lighting with neon accent (blue/turquoise rim light on phone edge)
- Depth of Field: Shallow focus on thumb and screen, background slightly blurred

---

## CLIP 2: Swipe Left - Delete Action (0-5 seconds)

### Visual Composition
- **Shot**: Screen-recording style or ultra-close-up of the phone screen
- **Screen State**: Gallery Cleaner app is active, photo card is centered
- **Photo Details**: 
  - A blurry or duplicate photo is displayed (slightly out of focus, low quality)
  - Photo has rounded corners (20px)
  - Background card is visible behind with subtle shadow

### Animation Sequence (Detailed Frame-by-Frame)

#### 0.0-0.8s: Initial Swipe Movement
- Thumb starts at center, begins moving left
- Photo card follows thumb movement with smooth physics
- Card rotates counter-clockwise (up to -15 degrees as it moves left)
- Card maintains scale (no shrinking yet)

#### 0.8-1.5s: Threshold Reached (120px swipe distance)
- **DELETE badge appears** at bottom-left corner:
  - Position: 16px from left edge, 16px from bottom
  - Design: Red background (#EF4444), rounded corners (16px)
  - Icon: Animated Lottie trash icon (22x22px, white)
  - Text: "DELETE" in uppercase, bold white text
  - Arrow: Small diagonal arrow pointing toward top-right
  - Badge has white border (2px, 60% opacity) and glowing shadow
- **Border effect appears**:
  - Red border (#EF4444 at 80% opacity) around the photo card
  - Border width: 1.5px to 5px (scales with swipe distance)
  - Border has subtle glow effect
- **Opacity of badge**: Gradually increases from 0 to 1.0 as swipe continues
- **Scale animation**: Badge scales from 0.88 to 1.0 as it becomes visible

#### 1.5-2.5s: Confirmation Phase
- Card continues moving left, now beyond threshold
- Red border intensifies (5px width, fully opaque)
- DELETE badge fully visible, Lottie animation plays (trash icon animating)
- Card rotation reaches maximum (-15 degrees)
- Haptic feedback indicator (subtle vibration ripple on screen)

#### 2.5-4.0s: Final Swipe & Exit
- Thumb releases, card continues momentum
- Smooth acceleration animation (easeInOut curve, 400ms duration)
- Card moves off-screen to the left (moves 1.5x screen width to the left)
- As card exits:
  - Photo fades out (opacity 1.0 → 0.0)
  - Particle effect: Small red particles scatter from the photo
  - Card shrinks slightly (scale 1.0 → 0.8) as it leaves
- Next photo card (from stack) slides up smoothly to center position
- DELETE badge fades out as card leaves

#### 4.0-5.0s: Completion
- New photo card is now centered and ready
- Text overlay appears: "DELETED" in red, with checkmark icon
- Stats update (if visible): "X photos deleted" counter increments

### Sound Design
- **0.8s**: Light haptic "buzz" when threshold is reached
- **1.5s**: Red border appears - subtle "click" sound
- **2.5s**: Thumb releases - "whoosh" sound (left direction, medium pitch)
- **3.0s**: Delete sound effect plays (trash.mp3 - subtle paper crumpling or digital delete sound)
- **4.0s**: Success "ding" when deletion is confirmed

### Technical Details
- Swipe threshold: 120 pixels from center
- Maximum rotation: -15 degrees (counter-clockwise)
- Animation curve: Curves.easeInOut for card exit
- Badge opacity formula: `clamp(swipeDistance / threshold, 0.0, 1.0)`
- Border width formula: `(opacity * 3.5) + 1.5` pixels

---

## CLIP 3: Swipe Right - Keep Action (0-5 seconds)

### Visual Composition
- **Shot**: Same screen-recording style, ultra-close-up
- **Screen State**: Gallery Cleaner app, new photo card centered
- **Photo Details**: 
  - A beautiful, clear photo is displayed (portrait, landscape, or meaningful moment)
  - High quality, vibrant colors
  - Rounded corners (20px)
  - Background card visible with depth

### Animation Sequence (Detailed Frame-by-Frame)

#### 0.0-0.8s: Initial Swipe Movement
- Thumb starts at center, begins moving right
- Photo card follows thumb movement smoothly
- Card rotates clockwise (up to +15 degrees as it moves right)
- Card maintains scale (no shrinking yet)

#### 0.8-1.5s: Threshold Reached (120px swipe distance)
- **KEEP badge appears** at bottom-right corner:
  - Position: 16px from right edge, 16px from bottom
  - Design: Green background (#22C55E), rounded corners (16px)
  - Icon: Animated Lottie keep icon (22x22px, white) - heart or library icon
  - Text: "KEEP" in uppercase, bold white text
  - Arrow: Small diagonal arrow pointing toward top-left
  - Badge has white border (2px, 60% opacity) and glowing shadow
- **Border effect appears**:
  - Green border (#22C55E at 80% opacity) around the photo card
  - Border width: 1.5px to 5px (scales with swipe distance)
  - Border has subtle glow effect
- **Opacity of badge**: Gradually increases from 0 to 1.0 as swipe continues
- **Scale animation**: Badge scales from 0.88 to 1.0 as it becomes visible

#### 1.5-2.5s: Confirmation Phase
- Card continues moving right, now beyond threshold
- Green border intensifies (5px width, fully opaque)
- KEEP badge fully visible, Lottie animation plays (keep icon animating - gentle pulse or glow)
- Card rotation reaches maximum (+15 degrees)
- Haptic feedback indicator (subtle vibration ripple on screen)
- Photo gets subtle brightness boost (slight glow effect)

#### 2.5-4.0s: Final Swipe & Exit
- Thumb releases, card continues momentum
- Smooth acceleration animation (easeInOut curve, 400ms duration)
- Card moves off-screen to the right (moves 1.5x screen width to the right)
- As card exits:
  - Photo fades out (opacity 1.0 → 0.0)
  - Particle effect: Small green sparkles/confetti particles scatter from the photo
  - Card shrinks slightly (scale 1.0 → 0.8) as it leaves
- Next photo card (from stack) slides up smoothly to center position
- KEEP badge fades out as card leaves

#### 4.0-5.0s: Completion
- New photo card is now centered and ready
- Text overlay appears: "KEPT" in green, with checkmark icon
- Stats update (if visible): "X photos kept" counter increments

### Sound Design
- **0.8s**: Light haptic "buzz" when threshold is reached
- **1.5s**: Green border appears - subtle "click" sound (higher pitch than delete)
- **2.5s**: Thumb releases - "whoosh" sound (right direction, higher pitch)
- **3.0s**: Keep sound effect plays (keep.mp3 - pleasant chime or success sound)
- **4.0s**: Success "ding" when photo is saved

### Technical Details
- Swipe threshold: 120 pixels from center
- Maximum rotation: +15 degrees (clockwise)
- Animation curve: Curves.easeInOut for card exit
- Badge opacity formula: `clamp(swipeDistance / threshold, 0.0, 1.0)`
- Border width formula: `(opacity * 3.5) + 1.5` pixels
- Keep sound is more pleasant/musical compared to delete sound

---

## CLIP 4: Rapid Swipe Sequence - Speed Demonstration (0-5 seconds)

### Visual Composition
- **Shot**: Screen recording showing multiple rapid swipes
- **Style**: Time-lapse feel but still smooth, showing multiple photos being processed

### Animation Sequence

#### 0.0-0.5s: First Photo - Delete
- Quick left swipe (under 1 second total)
- Photo exits left with DELETE badge visible
- Red particles scatter

#### 0.5-1.0s: Second Photo - Keep
- Immediate right swipe
- Photo exits right with KEEP badge visible
- Green sparkles appear

#### 1.0-1.5s: Third Photo - Delete
- Another quick left swipe
- Smooth transition

#### 1.5-2.0s: Fourth Photo - Keep
- Right swipe continues

#### 2.0-3.0s: Rapid Sequence
- Multiple photos processed rapidly (3-4 photos)
- Alternating delete/keep actions
- Cards stack and disappear quickly
- Stats counter updating rapidly in corner (if visible)

#### 3.0-4.0s: Slowdown
- Speed gradually returns to normal
- Final photo card is shown centered

#### 4.0-5.0s: Stats Reveal
- Screen shows summary:
  - "5 photos deleted"
  - "3 photos kept"
  - "Space freed: X GB" (if applicable)
- Text overlay: "Lightning Fast Decisions"

### Sound Design
- Rapid-fire sound effects (delete and keep sounds overlapping)
- Upbeat electronic music tempo increases
- Sounds become rhythmic, matching the swipe cadence

### Technical Details
- Each swipe takes ~0.8-1.0 seconds total
- Smooth transitions between photos (no lag)
- Stack of cards visible in background (2-3 cards deep)

---

## CLIP 5: Close-Up - Badge & Border Detail (0-5 seconds)

### Visual Composition
- **Shot**: Extreme close-up on the photo card and badges
- **Focus**: Badge animations and border effects

### Animation Sequence

#### 0.0-1.0s: Left Swipe - Delete Badge Detail
- Card slowly moves left (demonstration speed, not real-time)
- DELETE badge gradually appears at bottom-left
- Show the Lottie animation clearly:
  - Trash icon animates (opening/closing lid or particles)
  - Animation loops smoothly (1500ms duration)
  - Icon is white, crisp against red background
- Border gradually appears around photo:
  - Starts at 1.5px, grows to 5px
  - Red glow effect intensifies
  - Border has soft shadow

#### 1.5-2.5s: Badge Animation Detail
- Zoom in even closer on the DELETE badge
- Show the animated Lottie trash icon clearly
- Badge has:
  - White border (2px, 60% opacity)
  - Glowing red shadow (blur 20px, spread 2px)
  - Black shadow underneath (blur 16px)
- Text "DELETE" is uppercase, bold, white with black shadow

#### 2.5-3.5s: Right Swipe - Keep Badge Detail
- Card now moves right (demonstration speed)
- KEEP badge gradually appears at bottom-right
- Show the Lottie animation clearly:
  - Keep/library icon animates (gentle pulse or glow effect)
  - Animation loops smoothly (1000ms duration)
  - Icon is white, crisp against green background
- Border gradually appears:
  - Green border with glow
  - Similar width progression (1.5px to 5px)

#### 3.5-4.5s: Badge Comparison
- Split screen showing both badges side by side
- DELETE badge on left (red #EF4444)
- KEEP badge on right (green #22C55E)
- Both animations playing simultaneously
- Show the clear visual distinction

#### 4.5-5.0s: Pull Back
- Camera pulls back to show full screen context
- Both badges are visible as card swipes
- Text overlay: "Visual Feedback at Every Swipe"

### Sound Design
- Focus on badge-specific sounds:
  - DELETE: Lower-pitched "thunk" or "clunk"
  - KEEP: Higher-pitched "chime" or "sparkle"
- Minimal background music (subtle)

### Technical Details
- Badge size: ~80-100px wide (including text and icon)
- Icon size: 22x22px
- Text size: 16px, uppercase, bold, 1.2px letter spacing
- Border radius: 16px on badges, 20px on photo cards

---

## CLIP 6: Complete Flow - Before & After (0-5 seconds)

### Visual Composition
- **Shot**: Split-screen or before/after comparison
- **Left Side (Before)**: Cluttered gallery view
- **Right Side (After)**: Clean, organized gallery

### Animation Sequence

#### 0.0-1.0s: Before State
- Left side shows:
  - Gallery grid view with many photos
  - Some blurry photos visible
  - Some duplicates visible
  - Overall cluttered appearance
  - Stats: "1,234 photos, 15.2 GB"

#### 1.0-2.0s: Swipe Action Montage
- Split screen transitions to single screen
- Shows rapid swipe sequence (same as Clip 4 but condensed)
- 4-5 swipes shown in quick succession:
  - Delete (left), Keep (right), Delete (left), Keep (right), Delete (left)
- Sound effects overlapping

#### 2.0-3.0s: Transformation
- Screen splits again
- Left side: Photos being removed (fade out with red particle effects)
- Right side: Clean gallery forming (photos fading in smoothly)
- Stats counter updating in real-time

#### 3.0-4.0s: After State
- Both sides now show the "After" state
- Right side shows:
  - Clean, organized gallery grid
  - Only high-quality, meaningful photos
  - No duplicates or blurry photos
  - Stats: "856 photos, 8.7 GB"
- Text overlay appears: "6.5 GB Freed, 378 Photos Removed"

#### 4.0-5.0s: Final CTA
- Screen returns to single view
- App logo appears at top
- Slogan text: "Swipe Smart. Keep What Matters."
- App name: "Gallery Cleaner"
- Call-to-action button (if applicable)

### Sound Design
- Music builds to crescendo during transformation
- Success fanfare at the end
- Sound of "space being freed" (subtle whoosh or chime)

### Technical Details
- Before: 1,234 photos, 15.2 GB
- After: 856 photos, 8.7 GB
- Difference: 378 photos deleted, 6.5 GB freed

---

## Combined Montage Structure (All 6 Clips)

If combining all clips into a single 30-second video:

### Timeline
- **0:00-0:05**: Clip 1 - Introduction
- **0:05-0:10**: Clip 2 - Swipe Left Delete
- **0:10-0:15**: Clip 3 - Swipe Right Keep
- **0:15-0:20**: Clip 4 - Rapid Sequence
- **0:20-0:25**: Clip 5 - Badge Detail
- **0:25-0:30**: Clip 6 - Before & After

### Transitions
- Use smooth whip transitions between clips
- Each clip ends with a frame that leads into the next
- Maintain consistent color palette throughout
- Background music continues smoothly across all clips

---

## Visual Style Guidelines

### Color Palette (Strict Adherence)
- **Delete/Left**: #EF4444 (Red) - Use consistently for all delete-related elements
- **Keep/Right**: #22C55E (Green) - Use consistently for all keep-related elements
- **Primary**: #5D9CEC (Blue) - For app branding and UI elements
- **Accent**: #A5F1E9 (Turquoise) - For highlights and glow effects
- **Background Dark**: #191C24 - For dark mode scenes
- **Background Light**: #F8FAFC - For light mode scenes

### Typography
- **Headings**: Bold, modern sans-serif (Inter, SF Pro, or similar)
- **Body Text**: Medium weight, readable
- **Badge Text**: Uppercase, bold, 16px, 1.2px letter spacing
- **White text with shadows** for better visibility

### UI Elements
- **Border Radius**: 20px for photo cards, 16px for badges
- **Shadows**: Soft, subtle shadows with blur radius 16-24px
- **Animations**: Smooth, physics-based with easeInOut curves
- **Icons**: Lottie animations (22x22px) for delete and keep badges

### Effects
- **Particle Effects**: 
  - Delete: Red particles (dust, smoke, or sparks)
  - Keep: Green sparkles or confetti
- **Glow Effects**: 
  - Red glow for delete actions
  - Green glow for keep actions
  - Subtle turquoise rim light on phone edges
- **Haptic Feedback**: Visual ripple effect on screen when threshold is reached

---

## Sound Design Specifications

### Music
- **Genre**: Electronic Pop, Upbeat, Modern
- **Tempo**: 120-130 BPM
- **Mood**: Energetic, positive, tech-forward
- **Volume**: Background level (not overpowering)

### Sound Effects
1. **Swipe Threshold Reached**: 
   - Light haptic "buzz" (50-100ms, low frequency)
2. **Border Appearance**: 
   - Subtle "click" or "snap" (30-50ms)
3. **Swipe Release**: 
   - "Whoosh" sound (left = lower pitch, right = higher pitch, 200-300ms)
4. **Delete Action**: 
   - Paper crumpling or digital delete sound (300-500ms, lower pitch)
5. **Keep Action**: 
   - Pleasant chime or success sound (300-500ms, higher pitch)
6. **Success Confirmation**: 
   - Light "ding" or bell sound (100-200ms)

### Mixing
- Sound effects should be crisp and clear
- Music should support but not overwhelm
- Haptic feedback sounds should be subtle
- Overall mix: Bright, modern, professional

---

## Technical Camera Specifications

### Equipment
- **Camera**: 4K capable (for crisp screen recordings)
- **Lens**: Macro lens for close-ups
- **Stabilization**: Gimbal or tripod for smooth movements

### Settings
- **Resolution**: 1080x1920 (or 4K downscaled to 1080p)
- **Frame Rate**: 60fps for smooth motion
- **ISO**: Low (100-400) for clean image
- **Aperture**: f/2.8 - f/4 for shallow depth of field in close-ups
- **Shutter Speed**: 1/120s (double the frame rate for smooth motion blur)

### Lighting
- **Key Light**: Soft, diffused studio lighting from above
- **Rim Light**: Colored (turquoise/blue) accent light on phone edges
- **Background**: Dark gradient or subtle texture
- **Phone Screen**: Bright enough to be clearly visible (auto-brightness off)

---

## Post-Production Notes

### Editing
- Smooth transitions between clips (whip pans, cross-dissolves)
- Color grading to match app's color palette
- Sharpening for text and UI elements
- Motion blur where appropriate (natural camera movement)

### Text Overlays
- Use app's exact fonts (SF Pro for iOS, Roboto for Android)
- Ensure text is readable at all sizes
- Use drop shadows or outlines for contrast
- Animate text with ease-out curves

### Effects
- Particle effects for delete/keep actions
- Glow effects on borders and badges
- Subtle vignetting to focus attention
- Color correction to match brand colors exactly

---

## Marketing Message Integration

Each clip should reinforce:
- **Speed**: "Decide in seconds"
- **Simplicity**: "Just swipe left or right"
- **Visual Feedback**: "Clear indicators for every action"
- **Efficiency**: "Clean your gallery fast"
- **Control**: "You decide what stays"

Final tagline to appear at end: **"Swipe Smart. Keep What Matters."**

---

## Deliverables Checklist

- [ ] 6 individual 5-second clips (1080x1920, 60fps)
- [ ] 1 combined 30-second montage (1080x1920, 60fps)
- [ ] Sound design mix (stereo, -12dB peak level)
- [ ] Text overlay versions (with and without text)
- [ ] Color-graded versions matching brand palette
- [ ] Social media optimized versions (Instagram Stories, TikTok, YouTube Shorts)

---

## Notes for Video Production Team

1. **Use actual app screenshots** when possible for authenticity
2. **Motion graphics** can enhance the demo if screen recording isn't available
3. **Haptic feedback** can be simulated with subtle screen shake/ripple effects
4. **Lottie animations** for badges should match the actual app animations
5. **Color accuracy** is critical - use hex codes provided
6. **Test on multiple devices** to ensure the video looks good on various screen sizes
7. **Consider accessibility** - ensure text is readable and actions are clear

---

## Additional Assets Needed

- App icon/logo (high resolution, transparent background)
- Lottie animation files (trash.json, keep_photo.json) for reference
- Sound effect files (delete.mp3, keep.mp3) for reference
- Brand guidelines document (colors, fonts, tone)
- Screen recordings of actual app in action (for reference)

