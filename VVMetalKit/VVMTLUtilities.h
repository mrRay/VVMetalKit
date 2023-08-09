//
//  VVMTLUtilities.h
//  VVMetalKit
//
//  Created by testadmin on 7/5/23.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>
@protocol VVMTLTextureImage;

//NS_ASSUME_NONNULL_BEGIN




void CGBitmapContextUnpremultiply(CGContextRef ctx);

CGImageRef CreateCGImageRefFromVVMTLTextureImage(id<VVMTLTextureImage> inImg);
CGImageRef CreateCGImageRefFromResizedVVMTLTextureImage(id<VVMTLTextureImage> inImg, NSSize imgSize);

CGImageRef CreateCGImageRefFromMTLTexture(id<MTLTexture> inTex);
CGImageRef CreateCGImageRefFromResizedMTLTexture(id<MTLTexture> inTex, NSSize imgSize);

id<VVMTLTextureImage> CreateTextureFromCGImage(CGImageRef inImg);
id<VVMTLTextureImage> CreateTextureFromResizedCGImage(CGImageRef inImg, NSSize imgSize);

NSString * NSStringFromOSType(OSType n);
NSString * NSStringFromMTLPixelFormat(MTLPixelFormat n);




@interface NSImage (NSImageVVMTLUtilities)

+ (NSImage *) createFromMTLTexture:(id<MTLTexture>)n;
+ (NSImage *) createFromMTLTexture:(id<MTLTexture>)n sized:(NSSize)inSize;

@end




//NS_ASSUME_NONNULL_END
