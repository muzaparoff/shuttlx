//
//  ViewPerformanceModifiers.swift
//  ShuttlX
//
//  SwiftUI performance optimization modifiers
//  Created by ShuttlX on 6/9/25.
//

import SwiftUI
import Combine

// MARK: - Optimized List Components

/// High-performance list view with memory management
struct OptimizedListView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    
    @State private var visibleRange: Range<Data.Index>
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    
    init(
        data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
        self._visibleRange = State(initialValue: data.startIndex..<data.endIndex)
    }
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(data[visibleRange]), id: \.id) { item in
                content(item)
                    .optimizedForLists()
            }
        }
        .onPreferenceChange(ViewOffsetKey.self) { offset in
            updateVisibleRange(offset: offset)
        }
    }
    
    private func updateVisibleRange(offset: CGFloat) {
        // Implement smart viewport calculation for large lists
        let itemHeight: CGFloat = 80 // Estimated item height
        let viewportHeight: CGFloat = 600 // Estimated viewport height
        
        let startIndex = max(0, Int(abs(offset) / itemHeight) - 5)
        let endIndex = min(data.count, startIndex + Int(viewportHeight / itemHeight) + 10)
        
        if startIndex < data.count {
            let newRange = data.index(data.startIndex, offsetBy: startIndex)..<data.index(data.startIndex, offsetBy: endIndex)
            if newRange != visibleRange {
                visibleRange = newRange
            }
        }
    }
}

// MARK: - Performance Monitoring Views

struct PerformanceIndicatorView: View {
    @StateObject private var performanceService = PerformanceOptimizationService.shared
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(performanceService.memoryUsage.color)
                    .frame(width: 8, height: 8)
                
                Text("Performance")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showDetails.toggle() }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if showDetails {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Memory:")
                        Spacer()
                        Text(performanceService.memoryUsage.description)
                            .foregroundColor(performanceService.memoryUsage.color)
                    }
                    .font(.caption2)
                    
                    Button("Optimize") {
                        performanceService.performMemoryCleanup()
                    }
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Optimized Chart Components

struct OptimizedProgressChart: View {
    let data: [Double]
    let color: Color
    let animated: Bool
    
    @State private var animationProgress: Double = 0
    
    init(data: [Double], color: Color = .blue, animated: Bool = true) {
        self.data = data
        self.color = color
        self.animated = animated
    }
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let maxValue = data.max() ?? 1
                let width = geometry.size.width
                let height = geometry.size.height
                let stepWidth = width / CGFloat(data.count - 1)
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepWidth
                    let y = height - (CGFloat(value) / CGFloat(maxValue)) * height * animationProgress
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .drawingGroup() // Optimize rendering
        }
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 1.0)) {
                    animationProgress = 1.0
                }
            } else {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Memory-Efficient Image Loading

struct OptimizedAsyncImage: View {
    let url: URL?
    let placeholder: Image
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholder
                    .foregroundColor(.secondary)
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .overlay(
            Group {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        )
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        
        isLoading = true
        
        // Use background queue for image loading
        DispatchQueue.global(qos: .background).async {
            do {
                let data = try Data(contentsOf: url)
                if let loadedImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.image = loadedImage
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue = CGFloat.zero
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}

// MARK: - Performance-Optimized Containers

struct OptimizedScrollView<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let content: Content
    
    @State private var scrollOffset: CGFloat = 0
    
    init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content()
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ViewOffsetKey.self,
                            value: -geometry.frame(in: .named("scroll")).origin.y
                        )
                    }
                )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ViewOffsetKey.self) { value in
            scrollOffset = value
        }
    }
}

// MARK: - Debounced Search Field

struct DebouncedSearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSearchChanged: (String) -> Void
    
    @State private var debouncedText = ""
    @State private var debounceTimer: Timer?
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .onChange(of: text) { _, newValue in
                debounceTimer?.invalidate()
                debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    debouncedText = newValue
                    onSearchChanged(newValue)
                }
            }
    }
}
