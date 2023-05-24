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
		attachDesc.clearColor = MTLClearColorMake(0.0, 1.0, 0.0, 1.0);
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
	NSLog(@"%s",__func__);
	//	get the global comp mode controller, ask it for its resources object corresponding to this device
	MSLCompModeController		*compModeController = [MSLCompModeController global];
	self.resource = [compModeController resourceForDevice:self.device];
	NSLog(@"\t\tcomp mode controller is %@, resource is %@, device is %@",compModeController,_resource,self.device);
	//	we can get our PSO from the resources object
	self.renderPipelineStateObject = self.resource.pso_8bit;
	
}


#pragma mark - superclass overrides


- (void) renderCallback	{
	NSLog(@"%s",__func__);
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
		
		localMVPBuffer = [self.device
			newBufferWithBytes:&mvp
			length:sizeof(mvp)
			options:MTLResourceStorageModeShared];
		self.mvpBuffer = localMVPBuffer;
	}
	
	MSLCompModeRecipe		*localRecipe = self.recipe;
	//	run through the steps, assembling an array of the textures used by the various quad steps.  update the 'texIndex' values of the vertexes at the same time.
	NSMutableArray<MTLImgBuffer*>		*recipeTextures = [[NSMutableArray alloc] init];
	for (MSLCompModeRecipeStep * step in localRecipe.steps)	{
		//NSLog(@"\t\tprocessing step %@",step);
		MTLImgBuffer		*stepImg = step.img;
		if (stepImg == nil)	{
			for (int i=0; i<4; ++i)	{
				step->verts[i].texIndex = -1;
			}
			continue;
		}
		
		NSUInteger			matchingIndex = [recipeTextures indexOfObjectIdenticalTo:stepImg];
		if (matchingIndex == NSNotFound)	{
			//NSLog(@"\t\t\tdidn't find identical, searching for equal...");
			matchingIndex = [recipeTextures indexOfObjectIdenticalTo:stepImg];
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
	
	//	populate a buffer with the recipe's MSLCompModeQuadVertex data
	size_t		localRecipeSize = localRecipe.minBufferLength;
	id<MTLBuffer>		vertexDataBuffer = [self.device
		newBufferWithLength:localRecipeSize
		options:MTLResourceStorageModeShared];
	[localRecipe dumpToBuffer:vertexDataBuffer atOffset:0];
	//[vertexDataBuffer didModifyRange:NSMakeRange(0,vertexDataBuffer.length)];	//	only to be used if the resource is 'managed'
	
	//	make an argument buffer with all of the textures used by the recipe
	MSLCompModeControllerResource		*localResource = self.resource;
	id<MTLFunction>		localFragFunc = localResource.frgFunc;
	id<MTLArgumentEncoder>		argEncoder = [localFragFunc newArgumentEncoderWithBufferIndex:1];
	size_t		texStructLength = argEncoder.encodedLength;
	//NSLog(@"\t\targEncoder's encodedLength is %d",texStructLength);
	id<MTLBuffer>		texArrayBuffer = [self.device
		newBufferWithLength:texStructLength * localRecipe.steps.count
		options:MTLResourceStorageModeShared];
	int		tmpIndex = 0;
	for (MSLCompModeRecipeStep * step in localRecipe.steps)	{
		MTLImgBuffer		*stepImg = step.img;
		if (stepImg != nil)	{
			[argEncoder setArgumentBuffer:texArrayBuffer offset:tmpIndex * texStructLength];
			[argEncoder setTexture:stepImg.texture atIndex:0];	//	the '0' is the id of the var in the struct
			[self.renderEncoder useResource:stepImg.texture usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
		}
		++tmpIndex;
	}
	
	//	attach the MVP to the vertex shader
	[self.renderEncoder setVertexBuffer:localMVPBuffer offset:0 atIndex:MSLCompModeScene_VS_Index_MVPMatrix];
	//	attach the vertices to both shaders
	[self.renderEncoder setVertexBuffer:vertexDataBuffer offset:0 atIndex:MSLCompModeScene_VS_Index_Verts];
	[self.renderEncoder setFragmentBuffer:vertexDataBuffer offset:0 atIndex:0];
	//	draw the vertices
	[self.renderEncoder
		drawPrimitives:MTLPrimitiveTypeTriangleStrip
		vertexStart:0
		vertexCount:4];
	
	/*
	size_t			vertexCount = 4;
	size_t			vertexDataLength = sizeof(MSLCompModeQuadVertex) * vertexCount;
	id<MTLBuffer>		vertexData = [self.device
		newBufferWithLength:vertexDataLength
		options:MTLResourceStorageModeShared];
	MSLCompModeQuadVertex	*wPtr = vertexData.contents;
	wPtr->position = simd_make_float2( XXX, YYY );
	wPtr->texCoord = simd_make_float2( XXX, YYY );
	
	wPtr->invHomography = simd_matrix_from_rows(
		simd_make_float4( XXX, YYY, ZZZ, WWW ),
		simd_make_float4( XXX, YYY, ZZZ, WWW ),
		simd_make_float4( XXX, YYY, ZZZ, WWW ),
		simd_make_float4( XXX, YYY, ZZZ, WWW )
	);
	
	//wPtr->srcRect.origin.x = 
	//wPtr->srcRect.origin.y = 
	//wPtr->srcRect.size.width = 
	//wPtr->srcRect.size.height = 
	wPtr->srcRect = simd_make_float4( XXX, YYY, ZZZ, WWW );
	wPtr->flipH = false;
	wPtr->flipV = false;
	
	wPtr->opacity = XXX;
	wPtr->texIndex = XXX;
	wPtr->compModeIndex = XXX;
	*/
}


@end
