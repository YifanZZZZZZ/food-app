//
//  Utils.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 6/26/25.
//

import SwiftUI

func imageFromBase64(_ base64String: String) -> Image {
    guard let data = Data(base64Encoded: base64String),
          let uiImage = UIImage(data: data) else {
        return Image(systemName: "photo")
    }
    return Image(uiImage: uiImage)
}
