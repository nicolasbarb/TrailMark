# Editor Scrollable Profile Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor EditorView to use a horizontally scrollable elevation profile with a center marker for point selection.

**Architecture:** Replace the map+tabs layout with a single scrollable profile (50% height). The profile uses `ScrollView(.horizontal)` with padding so first/last points can reach the center marker. A fixed overlay shows the center marker, and a button below adds milestones at the current position.

**Tech Stack:** SwiftUI, TCA, Canvas, ScrollView with `.scrollPosition(id:)`

---

### Task 1: Add scroll position state to EditorFeature

**Files:**
- Modify: `TrailMark/Features/Editor/EditorFeature.swift:70-83`

**Step 1: Add scrolledPointIndex state**

In `EditorFeature.State`, add after `cursorPointIndex`:

```swift
var scrolledPointIndex: Int = 0
```

**Step 2: Add action for scroll position changes**

In `EditorFeature.Action`, add:

```swift
case scrollPositionChanged(Int)
```

**Step 3: Handle the action in reducer**

In the reducer body, add case:

```swift
case let .scrollPositionChanged(index):
    state.scrolledPointIndex = index
    return .none
```

**Step 4: Commit**

```bash
git add TrailMark/Features/Editor/EditorFeature.swift
git commit -m "feat(editor): add scrolledPointIndex state for scrollable profile"
```

---

### Task 2: Create ScrollableElevationProfileView

**Files:**
- Create: `TrailMark/Views/Components/ScrollableElevationProfileView.swift`

**Step 1: Create the new component**

```swift
import SwiftUI

struct ScrollableElevationProfileView: View {
    let trackPoints: [TrackPoint]
    let milestones: [Milestone]
    @Binding var scrolledPointIndex: Int

    private let pointSpacing: CGFloat = 6
    private let profileHeight: CGFloat = 200

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding = geometry.size.width / 2

            ZStack {
                // Background
                TM.bgSecondary

                // Scrollable profile
                ScrollView(.horizontal, showsIndicators: false) {
                    Canvas { context, size in
                        drawProfile(context: context, size: size, horizontalPadding: horizontalPadding)
                    }
                    .frame(
                        width: horizontalPadding * 2 + CGFloat(trackPoints.count) * pointSpacing,
                        height: geometry.size.height
                    )
                    .scrollTargetLayout()
                }
                .scrollPosition(id: Binding(
                    get: { scrolledPointIndex },
                    set: { if let newValue = $0 { scrolledPointIndex = newValue } }
                ))
                .scrollTargetBehavior(.viewAligned)

                // Center marker overlay (fixed)
                CenterMarkerView()
            }
        }
    }

    // MARK: - Drawing

    private func drawProfile(context: GraphicsContext, size: CGSize, horizontalPadding: CGFloat) {
        guard trackPoints.count >= 2 else { return }

        let paddingTop: CGFloat = 20
        let paddingBottom: CGFloat = 30

        let plotRect = CGRect(
            x: horizontalPadding,
            y: paddingTop,
            width: CGFloat(trackPoints.count) * pointSpacing,
            height: size.height - paddingTop - paddingBottom
        )

        let elevations = trackPoints.map(\.elevation)
        let minEle = elevations.min() ?? 0
        let maxEle = elevations.max() ?? 0
        let eleRange = max(maxEle - minEle, 1)

        // Draw fill
        drawFill(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)

        // Draw elevation line
        drawElevationLine(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)

        // Draw milestones
        drawMilestones(context: context, plotRect: plotRect, minEle: minEle, eleRange: eleRange)

        // Draw scroll target areas (invisible, for scroll positioning)
        drawScrollTargets(context: context, plotRect: plotRect)
    }

    private func drawFill(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        var fillPath = Path()

        for (index, point) in trackPoints.enumerated() {
            let x = plotRect.minX + CGFloat(index) * pointSpacing
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if index == 0 {
                fillPath.move(to: CGPoint(x: x, y: plotRect.maxY))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            } else {
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        let lastX = plotRect.minX + CGFloat(trackPoints.count - 1) * pointSpacing
        fillPath.addLine(to: CGPoint(x: lastX, y: plotRect.maxY))
        fillPath.closeSubpath()

        let gradient = Gradient(colors: [TM.trace.opacity(0.2), TM.trace.opacity(0.02)])
        context.fill(fillPath, with: .linearGradient(
            gradient,
            startPoint: CGPoint(x: 0, y: plotRect.minY),
            endPoint: CGPoint(x: 0, y: plotRect.maxY)
        ))
    }

    private func drawElevationLine(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        var linePath = Path()

        for (index, point) in trackPoints.enumerated() {
            let x = plotRect.minX + CGFloat(index) * pointSpacing
            let y = plotRect.maxY - CGFloat((point.elevation - minEle) / eleRange) * plotRect.height

            if index == 0 {
                linePath.move(to: CGPoint(x: x, y: y))
            } else {
                linePath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(linePath, with: .color(TM.trace), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
    }

    private func drawMilestones(context: GraphicsContext, plotRect: CGRect, minEle: Double, eleRange: Double) {
        for (index, milestone) in milestones.enumerated() {
            guard milestone.pointIndex < trackPoints.count else { continue }

            let x = plotRect.minX + CGFloat(milestone.pointIndex) * pointSpacing
            let y = plotRect.maxY - CGFloat((milestone.elevation - minEle) / eleRange) * plotRect.height

            // Dashed line down
            var dashPath = Path()
            dashPath.move(to: CGPoint(x: x, y: y))
            dashPath.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(dashPath, with: .color(TM.accent.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

            // Circle background
            let circleRect = CGRect(x: x - 8, y: y - 8, width: 16, height: 16)
            context.fill(Path(ellipseIn: circleRect), with: .color(milestone.milestoneType.color))

            // Circle border
            context.stroke(Path(ellipseIn: circleRect), with: .color(TM.bgPrimary), lineWidth: 2)

            // Number
            let text = Text("\(index + 1)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            context.draw(text, at: CGPoint(x: x, y: y), anchor: .center)
        }
    }

    private func drawScrollTargets(context: GraphicsContext, plotRect: CGRect) {
        // Draw invisible anchors for scroll positioning
        // This is handled by scrollTargetLayout on the container
    }
}

// MARK: - Center Marker

struct CenterMarkerView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Triangle pointing down
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundStyle(TM.accent)

            // Vertical line
            Rectangle()
                .fill(TM.accent.opacity(0.8))
                .frame(width: 2)
        }
        .frame(maxHeight: .infinity)
    }
}
```

**Step 2: Commit**

```bash
git add TrailMark/Views/Components/ScrollableElevationProfileView.swift
git commit -m "feat(editor): create ScrollableElevationProfileView component"
```

---

### Task 3: Add scroll target anchors for point-by-point scrolling

**Files:**
- Modify: `TrailMark/Views/Components/ScrollableElevationProfileView.swift`

**Step 1: Replace ScrollView content with LazyHStack of anchors**

Update the body to use scroll anchors:

```swift
var body: some View {
    GeometryReader { geometry in
        let horizontalPadding = geometry.size.width / 2
        let totalWidth = horizontalPadding * 2 + CGFloat(trackPoints.count) * pointSpacing

        ZStack {
            TM.bgSecondary

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .leading) {
                    // Canvas for drawing
                    Canvas { context, size in
                        drawProfile(context: context, size: size, horizontalPadding: horizontalPadding)
                    }
                    .frame(width: totalWidth, height: geometry.size.height)

                    // Invisible scroll anchors
                    LazyHStack(spacing: 0) {
                        ForEach(0..<trackPoints.count, id: \.self) { index in
                            Color.clear
                                .frame(width: pointSpacing, height: 1)
                                .id(index)
                        }
                    }
                    .padding(.leading, horizontalPadding - pointSpacing / 2)
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: Binding(
                get: { scrolledPointIndex },
                set: { if let newValue = $0 { scrolledPointIndex = newValue } }
            ))
            .scrollTargetBehavior(.viewAligned)
            .defaultScrollAnchor(.center)

            CenterMarkerView()
        }
    }
}
```

**Step 2: Commit**

```bash
git add TrailMark/Views/Components/ScrollableElevationProfileView.swift
git commit -m "feat(editor): add scroll anchors for point-by-point navigation"
```

---

### Task 4: Refactor EditorView to use new layout

**Files:**
- Modify: `TrailMark/Views/EditorView.swift`

**Step 1: Remove map and tabs, add scrollable profile**

Replace the `body` and remove `tabPicker`, `tabContent`, `mapTab`:

```swift
var body: some View {
    ZStack {
        TM.bgPrimary.ignoresSafeArea()

        if let detail = store.trailDetail {
            VStack(spacing: 0) {
                // Scrollable profile (50% height)
                ScrollableElevationProfileView(
                    trackPoints: detail.trackPoints,
                    milestones: store.milestones,
                    scrolledPointIndex: Binding(
                        get: { store.scrolledPointIndex },
                        set: { store.send(.scrollPositionChanged($0)) }
                    )
                )
                .containerRelativeFrame(.vertical) { height, _ in height / 2 }

                Divider()
                    .background(TM.bgTertiary)

                // Stats for current point
                if store.scrolledPointIndex < detail.trackPoints.count {
                    let point = detail.trackPoints[store.scrolledPointIndex]
                    currentPointStats(point: point)
                }

                // Add milestone button
                addMilestoneButton

                Spacer()
            }
        } else {
            ProgressView()
                .tint(TM.accent)
        }
    }
    .toolbar {
        ToolbarItem(placement: .title) {
            if let detail = store.trailDetail {
                Text(detail.trail.name)
            }
        }
        ToolbarItem(placement: .subtitle) {
            if let detail = store.trailDetail {
                TrailStatsView(distanceKm: detail.distKm, dPlus: detail.trail.dPlus)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Renommer", systemImage: "square.and.pencil") {
                Haptic.light.trigger()
                store.send(.renameButtonTapped)
            }
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .destructiveAction) {
            Button("Supprimer", systemImage: "trash", role: .destructive) {
                Haptic.warning.trigger()
                store.send(.deleteTrailButtonTapped)
            }
            .tint(Color.red)
        }
    }
    .toolbarRole(.editor)
    .alert($store.scope(state: \.alert, action: \.alert))
    .alert(
        "Renommer le parcours",
        isPresented: Binding(
            get: { store.isRenamingTrail },
            set: { if !$0 { store.send(.renameCancelled) } }
        )
    ) {
        TextField("Nom du parcours", text: $store.editedTrailName)
        Button("Annuler", role: .cancel) {
            Haptic.light.trigger()
            store.send(.renameCancelled)
        }
        Button("Renommer") {
            Haptic.medium.trigger()
            store.send(.renameConfirmed)
        }
        .keyboardShortcut(.defaultAction)
    }
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
        store.send(.onAppear)
    }
    .sheet(
        item: $store.scope(state: \.milestoneSheet, action: \.milestoneSheet)
    ) { sheetStore in
        MilestoneSheetView(store: sheetStore)
            .presentationDetents([.large])
            .presentationBackground(TM.bgCard)
    }
}
```

**Step 2: Add current point stats view**

```swift
private func currentPointStats(point: TrackPoint) -> some View {
    HStack(spacing: 24) {
        VStack(spacing: 2) {
            Text("ALTITUDE")
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .foregroundStyle(TM.textMuted)
            Text("\(Int(point.elevation)) m")
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(TM.textPrimary)
        }

        VStack(spacing: 2) {
            Text("DISTANCE")
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .foregroundStyle(TM.textMuted)
            Text(String(format: "%.2f km", point.distance / 1000))
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(TM.textPrimary)
        }
    }
    .padding(.vertical, 16)
}
```

**Step 3: Add milestone button**

```swift
private var addMilestoneButton: some View {
    Button {
        Haptic.medium.trigger()
        store.send(.profileTapped(store.scrolledPointIndex))
    } label: {
        Label("Ajouter un repère", systemImage: "plus.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(TM.accent, in: RoundedRectangle(cornerRadius: 12))
    }
    .padding(.horizontal, 20)
}
```

**Step 4: Remove or comment old code**

Comment out: `tabPicker`, `tabContent`, `mapTab`, `milestonesTab`, `milestonesEmptyState`, `milestonesList`, `milestoneRow`, and related toolbar items for milestones selection.

**Step 5: Commit**

```bash
git add TrailMark/Views/EditorView.swift
git commit -m "feat(editor): refactor to scrollable profile layout"
```

---

### Task 5: Update EditorFeature to use scrolledPointIndex for milestone creation

**Files:**
- Modify: `TrailMark/Features/Editor/EditorFeature.swift`

**Step 1: Update profileTapped to use scrolledPointIndex**

The `profileTapped` action already takes an index, so no changes needed. The EditorView now passes `store.scrolledPointIndex` to it.

**Step 2: Remove cursorPointIndex if no longer needed**

Keep `cursorPointIndex` for now (might be useful later), but it's no longer used.

**Step 3: Commit**

```bash
git add TrailMark/Features/Editor/EditorFeature.swift
git commit -m "refactor(editor): scrolledPointIndex replaces cursor for milestone creation"
```

---

### Task 6: Test and refine scroll behavior

**Files:**
- Modify: `TrailMark/Views/Components/ScrollableElevationProfileView.swift`

**Step 1: Run the app and test scrolling**

Build and run. Verify:
- Profile scrolls horizontally
- First point starts at center
- Last point can reach center
- Center marker stays fixed
- Milestones are visible on the curve

**Step 2: Adjust pointSpacing if needed**

If scroll is too fast/slow, adjust `pointSpacing`:
- More points → reduce spacing (e.g., `max(3, 2000 / trackPoints.count)`)
- Fewer points → increase spacing

**Step 3: Add haptic feedback on scroll stop**

```swift
.onChange(of: scrolledPointIndex) { _, _ in
    Haptic.selection.trigger()
}
```

**Step 4: Commit**

```bash
git add TrailMark/Views/Components/ScrollableElevationProfileView.swift
git commit -m "fix(editor): refine scroll behavior and add haptic feedback"
```

---

### Task 7: Clean up unused code

**Files:**
- Modify: `TrailMark/Views/EditorView.swift`
- Optionally delete: `TrailMark/Views/Components/ElevationProfileView.swift` (or keep for reference)

**Step 1: Remove commented code or move to separate file**

Remove the commented milestones tab code if not needed, or keep it clearly marked for future reactivation.

**Step 2: Remove unused imports**

Remove `import MapKit` from EditorView if no longer needed.

**Step 3: Update previews**

Update the `#Preview` macros to work with the new layout.

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore(editor): clean up unused code after refactor"
```
