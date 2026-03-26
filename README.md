# 🛒 Shopping List App — SQLite + Supabase Sync

## Features
- ✅ Full offline-first shopping list (SQLite)
- ☁️ Manual sync to Supabase (PostgreSQL)
- ⚔️ Conflict resolution — choose local or server version per item
- 📊 Budget tracker (estimated vs actual)
- 🏷️ Categories with icons
- 🌙 Dark mode

---

## 🚀 Quick Setup

### 1. Create Supabase project
1. Go to [supabase.com](https://supabase.com) and create a free project
2. Go to **SQL Editor** → paste the contents of `supabase_setup.sql` → Run

### 2. Add your credentials to `lib/main.dart`
```dart
const _supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
const _supabaseAnonKey = 'YOUR_ANON_KEY';
```
Find these at: **Project Settings → API**

### 3. Install dependencies & run
```bash
flutter pub get
flutter run
```

---

## 🔄 Sync Flow

```
[Tap Sync button]
        ↓
  Fetch all remote items
        ↓
  Compare updatedAt timestamps
        ↓
  ┌─────────────┬──────────────────┐
  │ No conflict │ Conflict found   │
  │             │ (both changed)   │
  ↓             ↓                  │
Push local  Show per-item dialog   │
Pull remote  user picks version ───┘
        ↓
  Apply all changes locally + remotely
        ↓
  Show "Synced ↑N pushed ↓N pulled"
```

---

## 📁 File Structure

```
lib/
├── main.dart                          # App entry + Supabase init
├── models/
│   └── shopping_item.dart             # Data model (with updatedAt, isDeleted)
├── db/
│   └── database_helper.dart           # SQLite CRUD + soft delete
├── services/
│   ├── supabase_service.dart          # Supabase API calls
│   └── sync_service.dart              # Sync logic + conflict detection
├── screens/
│   └── home_screen.dart               # Main UI with sync button
└── widgets/
    ├── shopping_item_card.dart        # Item card (swipe to delete)
    ├── add_edit_item_dialog.dart      # Add/edit form
    ├── conflict_resolution_dialog.dart # Side-by-side conflict picker
    └── sync_status_banner.dart        # Sync state banner
```

---

## 🗄️ SQLite Schema

```sql
CREATE TABLE shopping_items (
  id TEXT PRIMARY KEY,          -- UUID v4
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  estimated_price REAL NOT NULL,
  actual_price REAL,
  is_bought INTEGER DEFAULT 0,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,     -- used for conflict detection
  is_deleted INTEGER DEFAULT 0  -- soft delete for sync
);
```