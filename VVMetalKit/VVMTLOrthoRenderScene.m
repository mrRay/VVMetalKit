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
		self.mvpBuffer = CreateOrthogonalMVPBufferForCanvas(NSMakeRect(0,0,renderSize.width,renderSize.height),YES,NO,self.device);
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
