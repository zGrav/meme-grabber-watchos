//
//  ContentView.swift
//  meme-grabber-watchos Watch App
//
//  Created by David Silva on 31.05.25.
//

import SwiftUI

struct RedditResponse: Codable {
    struct DataContainer: Codable {
        struct Child: Codable {
            struct PostData: Codable {
                let url: String
                let post_hint: String?
            }
            let data: PostData
        }
        let children: [Child]
    }
    let data: DataContainer
}

@MainActor
class MemeFetcher: ObservableObject {
    @Published var memeImage: UIImage? = nil
    @Published var isLoading = false
    @Published private(set) var lastMemeURL: URL? = nil
    
    func fetchRandomMeme() async {
        isLoading = true
        memeImage = nil
        
        do {
            let url = URL(string: "https://www.reddit.com/r/memes/top.json?limit=50&t=day")!
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let response = try JSONDecoder().decode(RedditResponse.self, from: data)
            let memes = response.data.children.filter {
                $0.data.post_hint == "image" && (
                    $0.data.url.hasSuffix(".jpg") ||
                    $0.data.url.hasSuffix(".png") ||
                    $0.data.url.hasSuffix(".jpeg")
                )
            }
            
            let filteredMemes = memes.filter {
                URL(string: $0.data.url) != lastMemeURL
            }
            
            let memeToLoad = (filteredMemes.isEmpty ? memes : filteredMemes).randomElement()
            
            if let randomMeme = memeToLoad,
               let imageURL = URL(string: randomMeme.data.url) {
                let (imgData, _) = try await URLSession.shared.data(from: imageURL)
                if let uiImage = UIImage(data: imgData) {
                    memeImage = uiImage
                    lastMemeURL = imageURL
                } else {
                    memeImage = nil
                }
            } else {
                memeImage = nil
            }
        } catch {
            print("Error fetching meme or image:", error)
            memeImage = nil
        }
        
        isLoading = false
    }
}

struct ContentView: View {
    @StateObject private var fetcher = MemeFetcher()
    
    @State private var isZoomed = false
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero

    var body: some View {
        VStack {
            if fetcher.isLoading {
                ProgressView("Loading Meme...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let uiImage = fetcher.memeImage {
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width)
                        .scaleEffect(isZoomed ? 2.0 : 1.0)
                        .offset(offset)
                        .onTapGesture {
                            withAnimation {
                                if isZoomed {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                                isZoomed.toggle()
                            }
                        }
                        .gesture(
                            isZoomed ?
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height)
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                            : nil
                        )
                }
                .frame(height: 150)
            } else {
                Text("Tap below to load a meme.")
                    .multilineTextAlignment(.center)
                    .padding()
                    .textScale(Text.Scale.default)
            }
            
            if fetcher.memeImage != nil && !isZoomed {
                Text("Tap to zoom in/out.")
                    .textScale(Text.Scale.secondary)
            }
            
            if !isZoomed {
                Button("Load Meme") {
                    Task {
                        await fetcher.fetchRandomMeme()
                        withAnimation {
                            isZoomed = false
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
