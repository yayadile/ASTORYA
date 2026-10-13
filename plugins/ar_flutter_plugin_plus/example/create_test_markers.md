# Creating Good AR Tracking Images

## Current Issue

ARCore is throwing `ImageInsufficientQualityException` because the current test images don't have enough visual features for reliable tracking.

## Requirements for Good AR Tracking Images

### ✅ Good Features:

- High contrast between different areas
- Rich corners and edges
- Asymmetric design (avoid symmetry)
- Varied textures and patterns
- Good feature distribution across the image
- Sharp, clear details

### ❌ Avoid:

- Uniform colors or gradients
- Repetitive patterns
- Very simple shapes
- Low contrast images
- Blurry or low-resolution images
- Highly symmetric designs

## Recommended Test Images

1. **QR Code-style markers** - High contrast, rich features
2. **Magazine covers** - Good mix of text and images
3. **Playing cards** - Asymmetric, high contrast
4. **Product labels** - Text + logos + varied elements
5. **Posters with text and graphics**

## Quick Fix Options

### Option A: Use Google's Sample Images

Download sample tracking images from:

- ARCore samples repository
- Unity AR Foundation samples

### Option B: Generate QR-Code Style Markers

Create high-contrast geometric patterns with:

- Black and white elements
- Irregular borders
- Unique patterns for each marker

### Option C: Use Real-World Objects

Take photos of:

- Book covers
- Magazine pages
- Product packaging
- Posters with text

## Testing Your Images

You can test image quality using Google's ARCore Image Database evaluation tools or by following these guidelines:

- Image should have at least 1000 feature points when analyzed
- Good contrast ratio
- Sharp focus
- Minimum 480x480 pixels recommended
