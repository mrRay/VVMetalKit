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
#import "VVMTLUtilities.h"

#import "VVMTLTextureImage.h"
#import "VVMTLTextureImageDescriptor.h"

#import "VVMTLBuffer.h"
#import "VVMTLBufferDescriptor.h"

#import "VVMTLTextureLUT.h"
#import "VVMTLTextureLUTDescriptor.h"




#define A_HAS_B(a,b) (((a)&(b))==(b))
#define MAX_MTLTEXTUREIMAGE_LIFETIME 30
#define ROUNDAUPTOMULTOFB(A,B) ((((A)%(B))==0) ? (A) : ((A) + ((B)-((A)%(B)))))

static NSUInteger TEXINDEX = 0;
//static os_unfair_lock TEXINDEXLOCK = OS_UNFAIR_LOCK_INIT;

static VVMTLPool * __nullable _globalVVMTLPool = nil;




@interface VVMTLPool ()	{
	id<MTLDevice>		_device;
	NSMutableArray<id<VVMTLRecycleable>>		*_texPool;	//	FIFO, objects that are in the pool "too long" get freed
	NSMutableArray<id<VVMTLRecycleable>>		*_bufferPool;	//	FIFO.
	NSMutableArray<id<VVMTLRecycleable>>		*_lutPool;	//	FIFO
	CVMetalTextureCacheRef		_cvTexCache;
	CMClockRef			_clock;
}
//	really returns a VVMTLTextureImage or VVMTLBuffer, because that's what this class creates & vends
- (id<VVMTLRecycleable>) _recycledObjectMatching:(id<VVMTLRecycleableDescriptor>)n;
- (void) _labelTexture:(id<VVMTLTextureImage>)n;
- (NSError *) _generateMissingGPUAssetsInTexImg:(VVMTLTextureImage *)n;
- (NSError *) _generateMissingGPUAssetsInBuffer:(VVMTLBuffer *)n;
- (NSError *) _generateMissingGPUAssetsInTexLUT:(VVMTLTextureLUT *)n;
@end




@implementation VVMTLPool


+ (void) setGlobal:(VVMTLPool *)n	{
	_globalVVMTLPool = n;
}
+ (VVMTLPool *) global	{
	return _globalVVMTLPool;
}
- (instancetype) initWithDevice:(id<MTLDevice>)n	{
	self = [super init];
	
	if (n == nil)
		self = nil;
	
	if (self != nil)	{
		_device = n;
		_texPool = [[NSMutableArray alloc] init];
		_bufferPool = [[NSMutableArray alloc] init];
		_lutPool = [[NSMutableArray alloc] init];
		
		CVReturn		cvErr = kCVReturnSuccess;
		cvErr = CVMetalTextureCacheCreate(
			NULL,
			NULL,
			_device,
			NULL,
			&_cvTexCache);
		if (cvErr != kCVReturnSuccess)	{
			NSLog(@"ERR: unable to create metal texture cache (%d)",cvErr);
		}
		
		_clock = CMClockGetHostTimeClock();
	}
	
	return self;
}
- (CVMetalTextureCacheRef) cvTexCache	{
	return _cvTexCache;
}


#pragma mark - VVMTLRecyclingPool conformance


- (void) recycleObject:(id<VVMTLRecycleable>)n	{
	if (n == nil)
		return;
	@synchronized (self)	{
		if ([(NSObject*)n isVVMTLTextureImage])	{
			[_texPool insertObject:n atIndex:0];
		}
		else if ([(NSObject*)n isVVMTLBuffer])	{
			[_bufferPool insertObject:n atIndex:0];
		}
		else if ([(NSObject*)n isVVMTLTextureLUT])	{
			[_lutPool insertObject:n atIndex:0];
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
	
	if ([(NSObject*)n isVVMTLTextureImageDescriptor])	{
		//	if the descriptor doesn't have a bytes per row, calculate the bytes per row based on the pixel format and dimensions
		VVMTLTextureImageDescriptor		*recast = (VVMTLTextureImageDescriptor*)n;
		size_t			bytesPerRow = recast.bytesPerRow;
		if (bytesPerRow == 0)	{
			NSSize			adjustedImgSize = NSMakeSize(recast.width, recast.height);
			bytesPerRow = BytesPerRowFromMTLPixelFormatAndSize(recast.pfmt, &adjustedImgSize);
			
			if (recast.mtlBufferBacking || recast.iosfcBacking || recast.cvpbBacking)	{
				NSUInteger		tmpAlignment = [self.device minimumTextureBufferAlignmentForPixelFormat:recast.pfmt];
				if (tmpAlignment > 0)	{
					bytesPerRow = ROUNDAUPTOMULTOFB(bytesPerRow,tmpAlignment);
				}
			}
			
			recast.bytesPerRow = bytesPerRow;
		}
		
		for (id<VVMTLRecycleable> pooledObject in _texPool)	{
			if ([n matchForRecycling:pooledObject.descriptor])	{
				returnMe = pooledObject;
				[_texPool removeObjectAtIndex:tmpIndex];
				break;
			}
			++tmpIndex;
		}
	}
	else if ([(NSObject*)n isVVMTLBufferDescriptor])	{
		for (id<VVMTLRecycleable> pooledObject in _bufferPool)	{
			if ([n matchForRecycling:pooledObject.descriptor])	{
				returnMe = pooledObject;
				[_bufferPool removeObjectAtIndex:tmpIndex];
				break;
			}
			++tmpIndex;
		}
	}
	else if ([(NSObject*)n isVVMTLTextureLUTDescriptor])	{
		for (id<VVMTLRecycleable> pooledObject in _lutPool)	{
			if ([n matchForRecycling:pooledObject.descriptor])	{
				returnMe = pooledObject;
				[_lutPool removeObjectAtIndex:tmpIndex];
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
		NSArray<NSMutableArray*>		*pools = @[ _texPool, _bufferPool, _lutPool ];
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
		if (_cvTexCache != NULL)	{
			CVMetalTextureCacheFlush(_cvTexCache,0);
		}
	}	//	@synchronized
}


#pragma mark - frontend


- (id<MTLDevice>) device	{
	return _device;
}


- (void) timestampThis:(id<VVMTLTimestamp>)n	{
	if (n == nil)
		return;
	n.time = CMClockGetTime(_clock);
}


#pragma mark - texture creation


- (id<VVMTLTextureImage>) textureForDescriptor:(VVMTLTextureImageDescriptor*)inDesc	{
	if (inDesc == nil)
		return nil;
	VVMTLTextureImage			*returnMe = nil;
	@synchronized (self)	{
		returnMe = (VVMTLTextureImage*)[self _recycledObjectMatching:inDesc];
		if (returnMe != nil)
			return returnMe;
		
		returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:inDesc];
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	return returnMe;
}


- (id<VVMTLTextureImage>) bgra8TexSized:(NSSize)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatBGRA8Unorm
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
	return returnMe;
}
- (id<VVMTLTextureImage>) bgra8SRGBTexSized:(NSSize)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatBGRA8Unorm_sRGB
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
	return returnMe;
}

- (id<VVMTLTextureImage>) rgba8TexSized:(NSSize)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatRGBA8Unorm
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
	return returnMe;
}
- (id<VVMTLTextureImage>) rgba8SRGBTexSized:(NSSize)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatRGBA8Unorm_sRGB
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
	return returnMe;
}

- (id<VVMTLTextureImage>) rgb10a2TexSized:(NSSize)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatRGB10A2Uint
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
	return returnMe;
}

- (id<VVMTLTextureImage>) rgb10a2BufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	/*
		// ACCESS NOTES
	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		// modified CPU, need to push changes to GPU:
	[VVMTLTextureImage.buffer.buffer didModifyRange:XXX];
		// modified GPU, need to pull changes to CPU:
	[blitEncoder synchronizeResource::VVMTLTextureImage.buffer.buffer]
		// cmd buffer that owns the blit encoder must complete before data is valid!
	[self timestampThis:VVMTLTextureImage];
	void		*contents = (void *)[VVMTLTextureImage.buffer.buffer contents];
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
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:bpr];
	desc.mtlBufferBacking = YES;
	
	returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
	returnMe.buffer = backingBuffer;
	//returnMe.bytesPerRow = bpr;
	
	@synchronized (self)	{
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.preferDeletion = YES;
	[self timestampThis:returnMe];
	return returnMe;
}

//- (id<VVMTLTextureImage>) rgb10a2NormTexSized:(NSSize)n	{
//	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
//		createWithWidth:round(n.width)
//		height:round(n.height)
//		pixelFormat:MTLPixelFormatRGB10A2Unorm
//		storage:MTLStorageModePrivate
//		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
//		bytesPerRow:0];
//	VVMTLTextureImage			*returnMe = [self textureForDescriptor:desc];
//	
//	return returnMe;
//}

- (id<VVMTLTextureImage>) uyvyBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	/*
		// ACCESS NOTES
	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		// modified CPU, need to push changes to GPU:
	[VVMTLTextureImage.buffer.buffer didModifyRange:XXX];
		// modified GPU, need to pull changes to CPU:
	[blitEncoder synchronizeResource::VVMTLTextureImage.buffer.buffer]
		// cmd buffer that owns the blit encoder must complete before data is valid!
	[self timestampThis:VVMTLTextureImage];
	void		*contents = (void *)[VVMTLTextureImage.buffer.buffer contents];
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
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:bpr];
	desc.mtlBufferBacking = YES;
	
	returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
	returnMe.buffer = backingBuffer;
	//returnMe.bytesPerRow = bpr;
	
	@synchronized (self)	{
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.preferDeletion = YES;
	[self timestampThis:returnMe];
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
//		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
//		bytesPerRow:0];
//	VVMTLTextureImage			*returnMe = [self textureForDescriptor:desc];
//	
//	return returnMe;
//}

- (id<VVMTLTextureImage>) rgbaHalfFloatTexSized:(NSSize)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatRGBA16Float
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
	return returnMe;
}

- (id<VVMTLTextureImage>) rgbaFloatTexSized:(NSSize)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatRGBA32Float
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
	return returnMe;
}

//- (id<VVMTLTextureImage>) rgbaFloatBufferBackedTexSized:(NSSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
//	/*
//		// ACCESS NOTES
//	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
//		// modified CPU, need to push changes to GPU:
//	[VVMTLTextureImage.buffer.buffer didModifyRange:XXX];
//		// modified GPU, need to pull changes to CPU:
//	[blitEncoder synchronizeResource::VVMTLTextureImage.buffer.buffer]
//		// cmd buffer that owns the blit encoder must complete before data is valid!
//	[self timestampThis:VVMTLTextureImage];
//	void		*contents = (void *)[VVMTLTextureImage.buffer.buffer contents];
//	*/
//	
//	returnMe.preferDeletion = YES;
//}

//- (id<VVMTLTextureImage>) rgbaBufferBackedFloatTexSized:(NSSize)n	{
//	/*
//		// ACCESS NOTES
//	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
//		// modified CPU, need to push changes to GPU:
//	[VVMTLTextureImage.buffer.buffer didModifyRange:XXX];
//		// modified GPU, need to pull changes to CPU:
//	[blitEncoder synchronizeResource::VVMTLTextureImage.buffer.buffer]
//		// cmd buffer that owns the blit encoder must complete before data is valid!
//	[self timestampThis:VVMTLTextureImage];
//	void		*contents = (void *)[VVMTLTextureImage.buffer.buffer contents];
//	*/
//	
//	returnMe.preferDeletion = YES;
//}

- (id<VVMTLTextureImage>) bufferBackedTexSized:(NSSize)s pixelFormat:(MTLPixelFormat)pfmt basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	/*
		// ACCESS NOTES
	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		// modified CPU, need to push changes to GPU:
	[VVMTLTextureImage.buffer.buffer didModifyRange:XXX];
		// modified GPU, need to pull changes to CPU:
	[blitEncoder synchronizeResource::VVMTLTextureImage.buffer.buffer]
		// cmd buffer that owns the blit encoder must complete before data is valid!
	[self timestampThis:VVMTLTextureImage];
	void		*contents = (void *)[VVMTLTextureImage.buffer.buffer contents];
	*/
	size_t				targetLength = bpr * s.height;
	if (targetLength % 4096 != 0)
		targetLength = 4096 - (targetLength % 4096) + targetLength;
	VVMTLBuffer			*backingBuffer = (VVMTLBuffer*)[self bufferWithLengthNoCopy:targetLength storage:MTLStorageModeManaged basePtr:b bufferDeallocator:d];
	if (backingBuffer == nil)	{
		NSLog(@"ERR: unable to make backing buffer in %s",__func__);
		return nil;
	}
	
	VVMTLTextureImage		*returnMe = nil;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(s.width)
		height:round(s.height)
		pixelFormat:pfmt
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:bpr];
	desc.mtlBufferBacking = YES;
	
	returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
	returnMe.buffer = backingBuffer;
	//returnMe.bytesPerRow = bpr;
	
	@synchronized (self)	{
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.preferDeletion = YES;
	[self timestampThis:returnMe];
	return returnMe;
}

- (id<VVMTLTextureImage>) bufferBackedTexSized:(NSSize)s pixelFormat:(MTLPixelFormat)pfmt basePtr:(void*)b bytesPerRow:(uint32_t)bpr	{
	/*
		// ACCESS NOTES
	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		// modified CPU, need to push changes to GPU:
	[VVMTLTextureImage.buffer.buffer didModifyRange:XXX];
		// modified GPU, need to pull changes to CPU:
	[blitEncoder synchronizeResource::VVMTLTextureImage.buffer.buffer]
		// cmd buffer that owns the blit encoder must complete before data is valid!
	[self timestampThis:VVMTLTextureImage];
	void		*contents = (void *)[VVMTLTextureImage.buffer.buffer contents];
	*/
	
	size_t				targetLength = bpr * s.height;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(s.width)
		height:round(s.height)
		pixelFormat:pfmt
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:bpr];
	desc.mtlBufferBacking = YES;
	
	//	if we can find a pre-existing buffer-backed texture, we don't have to allocate anything- just copy the data into it, synchronize the data, and return it
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self recycledObjectMatching:desc];
	if (returnMe != nil)	{
		//	copy the data into the passed buffer
		memcpy(returnMe.buffer.buffer.contents, b, targetLength);
		
		[returnMe.buffer.buffer didModifyRange:NSMakeRange(0,targetLength)];
		
		//	timestamp, and return
		[self timestampThis:returnMe];
		return returnMe;
	}
	
	//	...if we're here, we couldn't find an existing tex matching the description- we have to create one...
	
	VVMTLBuffer			*backingBuffer = (VVMTLBuffer*)[self bufferWithLength:targetLength storage:MTLStorageModeManaged basePtr:b];
	if (backingBuffer == nil)	{
		NSLog(@"ERR: unable to make backing buffer in %s",__func__);
		return nil;
	}
	
	//	copy the data into the passed buffer
	//memcpy(backingBuffer.buffer.contents, b, targetLength);
	
	returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
	returnMe.buffer = backingBuffer;
	//returnMe.bytesPerRow = bpr;
	
	@synchronized (self)	{
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	
	returnMe.preferDeletion = NO;
	[self timestampThis:returnMe];
	return returnMe;
}

- (id<VVMTLTextureImage>) bufferBackedTexSized:(NSSize)s pixelFormat:(MTLPixelFormat)pfmt bytesPerRow:(uint32_t)bpr	{
	/*
		// ACCESS NOTES
	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		// modified CPU, need to push changes to GPU:
	[VVMTLTextureImage.buffer.buffer didModifyRange:XXX];
		// modified GPU, need to pull changes to CPU:
	[blitEncoder synchronizeResource::VVMTLTextureImage.buffer.buffer]
		// cmd buffer that owns the blit encoder must complete before data is valid!
	[self timestampThis:VVMTLTextureImage];
	void		*contents = (void *)[VVMTLTextureImage.buffer.buffer contents];
	*/
	
	size_t			targetLength = bpr * s.height;
	if (targetLength % 4096 != 0)
		targetLength = 4096 - (targetLength % 4096) + targetLength;
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(s.width)
		height:round(s.height)
		pixelFormat:pfmt
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:bpr];
	desc.mtlBufferBacking = YES;
	
	//	if we can find a pre-existing buffer-backed texture, we don't have to allocate anything
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
	return returnMe;
}

- (id<VVMTLTextureImage>) textureForExistingTexture:(id<MTLTexture>)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:n.width
		height:n.height
		pixelFormat:n.pixelFormat
		storage:n.storageMode
		usage:n.usage
		bytesPerRow:0];
	
	VVMTLTextureImage			*returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
	returnMe.texture = n;
	returnMe.pool = self;
	returnMe.preferDeletion = YES;
	returnMe.descriptor = desc;
	return returnMe;
}

- (id<VVMTLTextureImage>) bgra8IOSurfaceBackedTexSized:(NSSize)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatBGRA8Unorm
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	desc.iosfcBacking = YES;
	desc.cvpbBacking = YES;
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	
	returnMe.preferDeletion = NO;
	[self timestampThis:returnMe];
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
//		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
//		bytesPerRow:0];
//	desc.iosfcBacking = YES;
//	desc.cvpbBacking = YES;
//	VVMTLTextureImage			*returnMe = [self textureForDescriptor:desc];
//	
//	return returnMe;
//}

//- (id<VVMTLTextureImage>) rgbaHalfFloatIOSurfaceBackedTexFromCVPB:(CVPixelBufferRef)inCVPB	{
//}

//- (id<VVMTLTextureImage>) uyvyIOSurfaceBackedTexSized:(NSSize)n	{
//}

- (id<VVMTLTextureImage>) lum8TexSized:(NSSize)n	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(n.width)
		height:round(n.height)
		pixelFormat:MTLPixelFormatR8Unorm
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
	return returnMe;
}
- (id<VVMTLTextureImage>) bufferBackedLum8TexSized:(NSSize)n	{
	/*
		// ACCESS NOTES
	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		// modified CPU, need to push changes to GPU:
	[VVMTLTextureImage.buffer.buffer didModifyRange:XXX];
		// modified GPU, need to pull changes to CPU:
	[blitEncoder synchronizeResource::VVMTLTextureImage.buffer.buffer]
		// cmd buffer that owns the blit encoder must complete before data is valid!
	[self timestampThis:VVMTLTextureImage];
	void		*contents = (void *)[VVMTLTextureImage.buffer.buffer contents];
	*/
	uint32_t		bytesPerRow = 8 * round(n.width) / 8;
	id<VVMTLTextureImage>		returnMe = [self
		bufferBackedTexSized:n
		pixelFormat:MTLPixelFormatR8Unorm
		bytesPerRow:bytesPerRow];
	return returnMe;
}

- (id<VVMTLTextureImage>) textureForCVMTLTex:(CVMetalTextureRef)inRef sized:(NSSize)inSize	{
	if (inRef == NULL)
		return nil;
	
	id<MTLTexture>		tmpTex = CVMetalTextureGetTexture(inRef);
	if (tmpTex == nil)
		return nil;
	
	id<VVMTLTextureImage>		returnMe = [self textureForExistingTexture:tmpTex];
	
	returnMe.preferDeletion = YES;
	returnMe.supportingContext = inRef;
	CVBufferRetain(inRef);
	returnMe.deletionBlock = ^(id<VVMTLRecycleable> recycled)	{
		CVMetalTextureRef		recast = (CVMetalTextureRef)recycled.supportingContext;
		CVBufferRelease(recast);
	};
	[self timestampThis:returnMe];
	return returnMe;
}

//- (id<VVMTLBuffer>) bufferButNoTexSized:(size_t)inBufferSize options:(MTLResourceOptions)inOpts	{
//	MTLStorageMode		storage = MTLStorageModeShared;
//	if (A_HAS_B(inOpts,MTLStorageModeShared))	{
//		storage = MTLStorageModeShared;
//	}
//	else if (A_HAS_B(inOpts,MTLStorageModeManaged))	{
//		storage = MTLStorageModeManaged;
//	}
//	else if (A_HAS_B(inOpts,MTLStorageModePrivate))	{
//		storage = MTLStorageModePrivate;
//	}
//	return [self bufferWithLength:inBufferSize storage:storage];
//}

- (id<VVMTLTextureImage>) createFromNSImage:(NSImage *)n	{
	if (n == nil)
		return nil;
	
	NSSize			tmpSize = n.size;
	NSRect			tmpRect = NSMakeRect(0,0,tmpSize.width,tmpSize.height);
	size_t			bytesPerRow = 8 * 4 * tmpSize.width;	//	bits per component * number of components * width
	
	void			*tmpBacking = malloc(bytesPerRow * tmpSize.height);
	
	//CGColorSpaceRef		tmpSpace = CGColorSpaceCreateWithName( kCGColorSpaceITUR_709 );
	CGColorSpaceRef		tmpSpace = RenderProperties.global.colorSpace;
	CGBitmapInfo		tmpBitmapInfo = (CGBitmapInfo)kCGImageAlphaNoneSkipFirst;
	CGContextRef		tmpCGCtx = CGBitmapContextCreate( tmpBacking, tmpSize.width, tmpSize.height, 8, bytesPerRow, tmpSpace, tmpBitmapInfo);
	
	MTKTextureLoader	*tmpLoader = [[MTKTextureLoader alloc] initWithDevice:[RenderProperties global].device];
	NSGraphicsContext	*tmpNSCtx = [NSGraphicsContext graphicsContextWithCGContext:tmpCGCtx flipped:NO];
	CGImageRef			tmpCGImg = (tmpNSCtx==nil) ? NULL : [n CGImageForProposedRect:&tmpRect context:tmpNSCtx hints:nil];
	
	NSError				*nsErr = nil;
	id<MTLTexture>		tmpTex = (tmpCGImg==NULL) ? nil : [tmpLoader newTextureWithCGImage:tmpCGImg options:@{ MTKTextureLoaderOptionSRGB: @(NO) } error:&nsErr];
	id<VVMTLTextureImage>		returnMe = (tmpTex==nil) ? nil : [self textureForExistingTexture:tmpTex];
	
	tmpNSCtx = nil;
	tmpLoader = nil;
	if (tmpCGCtx != NULL)
		CGContextRelease(tmpCGCtx);
	if (tmpSpace != NULL)
		CGColorSpaceRelease(tmpSpace);
	if (tmpBacking != NULL)
		free(tmpBacking);
	
	[self timestampThis:returnMe];
	
	return returnMe;
}

- (id<VVMTLTextureImage>) createFromNSBitmapImageRep:(NSBitmapImageRep *)n	{
	if (n == nil)
		return nil;
	/*
		// ACCESS NOTES
	id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		// modified CPU, need to push changes to GPU:
	[VVMTLTextureImage.buffer.buffer didModifyRange:XXX];
		// modified GPU, need to pull changes to CPU:
	[blitEncoder synchronizeResource::VVMTLTextureImage.buffer.buffer]
		// cmd buffer that owns the blit encoder must complete before data is valid!
	[self timestampThis:VVMTLTextureImage];
	void		*contents = (void *)[VVMTLTextureImage.buffer.buffer contents];
	*/
	
	
	//	this only works if the bitmap's underlying data ptr is 4096-byte aligned!
	//id<VVMTLTextureImage>		returnMe = [self
	//	bufferBackedTexSized:n.size
	//	pixelFormat:MTLPixelFormatRGBA8Unorm_sRGB
	//	basePtr:n.bitmapData
	//	bytesPerRow:(uint32_t)n.bytesPerRow
	//	bufferDeallocator:^(void *ptr, NSUInteger length)	{
	//		NSBitmapImageRep		*tmpRep = n;
	//		tmpRep = nil;
	//	}];
	
	
	uint32_t		imgDataBytesPerRow = (uint32_t)n.bytesPerRow;
	uint32_t		imgBytesPerRow = n.size.width * (1 * 4);
	MTLPixelFormat		dstPxlFmt = MTLPixelFormatRGBA8Unorm;
	//MTLPixelFormat		dstPxlFmt = MTLPixelFormatRGBA8Unorm_sRGB;
	NSUInteger		linearAlignment = [RenderProperties.global.device minimumLinearTextureAlignmentForPixelFormat:dstPxlFmt];
	uint32_t		bufferBytesPerRow = (uint32_t)ROUNDAUPTOMULTOFB(imgBytesPerRow,linearAlignment);
	NSSize			bitmapSize = n.size;
	
	id<VVMTLTextureImage>		returnMe = nil;
	
	if (imgDataBytesPerRow == bufferBytesPerRow)	{
		returnMe = [self
			bufferBackedTexSized:bitmapSize
			pixelFormat:dstPxlFmt
			basePtr:n.bitmapData
			bytesPerRow:bufferBytesPerRow];
	}
	else	{
		returnMe = [self
			bufferBackedTexSized:bitmapSize
			pixelFormat:dstPxlFmt
			bytesPerRow:bufferBytesPerRow];
		
		size_t		totalBytesToWrite = bufferBytesPerRow * bitmapSize.height;
		
		void		*rPtr = n.bitmapData;
		void		*wPtr = [returnMe.buffer.buffer contents];
		
		for (int i=0; i<bitmapSize.height; ++i)	{
			memcpy(wPtr, rPtr, imgBytesPerRow);
			rPtr += imgDataBytesPerRow;
			wPtr += bufferBytesPerRow;
		}
		
		[returnMe.buffer.buffer didModifyRange:NSMakeRange(0,totalBytesToWrite)];
	}
	
	returnMe.flipV = YES;
	
	return returnMe;
}

- (id<VVMTLTextureImage>) textureForIOSurface:(IOSurfaceRef)n	{
	if (n == NULL)
		return nil;
	
	MTLPixelFormat		targetPF = MTLPixelFormatBGRA8Unorm;
	OSType				fourCC = IOSurfaceGetPixelFormat(n);
	switch (fourCC)	{
	case kCVPixelFormatType_OneComponent8:
		targetPF = MTLPixelFormatR8Unorm;
		//targetPF = MTLPixelFormatR8Unorm_sRGB;
		break;
	case kCVPixelFormatType_TwoComponent8:
		targetPF = MTLPixelFormatRG8Unorm;
		//targetPF = MTLPixelFormatRG8Unorm_sRGB;
		break;
	case kCVPixelFormatType_32RGBA:
		targetPF = MTLPixelFormatRGBA8Unorm;
		//targetPF = MTLPixelFormatRGBA8Unorm_sRGB;
		break;
	case kCVPixelFormatType_32BGRA:
		targetPF = MTLPixelFormatBGRA8Unorm;
		//targetPF = MTLPixelFormatBGRA8Unorm_sRGB;
		break;
	case kCVPixelFormatType_422YpCbCr8:
		NSLog(@"ERR: YCbCr fourCC not supported here (%s)",__func__);
		return nil;
	//case 0x00:
	default:
		NSLog(@"ERR: unrecognized fourCC (%X) in %s",fourCC,__func__);
		return nil;
	}
	
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:IOSurfaceGetWidth(n)
		height:IOSurfaceGetHeight(n)
		pixelFormat:targetPF
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	desc.iosfcBacking = YES;
	
	VVMTLTextureImage		*returnMe = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
	returnMe.iosfc = n;
	returnMe.preferDeletion = YES;
	
	@synchronized (self)	{
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexImg:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	[self timestampThis:returnMe];
	return returnMe;
}


#pragma mark - LUT creation


- (id<VVMTLTextureLUT>) lutForDescriptor:(VVMTLTextureLUTDescriptor*)inDesc	{
	if (inDesc == nil)
		return nil;
	VVMTLTextureLUT		*returnMe = nil;
	@synchronized (self)	{
		returnMe = (VVMTLTextureLUT*)[self _recycledObjectMatching:inDesc];
		if (returnMe != nil)
			return returnMe;
		
		returnMe = [[VVMTLTextureLUT alloc] initWithDescriptor:inDesc];
		NSError			*nsErr = [self _generateMissingGPUAssetsInTexLUT:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	return returnMe;
}


- (id<VVMTLTextureLUT>) bufferBacked1DLUTSized:(MTLSize)n	{
	MTLSize			targetSize = MTLSizeMake(n.width, 1, 1);
	VVMTLTextureLUTDescriptor		*desc = [VVMTLTextureLUTDescriptor
		createWithOrder:1
		size:targetSize
		pixelFormat:MTLPixelFormatRGBA32Float
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead];
	
	VVMTLTextureLUT		*returnMe = (VVMTLTextureLUT*)[self lutForDescriptor:desc];
	return returnMe;
	
}
- (id<VVMTLTextureLUT>) bufferBacked2DLUTSized:(MTLSize)n	{
	MTLSize			targetSize = MTLSizeMake(n.width, n.height, 1);
	VVMTLTextureLUTDescriptor		*desc = [VVMTLTextureLUTDescriptor
		createWithOrder:2
		size:targetSize
		pixelFormat:MTLPixelFormatRGBA32Float
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead];
	
	VVMTLTextureLUT		*returnMe = (VVMTLTextureLUT*)[self lutForDescriptor:desc];
	return returnMe;
}
- (id<VVMTLTextureLUT>) bufferBacked3DLUTSized:(MTLSize)n	{
	MTLSize			targetSize = n;
	VVMTLTextureLUTDescriptor		*desc = [VVMTLTextureLUTDescriptor
		createWithOrder:3
		size:targetSize
		pixelFormat:MTLPixelFormatRGBA32Float
		storage:MTLStorageModeManaged
		usage:MTLTextureUsageShaderRead];
	
	VVMTLTextureLUT		*returnMe = (VVMTLTextureLUT*)[self lutForDescriptor:desc];
	return returnMe;
}


#pragma mark - buffer creation


- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage	{
	//NSLog(@"%s",__func__);
	if (inLength < 1)
		return nil;
	
	size_t			targetLength = inLength;
	if (inLength % 4096 == 0)	{
		targetLength = inLength;
	}
	else	{
		targetLength = 4096 - (inLength % 4096) + inLength;
	}
	
	VVMTLBuffer			*returnMe = nil;
	
	VVMTLBufferDescriptor		*desc = [VVMTLBufferDescriptor createWithLength:targetLength storage:inStorage];
	
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
	
	returnMe.preferDeletion = NO;
	[self timestampThis:returnMe];
	return returnMe;
}
//	copies the data from the passed ptr into a new buffer.  safe to delete the passed ptr when this returns.
- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage basePtr:(nullable void*)b	{
	//NSLog(@"%s",__func__);
	
	if (inLength < 1)
		return nil;
	
	size_t			targetLength = inLength;
	//if (inLength % 4096 == 0)	{
	//	targetLength = inLength;
	//}
	//else	{
	//	targetLength = 4096 - (inLength % 4096) + inLength;
	//}
	
	VVMTLBufferDescriptor		*desc = [VVMTLBufferDescriptor createWithLength:targetLength storage:inStorage];
	VVMTLBuffer			*returnMe = nil;
	@synchronized (self)	{
		returnMe = (VVMTLBuffer*)[self _recycledObjectMatching:desc];
		//	if we found a recycled object that matches our specs...
		if (returnMe != nil)	{
			//	if the base ptr is non-nil, copy the data do the buffer- make no attempt to synchronize it (this should be done deterministically on a specific command buffer)
			if (b != NULL)	{
				id<MTLBuffer>		mtlBuffer = returnMe.buffer;
				memcpy( mtlBuffer.contents, b, inLength );
				if (desc.storage == MTLStorageModeManaged)	{
					[mtlBuffer didModifyRange:NSMakeRange(0, inLength)];
				}
			}
		}
		//	else we didn't find a recycled object that matches our specs- create one!
		else	{
			MTLResourceOptions		resourceStorageMode = MTLResourceStorageModeForMTLStorageMode(inStorage);
			id<MTLBuffer>		mtlBuffer = nil;
			if (b == NULL)	{
				mtlBuffer = [self.device newBufferWithLength:targetLength options:resourceStorageMode];
			}
			else	{
				mtlBuffer = [self.device newBufferWithBytes:b length:targetLength options:resourceStorageMode];
			}
			
			returnMe = [[VVMTLBuffer alloc] initWithDescriptor:desc];
			returnMe.buffer = mtlBuffer;
			returnMe.pool = self;
			returnMe.preferDeletion = NO;
		}
	}
	[self timestampThis:returnMe];
	return returnMe;
}
//	the MTLBuffer returned by this will be backed by the passed ptr, and modifying the MTLBuffer will modify its backing.
- (id<VVMTLBuffer>) bufferWithLengthNoCopy:(size_t)inLength storage:(MTLStorageMode)inStorage basePtr:(nullable void*)b bufferDeallocator:(nullable void (^)(void *pointer, NSUInteger length))d	{
	//NSLog(@"%s",__func__);
	if (b == nil)	{
		NSLog(@"ERR: nil prtr, %s",__func__);
		return nil;
	}
	size_t			targetLength = inLength;
	
	//size_t			pageSize = getpagesize();	//	WARNING: if you do these calculations here you may wind up copying more data from the read ptr than you're allowed to.
	//size_t			pageSizeRemainder = inLength % pageSize;
	//if (pageSizeRemainder != 0)
	//	targetLength += (pageSize - pageSizeRemainder);
	
	//size_t			pageSize = getpagesize();	//	WARNING: if you do these calculations here you may wind up copying more data from the read ptr than you're allowed to.
	//if (inLength % pageSize == 0)	{
	//	targetLength = inLength;
	//}
	//else	{
	//	targetLength = pageSize - (inLength % pageSize) + inLength;
	//}
	
	VVMTLBufferDescriptor		*desc = [VVMTLBufferDescriptor createWithLength:targetLength storage:inStorage];
	
	MTLResourceOptions		resourceStorageMode = MTLResourceStorageModeForMTLStorageMode(inStorage);
	VVMTLBuffer		*returnMe = [[VVMTLBuffer alloc] init];
	returnMe.pool = self;
	returnMe.descriptor = desc;
	returnMe.preferDeletion = YES;
	returnMe.buffer = [self.device
		newBufferWithBytesNoCopy:b
		length:targetLength
		options:resourceStorageMode
		deallocator:d];
	[self timestampThis:returnMe];
	return returnMe;
}


#pragma mark - backend


- (void) _labelTexture:(id<VVMTLTextureImage>)n	{
	if (n == nil)
		return;
	//os_unfair_lock_lock(&TEXINDEXLOCK);
	
	VVMTLTextureImageDescriptor		*desc = (VVMTLTextureImageDescriptor*)n.descriptor;
	NSString		*tmpString = [NSString
		stringWithFormat:@"%@ (%ld) %ldx%ld %d.%d.%d %d",
		NSStringFromMTLPixelFormat(desc.pfmt),
		(unsigned long)TEXINDEX,
		(unsigned long)desc.width,
		(unsigned long)desc.height,
		desc.mtlBufferBacking,
		desc.iosfcBacking,
		desc.cvpbBacking,
		n.flipV];
	n.texture.label = tmpString;
	++TEXINDEX;
	
	//os_unfair_lock_unlock(&TEXINDEXLOCK);
}


- (NSError *) _generateMissingGPUAssetsInTexImg:(VVMTLTextureImage *)n	{
	if (n == nil)
		return nil;
	
	n.pool = self;
	
	VVMTLTextureImageDescriptor		*desc = (VVMTLTextureImageDescriptor *)n.descriptor;
	//	if we couldn't find a pixel format, bail immediately
	MTLPixelFormat		descPixelFormat = desc.pfmt;
	OSType			cvPixelFormat = BestGuessCVPixelFormatTypeForMTLPixelFormat(descPixelFormat);
	if (cvPixelFormat == 0x00)	{
		//	...sometimes, it's okay if we can't figure out a CoreVideo pixel format for the metal texture format- these are the exceptions:
		switch (descPixelFormat)	{
		case MTLPixelFormatBC1_RGBA:
		case MTLPixelFormatBC3_RGBA:
		case MTLPixelFormatBC4_RUnorm:
		case MTLPixelFormatBC7_RGBAUnorm:
		case MTLPixelFormatBC6H_RGBUfloat:
		case MTLPixelFormatBC6H_RGBFloat:
			//	intentionally blank- do nothing, these pixel formats are "okay"
			break;
		default:
			return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"No pixel format found for %X",(uint32_t)desc.pfmt] }];
			break;
		}
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
	
	//	if the descriptor doesn't have a bytes per row, calculate the bytes per row based on the pixel format and dimensions
	size_t			bytesPerRow = desc.bytesPerRow;
	if (bytesPerRow == 0)	{
		NSSize			adjustedImgSize = size;
		bytesPerRow = BytesPerRowFromMTLPixelFormatAndSize(desc.pfmt, &adjustedImgSize);
		desc.bytesPerRow = bytesPerRow;
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
		desc.bytesPerRow = bytesPerRow;
	}
	
	//	if the descriptor indicates that we need an IOSurfaceRef as a backing, but we don't have one yet...
	if (iosfcBacking && iosfc == NULL)	{
		if (cvpb != NULL)	{
			iosfc = CVPixelBufferGetIOSurface(cvpb);	//	note: the returned IOSurfaceRef is NOT retained!
			if (iosfc == NULL)	{
				return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"problem while creating iosfc from cvpb" }];
			}
		}
		else	{
			//CFDictionaryRef		sfcDict = (__bridge CFDictionaryRef)@{
			//	(NSString*)kIOSurfaceWidth: @( desc.width ),
			//	(NSString*)kIOSurfaceHeight: @( desc.height ),
			//	(NSString*)kIOSurfaceBytesPerRow: @( bytesPerRow ),
			//	//IOSurfacePropertyKeyElementWidth: @( 1 ),
			//	//IOSurfacePropertyKeyElementHeight: @( 1 ),
			//	(NSString*)kIOSurfacePixelFormat: @( cvPixelFormat ),
			//};
			//iosfc = IOSurfaceCreate(sfcDict);
			
			return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"can't make iosfc from scratch" }];
		}
		
		n.iosfc = iosfc;
		
		bytesPerRow = IOSurfaceGetBytesPerRow(iosfc);
		desc.bytesPerRow = bytesPerRow;
	}
	
	//	if the descriptor indicates that we need a MTLBuffer (via id<VVMTLBuffer>) as a backing, but we don't have one yet...
	if (mtlBufferBacking && buffer == nil)	{
		size_t			targetBufferLength = bytesPerRow * size.height;
		buffer = [self bufferWithLength:targetBufferLength storage:desc.storage];
		n.buffer = buffer;
	}
	
	//	...okay, so at this point if we need a backing, we should have already created it- now we need to create a texture.
	
	if (texture == nil)	{
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
			texture = [buffer.buffer newTextureWithDescriptor:texDesc offset:0 bytesPerRow:bytesPerRow];
			n.texture = texture;
			[self _labelTexture:n];
		}
		//	else if there's an IOSurface we want to use to back the texture...
		else if (iosfc != NULL)	{
			texture = [_device newTextureWithDescriptor:texDesc iosurface:iosfc plane:0];
			n.texture = texture;
			[self _labelTexture:n];
		}
		//	else it's just a plain ol' texture
		else	{
			
			texture = [_device newTextureWithDescriptor:texDesc];
			n.texture = texture;
			[self _labelTexture:n];
		}
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
- (NSError *) _generateMissingGPUAssetsInTexLUT:(VVMTLTextureLUT *)n	{
	if (n == nil)
		return nil;
	
	n.pool = self;
	
	VVMTLTextureLUTDescriptor		*desc = (VVMTLTextureLUTDescriptor *)n.descriptor;
	
	//	local copies of vars to simplify access
	id<MTLTexture>			texture = n.texture;
	id<VVMTLBuffer>			buffer = n.buffer;
	
	uint8_t			order = desc.order;
	MTLSize			size = desc.size;
	BOOL			mtlBufferBacking = desc.mtlBufferBacking;
	
	size_t			bytesPerRow = size.width * 8 * 4 / 8;
	if (bytesPerRow == 0)	{
		switch (desc.pfmt)	{
		case MTLPixelFormatR8Unorm:	//	??
			bytesPerRow = size.width * 8 * 1 / 8;
			break;
		
		case MTLPixelFormatRG8Unorm:
			bytesPerRow = size.width * 8 * 2 / 8;
			break;
		
		//case MTLPixelFormatBGRG422:	//	BM stuff
		//	bytesPerRow = size.width * 8 * 2 / 8;
		//	break;
		//case MTLPixelFormatGBGR422:	//	BM stuff
		//	bytesPerRow = size.width * 8 * 2 / 8;
		//	break;
		case MTLPixelFormatRGBA8Unorm:
		case MTLPixelFormatRGBA8Unorm_sRGB:
			bytesPerRow = size.width * 8 * 4 / 8;
			break;
		case MTLPixelFormatBGRA8Unorm:
		case MTLPixelFormatBGRA8Unorm_sRGB:
			bytesPerRow = size.width * 8 * 4 / 8;
			break;
		
		case MTLPixelFormatRGBA32Float:
			bytesPerRow = size.width * 32 * 4 / 8;
			break;
		
		case MTLPixelFormatRGB10A2Uint:	//	BM stuff
			bytesPerRow = size.width * 32 / 8;
			break;
		case MTLPixelFormatRGB10A2Unorm:	//	not used?
			bytesPerRow = size.width * 32 / 8;
			break;
		
		case MTLPixelFormatRGBA16Uint:
			bytesPerRow = size.width * 16 * 4 / 8;
			break;
		default:
			//	intentionally blank
			break;
		}
	}
	
	//	if the descriptor indicates that we need a MTLBuffer (via id<VVMTLBuffer>) as a backing, but we don't have one yet...
	if (mtlBufferBacking && buffer == nil)	{
		size_t			targetBufferLength = bytesPerRow;
		if (order >=2)
			targetBufferLength *= size.height;
		if (order >= 3)
			targetBufferLength *= size.depth;
		buffer = [self bufferWithLength:targetBufferLength storage:desc.storage];
		n.buffer = buffer;
	}
	
	//	...okay, so at this point if we need a backing, we should have already created it- now we need to create a texture.
	
	if (texture == nil)	{
		MTLTextureDescriptor		*texDesc = [[MTLTextureDescriptor alloc] init];
		switch (desc.order)	{
		case 1:		texDesc.textureType = MTLTextureType1D;		break;
		case 2:		texDesc.textureType = MTLTextureType2D;		break;
		case 3:		texDesc.textureType = MTLTextureType3D;		break;
		default:	break;
		}
		texDesc.pixelFormat = desc.pfmt;
		texDesc.width = size.width;
		texDesc.height = size.height;
		texDesc.depth = size.depth;
		texDesc.storageMode = desc.storage;
		texDesc.resourceOptions = MTLResourceStorageModeForMTLStorageMode(desc.storage);
		texDesc.usage = desc.usage;
		
		//	if there's an id<VVMTLBuffer> we want to use to back the texture...
		if (buffer != nil)	{
			texture = [buffer.buffer newTextureWithDescriptor:texDesc offset:0 bytesPerRow:bytesPerRow];
			//[self _labelTexture:texture];
			n.texture = texture;
		}
		//	else it's just a plain ol' texture
		else	{
			texture = [_device newTextureWithDescriptor:texDesc];
			//[self _labelTexture:texture];
			
			n.texture = texture;
		}
	}
	
	
	return nil;
}


@end

