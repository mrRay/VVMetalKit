//
//  VVMTLOrthoRenderScene.m
//  VVMetalKit
//
//  Created by testadmin on 11/1/23.
//

#import "VVMTLOrthoRenderScene.h"

#include "CustomMetalViewShaderTypes.h"




@implementation VVMTLOrthoRenderScene

- (void) _renderSetup	{
	//	the super creates the command buffer, populates it with any transitive scheduled/completed blocks, configures the pass descriptor, makes an encoder and has it load the PSO (which must be prepared before this- likely on init?)
	[super _renderSetup];
	
	//	if we don't have an MVP buffer yet, make one now.  you'll have to attach this yourself!
	if (self.mvpBuffer == nil)	{
		NSSize			renderSize = self.renderSize;
		double			left = 0.0;
		double			right = renderSize.width;
		double			top = renderSize.height;
		double			bottom = 0.0;
		double			far = 1.0;
		double			near = -1.0;
		BOOL		flipV = YES;
		BOOL		flipH = NO;
		if (flipV)	{
			top = 0.0;
			bottom = renderSize.height;
		}
		if (flipH)	{
			right = 0.0;
			left = renderSize.width;
		}
		matrix_float4x4			mvp = simd_matrix_from_rows(
			//	old and busted
			//simd_make_float4( 2.0/(right-left), 0.0, 0.0, -1.0*(right+left)/(right-left) ),
			//simd_make_float4( 0.0, 2.0/(top-bottom), 0.0, -1.0*(top+bottom)/(top-bottom) ),
			//simd_make_float4( 0.0, 0.0, -2.0/(far-near), -1.0*(far+near)/(far-near) ),
			//simd_make_float4( 0.0, 0.0, 0.0, 1.0 )
			
			//	left-handed coordinate ortho!
			//simd_make_float4(	2.0/(right-left),	0.0,				0.0,				(right+left)/(left-right) ),
			//simd_make_float4(	0.0,				2.0/(top-bottom),	0.0,				(top+bottom)/(bottom-top) ),
			//simd_make_float4(	0.0,				0.0,				2.0/(far-near),	(near)/(near-far) ),
			//simd_make_float4(	0.0,				0.0,				0.0,				1.0 )
			
			//	right-handed coordinate ortho!
			simd_make_float4(	2.0/(right-left),	0.0,				0.0,				(right+left)/(left-right) ),
			simd_make_float4(	0.0,				2.0/(top-bottom),	0.0,				(top+bottom)/(bottom-top) ),
			simd_make_float4(	0.0,				0.0,				-2.0/(far-near),	(near)/(near-far) ),
			simd_make_float4(	0.0,				0.0,				0.0,				1.0 )
			
		);
		
		self.mvpBuffer = [self.device
			newBufferWithBytes:&mvp
			length:sizeof(mvp)
			options:MTLResourceStorageModeShared];
	}
	
}

- (void) renderCallback	{
	[super renderCallback];
	
	[self.renderEncoder
		setVertexBuffer:self.mvpBuffer
		offset:0
		atIndex:CMV_VS_IDX_MVP];
}

@end
