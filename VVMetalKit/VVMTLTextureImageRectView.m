//
//  VVMTLTextureImageRectView.m
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#import "VVMTLTextureImageRectView.h"
#import "TargetConditionals.h"
#import "VVMTLTextureImageRectViewShaderTypes.h"
#import "RenderProperties.h"
//#import "VVSizingTool.h"
#import "SizingTool_c.h"
#import "SizingTool_objc.h"




#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#define NSMakeRect CGRectMake
#define NSRect CGRect
#endif

#define VVMINX(r) ((r.size.width>=0) ? (r.origin.x) : (r.origin.x+r.size.width))
#define VVMAXX(r) ((r.size.width>=0) ? (r.origin.x+r.size.width) : (r.origin.x))
#define VVMINY(r) ((r.size.height>=0) ? (r.origin.y) : (r.origin.y+r.size.height))
#define VVMAXY(r) ((r.size.height>=0) ? (r.origin.y+r.size.height) : (r.origin.y))




@interface VVMTLTextureImageRectView ()
@end




@implementation VVMTLTextureImageRectView


#pragma mark - init/dealloc


- (void) generalInit	{
	[super generalInit];
	//NSLog(@"%s",__func__);
	
	_vertBuffer = nil;
	_mvpBuffer = nil;
	//_geoBuffer = nil;
	_imgBuffer = nil;
	_vertRect = NSZeroRect;
	_imgTint = nil;
	self.contentNeedsRedraw = YES;
}
- (void) awakeFromNib	{
	[super awakeFromNib];
}


#pragma mark - property overrides


@synthesize imgBuffer=_imgBuffer;
- (void) setImgBuffer:(id<VVMTLTextureImage>)inBuffer	{
	//NSLog(@"%s ... %@",__func__,inBuffer);
	@synchronized (self)	{
		_imgBuffer = inBuffer;
	}
	self.contentNeedsRedraw = YES;
}
- (id<VVMTLTextureImage>)imgBuffer	{
	@synchronized (self)	{
		return _imgBuffer;
	}
}


#pragma mark - frontend


- (void) drawInCmdBuffer:(id<MTLCommandBuffer>)cmdBuffer	{
	//NSDate			*methodStartDate = [NSDate date];
	//NSLog(@"%s ... %@, %p",__func__,self.label,cmdBuffer);
	//NSLog(@"\tmy bounds are %@",NSStringFromRect(self.bounds));
	VVMTLTextureImage	*localImgBuffer = nil;
	id<MTLBuffer>		localMVPBuffer = nil;
	id<MTLBuffer>		localVertBuffer = nil;
	id<MTLBuffer>		localGeoBuffer = nil;
	id<MTLRenderPipelineState>		localPSO = nil;;
	
	@synchronized (self)	{
		
		//	always set this to NO as soon as you're pretty sure the frame can/will be drawn!
		self.contentNeedsRedraw = NO;
		
		//	make sure the mvp buffer exists, create it if it doesn't
		if (self.mvpBuffer == nil)	{
			double			left = 0.0;
			double			right = viewportSize.x;
			double			top = viewportSize.y;
			double			bottom = 0.0;
			double			far = 1.0;
			double			near = -1.0;
			BOOL		flipV = YES;
			BOOL		flipH = NO;
			if (flipV)	{
				top = 0.0;
				bottom = viewportSize.y;
			}
			if (flipH)	{
				right = 0.0;
				left = viewportSize.x;
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
		
			self.mvpBuffer = [metalLayer.device
				newBufferWithBytes:&mvp
				length:sizeof(mvp)
				options:MTLResourceStorageModeShared];
		}
		localMVPBuffer = self.mvpBuffer;
		
		localImgBuffer = (VVMTLTextureImage*)self.imgBuffer;
		//	if there's an image buffer...
		if (localImgBuffer != nil)	{
			//NSLog(@"\t\tthere's an image buffer to draw...");
			
			CGRect			viewRect = CGRectMake(0,0,viewportSize.x,viewportSize.y);
			
			//NSLog(@"\t\timgBuffer is %@",localImgBuffer);
			//	make sure the vert buffer exists, create it if it doesn't
			if (self.vertBuffer == nil)	{
				const VVMTLTextureImageRectViewVertex		quadVerts[] = {
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
			localVertBuffer = self.vertBuffer;
			
			//	make a geometry struct!
			VVMTLTextureImageStruct		localGeoStruct;
			
			//	populate it with the contents of the img buffer (src rect of the texture that contains the image)
			[localImgBuffer populateStruct:&localGeoStruct];
			
			//	calculate where the image will draw in my bounds, apply it to the geometry struct
			localGeoStruct.dstRect = GRectFromNSRect(_vertRect);
			
			NSColor		*tintColor = self.imgTint;
			if (tintColor == nil)	{
				localGeoStruct.colorMultiplier = simd_make_float4(1,1,1,1);
			}
			else	{
				CGFloat		colorVals[8];
				[tintColor getComponents:colorVals];
				localGeoStruct.colorMultiplier = simd_make_float4(colorVals[0], colorVals[1], colorVals[2], 1.);
			}
			
			
			//	make a geometry buffer from the struct
			self.geoBuffer = [metalLayer.device
				newBufferWithBytes:&localGeoStruct
				length:sizeof(localGeoStruct)
				options:MTLResourceStorageModeShared];
			localGeoBuffer = self.geoBuffer;
		}
		
		localPSO = pso;
	}
	
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
	
	//	make a render encoder, configure it
	id<MTLRenderCommandEncoder>		renderEncoder = [cmdBuffer renderCommandEncoderWithDescriptor:passDescriptor];
	if (self.label != nil)
		renderEncoder.label = self.label;
	else
		renderEncoder.label = [NSString stringWithFormat:@"%@ encoder",self.className];
	[renderEncoder setViewport:(MTLViewport){ 0.f, 0.f, viewportSize.x, viewportSize.y, -1.f, 1.f }];
	[renderEncoder setRenderPipelineState:localPSO];
	
	//	if there's an image buffer...
	if (localImgBuffer != nil)	{
		//	pass data to the render encoder
		[renderEncoder
			setVertexBuffer:localVertBuffer
			offset:0
			atIndex:VVMTLTextureImageRectView_VS_Index_Verts];
		[renderEncoder
			setVertexBuffer:localMVPBuffer
			offset:0
			atIndex:VVMTLTextureImageRectView_VS_Index_MVPMatrix];
		
		[renderEncoder
			setFragmentTexture:localImgBuffer.texture
			atIndex:VVMTLTextureImageRectView_FS_Index_Color];
		
		[renderEncoder
			setFragmentBuffer:localGeoBuffer
			offset:0
			atIndex:VVMTLTextureImageRectView_FS_Index_Geo];
		
		[renderEncoder
			drawPrimitives:MTLPrimitiveTypeTriangleStrip
			vertexStart:0
			vertexCount:4];
		
		//	make sure the buffer we're drawing is retained until the command buffer has completed...
		[cmdBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
			VVMTLTextureImage	*tmpBuffer = localImgBuffer;
			id<MTLBuffer>		tmpMVPBuffer = localMVPBuffer;
			id<MTLBuffer>		tmpVertBuffer = localVertBuffer;
			id<MTLBuffer>		tmpGeoBuffer = localGeoBuffer;
			tmpBuffer = nil;
			
			id<CAMetalDrawable>		tmpDrawable = self->currentDrawable;
			tmpDrawable = nil;
			
			tmpBuffer = nil;
			tmpMVPBuffer = nil;
			tmpVertBuffer = nil;
			tmpGeoBuffer = nil;
		}];
	}
	
	//	finish up the encoder
	[renderEncoder endEncoding];
	
	//NSLog(@"\t\tcmd buffer should have cmds for %@ in it...",self);
	//	the buffer needs to draw the drawable!
	[cmdBuffer presentDrawable:currentDrawable];
	
	currentDrawable = nil;
	
	localImgBuffer = nil;
	
	//double		methodTime = fabs([methodStartDate timeIntervalSinceNow]);
	//if (methodTime > 1./60.)	{
	//	NSLog(@"\t\tTOO LONG- %s ... %@, %p- %0.4f",__func__,self.label,cmdBuffer,methodTime);
	//}
}


#pragma mark - superclass overrides


- (void) setDevice:(id<MTLDevice>)n	{
	@synchronized (self)	{
		[super setDevice:n];
		NSError				*nsErr = nil;
		NSBundle			*myBundle = [NSBundle bundleForClass:[VVMTLTextureImageRectView class]];
		id<MTLLibrary>		defaultLibrary = [device newDefaultLibraryWithBundle:myBundle error:&nsErr];
		id<MTLFunction>		vertFunc = [defaultLibrary newFunctionWithName:@"VVMTLTextureImageRectViewVertShader"];
		id<MTLFunction>		fragFunc = [defaultLibrary newFunctionWithName:@"VVMTLTextureImageRectViewFragShader"];
	
		MTLRenderPipelineDescriptor		*psDesc = [[MTLRenderPipelineDescriptor alloc] init];
		//psDesc.previewLabel = @"VVMTLTextureImageRectView pipeline";
		psDesc.vertexFunction = vertFunc;
		psDesc.fragmentFunction = fragFunc;
		psDesc.colorAttachments[0].pixelFormat = metalLayer.pixelFormat;
		
		//	commented out- this was an attempt to make VVMTLTextureImageRectView "transparent" (0 alpha would display view behind it)
		psDesc.alphaToCoverageEnabled = NO;
		psDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
		psDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
		//psDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
		psDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
		psDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
		//psDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
		psDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorZero;
		psDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
		psDesc.colorAttachments[0].blendingEnabled = YES;
	
		pso = [device newRenderPipelineStateWithDescriptor:psDesc error:&nsErr];
	
		self.vertBuffer = nil;
		self.mvpBuffer = nil;
	}
	self.contentNeedsRedraw = YES;
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
	return [NSString stringWithFormat:@"<%@ (%@) %p>",self.className,self.label,self];
}
//- (BOOL) isFlipped	{
//	return YES;
//}


@end

