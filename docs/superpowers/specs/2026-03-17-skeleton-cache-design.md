# Skeleton Loading & Template Cache Design

> **For agentic workers:** Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan.

**Goal:** Add SkeletonView placeholder animation on first load and filter switches, plus a stale-while-revalidate cache layer for API responses.

**Architecture:** SkeletonView native CollectionView integration on existing `TemplateCell`; a new `TemplateCache` service handling memory + disk caching with version/language-aware keys; cache lookup and background-refresh coordination happen in `TemplatesViewController`.

**Tech Stack:** SkeletonView (already in Podfile), NSCache (memory), FileManager + JSONSerialization (disk), Bundle version + Locale for cache key scoping.

---

## 1. Cache Layer (`Services/TemplateCache.swift`)

### 1.1 Cache Key

Format: `{type}_{appVersion}_{lang}[_{filters}_{page}]`

| Data | Example Key |
|------|-------------|
| Filter options | `options_1.0_zh-Hans` (no filter/page suffix) |
| Templates, no filters, page 1 | `templates_1.0_zh-Hans___p1` |
| Templates, category="business" | `templates_1.0_zh-Hans_business__p1` |

Rules:
- `type` must never contain underscores. Valid values: `options`, `templates` (enforced at call sites)
- `appVersion` = `CFBundleShortVersionString`
- `lang` = `Locale.preferredLanguages.first ?? "zh"`
- Filter segments = `category_style_themeColor` in fixed order; unselected = empty string (position always preserved)
- Only page 1 is cached; pages 2+ always fetch from network
- Disk filename: replace characters outside `[A-Za-z0-9._-]` with `-`, append `.json`

### 1.2 Serialization

`PPTAPIService.decryptResponse(_:)` already returns `Any` (JSON-parsed via `JSONSerialization`). **Do not add `Codable` to model structs.**

- **Memory cache:** stores the parsed `Any` directly in `CacheEntry`
- **Disk cache:** re-serialize the `Any` to `Data` with `JSONSerialization.data(withJSONObject:)` before writing; deserialize back with `JSONSerialization.jsonObject(with:)` on read and pass through the existing `parseTemplates` / `parseOptions` pipeline

```swift
// NSCache 要求 value 是 AnyObject，必须用 class
final class CacheEntry {
    let data: Any            // parsed JSON (Array or Dictionary)
    let timestamp: TimeInterval
    let ttl: TimeInterval
    init(data: Any, timestamp: TimeInterval, ttl: TimeInterval) {
        self.data = data; self.timestamp = timestamp; self.ttl = ttl
    }
}
```

### 1.3 Storage

**Memory (NSCache<NSString, CacheEntry>)**
- TTL is checked on every read (not at write time)

**Disk (`Library/Caches/PPTTemplateCache/`)**
- One JSON file per entry: `{ "timestamp": Double, "ttl": Double, "data": <JSON> }`
- All disk writes go through a **private serial `DispatchQueue`** to prevent write races
- Max 50 files; before each write, if file count ≥ 50 delete the oldest by modification date

### 1.4 TTL

| Data | TTL | Background refresh threshold |
|------|-----|------------------------------|
| Filter options | 24 hours | age ≥ ttl × 0.8 |
| Templates page 1 | 10 minutes | age ≥ ttl × 0.8 |

### 1.5 fetch(key) Return Values

```
1. Memory hit, age < ttl × 0.8  → .fresh(data)
2. Memory hit, age ≥ ttl × 0.8, age < ttl  → .fresh(data)  [caller schedules background refresh]
3. Memory hit, age ≥ ttl  → fall through to disk
4. Disk hit, age < ttl × 0.8   → promote to memory; .fresh(data)
5. Disk hit, age ≥ ttl × 0.8, age < ttl  → promote; .fresh(data)  [caller schedules background refresh]
6. Disk hit, age ≥ ttl   → promote stale; .stale(data)  [caller begins foreground refresh]
7. No cache              → .miss
```

`TemplateCache` has no reference to `TemplatesViewController`. It only stores and retrieves data; all refresh scheduling and UI decisions are the caller's responsibility.

### 1.6 Orphaned Cache Cleanup

On app launch in `AppDelegate`:
1. Enumerate all files in `PPTTemplateCache/`
2. For each file, split the base filename (without `.json`) on `_`
3. Check that `components[1] == currentAppVersion` (exact match, not substring)
4. Delete files that do not match

---

## 2. TemplatesViewController — Cache Integration

### 2.1 Load Generation Counter

Add `private var loadGeneration = 0` to prevent stale in-flight completions from overwriting current state.

```swift
func loadTemplates(reset: Bool) {
    // reset=true always proceeds, even if isLoading
    if reset {
        loadGeneration += 1          // invalidates all in-flight completions
        isLoading = false
        currentPage = 1
        templates = []
        hasMore = true
    }
    guard !isLoading, (reset || hasMore) else { return }

    let generation = loadGeneration
    isLoading = true
    ...
    // In completion:
    guard self.loadGeneration == generation else { return }  // discard stale
    ...
}
```

### 2.2 Cache Lookup & Refresh

`TemplatesViewController` owns the active key at all times. Background refresh comparison is done here:

```swift
private func currentCacheKey() -> String {
    TemplateCache.templatesKey(
        category: selectedCategory, style: selectedStyle,
        color: selectedColor, page: 1)
}
```

**Load flow:**

```
loadTemplates(reset: true):
  1. showSkeleton() immediately
  2. Look up TemplateCache.fetch(currentCacheKey())
  3a. .fresh(data)  → hideSkeleton(); render; if aging → scheduleBackgroundRefresh(key)
  3b. .stale(data)  → hideSkeleton(); render; begin foreground refresh (network)
  3c. .miss         → keep skeleton; call PPTAPIService; on return → store cache; hideSkeleton(); render

loadTemplates(reset: false) — pagination:
  No cache used; always fetch from network.
```

**Background refresh (aging case):**
```swift
func scheduleBackgroundRefresh(for key: String) {
    DispatchQueue.global().async { [weak self] in
        // fetch from network
        // on success:
        TemplateCache.shared.store(key, data)
        DispatchQueue.main.async {
            guard let self, self.currentCacheKey() == key else { return }
            self.collectionView.reloadData()  // silent, no skeleton
        }
    }
}
```

**Foreground refresh (stale case):** same as above but runs immediately after displaying stale data; no skeleton shown.

**On any refresh failure:** keep current data visible; no error UI.

---

## 3. SkeletonView Integration

### 3.1 TemplateCell

Add in `setupViews()`:

```swift
isSkeletonable = true
contentView.isSkeletonable = true
outerStack.isSkeletonable = true    // 中间层必须开启，否则骨架无法传递到子视图
infoStack.isSkeletonable = true
previewImageView.isSkeletonable = true
nameLabel.isSkeletonable = true
descLabel.isSkeletonable = true
usageLabel.isSkeletonable = true
```

### 3.2 TemplatesViewController

Conform to `SkeletonCollectionViewDataSource`. SkeletonView replaces the standard data source during skeleton display and calls only the `collectionSkeletonView` methods — the standard `numberOfItemsInSection` is **not** called while skeleton is active, so no collision with `templates.count`.

```swift
func collectionSkeletonView(_ skeletonView: UICollectionView,
                             numberOfCellsInSection section: Int) -> Int {
    currentLayoutMode == .grid ? 6 : 5
}

func collectionSkeletonView(_ skeletonView: UICollectionView,
                             cellIdentifierForItemAt indexPath: IndexPath) -> ReusableCellIdentifier {
    TemplateCell.reuseID
}
```

Show: `collectionView.showSkeleton(usingColor: .systemGray5, transition: .crossDissolve(0.25))`
Hide: `collectionView.hideSkeleton(reloadDataAfter: true, transition: .crossDissolve(0.25))`

---

## 4. Data Flow Summary

```
loadTemplates(reset: true)
  → showSkeleton()
  → TemplateCache.fetch(key)
      .fresh  → hideSkeleton, render [+ background refresh if aging]
      .stale  → hideSkeleton, render + foreground refresh
      .miss   → PPTAPIService → cache.store → hideSkeleton, render

loadTemplates(reset: false)  [pagination]
  → PPTAPIService directly (no cache)
  → insertItems (no skeleton)
```

---

## 5. Files Changed

| File | Change |
|------|--------|
| `Services/TemplateCache.swift` | **New** |
| `AppDelegate.swift` | Orphaned cache cleanup on launch |
| `Views/TemplateCell.swift` | Add `isSkeletonable` to subviews |
| `ViewControllers/TemplatesViewController.swift` | Cache integration + SkeletonView conformance + loadGeneration |
| `Services/PPTAPIService.swift` | No change |

---

## 6. Out of Scope

- Offline support
- Cache for pages 2+
- Manual cache-clear UI
- Error banner on refresh failure
- Codable conformance on model structs
