//
//  VVMTLPool.m
//  VVMetalKit
//
//  Created by testadmin on 6/26/23.
//

#import "VVMTLPool.h"
#import <MetalKit/MetalKit.h>
#import <os/lock.h>

#import "RenderProperties.h"

#import "VVMTLTextureImage.h"
#import "VVMTLTextureImageDescriptor.h"

#import "VVMTLBuffer.h"
#import "VVMTLBufferDescriptor.h"




#define A_HAS_B(a,b) (((a)&(b))==(b))
#define MAX_MTLTEXTUREIMAGE_LIFETIME 30

static NSUInteger TEXINDEX = 0;
//static os_unfair_lock TEXINDEXLOCK = OS_UNFAIR_LOCK_INIT;




@interface VVMTLPool ()	{
	id<MTLDevice>		_device;
	NSMutableArray<id<VVMTLRecycleable>>		*_texPool;	//	FIFO, objects that are in the pool "too long" get freed
	NSMutableArray<id<VVMTLRecycleable>>		*_bufferPool;	//	FIFO.
}
//	really returns a VVMTLTextureImage or VVMTLBuffer, because that's what this class creates & vends
- (id<VVMTLRecycleable>) _recycledObjectMatching:(id<VVMTLRecycleableDescriptor>)n;
- (void) _labelTexture:(id<MTLTexture>)n;
- (NSError *) _generateMissingGPUAssetsInTexImg:(VVMTLTextureImage *)n;
- (NSError *) _generateMissingGPUAssetsInBuffer:(VVMTLBuffer *)n;
@end




@implementation VVMTLPool


- (instancetype) initWithDevice:(id<MTLDevice>)n	{
	self = [super init];
	
	if (n == nil)
		self = nil;
	
	if (self != nil)	{
		_device = n;
		_texPool = [[NSMutableArray alloc] init];
		_bufferPool = [[NSMutableArray alloc] init];
	}
	
	return self;
}


#pragma mark - VVMTLRecyclingPool conformance


- (void) recycleObject:(id<VVMTLRecycleable>)n	{
	if (n == nil)
		return;
	@synchronized (self)	{
		if ([(NSObject*)n isVVMTLBuffer])	{
			[_bufferPool insertObject:n atIndex:0];
		}
		else if ([(NSObject*)n isVVMTLTextureImage])	{
			[_texPool insertObject:n atIndex:0];
		}
	}
}

- (id<VVMTLRecycleable>) recycledObjectMatching:(id<VVMTLRecycleableDescriptor>)n	{
	@synchronized (self)	{
		return [self _recycledObjectMatching:n];
	}
}
- (id<VVMTLRecycleable>) _recycledObjectMatching:(id<VVMTLRecycleableDescriptor>)n	{
	if (n == nil)
		return nil;
	id<VVMTLRecycleable>		returnMe = nil;
	int			tmpIndex = 0;
	
	if ([(NSObject*)n isVVMTLBufferDescriptor])	{
		for (id<VVMTLRecycleable> pooledObject in _bufferPool)	{
			if ([n matchForRecycling:pooledObject.descriptor])	{
				returnMe = pooledObject;
				[_bufferPool removeObjectAtIndex:tmpIndex];
				break;
			}
			++tmpIndex;
		}
	}
	else if ([(NSObject*)n isVVMTLTextureImageDescriptor])	{
		for (id<VVMTLRecycleable> pooledObject in _texPool)	{
			if ([n matchForRecycling:pooledObject.descriptor])	{
				returnMe = pooledObject;
				[_texPool removeObjectAtIndex:tmpIndex];
				break;
			}
			++tmpIndex;
		}
	}
	else	{
		NSLog(@"ERR: unrecognized descriptor (%@) in %s",n,__func__);
	}
	
	return returnMe;
}

- (void) housekeeping	{
	@synchronized (self)	{
		NSArray<NSMutableArray*>		*pools = @[ _texPool, _bufferPool ];
		for (NSMutableArray * pool in pools)	{
			
			int			tmpIndex = 0;
			NSMutableIndexSet		*indexesToDelete = nil;
			
			for (id<VVMTLRecycleable> pooledObject in pool)	{
				int			tmpCount = pooledObject.recycleCount;
				if (tmpCount >= MAX_MTLTEXTUREIMAGE_LIFETIME)	{
					if (indexesToDelete == nil)
						indexesToDelete = [[NSMutableIndexSet alloc] init];
					[indexesToDelete addIndex:tmpIndex];
					pooledObject.preferDeletion = YES;
				}
				else	{
					++tmpCount;
					pooledObject.recycleCount = tmpCount;
				}
				++tmpIndex;
			}
			if (indexesToDelete != nil)	{
				[pool removeObjectsAtIndexes:indexesToDelete];
			}
			
		}	//	pools for loop
	}	//	@synchronized
}


#pragma mark - frontend


- (id<MTLDevice>) device	{
	return _device;
}


#pragma mark - texture creation


- (id<VVMTLTextureImage>) bgra8TexSized:(NSSize)n	{
	VVMTLTextureImage			*returnMe = nil;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatBGRA8Unorm
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
	
	@synchronized (self)	{
		returnMe = (VVMTLTextureImage*)[self _recycledObjectMatching:desc];
		if (returnMe != nil)
			return returnMe;
		
		returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- bgra8"];
	
	return returnMe;
}

- (id<VVMTLTextureImage>) rgba8TexSized:(NSSize)n	{
	VVMTLTextureImage			*returnMe = nil;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatRGBA8Unorm
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
	
	@synchronized (self)	{
		returnMe = (VVMTLTextureImage*)[self _recycledObjectMatching:desc];
		if (returnMe != nil)
			return returnMe;
		
		returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- rgba8"];
	
	return returnMe;
}

- (id<VVMTLTextureImage>) rgb10a2TexSized:(NSSize)n	{
	VVMTLTextureImage			*returnMe = nil;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatRGB10A2Uint
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
	
	@synchronized (self)	{
		returnMe = (VVMTLTextureImage*)[self _recycledObjectMatching:desc];
		if (returnMe != nil)
			return returnMe;
		
		returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- rgb10a2"];
	
	return returnMe;
}

- (id<VVMTLTextureImage>) rgb10a2BufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	/*
	WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:

	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
	[blitEncoder synchronizeResource:VVMTLTextureImage.buffer.buffer];
	[blitEncoder endEncoding];
	[cmdBuffer commit];
	[cmdBuffer waitUntilCompleted];
	float		*contents = (float *)[newFrame.buffer contents];
	*/
	VVMTLBuffer			*backingBuffer = (VVMTLBuffer*)[self bufferWithLengthNoCopy:bpr*s.height storage:MTLStorageModeManaged basePtr:b bufferDeallocator:d];
	if (backingBuffer == nil)	{
		NSLog(@"ERR: unable to make backing buffer in %s",__func__);
		return nil;
	}
	
	VVMTLTextureImage		*returnMe = nil;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(s.width)
		height:round(s.height)
		pixelFormat:MTLPixelFormatRGB10A2Uint
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
	desc.mtlBufferBacking = YES;
	
	returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
	returnMe.buffer = backingBuffer;
	
	@synchronized (self)	{
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- rgb10a2B"];
	returnMe.preferDeletion = YES;
	
	return returnMe;
}

//- (id<VVMTLTextureImage>) rgb10a2NormTexSized:(NSSize)n	{
//	VVMTLTextureImage			*returnMe = nil;
//	
//	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
//		createWithWidth:round(n.width)
//		height:round(n.height)
//		pixelFormat:MTLPixelFormatRGB10A2Unorm
//		storage:MTLStorageModePrivate
//		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
//	
//	@synchronized (self)	{
//		returnMe = (VVMTLTextureImage*)[self _recycledObjectMatching:desc];
//		if (returnMe != nil)
//			return returnMe;
//		
//		returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
//		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
//		if (nsErr != nil)	{
//			NSLog(@"ERR (%@) in %s",nsErr,__func__);
//			return nil;
//		}
//	}
//	
//	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- rgb10a2n"];
//	
//	return returnMe;
//}

- (id<VVMTLTextureImage>) uyvyBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	/*
	WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:

	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
	[blitEncoder synchronizeResource:VVMTLTextureImage.buffer.buffer];
	[blitEncoder endEncoding];
	[cmdBuffer commit];
	[cmdBuffer waitUntilCompleted];
	float		*contents = (float *)[newFrame.buffer contents];
	*/
	VVMTLBuffer			*backingBuffer = (VVMTLBuffer*)[self bufferWithLengthNoCopy:bpr*s.height storage:MTLStorageModeManaged basePtr:b bufferDeallocator:d];
	if (backingBuffer == nil)	{
		NSLog(@"ERR: unable to make backing buffer in %s",__func__);
		return nil;
	}
	
	VVMTLTextureImage		*returnMe = nil;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(s.width)
		height:round(s.height)
		pixelFormat:MTLPixelFormatBGRG422
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
	desc.mtlBufferBacking = YES;
	
	returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
	returnMe.buffer = backingBuffer;
	
	@synchronized (self)	{
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- uyvyBB"];
	returnMe.preferDeletion = YES;
	
	return returnMe;
}

//- (id<VVMTLTextureImage>) rgba16TexSized:(NSSize)n	{
//	VVMTLTextureImage			*returnMe = nil;
//	
//	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
//		createWithWidth:round(n.width)
//		height:round(n.height)
//		pixelFormat:MTLPixelFormatRGBA16Uint
//		storage:MTLStorageModePrivate
//		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
//	
//	@synchronized (self)	{
//		returnMe = (VVMTLTextureImage*)[self _recycledObjectMatching:desc];
//		if (returnMe != nil)
//			return returnMe;
//		
//		returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
//		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
//		if (nsErr != nil)	{
//			NSLog(@"ERR (%@) in %s",nsErr,__func__);
//			return nil;
//		}
//	}
//	
//	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- rgba16"];
//	
//	return returnMe;
//}

- (id<VVMTLTextureImage>) rgbaFloatTexSized:(NSSize)n	{
	VVMTLTextureImage			*returnMe = nil;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatRGBA32Float
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
	
	@synchronized (self)	{
		returnMe = (VVMTLTextureImage*)[self _recycledObjectMatching:desc];
		if (returnMe != nil)
			return returnMe;
		
		returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- rgbaF"];
	
	return returnMe;
}

//- (id<VVMTLTextureImage>) rgbaFloatBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
//	/*
//	WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:
//
//	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
//	[blitEncoder synchronizeResource:VVMTLTextureImage.buffer.buffer];
//	[blitEncoder endEncoding];
//	[cmdBuffer commit];
//	[cmdBuffer waitUntilCompleted];
//	float		*contents = (float *)[newFrame.buffer contents];
//	*/
//	
//	returnMe.preferDeletion = YES;
//}

//- (id<VVMTLTextureImage>) rgbaBufferBackedFloatTexSized:(NSSize)n	{
//	/*
//	WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:
//
//	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
//	[blitEncoder synchronizeResource:VVMTLTextureImage.buffer.buffer];
//	[blitEncoder endEncoding];
//	[cmdBuffer commit];
//	[cmdBuffer waitUntilCompleted];
//	float		*contents = (float *)[newFrame.buffer contents];
//	*/
//	
//	returnMe.preferDeletion = YES;
//}

- (id<VVMTLTextureImage>) bgra8BufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	/*
	WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:

	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
	[blitEncoder synchronizeResource:VVMTLTextureImage.buffer.buffer];
	[blitEncoder endEncoding];
	[cmdBuffer commit];
	[cmdBuffer waitUntilCompleted];
	float		*contents = (float *)[newFrame.buffer contents];
	*/
	VVMTLBuffer			*backingBuffer = (VVMTLBuffer*)[self bufferWithLengthNoCopy:bpr*s.height storage:MTLStorageModeManaged basePtr:b bufferDeallocator:d];
	if (backingBuffer == nil)	{
		NSLog(@"ERR: unable to make backing buffer in %s",__func__);
		return nil;
	}
	
	VVMTLTextureImage		*returnMe = nil;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(s.width)
		height:round(s.height)
		pixelFormat:MTLPixelFormatBGRA8Unorm
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
	desc.mtlBufferBacking = YES;
	
	returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
	returnMe.buffer = backingBuffer;
	
	@synchronized (self)	{
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- bgra8BB"];
	returnMe.preferDeletion = YES;
	
	return returnMe;
}

//- (id<VVMTLTextureImage>) rgbaHalfFloatTexSized:(NSSize)n	{
//	VVMTLTextureImage			*returnMe = nil;
//	
//	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
//		createWithWidth:round(n.width)
//		height:round(n.height)
//		pixelFormat:MTLPixelFormatRGBA16Float
//		storage:MTLStorageModePrivate
//		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
//	
//	@synchronized (self)	{
//		returnMe = (VVMTLTextureImage*)[self _recycledObjectMatching:desc];
//		if (returnMe != nil)
//			return returnMe;
//		
//		returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
//		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
//		if (nsErr != nil)	{
//			NSLog(@"ERR (%@) in %s",nsErr,__func__);
//			return nil;
//		}
//	}
//	
//	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- rgbaHF"];
//	
//	return returnMe;
//}

//- (id<VVMTLTextureImage>) rgbaHalfFloatBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
//	/*
//	WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:
//
//	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
//	[blitEncoder synchronizeResource:VVMTLTextureImage.buffer.buffer];
//	[blitEncoder endEncoding];
//	[cmdBuffer commit];
//	[cmdBuffer waitUntilCompleted];
//	float		*contents = (float *)[newFrame.buffer contents];
//	*/
//	
//	returnMe.preferDeletion = YES;
//}

- (id<VVMTLTextureImage>) bufferForExistingTexture:(id<MTLTexture>)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:n.width
		height:n.height
		pixelFormat:n.pixelFormat
		storage:n.storageMode
		usage:n.usage];
	
	VVMTLTextureImage			*returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
	returnMe.texture = n;
	returnMe.pool = self;
	returnMe.preferDeletion = YES;
	returnMe.descriptor = desc;
	return returnMe;
}

- (id<VVMTLTextureImage>) bgra8IOSurfaceBackedTexSized:(NSSize)n	{
	VVMTLTextureImage			*returnMe = nil;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatBGRA8Unorm
		storage:MTLStorageModeShared
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
	desc.iosfcBacking = YES;
	desc.cvpbBacking = YES;
	
	@synchronized (self)	{
		returnMe = (VVMTLTextureImage*)[self _recycledObjectMatching:desc];
		if (returnMe != nil)
			return returnMe;
		
		returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- bgra8IO"];
	
	return returnMe;
}

//- (id<VVMTLTextureImage>) rgbaFloat32IOSurfaceBackedTexSized:(NSSize)n	{
//	VVMTLTextureImage			*returnMe = nil;
//	
//	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
//		createWithWidth:round(n.width)
//		height:round(n.height)
//		pixelFormat:MTLPixelFormatRGBA32Float
//		storage:MTLStorageModeShared
//		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite];
//	desc.iosfcBacking = YES;
//	desc.cvpbBacking = YES;
//	
//	@synchronized (self)	{
//		returnMe = (VVMTLTextureImage*)[self _recycledObjectMatching:desc];
//		if (returnMe != nil)
//			return returnMe;
//		
//		returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
//		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
//		if (nsErr != nil)	{
//			NSLog(@"ERR (%@) in %s",nsErr,__func__);
//			return nil;
//		}
//	}
//	
//	returnMe.texture.label = [returnMe.texture.label stringByAppendingString:@"- rgbaFIO"];
//	
//	return returnMe;
//}

//- (id<VVMTLTextureImage>) rgbaHalfFloatIOSurfaceBackedTexFromCVPB:(CVPixelBufferRef)inCVPB	{
//}

//- (id<VVMTLTextureImage>) uyvyIOSurfaceBackedTexSized:(NSSize)n	{
//}

- (id<VVMTLTextureImage>) bufferForCVMTLTex:(CVMetalTextureRef)inRef sized:(NSSize)inSize	{
	if (inRef == NULL)
		return nil;
	
	id<MTLTexture>		tmpTex = CVMetalTextureGetTexture(inRef);
	if (tmpTex == nil)
		return nil;
	
	return [self bufferForExistingTexture:tmpTex];
}

- (id<VVMTLBuffer>) bufferButNoTexSized:(size_t)inBufferSize options:(MTLResourceOptions)inOpts	{
	MTLStorageMode		storage = MTLStorageModeShared;
	if (A_HAS_B(inOpts,MTLStorageModeShared))	{
		storage = MTLStorageModeShared;
	}
	else if (A_HAS_B(inOpts,MTLStorageModeManaged))	{
		storage = MTLStorageModeManaged;
	}
	else if (A_HAS_B(inOpts,MTLStorageModePrivate))	{
		storage = MTLStorageModePrivate;
	}
	return [self bufferWithLength:inBufferSize storage:storage];
}

- (id<VVMTLTextureImage>) createFromNSImage:(NSImage *)n	{
	if (n == nil)
		return nil;
	
	NSSize			tmpSize = n.size;
	NSRect			tmpRect = NSMakeRect(0,0,tmpSize.width,tmpSize.height);
	size_t			bytesPerRow = 8 * 4 * tmpSize.width;	//	bits per component * number of components * width
	
	void			*tmpBacking = malloc(bytesPerRow * tmpSize.height);
	
	CGColorSpaceRef		tmpSpace = CGColorSpaceCreateWithName( kCGColorSpaceITUR_709 );
	CGBitmapInfo		tmpBitmapInfo = (CGBitmapInfo)kCGImageAlphaNoneSkipFirst;
	CGContextRef		tmpCGCtx = CGBitmapContextCreate( tmpBacking, tmpSize.width, tmpSize.height, 8, bytesPerRow, tmpSpace, tmpBitmapInfo);
	
	MTKTextureLoader	*tmpLoader = [[MTKTextureLoader alloc] initWithDevice:[RenderProperties global].device];
	NSGraphicsContext	*tmpNSCtx = [NSGraphicsContext graphicsContextWithCGContext:tmpCGCtx flipped:NO];
	CGImageRef			tmpCGImg = (tmpNSCtx==nil) ? NULL : [n CGImageForProposedRect:&tmpRect context:tmpNSCtx hints:nil];
	
	NSError				*nsErr = nil;
	id<MTLTexture>		tmpTex = (tmpCGImg==NULL) ? nil : [tmpLoader newTextureWithCGImage:tmpCGImg options:@{ MTKTextureLoaderOptionSRGB: @(NO) } error:&nsErr];
	id<VVMTLTextureImage>		returnMe = (tmpTex==nil) ? nil : [self bufferForExistingTexture:tmpTex];
	
	tmpNSCtx = nil;
	tmpLoader = nil;
	if (tmpCGCtx != NULL)
		CGContextRelease(tmpCGCtx);
	if (tmpSpace != NULL)
		CGColorSpaceRelease(tmpSpace);
	if (tmpBacking != NULL)
		free(tmpBacking);
	
	return returnMe;
}


#pragma mark - buffer creation


- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage	{
	VVMTLBuffer			*returnMe = nil;
	
	VVMTLBufferDescriptor		*desc = [VVMTLBufferDescriptor createWithLength:inStorage storage:inStorage];
	
	//MTLResourceOptions			resourceStorageMode = MTLResourceStorageModeForMTLStorageMode(inStorage);
	@synchronized (self)	{
		returnMe = (VVMTLBuffer*)[self _recycledObjectMatching:desc];
		if (returnMe != nil)
			return returnMe;
		
		returnMe = [[VVMTLBuffer alloc] initWithDescriptor:desc];
		NSError			*nsErr = [self _generateMissingGPUAssetsInBuffer:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	//returnMe.buffer.label = [returnMe.buffer.label stringByAppendingString:@"???"];
	
	return returnMe;
}
//	copies the data from the passed ptr into a new buffer.  safe to delete the passed ptr when this returns.
- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage basePtr:(nullable void*)b	{
	size_t			targetLength = 0;
	if (inLength % 4096 == 0)	{
		targetLength = inLength;
	}
	else	{
		targetLength = 4096 - (inLength % 4096) + inLength;
	}
	VVMTLBufferDescriptor		*desc = [VVMTLBufferDescriptor createWithLength:targetLength storage:inStorage];
	
	MTLResourceOptions			resourceStorageMode = MTLResourceStorageModeForMTLStorageMode(inStorage);
	id<MTLBuffer>	buffer = nil;
	if (b == NULL)	{
		buffer = [self.device newBufferWithLength:targetLength options:resourceStorageMode];
	}
	else	{
		buffer = [self.device newBufferWithBytes:b length:targetLength options:resourceStorageMode];
	}
	
	VVMTLBuffer		*returnMe = [[VVMTLBuffer alloc] init];
	returnMe.buffer = buffer;
	returnMe.pool = self;
	returnMe.preferDeletion = YES;
	returnMe.descriptor = desc;
	
	return returnMe;
}
//	the MTLBuffer returned by this will be backed by the passed ptr, and modifying the MTLBuffer will modify its backing.
- (id<VVMTLBuffer>) bufferWithLengthNoCopy:(size_t)inLength storage:(MTLStorageMode)inStorage basePtr:(nullable void*)b bufferDeallocator:(nullable void (^)(void *pointer, NSUInteger length))d	{
	size_t			targetLength = 0;
	size_t			pageSize = getpagesize();
	if (inLength % pageSize == 0)	{
		targetLength = inLength;
	}
	else	{
		targetLength = pageSize - (inLength % pageSize) + inLength;
	}
	VVMTLBufferDescriptor		*desc = [VVMTLBufferDescriptor createWithLength:targetLength storage:inStorage];
	
	MTLResourceOptions		resourceStorageMode = MTLResourceStorageModeForMTLStorageMode(inStorage);
	id<MTLBuffer>	buffer = nil;
	if (b == NULL)	{
		buffer = [self.device newBufferWithLength:targetLength options:resourceStorageMode];
	}
	else	{
		buffer = [self.device newBufferWithBytesNoCopy:b length:targetLength options:resourceStorageMode deallocator:d];
	}
	
	VVMTLBuffer		*returnMe = [[VVMTLBuffer alloc] init];
	returnMe.buffer = buffer;
	returnMe.pool = self;
	returnMe.preferDeletion = YES;
	returnMe.descriptor = desc;
	
	return returnMe;
}


#pragma mark - backend


- (void) _labelTexture:(id<MTLTexture>)n	{
	if (n == nil)
		return;
	//os_unfair_lock_lock(&TEXINDEXLOCK);
	
	n.label = [NSString stringWithFormat:@"%ld",(unsigned long)TEXINDEX];
	++TEXINDEX;
	
	//os_unfair_lock_unlock(&TEXINDEXLOCK);
}


- (NSError *) _generateMissingGPUAssetsInTexImg:(VVMTLTextureImage *)n	{
	if (n == nil)
		return nil;
	VVMTLTextureImageDescriptor		*desc = (VVMTLTextureImageDescriptor *)n.descriptor;
	//	if we couldn't find a pixel format, bail immediately
	OSType			cvPixelFormat = BestGuessCVPixelFormatTypeForMTLPixelFormat(desc.pfmt);
	if (cvPixelFormat == 0x00)	{
		return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"No pixel format found for %X",(uint32_t)desc.pfmt] }];
	}
	
	//	local copies of vars to simplify access
	id<MTLTexture>			texture = n.texture;
	id<VVMTLBuffer>			buffer = n.buffer;
	IOSurfaceRef			iosfc = n.iosfc;
	CVPixelBufferRef		cvpb = n.cvpb;
	
	NSSize			size = NSMakeSize(desc.width, desc.height);
	BOOL			mtlBufferBacking = desc.mtlBufferBacking;
	BOOL			iosfcBacking = desc.iosfcBacking;
	BOOL			cvpbBacking = desc.cvpbBacking;
	
	size_t			bytesPerRow = 0;
	switch (desc.pfmt)	{
	case MTLPixelFormatR8Unorm:	//	??
		bytesPerRow = size.width * 8 * 1 * size.height / 8;
		break;
	
	case MTLPixelFormatRG8Unorm:
		bytesPerRow = size.width * 8 * 2 * size.height / 8;
		break;
	
	case MTLPixelFormatBGRG422:	//	BM stuff
		bytesPerRow = size.width * 8 * 2 * size.height / 8;
		break;
	case MTLPixelFormatGBGR422:	//	BM stuff
		bytesPerRow = size.width * 8 * 2 * size.height / 8;
		break;
	case MTLPixelFormatRGBA8Unorm:
		bytesPerRow = size.width * 8 * 4 * size.height / 8;
		break;
	case MTLPixelFormatBGRA8Unorm:
		bytesPerRow = size.width * 8 * 4 * size.height / 8;
		break;
	
	case MTLPixelFormatRGBA32Float:
		bytesPerRow = size.width * 32 * 4 * size.height / 8;
		break;
	
	case MTLPixelFormatRGB10A2Uint:	//	BM stuff
		bytesPerRow = size.width * 32 * size.height / 8;
		break;
	case MTLPixelFormatRGB10A2Unorm:	//	not used?
		bytesPerRow = size.width * 32 * size.height / 8;
		break;
	
	case MTLPixelFormatRGBA16Uint:
		bytesPerRow = size.width * 16 * 4 * size.height / 8;
		break;
	default:
		//	intentionally blank
		break;
	}
	
	//	if the descriptor indicates that we need a CVPixelBufferRef as a backing, but we don't have one yet...
	if (cvpbBacking && cvpb == NULL)	{
		CVReturn		cvErr = CVPixelBufferCreate(
			kCFAllocatorDefault,
			desc.width,
			desc.height,
			cvPixelFormat,
			(__bridge CFDictionaryRef)@{ (NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{} },
			&cvpb);
		if (cvErr != kCVReturnSuccess || cvpb == NULL)	{
			return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"problem (%d) while creating pixel buffer",cvErr] }];
		}
		
		n.cvpb = cvpb;
		
		CVPixelBufferRelease(cvpb);
		
		bytesPerRow = CVPixelBufferGetBytesPerRow(cvpb);
	}
	
	//	if the descriptor indicates that we need an IOSurfaceRef as a backing, but we don't have one yet...
	if (iosfcBacking && iosfc == NULL)	{
		if (cvpb != NULL)	{
			iosfc = CVPixelBufferGetIOSurface(cvpb);
			if (iosfc == NULL)	{
				return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"problem while creating iosfc from cvpb" }];
			}
		}
		else	{
			return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"can't make iosfc from scratch" }];
		}
		
		n.iosfc = iosfc;
		
		CFRelease(iosfc);
		
		bytesPerRow = IOSurfaceGetBytesPerRow(iosfc);
	}
	
	//	if the descriptor indicates that we need a MTLBuffer (via id<VVMTLBuffer>) as a backing, but we don't have one yet...
	if (mtlBufferBacking && buffer == nil)	{
		size_t			targetBufferLength = bytesPerRow * size.height;
		buffer = [self bufferWithLength:targetBufferLength storage:desc.storage];
	}
	
	//	...okay, so at this point if we need a backing, we should have already created it- now we need to create a texture.
	
	MTLTextureDescriptor		*texDesc = [[MTLTextureDescriptor alloc] init];
	texDesc.textureType = MTLTextureType2D;
	texDesc.pixelFormat = desc.pfmt;
	texDesc.width = size.width;
	texDesc.height = size.height;
	texDesc.depth = 1;
	texDesc.storageMode = desc.storage;
	texDesc.resourceOptions = MTLResourceStorageModeForMTLStorageMode(desc.storage);
	texDesc.usage = desc.usage;
	
	//	if there's an id<VVMTLBuffer> we want to use to back the texture...
	if (buffer != nil)	{
	}
	//	else if there's an IOSurface we want to use to back the texture...
	else if (iosfc != NULL)	{
	}
	//	else it's just a plain ol' texture
	else	{
		
		texture = [_device newTextureWithDescriptor:texDesc];
		[self _labelTexture:texture];
		
		n.texture = texture;
	}
	
	
	return nil;
}
- (NSError *) _generateMissingGPUAssetsInBuffer:(VVMTLBuffer *)n	{
	if (n == nil)
		return nil;
	
	id<MTLBuffer>	buffer = n.buffer;
	//	if there's already a buffer, we're done!
	if (buffer != nil)
		return nil;
	
	VVMTLBufferDescriptor		*desc = (VVMTLBufferDescriptor*)n.descriptor;
	MTLResourceOptions		resourceStorageMode = MTLResourceStorageModeForMTLStorageMode(desc.storage);
	buffer = [self.device newBufferWithLength:desc.length options:resourceStorageMode];
	
	n.buffer = buffer;
	n.pool = self;
	
	return nil;
}


@end













static inline MTLResourceOptions MTLResourceStorageModeForMTLStorageMode(MTLStorageMode inStorage)	{
	MTLResourceOptions		returnMe = MTLResourceStorageModePrivate;
	switch (inStorage)	{
	case MTLStorageModePrivate:
		returnMe = MTLResourceStorageModePrivate;
		break;
	case MTLStorageModeShared:
		returnMe = MTLResourceStorageModeShared;
		break;
	case MTLStorageModeManaged:
		returnMe = MTLResourceStorageModeManaged;
		break;
	case MTLStorageModeMemoryless:
		//	intentionally blank, not handled
		break;
	}
	return returnMe;
}

static inline OSType BestGuessCVPixelFormatTypeForMTLPixelFormat(MTLPixelFormat inPF)	{
	OSType			cvPixelFormat = 0x00;
	switch (inPF)	{
	case MTLPixelFormatR8Unorm:	//	??
		cvPixelFormat = kCVPixelFormatType_OneComponent8;
		break;
	
	case MTLPixelFormatRG8Unorm:
		cvPixelFormat = kCVPixelFormatType_TwoComponent8;
		break;
	
	case MTLPixelFormatBGRG422:	//	BM stuff
		cvPixelFormat = kCVPixelFormatType_422YpCbCr8;
		break;
	case MTLPixelFormatGBGR422:	//	BM stuff
		cvPixelFormat = kCVPixelFormatType_422YpCbCr8_yuvs;
		//cvPixelFormat = kCVPixelFormatType_422YpCbCr8FullRange;
		break;
	case MTLPixelFormatRGBA8Unorm:
		cvPixelFormat = kCVPixelFormatType_32RGBA;
		break;
	case MTLPixelFormatBGRA8Unorm:
		cvPixelFormat = kCVPixelFormatType_32BGRA;
		break;
	
	case MTLPixelFormatRGBA32Float:
		cvPixelFormat = kCVPixelFormatType_128RGBAFloat;
		break;
	
	case MTLPixelFormatRGB10A2Uint:	//	BM stuff
		cvPixelFormat = kCVPixelFormatType_30RGB;
		break;
	case MTLPixelFormatRGB10A2Unorm:	//	not used?
		cvPixelFormat = kCVPixelFormatType_30RGB;
		break;
	
	case MTLPixelFormatRGBA16Uint:
		//	no corresponding CV pixel fmt?
		break;
	default:
		//	intentionally blank
		break;
	}
	return cvPixelFormat;
}

