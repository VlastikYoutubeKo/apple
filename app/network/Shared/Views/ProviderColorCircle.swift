//
//  ProviderColorCircle.swift
//  URnetwork
//
//  Created by Stuart Kuentzel on 8/5/25.
//

import SwiftUI

struct ProviderColorCircle: View {
    
    var color: Color
    
    init(_ color: Color) {
        self.color = color
    }
    
    #if os(iOS)
//    let padding: CGFloat = 16
    let circleWidth: CGFloat = 40
    #elseif os(macOS)
//    let padding: CGFloat = 0
    let circleWidth: CGFloat = 30
    #endif
    
    var body: some View {
        
        Circle()
            .frame(width: circleWidth, height: circleWidth)
            .foregroundColor(color)
        
    }
}

#Preview {
    ProviderColorCircle(
        .urCoral
    )
}
