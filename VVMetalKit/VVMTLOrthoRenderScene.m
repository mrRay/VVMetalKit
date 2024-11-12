//
//  VVMTLOrthoRenderScene.m
//  VVMetalKit
//
//  Created by testadmin on 11/1/23.
//

#import "VVMTLOrthoRenderScene.h"

#include "CustomMetalViewShaderTypes.h"




@implementation VVMTLOrthoRenderScene

- (void) _setMVPBuffer	{
	NSSize			renderSize = self.renderSize;
	self.mvpBuffer = CreateOrthogonalMVPBufferForCanvas(NSMakeRect(0,0,renderSize.width,renderSize.height),YES,NO,self.device);
}

- (void) renderCallback	{
	[super renderCallback];
	
	[self.renderEncoder
		setVertexBuffer:self.mvpBuffer
		offset:0
		atIndex:CMV_VS_IDX_MVP];
}

@end
