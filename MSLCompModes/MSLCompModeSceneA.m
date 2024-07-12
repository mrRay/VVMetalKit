//
//  MSLCompModeSceneA.m
//  MSLCompModes
//
//  Created by testadmin on 5/18/23.
//

#import "MSLCompModeSceneA.h"
#import "MSLCompModeController.h"
#import "MSLCompModeResourceController.h"
#import "MSLCompModeResource.h"
#import "MSLCompModeRecipeStep.h"
#import "MSLCompModeRecipe.h"

#import "MSLCompModeSceneAShaderTypes.h"

#import "VVMacros.h"




#define VVMINX(r) ((r.size.width>=0) ? (r.origin.x) : (r.origin.x+r.size.width))
#define VVMAXX(r) ((r.size.width>=0) ? (r.origin.x+r.size.width) : (r.origin.x))
#define VVMINY(r) ((r.size.height>=0) ? (r.origin.y) : (r.origin.y+r.size.height))
#define VVMAXY(r) ((r.size.height>=0) ? (r.origin.y+r.size.height) : (r.origin.y))




@implementation MSLCompModeSceneA


- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (self != nil)	{
	}
	return self;
}


- (void) compModeReloadNotification:(NSNotification *)note	{
	//NSLog(@"%s",__func__);
	
	//	we're 'scene A', so get 'rsrcCtrlrA' from the global comp mode controller, and get our resource from that
	MSLCompModeResourceController		*rsrcCtrlr = MSLCompModeController.global.rsrcCtrlrA;
	self.resource = [rsrcCtrlr resourceForDevice:self.device];
	//	we can get our PSO from the resources object
	self.renderPSO = self.resource.pso_8bit;
	
}


#pragma mark - superclass overrides


- (void) renderCallback	{
	//NSLog(@"%s",__func__);
	
	MSLCompModeResource		*localResource = self.resource;
	if (localResource == nil)	{
		NSLog(@"ERR: localResources nil, %s",__func__);
		return;
	}
	
	NSRect			canvasBounds = self.canvasBounds;
	MSLCompModeRecipe		*localRecipe = self.recipe;
	uint16_t		maxLayerCount = localRecipe.steps.count;
	
	//	this part:
	//	- gathers (and populates if necessary) the mvp buffer
	//	- attaches it to the shader
	id<MTLBuffer>		localMVPBuffer = self.mvpBuffer;
	if (localMVPBuffer == nil)	{
		localMVPBuffer = CreateOrthogonalMVPBufferForCanvas(canvasBounds, NO, NO, self.device);
		self.mvpBuffer = localMVPBuffer;
	}
	
	[self.renderEncoder useResource:localMVPBuffer usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
	[self.renderEncoder setVertexBuffer:localMVPBuffer offset:0 atIndex:MSLCompModeSceneA_VS_Index_MVPMatrix];
	
	
	//	this part:
	//	- populates 'vertexBuffer'
	//	- populates 'layersBuffer', attaches it to the shader
	//	- assembles an array of textures (one for each "layer") used by the recipe (to be added to the shader later via argument buffer encoder)
	size_t		vertexBufferSize = sizeof(MSLCompModeQuadVertex) * 4 * maxLayerCount;
	size_t		layersBufferSize = sizeof(MSLCompModeLayer) * maxLayerCount;
	id<VVMTLBuffer>		vertexBuffer = [VVMTLPool.global bufferWithLength:ROUNDAUPTOMULTOFB(vertexBufferSize, 64) storage:MTLStorageModeManaged];
	id<VVMTLBuffer>		layersBuffer = [VVMTLPool.global bufferWithLength:ROUNDAUPTOMULTOFB(layersBufferSize, 64) storage:MTLStorageModeManaged];
	NSMutableArray<id<VVMTLTextureImage>>		*recipeTextures = [[NSMutableArray alloc] init];
	
	MSLCompModeQuadVertex		*baseQuadPtr = (MSLCompModeQuadVertex*)vertexBuffer.buffer.contents;
	MSLCompModeQuadVertex		*quadPtr = baseQuadPtr;
	MSLCompModeLayer		*baseLayerPtr = (MSLCompModeLayer*)layersBuffer.buffer.contents;
	MSLCompModeLayer		*layerPtr = baseLayerPtr;
	
	uint16_t		tmpLayerIndex = 0;
	for (MSLCompModeRecipeStep * step in localRecipe.steps)	{
		//NSLog(@"\t\tprocessing step %@",step);
		
		//	update the vert's layerIndex member, and then use it to populate the vertex buffer
		for (int i=0; i<4; ++i)	{
			step->verts[i].layerIndex = tmpLayerIndex;
		}
		memcpy( quadPtr, step->verts, (sizeof(MSLCompModeQuadVertex)*4) );
		
		//	find the index of the texture in the array of recipe textures (adding it if necessary).  an index of -1 means "no image".
		id<VVMTLTextureImage>		stepImg = step.img;
		NSInteger			localTextureIndex = (stepImg==nil) ? -1 : [recipeTextures indexOfObjectIdenticalTo:stepImg];
		if (localTextureIndex == NSNotFound)	{
			localTextureIndex = (stepImg==nil) ? -1 : [recipeTextures indexOfObject:stepImg];
		}
		if (localTextureIndex == NSNotFound)	{
			if (stepImg == nil)	{
				localTextureIndex = -1;
			}
			else	{
				localTextureIndex = recipeTextures.count;
				[recipeTextures addObject:stepImg];
			}
		}
		
		//	calculate the offset of this layer, in bytes, relative to the beginning of the MTLBuffer.
		size_t		layerPtrOffsetInBytes = (layerPtr - baseLayerPtr) * sizeof(MSLCompModeLayer);
		
		//	populate the 'layerPtr' struct in the buffer
		[step dumpTexToGeoMatrixToBuffer:layersBuffer.buffer atOffset:layerPtrOffsetInBytes];
		NSRect		srcRect = (stepImg==nil) ? NSZeroRect : stepImg.srcRect;
		layerPtr->srcRect = (GRect){ (GPoint){ srcRect.origin.x, srcRect.origin.y }, (GSize){ srcRect.size.width, srcRect.size.height } };
		layerPtr->opacity = step.opacity;
		layerPtr->texIndex = localTextureIndex;
		layerPtr->compModeIndex = step.compModeIndex;
		
		//	update stride ptrs/indexes
		quadPtr += 4;
		++layerPtr;
		
		++tmpLayerIndex;
	}
	
	[vertexBuffer.buffer didModifyRange:NSMakeRange(0,vertexBufferSize)];
	[layersBuffer.buffer didModifyRange:NSMakeRange(0,layersBufferSize)];
	
	[self.renderEncoder useResource:vertexBuffer.buffer usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
	[self.renderEncoder setVertexBuffer:vertexBuffer.buffer offset:0 atIndex:MSLCompModeSceneA_VS_Index_Verts];
	
	[self.renderEncoder useResource:layersBuffer.buffer usage:MTLResourceUsageRead stages:MTLRenderStageVertex|MTLRenderStageFragment];
	[self.renderEncoder setVertexBuffer:layersBuffer.buffer offset:0 atIndex:MSLCompModeSceneA_VS_Index_Layers];
	[self.renderEncoder setFragmentBuffer:layersBuffer.buffer offset:0 atIndex:MSLCompModeSceneA_FS_Index_Layers];
	
	
	uint16_t		actualLayerCount = tmpLayerIndex;
	uint16_t		actualImageCount = recipeTextures.count;
	
	
	//	this part:
	//	- makes the argument encoder for passing textures to the shader, and populates it with the array of textures we assembled earlier
	id<MTLFunction>		localFragFunc = localResource.frgFunc;
	id<MTLArgumentEncoder>		argEncoder = [localFragFunc newArgumentEncoderWithBufferIndex:MSLCompModeSceneA_FS_Index_Textures];
	size_t		texStructLength = argEncoder.encodedLength;
	size_t		texArrayBufferSize = texStructLength * actualImageCount;
	id<MTLBuffer>		texArrayBuffer = [self.device newBufferWithLength:texArrayBufferSize options:MTLResourceStorageModeShared];
	
	int		texIndex = 0;
	for (id<VVMTLTextureImage> recipeTexture in recipeTextures)	{
		[argEncoder setArgumentBuffer:texArrayBuffer offset:(texIndex * texStructLength)];
		[argEncoder setTexture:recipeTexture.texture atIndex:0];	//	the '0' is the id of the var in the struct (which is auto-generated by the compiler in this context)
		
		[self.renderEncoder useResource:recipeTexture.texture usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
		
		++texIndex;
	}
	
	//[self.renderEncoder useResource:texArrayBuffer usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
	[self.renderEncoder setFragmentBuffer:texArrayBuffer offset:0 atIndex:MSLCompModeSceneA_FS_Index_Textures];
	
	
	//	this part:
	//	- populates the job buffer
	//	- attaches it to the shader
	size_t		jobBufferSize = sizeof(MSLCompModeJob);
	id<VVMTLBuffer>		jobBuffer = [VVMTLPool.global bufferWithLength:ROUNDAUPTOMULTOFB(jobBufferSize, 64) storage:MTLStorageModeManaged];
	MSLCompModeJob		*baseJobPtr = (MSLCompModeJob*)jobBuffer.buffer.contents;
	
	CGSize				renderSize = self.renderSize;
	baseJobPtr->canvasRect = (vector_float4)simd_make_float4(canvasBounds.origin.x, canvasBounds.origin.y, canvasBounds.size.width, canvasBounds.size.height);
	baseJobPtr->layerCount = (layerPtr - baseLayerPtr);
	
	[jobBuffer.buffer didModifyRange:NSMakeRange(0,jobBufferSize)];
	
	[self.renderEncoder useResource:jobBuffer.buffer usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
	[self.renderEncoder setFragmentBuffer:jobBuffer.buffer offset:0 atIndex:MSLCompModeSceneA_FS_Index_Job];
	
	
	//	this part:
	//	- populates index buffer used to draw the vertices in one shot
	size_t		indexBufferSize = sizeof(uint16_t) * 5 * maxLayerCount;
	id<VVMTLBuffer>		indexBuffer = [VVMTLPool.global bufferWithLength:ROUNDAUPTOMULTOFB(indexBufferSize, 64) storage:MTLStorageModeManaged];
	uint16_t		*indexBasePtr = (uint16_t*)indexBuffer.buffer.contents;
	uint16_t		*indexPtr = indexBasePtr;
	
	for (int i=0; i<actualLayerCount; ++i)	{
		int		localBaseCount = 4 * i;
		*(indexPtr + 0) = (localBaseCount + 0);
		*(indexPtr + 1) = (localBaseCount + 1);
		*(indexPtr + 2) = (localBaseCount + 2);
		*(indexPtr + 3) = (localBaseCount + 3);
		*(indexPtr + 4) = 0xFFFF;
		
		indexPtr += 5;
	}
	[indexBuffer.buffer didModifyRange:NSMakeRange(0, indexBufferSize)];
	
	[self.renderEncoder useResource:indexBuffer.buffer usage:MTLResourceUsageRead stages:MTLRenderStageVertex];
	
	
	//	draw the vertices
	[self.renderEncoder
		drawIndexedPrimitives:MTLPrimitiveTypeTriangleStrip
		indexCount:((void*)indexPtr - (void*)indexBasePtr)/sizeof(uint16_t)
		indexType:MTLIndexTypeUInt16
		indexBuffer:indexBuffer.buffer
		indexBufferOffset:0];
	
	
	//	ensure that the various resources used by the shader program will be resident and unaltered on the GPU under the command buffer has completed
	[self.commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completed)	{
		id<MTLBuffer>		cbLocalMVPBuffer = localMVPBuffer;
		id<VVMTLBuffer>		cbVertexBuffer = vertexBuffer;
		id<VVMTLBuffer>		cbLayersBuffer = layersBuffer;
		NSMutableArray<id<VVMTLTextureImage>>		*cbRecipeTextures = recipeTextures;
		id<MTLBuffer>		cbTexArrayBuffer = texArrayBuffer;
		id<VVMTLBuffer>		cbJobBuffer = jobBuffer;
		id<VVMTLBuffer>		cbIndexBuffer = indexBuffer;
		
		cbIndexBuffer = nil;
		cbJobBuffer = nil;
		cbTexArrayBuffer = nil;
		[cbRecipeTextures removeAllObjects];
		cbRecipeTextures = nil;
		cbLayersBuffer = nil;
		cbVertexBuffer = nil;
		cbLocalMVPBuffer = nil;
	}];
	
}


@end
