//
//  CMVMTLDrawObjectScene.m
//  VVMetalKit
//
//  Created by testadmin on 11/12/24.
//

#import "CMVMTLDrawObjectScene.h"
#import "CustomMetalView.h"
#import "CMVMTLDrawObject.h"




@interface CMVMTLDrawObjectScene ()
@property (readwrite,nonatomic) id<MTLArgumentEncoder> textureArgumentEncoder;
@end




@implementation CMVMTLDrawObjectScene

- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super initWithDevice:inDevice];
	if (self != nil)	{
		self.drawObject = nil;
		
		self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);
		self.renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
		
		NSError				*nsErr = nil;
		NSBundle			*myBundle = [NSBundle bundleForClass:[CustomMetalView class]];
		id<MTLLibrary>		defaultLibrary = [inDevice newDefaultLibraryWithBundle:myBundle error:&nsErr];
		id<MTLFunction>		vertFunc = [defaultLibrary newFunctionWithName:@"CustomMetalViewVertShader"];
		id<MTLFunction>		fragFunc = [defaultLibrary newFunctionWithName:@"CustomMetalViewFragShader"];
		
		self.renderPSODesc.label = @"CMVMTLDrawObjectScene";
		self.renderPSODesc.vertexFunction = vertFunc;
		self.renderPSODesc.fragmentFunction = fragFunc;
		self.renderPSODesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		
	}
	return self;
}

- (void) renderCallback	{
	[super renderCallback];
	
	CMVMTLDrawObject		*localDrawObject = self.drawObject;
	if (localDrawObject != nil)	{
		//[localDrawObject executeInRenderEncoder:self.renderEncoder commandBuffer:self.commandBuffer];
		
		id<MTLArgumentEncoder>		argEncoder = self.textureArgumentEncoder;
		[localDrawObject executeInRenderEncoder:self.renderEncoder textureArgumentEncoder:argEncoder commandBuffer:self.commandBuffer];
		localDrawObject = nil;
	}
}

- (void) _loadPSO	{
	//NSLog(@"%s",__func__);
	if (self.renderPSO == nil)	{
		self.textureArgumentEncoder = nil;
	}
	[super _loadPSO];
}

@synthesize textureArgumentEncoder=_textureArgumentEncoder;
- (void) setTextureArgumentEncoder:(id<MTLArgumentEncoder>)n	{
	_textureArgumentEncoder = n;
}
- (id<MTLArgumentEncoder>) textureArgumentEncoder	{
	if (_textureArgumentEncoder != nil)
		return _textureArgumentEncoder;
	id<MTLFunction>		localFunc = self.renderPSODesc.fragmentFunction;
	if (localFunc == nil)
		return nil;
	_textureArgumentEncoder = [localFunc newArgumentEncoderWithBufferIndex:CMV_FS_Idx_Tex];
	return _textureArgumentEncoder;
}

- (BOOL) isACMVMTLDrawObjectScene	{
	return YES;
}

@end
