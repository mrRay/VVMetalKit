//
//  VVMTLPerspRenderScene.m
//  VVMetalKit
//
//  Created by testadmin on 10/8/24.
//

#import "VVMTLPerspRenderScene.h"

#include "CustomMetalViewShaderTypes.h"
#import <VVMetalKit/SizingTool_objc.h>
//#import "AAPLTransforms.h"
#import <VVMetalKit/AAPLMathUtilities.h>




#define VVMINX(r) ((r.size.width>=0) ? (r.origin.x) : (r.origin.x+r.size.width))
#define VVMAXX(r) ((r.size.width>=0) ? (r.origin.x+r.size.width) : (r.origin.x))
#define VVMINY(r) ((r.size.height>=0) ? (r.origin.y) : (r.origin.y+r.size.height))
#define VVMAXY(r) ((r.size.height>=0) ? (r.origin.y+r.size.height) : (r.origin.y))

using namespace simd;


@implementation VVMTLPerspRenderScene

- (void) _renderSetup	{
	//	the super creates the command buffer, populates it with any transitive scheduled/completed blocks, configures the pass descriptor, makes an encoder and has it load the PSO (which must be prepared before this- likely on init?)
	[super _renderSetup];
	
	//	if we don't have an MVP buffer yet, make one now.  you'll have to attach this yourself!
	if (self.mvpBuffer == nil)	{
		//NSSize			renderSize = self.renderSize;
		//self.mvpBuffer = CreatePerspectiveMVPBufferForCanvas(NSMakeRect(0,0,renderSize.width,renderSize.height),YES,NO,self.device);
		//self.mvpBuffer = CreatePerspectiveMVPBufferForCanvas(NSMakeRect(0,0,renderSize.width,renderSize.height),NO,NO,self.device);
		
		//self.mvpBuffer = CreateOrthogonalMVPBufferForCanvas(NSMakeRect(0,0,renderSize.width,renderSize.height),YES,NO,self.device);
		
		self.mvpBuffer = [self generateMVPBuffer];
		
		//NSRect		rawCanvas = NSMakeRect(0,0,renderSize.width,renderSize.height);
		//NSRect		canvasSizedWithinUnity = NSRectThatFitsRectInRect( rawCanvas, NSMakeRect(-1,-1,2,2), SizingModeFill );
		//NSLog(@"******** canvasSizedWithinUnity is %@",NSStringFromRect(canvasSizedWithinUnity));
		//self.mvpBuffer = CreatePerspectiveMVPBufferForCanvas(canvasSizedWithinUnity, YES, NO, self.device );
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
	NSRect		canvasRect = NSMakeRect(0,0,renderSize.width,renderSize.height);
	
	double		left = VVMINX(canvasRect);
	double		right = VVMAXX(canvasRect);
	double		top = VVMAXY(canvasRect);
	double		bottom = VVMINY(canvasRect);
	
	float		PI_CONST = 3.14159265359;
	
	float		angleOfViewRad = 75. * PI_CONST / 180.;
	float		aspectRatio = renderSize.width/renderSize.height;
	float		near = 1.0;
	float		far = 100.0;
	
	//	assume we're getting a quad with vertex geometry that is on the same order as the render dimensions, so we need to scale this down to have a height of 2 (width depends on aspect ratio)
	//float4x4		scaleMatrix = matrix_identity_float4x4;
	//float4x4		scaleMatrix = matrix4x4_scale(1., 1., 1.);
	//float4x4		scaleMatrix = matrix4x4_scale(2.*aspectRatio/renderSize.width, 2./renderSize.height, 1.);
	float4x4		scaleMatrix = matrix4x4_scale(2./renderSize.height, 2./renderSize.height, 1.);
	
	//	the translate will be applied after the scale, this offset will center the quad's geometry
	//float4x4		transMatrix = matrix4x4_translation( 0., 0., 0. );
	float4x4		transMatrix = matrix4x4_translation( -aspectRatio, -1., 0. );
	//float4x4		transMatrix = matrix4x4_translation( -renderSize.width/2., -renderSize.height/2., 0. );
	
	//	this is a rotation- it's empty, but i'm leaving a placeholder to play with later
	float4x4		rotateMatrix = matrix_identity_float4x4;
	//float4x4		rotateMatrix = matrix4x4_from_quaternion( quaternion(radians_from_degrees(5.), 0., 1., 0.) );
	
	//	this...
	//float4x4		modelMatrix = matrix_identity_float4x4;
	//modelMatrix = scaleMatrix * modelMatrix;
	//modelMatrix = transMatrix * modelMatrix;
	//modelMatrix = rotateMatrix * modelMatrix;
	//	...is equivalent to this.
	float4x4		modelMatrix = rotateMatrix * transMatrix * scaleMatrix;
	
	//	the view matrix just pushes the geometry back a bit so it's visible
	float4x4		viewMatrix = matrix4x4_translation(0, 0, aspectRatio);
	//float4x4		viewMatrix = matrix4x4_translation(0, 0, 2);
	
	float4x4		projectionMatrix = matrix_perspective_left_hand(radians_from_degrees(60.0f), aspectRatio, near, far);
	
	//	this...
	//float4x4		viewProjectionMatrix = matrix_multiply(projectionMatrix, viewMatrix);
	//float4x4		mvpMatrix = matrix_multiply(viewProjectionMatrix, modelMatrix);
	
	//	...is equivalent to this...
	//float4x4		mvpMatrix = matrix_identity_float4x4;
	//mvpMatrix = modelMatrix * mvpMatrix;
	//mvpMatrix = viewMatrix * mvpMatrix;
	//mvpMatrix = projectionMatrix * mvpMatrix;
	
	//	...is equivalent to this.
	float4x4		mvpMatrix = projectionMatrix * viewMatrix * modelMatrix;
	
	id<MTLBuffer>		returnMe = [self.device
		newBufferWithBytes:&mvpMatrix
		length:sizeof(mvpMatrix)
		options:MTLResourceStorageModeShared];
	
	return returnMe;
	
}

@end
