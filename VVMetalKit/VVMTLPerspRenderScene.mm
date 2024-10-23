//
//  VVMTLPerspRenderScene.m
//  VVMetalKit
//
//  Created by testadmin on 10/8/24.
//

#import "VVMTLPerspRenderScene.h"

#include "CustomMetalViewShaderTypes.h"
#import <VVMetalKit/VVMetalKit.h>
//#import "AAPLTransforms.h"
#import <VVMetalKit/AAPLMathUtilities.h>




#define VVMINX(r) ((r.size.width>=0) ? (r.origin.x) : (r.origin.x+r.size.width))
#define VVMAXX(r) ((r.size.width>=0) ? (r.origin.x+r.size.width) : (r.origin.x))
#define VVMINY(r) ((r.size.height>=0) ? (r.origin.y) : (r.origin.y+r.size.height))
#define VVMAXY(r) ((r.size.height>=0) ? (r.origin.y+r.size.height) : (r.origin.y))

using namespace simd;


@implementation VVMTLPerspRenderScene

- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (self != nil)	{
		
		//	depth attachment pixel format- any subclasses of this class need a depth buffer!
		self.renderPSODesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
		
		MTLDepthStencilDescriptor		*desc = [MTLDepthStencilDescriptor new];
		desc.depthCompareFunction = MTLCompareFunctionLess;
		desc.depthWriteEnabled = YES;
		
		self.depthState = [self.device newDepthStencilStateWithDescriptor:desc];
		
	}
	return self;
}
- (void) _renderSetup	{
	//	the super creates the command buffer, populates it with any transitive scheduled/completed blocks, configures the pass descriptor, makes an encoder and has it load the PSO (which must be prepared before this- likely on init?)
	[super _renderSetup];
	
	//	if we don't have an MVP buffer yet, make one now.  you'll have to attach this yourself!
	if (self.mvpBuffer == nil)	{
		self.mvpBuffer = [self generateMVPBuffer];
	}
}

- (void) renderCallback	{
	[super renderCallback];
	
	[self.renderEncoder
		setVertexBuffer:self.mvpBuffer
		offset:0
		atIndex:CMV_VS_IDX_MVP];
}

- (id<MTLBuffer>) generateMVPBuffer	{
	NSSize		renderSize = self.renderSize;
	//NSRect		canvasRect = NSMakeRect(0,0,renderSize.width,renderSize.height);
	
	//double		left = VVMINX(canvasRect);
	//double		right = VVMAXX(canvasRect);
	//double		top = VVMAXY(canvasRect);
	//double		bottom = VVMINY(canvasRect);
	
	//float		PI_CONST = 3.14159265359;
	
	//float		angleOfViewRad = 75. * PI_CONST / 180.;
	float		aspectRatio = renderSize.width/renderSize.height;
	float		near = 0.01;
	float		far = 10.0;
	
	//	assume we're getting a quad with vertex geometry that is on the same order as the render dimensions, so we need to scale this down to have a height of 2 (width depends on aspect ratio)
	//float4x4		scaleMatrix = matrix_identity_float4x4;
	float4x4		scaleMatrix = matrix4x4_scale(2.*aspectRatio/renderSize.width, 2./renderSize.height, 1.);
	
	//	the translate will be applied after the scale, this offset will center the quad's geometry around the origin after it's been resized to the above expected dimensions
	//float4x4		transMatrix = matrix4x4_translation( 0., 0., 0. );
	float4x4		transMatrix = matrix4x4_translation( -aspectRatio, -1., 0. );
	
	//	use quaternions to create a rotation matrix using the provided rotation amounts to avoid gimbal lock
	float4x4		rotateMatrix;
	quaternion_float		xrot = quaternion_from_axis_angle(simd_make_float3(1,0,0), radians_from_degrees(0.));
	quaternion_float		yrot = quaternion_from_axis_angle(simd_make_float3(0,1,0), radians_from_degrees(0.));
	quaternion_float		zrot = quaternion_from_axis_angle(simd_make_float3(0,0,1), radians_from_degrees(0.));
	//rotateMatrix = matrix4x4_from_quaternion(zrot);
	//rotateMatrix = matrix_identity_float4x4;
	rotateMatrix = matrix4x4_from_quaternion( quaternion_multiply(zrot,quaternion_multiply(yrot,xrot)) );
	
	//	here's a post-move translation- now that the geometry's been scaled, centered, and rotated, place it in the world
	float4x4		postRotateMatrix = matrix4x4_translation(0., 0., aspectRatio + 0.5);
	
	//	concatenate these transforms to create the model transform matrix
	float4x4		modelMatrix = postRotateMatrix * rotateMatrix * transMatrix * scaleMatrix;
	
	//	the view matrix "positions the camera" (really just moves the world around the camera)
	float4x4		viewMatrix = matrix_identity_float4x4;
	//float4x4		viewMatrix = matrix_look_at_left_hand(simd_make_float3(0,0,-1), simd_make_float3(0,0,0), simd_make_float3(0,1,0));
	
	//	the projection transform effectively determines how the 3d scene data is represented two-dimensionally
	float4x4		projectionMatrix = matrix_perspective_left_hand(radians_from_degrees(60.0f), aspectRatio, near, far);
	//float4x4		projectionMatrix = matrix_identity_float4x4;
	
	//	calculate the MVP matrix
	float4x4		mvpMatrix = projectionMatrix * viewMatrix * modelMatrix;
	//float4x4		mvpMatrix = matrix_ortho_left_hand(left, right, bottom, top, near, far);
	
	id<MTLBuffer>		returnMe = [self.device
		newBufferWithBytes:&mvpMatrix
		length:sizeof(mvpMatrix)
		options:MTLResourceStorageModeShared];
	
	return returnMe;
}

@end
