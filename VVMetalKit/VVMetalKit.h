#import <Foundation/Foundation.h>

//! Project version number for VVMetalKit.
FOUNDATION_EXPORT double VVMetalKitVersionNumber;

//! Project version string for VVMetalKit.
FOUNDATION_EXPORT const unsigned char VVMetalKitVersionString[];

#import <Metal/Metal.h>

#import <TargetConditionals.h>
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1

#import <VVMetalKitTouch/RenderProperties.h>
#import <VVMetalKitTouch/MTLEncodedDrawObject.h>
#import <VVMetalKitTouch/MTLImgBufferShaderTypes.h>
#import <VVMetalKitTouch/MTLImgBuffer.h>
#import <VVMetalKitTouch/MTLImgBufferPool.h>
#import <VVMetalKitTouch/MTLScene.h>
#import <VVMetalKitTouch/MTLComputeScene.h>
#import <VVMetalKitTouch/MTLRenderScene.h>
#import <VVMetalKitTouch/SwizzleMTLScene.h>
#import <VVMetalKitTouch/CopierMTLScene.h>
#import <VVMetalKitTouch/CustomMetalView.h>
#import <VVMetalKitTouch/MTLImgBufferRectView.h>
#import <VVMetalKitTouch/MTLImgBufferView.h>
#import <VVMetalKitTouch/MTLImgBufferRectViewShaderTypes.h>
//#import <VVMetalKitTouch/VVSizingTool.h>
#import <VVMetalKitTouch/SizingTool_c.h>
#import <VVMetalKitTouch/SizingTool_objc.h>
#import <VVMetalKitTouch/SizingTool_Metal.h>
#import <VVMetalKitTouch/SwizzleMTLScene.h>
#import <VVMetalKitTouch/VVColorConversions.h>
#import <VVMetalKitTouch/BilinearInterpolation.h>
#import <VVMetalKitTouch/BicubicInterpolation.h>

#import <VVMetalKitTouch/VVMTLTimestamp.h>
#import <VVMetalKitTouch/VVMTLImage.h>
#import <VVMetalKitTouch/VVMTLRecycleable.h>
#import <VVMetalKitTouch/VVMTLRecycleableDescriptor.h>
#import <VVMetalKitTouch/VVMTLRecyclingPool.h>
#import <VVMetalKitTouch/VVMTLBuffer.h>
#import <VVMetalKitTouch/VVMTLBufferDescriptor.h>
#import <VVMetalKitTouch/VVMTLTextureImage.h>
#import <VVMetalKitTouch/VVMTLTextureImageDescriptor.h>
#import <VVMetalKitTouch/VVMTLPool.h>

#else

#import <VVMetalKit/RenderProperties.h>
#import <VVMetalKit/MTLEncodedDrawObject.h>
#import <VVMetalKit/MTLImgBufferShaderTypes.h>
#import <VVMetalKit/MTLImgBuffer.h>
#import <VVMetalKit/MTLImgBufferPool.h>
#import <VVMetalKit/MTLScene.h>
#import <VVMetalKit/MTLComputeScene.h>
#import <VVMetalKit/MTLRenderScene.h>
#import <VVMetalKit/SwizzleMTLScene.h>
#import <VVMetalKit/CopierMTLScene.h>
#import <VVMetalKit/CustomMetalView.h>
#import <VVMetalKit/MTLImgBufferRectView.h>
#import <VVMetalKit/MTLImgBufferView.h>
#import <VVMetalKit/MTLImgBufferRectViewShaderTypes.h>
//#import <VVMetalKit/VVSizingTool.h>
#import <VVMetalKit/SizingTool_c.h>
#import <VVMetalKit/SizingTool_objc.h>
#import <VVMetalKit/SizingTool_metal.h>
#import <VVMetalKit/SwizzleMTLScene.h>
#import <VVMetalKit/VVColorConversions.h>
#import <VVMetalKit/BilinearInterpolation.h>
#import <VVMetalKit/BicubicInterpolation.h>

#import <VVMetalKit/VVMTLTimestamp.h>
#import <VVMetalKit/VVMTLImage.h>
#import <VVMetalKit/VVMTLRecycleable.h>
#import <VVMetalKit/VVMTLRecycleableDescriptor.h>
#import <VVMetalKit/VVMTLRecyclingPool.h>
#import <VVMetalKit/VVMTLBuffer.h>
#import <VVMetalKit/VVMTLBufferDescriptor.h>
#import <VVMetalKit/VVMTLTextureImage.h>
#import <VVMetalKit/VVMTLTextureImageDescriptor.h>
#import <VVMetalKit/VVMTLPool.h>

#endif

