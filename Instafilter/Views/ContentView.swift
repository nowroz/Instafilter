//
//  ContentView.swift
//  Instafilter
//
//  Created by Nowroz Islam on 8/7/24.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var processedImage: Image?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var intensity: Double = 0.5
    @State private var currentFilter: CIFilter = .sepiaTone()
    @State private var showingConfirmationDialog: Bool = false
    
    @AppStorage("changeFilterTapCount") private var changeFilterTapCount: Int = 0
    @Environment(\.requestReview) private var requestReview
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    if let processedImage {
                        processedImage
                            .resizable()
                            .scaledToFit()
                    } else {
                        ContentUnavailableView("No Photo", systemImage: "photo.badge.plus", description: Text("Tap to import a photo."))
                    }
                }
                .buttonStyle(.plain)
                .onChange(of: photosPickerItem, loadImage)
                
                Spacer()
                
                VStack(spacing: 20){
                    LabeledContent("Intensity") {
                        Slider(value: $intensity, in: 0...1)
                    }
                    
                    HStack {
                        Button("Change Filter", systemImage: "camera.filters", action: changeFilter)
                        
                        Spacer()
                        
                        if let processedImage {
                            ShareLink(item: processedImage, preview: SharePreview("Instafilter Image", image: processedImage))
                        }
                    }
                }
            }
            .navigationTitle("Instafilter")
            .padding()
            .onChange(of: intensity, applyProcessing)
            .confirmationDialog("Change filter", isPresented: $showingConfirmationDialog) {
                Button("Crystalize") { setFilter(.crystallize()) }
                Button("Edges") { setFilter(.edges()) }
                Button("Gaussian Blur") { setFilter(.gaussianBlur()) }
                Button("Pixellate") { setFilter(.pixellate()) }
                Button("Sepia Tone") { setFilter(.sepiaTone()) }
                Button("Unsharp Mask") { setFilter(.unsharpMask()) }
                Button("Vignette") { setFilter(.vignette()) }
            }
        }
    }
    
    func changeFilter() {
        showingConfirmationDialog = true
    }
    
    @MainActor func setFilter(_ filter: CIFilter) {
        guard photosPickerItem != nil else { return }
        currentFilter = filter
        loadImage()
        
        changeFilterTapCount += 1
        
        if changeFilterTapCount > 20 {
            requestReview()
        }
    }
    
    func loadImage() {
        Task { @MainActor in
            guard let imageData = try? await photosPickerItem?.loadTransferable(type: Data.self) else {
                fatalError("Failed to load image data")
            }
            
            let uiImage = UIImage(data: imageData)
            
            guard let uiImage else {
                fatalError("Failed to create UIImage from image data")
            }
            
            let inputImage = CIImage(image: uiImage)
            
            guard let inputImage else {
                fatalError("Failed to create CIImage from UIImage")
            }
            
            currentFilter.setValue(inputImage, forKey: kCIInputImageKey)
            
            applyProcessing()
        }
    }
    
    func setFilterValues() {
        if currentFilter.inputKeys.contains(kCIInputIntensityKey) {
            currentFilter.setValue(intensity, forKey: kCIInputIntensityKey)
        }
        if currentFilter.inputKeys.contains(kCIInputRadiusKey) {
            currentFilter.setValue(intensity * 200, forKey: kCIInputRadiusKey)
        }
        if currentFilter.inputKeys.contains(kCIInputScaleKey) {
            currentFilter.setValue(intensity * 10, forKey: kCIInputScaleKey)
        }
    }
    
    func applyProcessing() {
        guard photosPickerItem != nil  else { return }
        
        setFilterValues()
        
        guard let outputImage = currentFilter.outputImage else {
            fatalError("Failed to apply filter to CIImage")
        }
        
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            fatalError("Failed to create CGImage from CIImage")
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        processedImage = Image(uiImage: uiImage)
    }
}

#Preview {
    ContentView()
}
