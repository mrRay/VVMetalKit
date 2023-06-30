//
//  MSLCompModeScene.m
//  MSLCompModes
//
//  Created by testadmin on 5/18/23.
//

#import "MSLCompModeScene.h"
#import "MSLCompModeController.h"
#import "MSLCompModeControllerResource.h"
#import "MSLCompModeRecipeStep.h"
#import "MSLCompModeRecipe.h"




@interface MSLCompModeScene ()
@property (strong,readwrite) MSLCompModeControllerResource * resource;
@end




@implementation MSLCompModeScene


- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (self != nil)	{
		MTLRenderPassColorAttachmentDescriptor		*attachDesc = self.renderPassDescriptor.colorAttachments[0];
		attachDesc.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
		//attachDesc.loadAction = MTLLoadActionDontCare;
		attachDesc.loadAction = MTLLoadActionClear;
		//attachDesc.loadAction = MTLLoadActionLoad;
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			selector:@selector(compModeReloadNotification:)
			name:kMSLCompModeReloadNotificationName
			object:nil];
	}
	return self;
}
- (void) dealloc	{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kMSLCompModeReloadNotificationName object:nil];
}


- (void) compModeReloadNotification:(NSNotification *)note	{
	//NSLog(@"%s",__func__);
	//	get the global comp mode controller, ask it for its resources object corresponding to this device
	MSLCompModeController		*compModeController = [MSLCompModeController global];
	self.resource = [compModeController resourceForDevice:self.device];
	//	we can get our PSO from the resources object
	self.renderPipelineStateObject = self.resource.pso_8bit;
	
}


#pragma mark - superclass overrides


- (void) renderCallback	{
	//NSLog(@"%s",__func__);
	
	//	get a local copy of the MVP buffer (creating one if it doesn't exist)
	id<MTLBuffer>		localMVPBuffer = self.mvpBuffer;
	if (localMVPBuffer == nil)	{
		CGSize			renderSize = self.renderSize;
		double			left = 0.0;
		double			right = renderSize.width;
		double			top = renderSize.height;
		double			bottom = 0.0;
		double			far = 1.0;
		double			near = -1.0;
		BOOL		flipV = NO;
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
		
		localMVPBuffer = [self.device
			newBufferWithBytes:&mvp
			length:sizeof(mvp)
			options:MTLResourceStorageModeShared];
		self.mvpBuffer = localMVPBuffer;
	}
	
	MSLCompModeRecipe		*localRecipe = self.recipe;
	//	run through the steps, assembling an array of the textures used by the various quad steps.  update the 'texIndex' values of the vertexes at the same time.
	NSMutableArray<id<VVMTLTextureImage>>		*recipeTextures = [[NSMutableArray alloc] init];
	for (MSLCompModeRecipeStep * step in localRecipe.steps)	{
		//NSLog(@"\t\tprocessing step %@",step);
		id<VVMTLTextureImage>		stepImg = step.img;
		if (stepImg == nil)	{
			for (int i=0; i<4; ++i)	{
				step->verts[i].texIndex = -1;
			}
			continue;
		}
		
		NSUInteger			matchingIndex = [recipeTextures indexOfObjectIdenticalTo:stepImg];
		if (matchingIndex == NSNotFound)	{
			//NSLog(@"\t\t\tdidn't find identical, searching for equal...");
			matchingIndex = [recipeTextures indexOfObject:stepImg];
		}
		if (matchingIndex == NSNotFound)	{
			matchingIndex = recipeTextures.count;
			//NSLog(@"\t\t\tdidn't find equal, adding and setting matchingIndex to %d",recipeTextures.count);
			[recipeTextures addObject:stepImg];
		}
		
		for (int i=0; i<4; ++i)	{
			step->verts[i].texIndex = matchingIndex;
		}
	}
	
	//	each quad is a tri-strip.  we need to draw one quad (4 vertexes + 1 "stop bit") for each step.  we want to draw all the quads with one call.  we need an index buffer for drawing.
	size_t		indexBufferSize = sizeof(uint16_t) * 5 * localRecipe.steps.count;
	id<MTLBuffer>		indexBuffer = [self.device
		newBufferWithLength:indexBufferSize
		options:MTLResourceStorageModeManaged];
	uint16_t			*indexBasePtr = indexBuffer.contents;
	uint16_t			*indexWPtr = indexBasePtr;
	//	for each step, add the four adjacent vertices and a stop bit
	for (int i=0; i<localRecipe.steps.count; ++i)	{
		int			localBaseCount = 4 * i;
		*(indexWPtr + 0) = (localBaseCount + 0);
		*(indexWPtr + 1) = (localBaseCount + 1);
		*(indexWPtr + 2) = (localBaseCount + 2);
		*(indexWPtr + 3) = (localBaseCount + 3);
		*(indexWPtr + 4) = 0xFFFF;
		indexWPtr += 5;
	}
	[indexBuffer didModifyRange:NSMakeRange(0,indexBuffer.length)];
	[self.renderEncoder useResource:indexBuffer usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
	
	//	populate a buffer with the recipe's MSLCompModeQuadVertex data
	size_t		localVertexRecipeSize = localRecipe.minVertexBufferLength;
	id<MTLBuffer>		vertexDataBuffer = [self.device
		newBufferWithLength:localVertexRecipeSize
		options:MTLResourceStorageModeManaged];
	[localRecipe dumpVertexDataToBuffer:vertexDataBuffer atOffset:0];
	[vertexDataBuffer didModifyRange:NSMakeRange(0,vertexDataBuffer.length)];	//	only to be used if the resource is 'managed'
	[self.renderEncoder useResource:vertexDataBuffer usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
	
	//	populate a buffer with the recipe's projection matrix data
	size_t		localProjectionMatricesBufferSize = localRecipe.minProjectionMatrixBufferLength;
	id<MTLBuffer>		projectionMatricesBuffer = [self.device
		newBufferWithLength:localProjectionMatricesBufferSize
		options:MTLResourceStorageModeManaged];
	[localRecipe dumpProjectionMatricesToBuffer:projectionMatricesBuffer atOffset:0];
	[projectionMatricesBuffer didModifyRange:NSMakeRange(0,projectionMatricesBuffer.length)];	//	only to be used if the resource is 'managed'
	[self.renderEncoder useResource:projectionMatricesBuffer usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
	
	//	make an argument buffer with all of the textures used by the recipe (which we assembled earlier)
	MSLCompModeControllerResource		*localResource = self.resource;
	if (localResource == nil)	{
		NSLog(@"ERR: localResources nil, %s",__func__);
		return;
	}
	id<MTLFunction>		localFragFunc = localResource.frgFunc;
	id<MTLArgumentEncoder>		argEncoder = [localFragFunc newArgumentEncoderWithBufferIndex:1];
	size_t		texStructLength = argEncoder.encodedLength;
	//NSLog(@"\t\targEncoder's encodedLength is %d",texStructLength);
	id<MTLBuffer>		texArrayBuffer = [self.device
		newBufferWithLength:texStructLength * localRecipe.steps.count
		options:MTLResourceStorageModeShared];
	int			tmpIndex = 0;
	for (id<VVMTLTextureImage> recipeTexture in recipeTextures)	{
		[argEncoder setArgumentBuffer:texArrayBuffer offset:tmpIndex * texStructLength];
		[argEncoder setTexture:recipeTexture.texture atIndex:0];	//	the '0' is the id of the var in the struct (which is auto-generated by the compiler in this context)
		[self.renderEncoder useResource:recipeTexture.texture usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
		++tmpIndex;
	}
	
	//	attach the MVP and the buffer with the projection matrices to the vertex shader
	[self.renderEncoder setVertexBuffer:localMVPBuffer offset:0 atIndex:MSLCompModeScene_VS_Index_MVPMatrix];
	[self.renderEncoder setVertexBuffer:projectionMatricesBuffer offset:0 atIndex:MSLCompModeScene_VS_Index_Homography];
	//	attach the vertices to both shaders
	[self.renderEncoder setVertexBuffer:vertexDataBuffer offset:0 atIndex:MSLCompModeScene_VS_Index_Verts];
	[self.renderEncoder setFragmentBuffer:vertexDataBuffer offset:0 atIndex:0];
	//	attach the argument buffer to the frag shader
	[self.renderEncoder setFragmentBuffer:texArrayBuffer offset:0 atIndex:1];
	
	//	draw the vertices
	[self.renderEncoder
		drawIndexedPrimitives:MTLPrimitiveTypeTriangleStrip
		indexCount:((void*)indexWPtr - (void*)indexBasePtr)/sizeof(uint16_t)
		indexType:MTLIndexTypeUInt16
		indexBuffer:indexBuffer
		indexBufferOffset:0];
	
	//	ensure that the various resources used by the shader will be resident and unaltered on the GPU until the command buffer has completed
	[self.commandBuffer addCompletedHandler:^(id<MTLCommandBuffer>cb)	{
		NSMutableArray<id<VVMTLTextureImage>>		*tmpTextures = recipeTextures;
		id<MTLBuffer>		tmpMVP = localMVPBuffer;
		id<MTLBuffer>		tmpVertexData = vertexDataBuffer;
		id<MTLBuffer>		tmpProjectionMatricesBuffer = projectionMatricesBuffer;
		
		tmpProjectionMatricesBuffer = nil;
		tmpVertexData = nil;
		tmpMVP = nil;
		tmpTextures = nil;
	}];
	
}


@end
