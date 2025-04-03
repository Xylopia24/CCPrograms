# ComputerCraft APIs Collection

TEMP

A comprehensive suite of powerful, modular APIs designed for ComputerCraft/CC:Tweaked that enhance development capabilities with robust, reusable components.

## Overview

This collection provides carefully crafted APIs for common tasks in ComputerCraft programming, from UI and data management to audio and peripheral control. Each API follows consistent design patterns with thorough documentation and examples.

## Available APIs

### 🖥️ Display & UI

- **[MirrorDisplay](MirrorDisplay/README.md)** - Terminal mirroring to monitors with advanced styling

  - Terminal output mirroring to connected monitors
  - Custom borders and headers with multiple styles
  - Automatic scaling and positioning
  - TaskMaster integration for background operations
  - Theme support for consistent styling

- **[ThemeManager](ThemeManager/README.md)** - Advanced terminal color theme management
  - Complete terminal color palette customization
  - Theme categorization with subdirectories
  - UI element semantic mapping (headers, buttons, etc.)
  - Theme preview functionality
  - Hex color conversion utilities

### 💾 Data Management

- **[DataManager](DataManager/README.md)** - Multi-format data serialization system
  - Support for JSON, Lua tables, and INI/metadata formats
  - Subdirectory organization with automatic folder creation
  - Pretty-printed output for all formats
  - Type conversion between formats
  - Consistent API across all data types

### 🔊 Audio

- **[AudioManager](AudioManager/README.md)** - Comprehensive speaker management
  - Multi-speaker stereo output with balance controls
  - Playlist management with shuffle and looping
  - Volume control with smooth fading effects
  - Cross-fading between tracks
  - Event-based system for audio state changes
  - TaskMaster integration for parallel audio processing

### 🔌 Hardware Management

- **[PeripheralManager](PeripheralManager/README.md)** - Smart peripheral device management
  - Friendly name aliases for peripherals
  - Peripheral grouping for batch operations
  - Automatic peripheral discovery and reconnection
  - Connection tracking and status monitoring
  - Persistent peripheral configuration between restarts

### 📝 System Utilities

- **[Logger](Logger/README.md)** - Advanced logging system
  - Multiple severity levels (debug, info, warn, error, fatal)
  - Category-based log organization
  - Automatic log rotation and backup management
  - Timestamp formatting and contextual logging
  - Configurable console output
