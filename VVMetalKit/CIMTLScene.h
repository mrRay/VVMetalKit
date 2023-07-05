//
//  CIMTLScene.h
//  VVTestApps
//
//  Created by testadmin on 7/5/23.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <VVMetalKit/VVMTLScene.h>
#import <VVMetalKit/VVMTLTextureImage.h>

NS_ASSUME_NONNULL_BEGIN




@interface CIMTLScene : VVMTLScene

- (instancetype) initWithDevice:(id<MTLDevice>)inDevice;

- (void) renderCIImage:(CIImage *)inCIImage toTexture:(id<VVMTLTextureImage>)inTex inCommandBuffer:(id<MTLCommandBuffer>)inCB;

- (id<VVMTLTextureImage>) renderCIImage:(CIImage *)inCIImage toTextureSized:(NSSize)inSize inCommandBuffer:(id<MTLCommandBuffer>)inCB;

@end




NS_ASSUME_NONNULL_END
