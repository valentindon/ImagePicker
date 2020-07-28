import Foundation
import UIKit
import Photos

open class AssetManager {
  
  public static func getImage(_ name: String) -> UIImage {
    let traitCollection = UITraitCollection(displayScale: 3)
    var bundle = Bundle(for: AssetManager.self)
    
    if let resource = bundle.resourcePath, let resourceBundle = Bundle(path: resource + "/ImagePicker.bundle") {
      bundle = resourceBundle
    }
    
    return UIImage(named: name, in: bundle, compatibleWith: traitCollection) ?? UIImage()
  }
  
  public static func fetch(withConfiguration configuration: Configuration, _ completion: @escaping (_ assets: [PHAsset]) -> Void) {
    guard PHPhotoLibrary.authorizationStatus() == .authorized else { return }
    
    DispatchQueue.global(qos: .background).async {
      let fetchResult = configuration.allowVideoSelection
        ? PHAsset.fetchAssets(with: PHFetchOptions())
        : PHAsset.fetchAssets(with: .image, options: PHFetchOptions())
      
      if fetchResult.count > 0 {
        var assets = [PHAsset]()
        fetchResult.enumerateObjects({ object, _, _ in
          assets.insert(object, at: 0)
        })
        
        DispatchQueue.main.async {
          completion(assets)
        }
      }
    }
  }
  
  public static func resolveAsset(_ asset: PHAsset, size: CGSize = CGSize(width: 720, height: 1280), shouldPreferLowRes: Bool = false, completion: @escaping (_ image: UIImage?) -> Void) {
    let imageManager = PHImageManager.default()
    let requestOptions = PHImageRequestOptions()
    requestOptions.deliveryMode = shouldPreferLowRes ? .fastFormat : .highQualityFormat
    requestOptions.isNetworkAccessAllowed = true
    
    imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions) { image, info in
      if let info = info, info["PHImageFileUTIKey"] == nil {
        DispatchQueue.main.async(execute: {
          completion(image)
        })
      }
    }
  }
  
  public static func resolveAssets(_ assets: [PHAsset], size: CGSize = CGSize(width: 720, height: 1280)) -> [UIImage] {
    let imageManager = PHImageManager.default()
    let requestOptions = PHImageRequestOptions()
    requestOptions.isSynchronous = true
    
    var images = [UIImage]()
    for asset in assets {
      imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions) { image, _ in
        if let image = image {
          images.append(image)
        }
      }
    }
    return images
  }
  
  public static func assetsURLs (_ assets: [PHAsset], completionHandler: @escaping ([URL])->Void ) {
    var imageURLs = [URL]()
    let assetsGroup = DispatchGroup()
    for asset in assets {
      assetsGroup.enter()
      getURL(ofPhotoWith: asset) { (url) in
        if let url = url {
          imageURLs.append(url)
        }
        assetsGroup.leave()
      }
    }
    assetsGroup.notify(queue: .main) {
      completionHandler(imageURLs)
    }
    
  }
  
  private static func getURL(ofPhotoWith mPhasset: PHAsset, completionHandler : @escaping ((_ responseURL : URL?) -> Void)) {
    
    if mPhasset.mediaType == .image {
      let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
      options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
        return true
      }
      
      mPhasset.requestContentEditingInput(with: options, completionHandler: { (contentEditingInput, info) in
        completionHandler(contentEditingInput!.fullSizeImageURL)
      })
    } else if mPhasset.mediaType == .video {
      let options: PHVideoRequestOptions = PHVideoRequestOptions()
      options.version = .original
      PHImageManager.default().requestAVAsset(forVideo: mPhasset, options: options, resultHandler: { (asset, audioMix, info) in
        if let urlAsset = asset as? AVURLAsset {
          let localVideoUrl = urlAsset.url
          completionHandler(localVideoUrl)
        } else {
          completionHandler(nil)
        }
      })
    }
    
  }
}
