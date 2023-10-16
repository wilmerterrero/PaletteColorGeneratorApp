//
//  PaletteColorGeneratorApp.swift
//  PaletteColorGenerator
//
//  Created by Wilmer Terrero on 15/10/23.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var colors: [(Color, String, Color)] = generateRandomColors()
    @State private var isHovered: Bool = false
    @State private var hoveredHex: String? = nil
    @State private var isLoading: Bool = false
    @State private var draggedIndex: Int?
    @State private var draggedOffset: CGSize = .zero
    @State private var isSidebarVisible: Bool = true
    
    var body: some View {
        NavigationView {
            sidebarView
            colorView
        }
    }
    
    var sidebarView: some View {
        List {
            ForEach(0..<10, id: \.self) { i in
                NavigationLink(destination: colorView) {
                    Text("User Palette \(i)")
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
    }
    
    var colorView: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                colorsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            header
        }
        .onSpacePress {
            colors = generateRandomColors()
        }
    }
    
    var uploadImageButton: some View {
        Button(action: uploadImage) {
            Image(systemName: "camera.fill")
                .foregroundColor(.white)
        }.help("Create palette from photo")
    }
    
    var saveButton: some View {
        Button(action: uploadImage) {
            Image(systemName: "heart.fill")
                .foregroundColor(.white)
        }.help("Save palette")
    }
    
    var settingsButton: some View {
        Button(action: uploadImage) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.white)
        }.help("Preferences")
    }
    
    var sidebarButton: some View {
        Button(action: toggleSidebar) {
            Image(systemName: "sidebar.right")
                .foregroundColor(.white)
        }.help("Preferences")
    }
    
    var header: some View {
        HStack(alignment: .center) {
            Spacer()
            HStack {
                HStack(spacing: 0) {
                    saveButton
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, 5)
                    uploadImageButton
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, 5)
                    settingsButton
                }
                .background(Color.black.opacity(0.1))
                .cornerRadius(10)
                sidebarButton
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding([.top, .trailing], 20)
    }
    
    var footer: some View {
        Text("Press spacebar to generate more colors").frame(maxWidth: .infinity, alignment: .center)
    }
    
    var colorsList: some View {
        List {
            Section(footer: footer) {
                ForEach(colors.indices, id: \.self) { index in
                    let (color, hexString, contrastColor) = colors[index]
                    ZStack {
                        Rectangle()
                            .fill(color)
                            .onHover { hovering in
                                hoveredHex = hovering ? hexString : nil
                            }
                        
                        Button(action: {
                            copyToClipboard(hexString)
                        }) {
                            Image(systemName: "doc.on.doc.fill")
                                .foregroundColor(contrastColor)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding([.top, .trailing], 20)
                        .help("Copy to clipboard")
                        
                        Text(hexString)
                            .foregroundColor(contrastColor)
                            .font(.body)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(height: 50)
                }
                .onMove { indices, newOffset in
                    colors.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
        }
        .listStyle(.plain)
    }
    
    func uploadImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.jpeg, .png]
        
        if panel.runModal() == .OK {
            if let url = panel.url, let image = NSImage(contentsOf: url) {
                isLoading = true
                processImage(image)
            }
        }
    }
    
    func processImage(_ image: NSImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let pixelDataArray = pixelData(from: image) {
                let width = Int(image.size.width)
                let height = Int(image.size.height)
                let _colors = analyzeBitmap(pixelDataArray, width: width, height: height)
                let dominantColors = kMeans(colors: _colors, k: 5, iterations: 10)
                DispatchQueue.main.async {
                    colors = dominantColors.map { color in
                        let swiftUIColor = Color(color)
                        return (swiftUIColor, color.toHex(), swiftUIColor.contrast())
                    }
                    isLoading = false
                }
            }
        }
    }
    
    func toggleSidebar() {
        #if os(macOS)
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        #endif
    }
}

func analyzeBitmap(_ data: [UInt8], width: Int, height: Int) -> [NSColor] {
    var colors: [NSColor] = []

    for y in 0..<height {
        for x in 0..<width {
            let pixelInfo: Int = ((width * y) + x) * 4
            let r = CGFloat(data[pixelInfo]) / CGFloat(255.0)
            let g = CGFloat(data[pixelInfo + 1]) / CGFloat(255.0)
            let b = CGFloat(data[pixelInfo + 2]) / CGFloat(255.0)
            let a = CGFloat(data[pixelInfo + 3]) / CGFloat(255.0)

            colors.append(NSColor(red: r, green: g, blue: b, alpha: a))
        }
    }
    return colors
}

func averageColor(_ colors: [NSColor]) -> NSColor {
    let count = CGFloat(colors.count)
    let sumRed = colors.reduce(CGFloat(0)) { $0 + $1.redComponent }
    let sumGreen = colors.reduce(CGFloat(0)) { $0 + $1.greenComponent }
    let sumBlue = colors.reduce(CGFloat(0)) { $0 + $1.blueComponent }

    return NSColor(
        red: sumRed / count,
        green: sumGreen / count,
        blue: sumBlue / count,
        alpha: 1.0
    )
}

func kMeans(colors: [NSColor], k: Int, iterations: Int) -> [NSColor] {
    var centroids = randomCentroids(colors: colors, k: k)
    var lastCentroids = [NSColor]()

    for _ in 0..<iterations {
        var clusters: [[NSColor]] = .init(repeating: [], count: k)

        // Cluster Assignment
        for color in colors {
            let closestCentroidIndex = nearestCentroidIndex(for: color, centroids: centroids)
            clusters[closestCentroidIndex].append(color)
        }

        lastCentroids = centroids

        // Recalculate Centroids
        for i in 0..<k {
            centroids[i] = averageColor(clusters[i])
        }

        // Convergence Check
        if centroids == lastCentroids {
            break
        }
    }

    return centroids
}

func randomCentroids(colors: [NSColor], k: Int) -> [NSColor] {
    return Array(colors.shuffled().prefix(k))
}

func nearestCentroidIndex(for color: NSColor, centroids: [NSColor]) -> Int {
    var minDistance: CGFloat = .greatestFiniteMagnitude
    var minIndex = 0

    for (index, centroid) in centroids.enumerated() {
        let distance = colorDistance(color, centroid)
        if distance < minDistance {
            minDistance = distance
            minIndex = index
        }
    }
    return minIndex
}

func colorDistance(_ a: NSColor, _ b: NSColor) -> CGFloat {
    let r = pow(a.redComponent - b.redComponent, 2)
    let g = pow(a.greenComponent - b.greenComponent, 2)
    let bl = pow(a.blueComponent - b.blueComponent, 2)
    return sqrt(r + g + bl)
}


func pixelData(from image: NSImage) -> [UInt8]? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

    let width = cgImage.width
    let height = cgImage.height

    let bitsPerComponent = 8
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let totalBytes = height * bytesPerRow

    var data = [UInt8](repeating: 0, count: totalBytes)

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: &data, width: width, height: height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    return data
}


func generateRandomColors() -> [(Color, String, Color)] {
    var newColors: [(Color, String, Color)] = []
    for _ in 0..<5 {
        let red = CGFloat.random(in: 0...1)
        let green = CGFloat.random(in: 0...1)
        let blue = CGFloat.random(in: 0...1)
        
        let color = Color(red: Double(red), green: Double(green), blue: Double(blue))
        
        let hexString = String(format: "#%02X%02X%02X",
                               Int(red * 255),
                               Int(green * 255),
                               Int(blue * 255))
        
        newColors.append((color, hexString, color.contrast()))
    }
    return newColors
}

func copyToClipboard(_ string: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.declareTypes([.string], owner: nil)
    pasteboard.setString(string, forType: .string)
}


struct SpacebarObserver: NSViewRepresentable {
    let action: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 49 {
                self.action()
            }
            return event
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Do nothing
    }
}

@main
struct PaletteColorGenerator: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationTitle("Palette")
                .environment(\.colorScheme, .light) // for test
        }
        .commands {
            SidebarCommands()
        }
    }
}

extension View {
    func onSpacePress(perform action: @escaping () -> Void) -> some View {
        background(SpacebarObserver(action: action))
    }
}

extension NSColor {
    func toHex() -> String {
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(Float(redComponent) * 255.0),
                      lroundf(Float(greenComponent) * 255.0),
                      lroundf(Float(blueComponent) * 255.0))
    }
}

extension Color {
    func contrast() -> Color {
        let uiColor = NSColor(self)
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let yiq = (Double(red) * 299 + Double(green) * 587 + Double(blue) * 114) / 1000
        return yiq >= 0.5 ? Color.black : Color.white
    }
}
