//
//  VVMTLUtilities.h
//  VVMetalKit
//
//  Created by testadmin on 7/5/23.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>

//NS_ASSUME_NONNULL_BEGIN

CGImageRef CreateCGImageRefFromMTLTexture(id<MTLTexture> inTex);

NSString * NSStringFromOSType(OSType n);

//NS_ASSUME_NONNULL_END
