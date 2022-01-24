#import "MTLImgBufferView.h"
#import "MTLImgBufferViewShaderTypes.h"
#import "RenderProperties.h"
#import "VVSizingTool.h"
#import "SizingTool_c.h"




@interface MTLImgBufferView ()
@end




@implementation MTLImgBufferView


#pragma mark - init/dealloc


- (void) generalInit	{
	[super generalInit];
	//NSLog(@"%s",__func__);
	
	self.vertBuffer = nil;
	self.mvpBuffer = nil;
	self.geoBuffer = nil;
	self.imgBuffer = nil;
	
	//	this makes the view "transparent" (areas with alpha of 0 will show the background of the enclosing view)
	self.layer.opaque = NO;
	self.layer.backgroundColor = [[NSColor clearColor] CGColor];
	passDescriptor = [MTLRenderPassDescriptor new];
	passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
	passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
	passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
}
- (void) awakeFromNib	{
}
- (BOOL) opaque	{
	return NO;
}


#pragma mark - property overrides


@synthesize imgBuffer=myImgBuffer;
- (void) setImgBuffer:(MTLImgBuffer *)inBuffer	{
	//NSLog(@"%s ... %@",__func__,inBuffer);
	@synchronized (self)	{
		myImgBuffer = inBuffer;
	}
}
- (MTLImgBuffer *)imgBuffer	{
	return myImgBuffer;
}


#pragma mark - frontend


- (void) drawInCmdBuffer:(id<MTLCommandBuffer>)cmdBuffer	{
	//NSLog(@"%s ... %@",__func__,self.label);
	//NSLog(@"\tmy bounds are %@",NSStringFromRect(self.bounds));
	@synchronized (self)	{
		if (metalLayer.device==nil || metalLayer==nil)	{
			NSLog(@"ERR: bailing, %s",__func__);
			return;
		}
		
		//	configure the current drawable & render pass descriptor
		currentDrawable = metalLayer.nextDrawable;
		if (currentDrawable == nil)	{
			NSLog(@"ERR: current drawable nil in %s",__func__);
			return;
		}
		if (currentDrawable.texture == nil)	{
			NSLog(@"ERR: current drawable tex nil in %s",__func__);
			return;
		}
		passDescriptor.colorAttachments[0].texture = currentDrawable.texture;
		
		MTLImgBuffer		*localImgBuffer = self.imgBuffer;
		//	if there's an image buffer...
		if (localImgBuffer != nil)	{
			//NSLog(@"\t\tthere's an image buffer to draw...");
			
			CGRect			viewRect = CGRectMake(0,0,viewportSize.x,viewportSize.y);
			
			//NSLog(@"\t\timgBuffer is %@",localImgBuffer);
			//	make sure the vert buffer exists, create it if it doesn't
			if (self.vertBuffer == nil)	{
				const MTLImgBufferViewVertex		quadVerts[] = {
					{ { CGRectGetMinX(viewRect), CGRectGetMinY(viewRect) } },
					{ { CGRectGetMinX(viewRect), CGRectGetMaxY(viewRect) } },
					{ { CGRectGetMaxX(viewRect), CGRectGetMinY(viewRect) } },
					{ { CGRectGetMaxX(viewRect), CGRectGetMaxY(viewRect) } },
				};
		
				self.vertBuffer = [metalLayer.device
					newBufferWithBytes:quadVerts
					length:sizeof(quadVerts)
					options:MTLResourceStorageModeShared];
			}
			
			//	make a geometry struct!
			MTLImgBufferStruct		localGeoStruct;
			
			//	populate it with the contents of the img buffer (src rect of the texture that contains the image)
			[localImgBuffer populateStruct:&localGeoStruct];
			
			//	calculate where the image will draw in my bounds, apply it to the geometry struct
			NSRect			imgRect = [VVSizingTool
				rectThatFitsRect:NSMakeRect(localGeoStruct.srcRect.origin.x, localGeoStruct.srcRect.origin.y, localGeoStruct.srcRect.size.width, localGeoStruct.srcRect.size.height)
				inRect:viewRect
				sizingMode:VVSizingModeFit];
			//localGeoStruct.dstRect.origin.x = imgRect.origin.x;
			//localGeoStruct.dstRect.origin.y = imgRect.origin.y;
			//localGeoStruct.dstRect.size.width = imgRect.size.width;
			//localGeoStruct.dstRect.size.height = imgRect.size.height;
			localGeoStruct.dstRect = MakeRect(imgRect.origin.x, imgRect.origin.y, imgRect.size.width, imgRect.size.height);
			
			//	make a geometry buffer from the struct
			self.geoBuffer = [metalLayer.device
				newBufferWithBytes:&localGeoStruct
				length:sizeof(localGeoStruct)
				options:MTLResourceStorageModeShared];
			
		}
		
		//	make sure the mvp buffer exists, create it if it doesn't
		if (self.mvpBuffer == nil)	{
			matrix_float4x4			mvp = simd_matrix_from_rows(
				simd_make_float4(2.0/viewportSize.x, 0.0, 0.0, -1.0),
				simd_make_float4(0.0, 2.0/viewportSize.y, 0.0, -1.0),
				simd_make_float4(0.0, 0.0, -0.5, 0.5),
				simd_make_float4(0.0, 0.0, 0.0, 1.0)
			);
		
			self.mvpBuffer = [metalLayer.device
				newBufferWithBytes:&mvp
				length:sizeof(mvp)
				options:MTLResourceStorageModeShared];
		}
		
		
		//	make a render encoder, configure it
		id<MTLRenderCommandEncoder>		renderEncoder = [cmdBuffer renderCommandEncoderWithDescriptor:passDescriptor];
		if (self.label != nil)
			renderEncoder.label = self.label;
		else
			renderEncoder.label = @"MTLImgBufferView encoder";
		[renderEncoder setViewport:(MTLViewport){ 0.f, 0.f, viewportSize.x, viewportSize.y, -1.f, 1.f }];
		[renderEncoder setRenderPipelineState:_pso];
		
		//	if there's an image buffer...
		if (localImgBuffer != nil)	{
			//	pass data to the render encoder
			[renderEncoder
				setVertexBuffer:self.vertBuffer
				offset:0
				atIndex:MTLImgBufferView_VS_Index_Verts];
			[renderEncoder
				setVertexBuffer:self.mvpBuffer
				offset:0
				atIndex:MTLImgBufferView_VS_Index_MVPMatrix];
			
			[renderEncoder
				setFragmentTexture:localImgBuffer.texture
				atIndex:MTLImgBufferView_FS_Index_Color];
			
			[renderEncoder
				setFragmentBuffer:self.geoBuffer
				offset:0
				atIndex:MTLImgBufferView_FS_Index_Geo];
			
			[renderEncoder
				drawPrimitives:MTLPrimitiveTypeTriangleStrip
				vertexStart:0
				vertexCount:4];
			
			//	make sure the buffer we're drawing is retained until the command buffer has completed...
			[cmdBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
				MTLImgBuffer		*tmpBuffer = localImgBuffer;
				tmpBuffer = nil;
			}];
		}
		
		//	finish up the encoder
		[renderEncoder endEncoding];
		
		//NSLog(@"\t\tcmd buffer should have cmds for %@ in it...",self);
		//	the buffer needs to draw the drawable!
		[cmdBuffer presentDrawable:currentDrawable];
		
		currentDrawable = nil;
		
		localImgBuffer = nil;
	}
}


#pragma mark - superclass overrides


- (void) setDevice:(id<MTLDevice>)n	{
	@synchronized (self)	{
		[super setDevice:n];
		NSError				*nsErr = nil;
		NSBundle			*myBundle = [NSBundle bundleForClass:[self class]];
		id<MTLLibrary>		defaultLibrary = [device newDefaultLibraryWithBundle:myBundle error:&nsErr];
		id<MTLFunction>		vertFunc = [defaultLibrary newFunctionWithName:@"PreviewViewVertShader"];
		id<MTLFunction>		fragFunc = [defaultLibrary newFunctionWithName:@"PreviewViewFragShader"];
	
		MTLRenderPipelineDescriptor		*psDesc = [[MTLRenderPipelineDescriptor alloc] init];
		//psDesc.previewLabel = @"VVMTLImgBufferView pipeline";
		psDesc.vertexFunction = vertFunc;
		psDesc.fragmentFunction = fragFunc;
		psDesc.colorAttachments[0].pixelFormat = metalLayer.pixelFormat;
		
		//	commented out- this was an attempt to make MTLImgBufferView "transparent" (0 alpha would display view behind it)
		psDesc.alphaToCoverageEnabled = YES;
		psDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
		psDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
		//psDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
		psDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
		psDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
		//psDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
		psDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorZero;
		psDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
		psDesc.colorAttachments[0].blendingEnabled = YES;
	
		_pso = [device newRenderPipelineStateWithDescriptor:psDesc error:&nsErr];
	
		self.vertBuffer = nil;
		self.mvpBuffer = nil;
	}
}
- (BOOL) reconfigureDrawable	{
	@synchronized (self)	{
		BOOL		sizeChanged = [super reconfigureDrawable];
	
		if (sizeChanged)	{
			self.vertBuffer = nil;
			self.mvpBuffer = nil;
		}
	
		return sizeChanged;
	}
}
- (NSString *) description	{
	return [NSString stringWithFormat:@"<MTLImgBufferView %@>",self.label];
}


@end
