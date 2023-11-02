#import <Foundation/Foundation.h>

//! Project version number for VVMetalKit.
FOUNDATION_EXPORT double VVMetalKitVersionNumber;

//! Project version string for VVMetalKit.
FOUNDATION_EXPORT const unsigned char VVMetalKitVersionString[];

#import <Metal/Metal.h>

#import <TargetConditionals.h>
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1

#import <VVMetalKitTouch/RenderProperties.h>
#import <VVMetalKitTouch/SwizzleMTLScene.h>
#import <VVMetalKitTouch/CopierMTLScene.h>
#import <VVMetalKitTouch/CustomMetalView.h>
#import <VVMetalKitTouch/CMVMTLDrawObject.h>
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
#import <VVMetalKitTouch/VVMTLLUT.h>
#import <VVMetalKitTouch/VVMTLRecycleable.h>
#import <VVMetalKitTouch/VVMTLRecycleableDescriptor.h>
#import <VVMetalKitTouch/VVMTLRecyclingPool.h>
#import <VVMetalKitTouch/VVMTLBuffer.h>
#import <VVMetalKitTouch/VVMTLBufferDescriptor.h>
#import <VVMetalKitTouch/VVMTLTextureImage.h>
#import <VVMetalKitTouch/VVMTLTextureImageDescriptor.h>
#import <VVMetalKitTouch/VVMTLTextureLUT.h>
#import <VVMetalKitTouch/VVMTLTextureLUTDescriptor.h>
#import <VVMetalKitTouch/VVMTLPool.h>

#import <VVMetalKitTouch/VVMTLScene.h>
#import <VVMetalKitTouch/VVMTLComputeScene.h>
#import <VVMetalKitTouch/VVMTLRenderScene.h>

#import <VVMetalKitTouch/VVMTLTextureImageRectView.h>
#import <VVMetalKitTouch/VVMTLTextureImageView.h>
#import <VVMetalKitTouch/VVMTLTextureImageRectViewShaderTypes.h>
#import <VVMetalKitTouch/VVMTLTextureImageShaderTypes.h>

#import <VVMetalKitTouch/VVMTLUtilities.h>
#import <VVMetalKitTouch/CIMTLScene.h>

#else

#import <VVMetalKit/RenderProperties.h>
#import <VVMetalKit/SwizzleMTLScene.h>
#import <VVMetalKit/CopierMTLScene.h>
#import <VVMetalKit/CustomMetalView.h>
#import <VVMetalKit/CMVMTLDrawObject.h>
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
#import <VVMetalKit/VVMTLLUT.h>
#import <VVMetalKit/VVMTLRecycleable.h>
#import <VVMetalKit/VVMTLRecycleableDescriptor.h>
#import <VVMetalKit/VVMTLRecyclingPool.h>
#import <VVMetalKit/VVMTLBuffer.h>
#import <VVMetalKit/VVMTLBufferDescriptor.h>
#import <VVMetalKit/VVMTLTextureImage.h>
#import <VVMetalKit/VVMTLTextureImageDescriptor.h>
#import <VVMetalKit/VVMTLTextureLUT.h>
#import <VVMetalKit/VVMTLTextureLUTDescriptor.h>
#import <VVMetalKit/VVMTLPool.h>

#import <VVMetalKit/VVMTLScene.h>
#import <VVMetalKit/VVMTLComputeScene.h>
#import <VVMetalKit/VVMTLRenderScene.h>
#import <VVMetalKit/VVMTLOrthoRenderScene.h>

#import <VVMetalKit/VVMTLTextureImageRectView.h>
#import <VVMetalKit/VVMTLTextureImageView.h>
#import <VVMetalKit/VVMTLTextureImageRectViewShaderTypes.h>
#import <VVMetalKit/VVMTLTextureImageShaderTypes.h>

#import <VVMetalKit/VVMTLUtilities.h>
#import <VVMetalKit/CIMTLScene.h>

#endif


