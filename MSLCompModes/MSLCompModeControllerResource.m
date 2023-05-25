//
//  MSLCompModeControllerResource.m
//  MSLCompModes
//
//  Created by testadmin on 5/18/23.
//

#import "MSLCompModeControllerResource.h"




@interface MSLCompModeControllerResource ()
@property (readwrite,strong) id<MTLLibrary> lib;
@property (readwrite,strong) id<MTLFunction> vtxFunc;
@property (readwrite,strong) id<MTLFunction> frgFunc;
@property (readwrite,strong) id<MTLRenderPipelineState> pso_8bit;
@property (readwrite,strong) id<MTLRenderPipelineState> pso_float;
@end




@implementation MSLCompModeControllerResource


+ (instancetype) createWithDevice:(id<MTLDevice>)inDevice shaderSrc:(NSString *)inSrc	{
	return [[MSLCompModeControllerResource alloc] initWithDevice:inDevice shaderSrc:inSrc];
}


- (instancetype) initWithDevice:(id<MTLDevice>)inDevice shaderSrc:(NSString *)inSrc	{
	NSLog(@"%s",__func__);
	self = [super init];
	if (self != nil)	{
		_device = inDevice;
		
		NSError			*nsErr = nil;
		
		_lib = [_device newLibraryWithSource:inSrc options:nil error:&nsErr];
		if (_lib == nil || nsErr != nil)	{
			NSLog(@"ERR: unable to make lib from shader src (%@), bailing, %s, %@",nsErr,__func__,inSrc);
			self = nil;
			return self;
		}
		
		_vtxFunc = [_lib newFunctionWithName:@"MSLCompModeControllerVtxFunc"];
		if (_vtxFunc == nil)	{
			NSLog(@"ERR: unable to locate vtx func in shader src, bailng, %s, %@",__func__,inSrc);
			self = nil;
			return self;
		}
		_frgFunc = [_lib newFunctionWithName:@"MSLCompModeControllerFrgFunc"];
		if (_frgFunc == nil)	{
			NSLog(@"ERR: unable to locate frg func in shader src, bailng, %s, %@",__func__,inSrc);
			self = nil;
			return self;
		}
		
		MTLRenderPipelineDescriptor		*passDesc_8bit = [[MTLRenderPipelineDescriptor alloc] init];
		MTLRenderPipelineDescriptor		*passDesc_float = [[MTLRenderPipelineDescriptor alloc] init];
		for (MTLRenderPipelineDescriptor * passDesc in @[ passDesc_8bit, passDesc_float ])	{
			passDesc.vertexFunction = _vtxFunc;
			passDesc.fragmentFunction = _frgFunc;
			
			passDesc.fragmentBuffers[0].mutability = MTLMutabilityImmutable;
			passDesc.fragmentBuffers[1].mutability = MTLMutabilityImmutable;
		}
		passDesc_8bit.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
		passDesc_float.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
		
		_pso_8bit = [_device newRenderPipelineStateWithDescriptor:passDesc_8bit error:&nsErr];
		if (_pso_8bit == nil || nsErr != nil)	{
			NSLog(@"ERR: unable to make pso A in %s, %@",__func__,nsErr);
			self = nil;
			return self;
		}
		_pso_float = [_device newRenderPipelineStateWithDescriptor:passDesc_float error:&nsErr];
		if (_pso_float == nil || nsErr != nil)	{
			NSLog(@"ERR: unable to make pso B in %s, %@",__func__,nsErr);
			self = nil;
			return self;
		}
	}
	return self;
}


@end
