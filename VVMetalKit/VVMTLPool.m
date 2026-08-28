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

#import "VVMTLSurfaceImage.h"
#import "VVMTLSurfaceImageDescriptor.h"




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
	NSMutableArray<id<VVMTLRecycleable>>		*_surfacePool;	//	FIFO
	CVMetalTextureCacheRef		_cvTexCache;
	CMClockRef			_clock;
	id<VVMTLTextureImage>		_emptyBlackTexture;
	//	Self-tick timer that calls -housekeeping every 500ms regardless
	//	of render activity. Without it, non-EVERYFRAME modules that go
	//	idle (e.g. hello-world parked behind requestRedraw) leave the
	//	recycle bins full forever — a quick resize-driven texture churn
	//	pins big-size textures in the pool until the next manual
	//	housekeeping call. See -_startHousekeepingTimer.
	dispatch_source_t	_housekeepingTimer;
}
@property (readwrite) BOOL supportsMemoryless;
@property (readwrite) BOOL supportsTileShaders;
//	really returns a VVMTLTextureImage or VVMTLBuffer, because that's what this class creates & vends
- (id<VVMTLRecycleable>) _recycledObjectMatching:(id<VVMTLRecycleableDescriptor>)n;
- (void) _labelTexture:(id<VVMTLTextureImage>)n;
- (NSError *) _generateMissingGPUAssetsInTexImg:(VVMTLTextureImage *)n;
- (NSError *) _generateMissingGPUAssetsInBuffer:(VVMTLBuffer *)n;
- (NSError *) _generateMissingGPUAssetsInTexLUT:(VVMTLTextureLUT *)n;
- (NSError *) _generateMissingGPUAssetsInSurfaceImage:(VVMTLSurfaceImage *)n;
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
		_surfacePool = [[NSMutableArray alloc] init];
		_supportsMemoryless = ([_device supportsFamily:MTLGPUFamilyApple8] || [_device supportsFamily:MTLGPUFamilyApple7]);
		_supportsTileShaders = ([_device supportsFamily:MTLGPUFamilyApple4]);
		
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
		
		//	create the empty black texture by generating a new texture (guaranteed to be empty black as long as it's not recycled)
		VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
			createWithWidth:8
			height:8
			pixelFormat:MTLPixelFormatBGRA8Unorm
			storage:MTLStorageModePrivate
			usage:MTLTextureUsageShaderRead
			bytesPerRow:0];
		_emptyBlackTexture = [[VVMTLTextureImage alloc] initWithDescriptor:desc];
		NSError		*nsErr = [self _generateMissingGPUAssetsInTexImg:(VVMTLTextureImage*)_emptyBlackTexture];
		if (nsErr != nil)	{
			NSLog(@"ERR: (%@) in %s",nsErr,__func__);
		}
		[self _startHousekeepingTimer];
	}

	return self;
}

- (void) dealloc	{
	if (_housekeepingTimer != nil)	{
		dispatch_source_cancel(_housekeepingTimer);
		_housekeepingTimer = nil;
	}
}

//	Internal 250ms self-tick on a utility-QoS queue. The pool's
//	-housekeeping is @synchronized(self), so it composes safely with
//	external per-frame callers; double-bumps just speed eviction. The
//	timer is created suspended (dispatch_source default) and resumed
//	immediately so it starts firing the first interval after init.
//	At 250ms × MAX_MTLTEXTUREIMAGE_LIFETIME (30), idle items drain
//	in ~7.5s — slow enough to avoid evicting items mid-resize, fast
//	enough that non-EVERYFRAME modules don't leave the pool full for
//	a noticeable wait after a resize storm.
- (void) _startHousekeepingTimer	{
	dispatch_queue_t q = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
	_housekeepingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
	if (_housekeepingTimer == nil) return;
	uint64_t intervalNs = 250ull * NSEC_PER_MSEC;
	dispatch_source_set_timer(_housekeepingTimer,
		dispatch_time(DISPATCH_TIME_NOW, (int64_t)intervalNs),
		intervalNs,
		25ull * NSEC_PER_MSEC);     //	leeway: timer coalescing is fine here
	__weak typeof(self) weakSelf = self;
	dispatch_source_set_event_handler(_housekeepingTimer, ^{
		typeof(self) strongSelf = weakSelf;
		if (strongSelf != nil) [strongSelf housekeeping];
	});
	dispatch_resume(_housekeepingTimer);
}

- (CVMetalTextureCacheRef) cvTexCache	{
	return _cvTexCache;
}
- (id<VVMTLTextureImage>) emptyBlackTexture	{
	return _emptyBlackTexture;
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
		else if ([(NSObject*)n isVVMTLSurfaceImage])	{
			[_surfacePool insertObject:n atIndex:0];
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
	else if ([(NSObject*)n isVVMTLSurfaceImageDescriptor])	{
		for (id<VVMTLRecycleable> pooledObject in _surfacePool)	{
			if ([n matchForRecycling:pooledObject.descriptor])	{
				returnMe = pooledObject;
				[_surfacePool removeObjectAtIndex:tmpIndex];
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
		NSArray<NSMutableArray*>		*pools = @[ _texPool, _bufferPool, _lutPool, _surfacePool ];
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


//	Short labels for the most common MTLPixelFormat values. Falls back
//	to the numeric value for anything unrecognized so the snapshot still
//	carries useful info even for exotic formats.
static NSString * VVMTLPoolPixelFormatName(MTLPixelFormat pfmt)	{
	switch (pfmt)	{
		case MTLPixelFormatBGRA8Unorm:        return @"BGRA8";
		case MTLPixelFormatBGRA8Unorm_sRGB:   return @"BGRA8_sRGB";
		case MTLPixelFormatRGBA8Unorm:        return @"RGBA8";
		case MTLPixelFormatRGBA8Unorm_sRGB:   return @"RGBA8_sRGB";
		case MTLPixelFormatRGBA16Float:       return @"RGBA16F";
		case MTLPixelFormatRGBA32Float:       return @"RGBA32F";
		case MTLPixelFormatRGB10A2Unorm:      return @"RGB10A2";
		case MTLPixelFormatR8Unorm:           return @"R8";
		case MTLPixelFormatDepth32Float:      return @"Depth32F";
		case MTLPixelFormatStencil8:          return @"Stencil8";
		case MTLPixelFormatDepth32Float_Stencil8: return @"D32F_S8";
		default:                              return [NSString stringWithFormat:@"fmt%lu", (unsigned long)pfmt];
	}
}

- (NSDictionary *) poolSnapshot	{
	NSMutableArray<NSDictionary*>	*texRows = [NSMutableArray array];
	NSMutableArray<NSDictionary*>	*bufRows = [NSMutableArray array];
	NSMutableArray<NSDictionary*>	*lutRows = [NSMutableArray array];
	@synchronized (self)	{
		//	Textures: bytes = bytesPerRow * height * max(1, sampleCount).
		//	bytesPerRow is computed lazily on the descriptor (0 means
		//	"not yet derived"); use the same VVMTLUtilities helper the
		//	pool itself uses internally to keep numbers consistent.
		for (id<VVMTLRecycleable> obj in _texPool)	{
			id<VVMTLRecycleableDescriptor> d = obj.descriptor;
			if (![(NSObject*)d isVVMTLTextureImageDescriptor]) continue;
			VVMTLTextureImageDescriptor	*td = (VVMTLTextureImageDescriptor*)d;
			NSSize sz = NSMakeSize((CGFloat)td.width, (CGFloat)td.height);
			size_t bpr = td.bytesPerRow;
			if (bpr == 0)	{
				bpr = BytesPerRowFromMTLPixelFormatAndSize(td.pfmt, &sz);
			}
			NSUInteger samples = (td.sampleCount > 0) ? (NSUInteger)td.sampleCount : 1u;
			uint64_t bytes = (uint64_t)bpr * (uint64_t)td.height * (uint64_t)samples;
			NSString *label = [NSString stringWithFormat:@"%lu × %lu %@",
				(unsigned long)td.width,
				(unsigned long)td.height,
				VVMTLPoolPixelFormatName(td.pfmt)];
			if (samples > 1)	{
				label = [label stringByAppendingFormat:@" × %luMSAA", (unsigned long)samples];
			}
			[texRows addObject:@{
				@"label": label,
				@"bytes": @(bytes),
				@"age":   @(obj.recycleCount),
			}];
		}
		//	Buffers: bytes = descriptor.length.
		for (id<VVMTLRecycleable> obj in _bufferPool)	{
			id<VVMTLRecycleableDescriptor> d = obj.descriptor;
			if (![(NSObject*)d isVVMTLBufferDescriptor]) continue;
			VVMTLBufferDescriptor *bd = (VVMTLBufferDescriptor*)d;
			NSString *label = [NSString stringWithFormat:@"MTLBuffer %lu B", (unsigned long)bd.length];
			[bufRows addObject:@{
				@"label": label,
				@"bytes": @((uint64_t)bd.length),
				@"age":   @(obj.recycleCount),
			}];
		}
		//	LUTs: bytes unknown without poking the LUT descriptor's
		//	type-specific size; report 0 and let the label carry the
		//	identity so the user at least sees they exist.
		for (id<VVMTLRecycleable> obj in _lutPool)	{
			NSString *label = [NSString stringWithFormat:@"LUT %@", NSStringFromClass([(NSObject*)obj.descriptor class])];
			[lutRows addObject:@{
				@"label": label,
				@"bytes": @(0ULL),
				@"age":   @(obj.recycleCount),
			}];
		}
	}
	return @{
		@"textures": texRows,
		@"buffers":  bufRows,
		@"luts":     lutRows,
	};
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
	if (inDesc.width <= 0 || inDesc.height <= 0)
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


- (id<VVMTLTextureImage>) bgra8TexSized:(NSSize)inSize	{
	VVMTLTextureImageDescriptor		*desc = [VVMTLTextureImageDescriptor
		createWithWidth:round(inSize.width)
		height:round(inSize.height)
		pixelFormat:MTLPixelFormatBGRA8Unorm
		storage:MTLStorageModePrivate
		usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
		bytesPerRow:0];
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
	return returnMe;
}
- (id<VVMTLTextureImage>) bgra8TexSized:(NSSize)inSize sampleCount:(NSUInteger)inSampleCount	{
	VVMTLTextureImageDescriptor		*desc = nil;
	if (inSampleCount>1 && _supportsMemoryless)	{
		desc = [VVMTLTextureImageDescriptor
			createWithWidth:round(inSize.width)
			height:round(inSize.height)
			pixelFormat:MTLPixelFormatBGRA8Unorm
			//storage:MTLStorageModePrivate
			storage:MTLStorageModeMemoryless
			//usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
			usage:MTLTextureUsageRenderTarget
			bytesPerRow:0];
		desc.textureType = (inSampleCount<=1) ? MTLTextureType2D : MTLTextureType2DMultisample;
		desc.sampleCount = inSampleCount;
	}
	else	{
		desc = [VVMTLTextureImageDescriptor
			createWithWidth:round(inSize.width)
			height:round(inSize.height)
			pixelFormat:MTLPixelFormatBGRA8Unorm
			storage:MTLStorageModePrivate
			//usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
			usage:MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead
			bytesPerRow:0];
		desc.textureType = (inSampleCount<=1) ? MTLTextureType2D : MTLTextureType2DMultisample;
		desc.sampleCount = inSampleCount;
	}
	
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
- (id<VVMTLTextureImage>) rgbaFloatTexSized:(NSSize)n sampleCount:(NSUInteger)inSampleCount	{
	VVMTLTextureImageDescriptor		*desc = nil;
	if (inSampleCount>1 && _supportsMemoryless)	{
		desc = [VVMTLTextureImageDescriptor
			createWithWidth:round(n.width)
			height:round(n.height)
			pixelFormat:MTLPixelFormatRGBA32Float
			//storage:MTLStorageModePrivate
			storage:MTLStorageModeMemoryless
			//usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
			usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget
			bytesPerRow:0];
		desc.textureType = (inSampleCount<=1) ? MTLTextureType2D : MTLTextureType2DMultisample;
		desc.sampleCount = inSampleCount;
	}
	else	{
		desc = [VVMTLTextureImageDescriptor
			createWithWidth:round(n.width)
			height:round(n.height)
			pixelFormat:MTLPixelFormatRGBA32Float
			storage:MTLStorageModePrivate
			//usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
			usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget
			bytesPerRow:0];
		desc.textureType = (inSampleCount<=1) ? MTLTextureType2D : MTLTextureType2DMultisample;
		desc.sampleCount = inSampleCount;
	}
	
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
	if (n == nil)
		return nil;
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

- (id<VVMTLTextureImage>) depthTexSized:(NSSize)n	{
	return [self depthTexSized:n sampleCount:1];
}
- (id<VVMTLTextureImage>) depthTexSized:(NSSize)n sampleCount:(NSUInteger)inSampleCount	{
	VVMTLTextureImageDescriptor		*desc = nil;
	if (_supportsMemoryless)	{
		desc = [VVMTLTextureImageDescriptor
			createWithWidth:round(n.width)
			height:round(n.height)
			pixelFormat:MTLPixelFormatDepth32Float
			//pixelFormat:MTLPixelFormatDepth32Float_Stencil8
			//storage:MTLStorageModePrivate
			storage:MTLStorageModeMemoryless
			//usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
			usage:MTLTextureUsageRenderTarget
			bytesPerRow:0];
		desc.textureType = (inSampleCount<=1) ? MTLTextureType2D : MTLTextureType2DMultisample;
		desc.sampleCount = inSampleCount;
	}
	else	{
		desc = [VVMTLTextureImageDescriptor
			createWithWidth:round(n.width)
			height:round(n.height)
			pixelFormat:MTLPixelFormatDepth32Float
			storage:MTLStorageModePrivate
			//usage:MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite
			usage:MTLTextureUsageRenderTarget
			bytesPerRow:0];
		desc.textureType = (inSampleCount<=1) ? MTLTextureType2D : MTLTextureType2DMultisample;
		desc.sampleCount = inSampleCount;
	}
	
	VVMTLTextureImage			*returnMe = (VVMTLTextureImage*)[self textureForDescriptor:desc];
	[self timestampThis:returnMe];
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
	if (tmpSpace != NULL)
		CGColorSpaceRetain(tmpSpace);
	CGBitmapInfo		tmpBitmapInfo = (CGBitmapInfo)kCGImageAlphaNoneSkipFirst;
	CGContextRef		tmpCGCtx = CGBitmapContextCreate( tmpBacking, tmpSize.width, tmpSize.height, 8, bytesPerRow, tmpSpace, tmpBitmapInfo);
	
	MTKTextureLoader	*tmpLoader = [[MTKTextureLoader alloc] initWithDevice:[RenderProperties global].device];
	NSGraphicsContext	*tmpNSCtx = [NSGraphicsContext graphicsContextWithCGContext:tmpCGCtx flipped:NO];
	CGImageRef			tmpCGImg = (tmpNSCtx==nil) ? NULL : [n CGImageForProposedRect:&tmpRect context:tmpNSCtx hints:nil];
	
	
	
	/*
	NSError				*nsErr = nil;
	id<MTLTexture>		tmpTex = (tmpCGImg==NULL) ? nil : [tmpLoader newTextureWithCGImage:tmpCGImg options:@{ MTKTextureLoaderOptionSRGB: @(NO) } error:&nsErr];
	id<VVMTLTextureImage>		returnMe = (tmpTex==nil) ? nil : [self textureForExistingTexture:tmpTex];
	*/
	id<VVMTLTextureImage>		returnMe = CreateTextureFromCGImage(tmpCGImg);
	
	
	
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
	if (inDesc.size.width <= 0 || inDesc.size.height <= 0 || inDesc.size.depth <= 0)
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


#pragma mark - surface image creation


- (id<VVMTLSurfaceImage>) surfaceImageForDescriptor:(VVMTLSurfaceImageDescriptor*)inDesc	{
	if (inDesc == nil)
		return nil;
	if (inDesc.width <= 0 || inDesc.height <= 0)
		return nil;
	VVMTLSurfaceImage		*returnMe = nil;
	@synchronized (self)	{
		returnMe = (VVMTLSurfaceImage*)[self _recycledObjectMatching:inDesc];
		//	recycled match- no CVPixelBufferCreate, the asset already carries its surface/buffer/geometry
		if (returnMe != nil)	{
			[self timestampThis:returnMe];
			return returnMe;
		}

		returnMe = [[VVMTLSurfaceImage alloc] initWithDescriptor:inDesc];
		NSError			*nsErr = [self _generateMissingGPUAssetsInSurfaceImage:returnMe];
		if (nsErr != nil)	{
			NSLog(@"ERR (%@) in %s",nsErr,__func__);
			return nil;
		}
	}
	[self timestampThis:returnMe];
	return returnMe;
}


- (id<VVMTLSurfaceImage>) ycbcr420fSurfaceImageSized:(NSSize)n	{
	VVMTLSurfaceImageDescriptor		*desc = [VVMTLSurfaceImageDescriptor
		createWithWidth:(NSUInteger)round(n.width)
		height:(NSUInteger)round(n.height)
		cvPixelFormat:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
		storage:MTLStorageModeShared];
	return [self surfaceImageForDescriptor:desc];
}
- (id<VVMTLSurfaceImage>) ycbcr420vSurfaceImageSized:(NSSize)n	{
	VVMTLSurfaceImageDescriptor		*desc = [VVMTLSurfaceImageDescriptor
		createWithWidth:(NSUInteger)round(n.width)
		height:(NSUInteger)round(n.height)
		cvPixelFormat:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
		storage:MTLStorageModeShared];
	return [self surfaceImageForDescriptor:desc];
}


#pragma mark - buffer creation


- (id<VVMTLBuffer>) bufferWithLength:(size_t)inLength storage:(MTLStorageMode)inStorage	{
	//NSLog(@"%s ... %ld",__func__,inLength);
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
	//	no-copy buffer creation fails if 'b' isn't page-aligned- return nil instead of a wrapper with a nil buffer
	if (returnMe.buffer == nil)	{
		NSLog(@"ERR: unable to make no-copy buffer (%ld bytes, basePtr %p) in %s",targetLength,b,__func__);
		return nil;
	}
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
		case MTLPixelFormatDepth32Float_Stencil8:
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
	if (round(size.width)==0 || round(size.height)==0)	{
		return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid dimensions (%d x %d)",(int)round(size.width),(int)round(size.height)] }];
	}
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
		
		bytesPerRow = CVPixelBufferGetBytesPerRow(cvpb);
		desc.bytesPerRow = bytesPerRow;
		
		CVPixelBufferRelease(cvpb);
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
		NSUInteger		alignment = [self.device minimumLinearTextureAlignmentForPixelFormat:descPixelFormat];
		bytesPerRow = ROUNDAUPTOMULTOFB(bytesPerRow, alignment);
		size_t			targetBufferLength = bytesPerRow * size.height;
		buffer = [self bufferWithLength:targetBufferLength storage:desc.storage];
		n.buffer = buffer;
	}
	
	//	...okay, so at this point if we need a backing, we should have already created it- now we need to create a texture.
	
	if (texture == nil)	{
		MTLTextureDescriptor		*texDesc = [[MTLTextureDescriptor alloc] init];
		texDesc.textureType = desc.textureType;
		texDesc.sampleCount = desc.sampleCount;
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

	//	if we still don't have a texture, creation failed- return an error so callers vend nil instead of a texture-less image.
	//	mark the failed image for deletion, or its dealloc will recycle a texture-less copy back into the pool (which vends recycled objects as-is)
	if (n.texture == nil)	{
		n.preferDeletion = YES;
		return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"unable to create texture (%dx%d, fmt %X, bpr %d, backing %d.%d.%d)",(int)desc.width,(int)desc.height,(uint32_t)desc.pfmt,(int)bytesPerRow,desc.mtlBufferBacking,desc.iosfcBacking,desc.cvpbBacking] }];
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

	if (buffer == nil)	{
		n.preferDeletion = YES;
		return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"unable to create buffer (%ld bytes)",(unsigned long)desc.length] }];
	}

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
	if (round(size.width)==0 || round(size.height)==0 || round(size.depth)==0)	{
		return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid dimensions (%d x %d x %d)",(int)round(size.width),(int)round(size.height),(int)round(size.depth)] }];
	}
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
- (NSError *) _generateMissingGPUAssetsInSurfaceImage:(VVMTLSurfaceImage *)n	{
	if (n == nil)
		return nil;

	n.pool = self;

	//	if it already has its backing (e.g. a recycled asset), we're done
	if (n.cvpb != NULL && n.wholeSurfaceBuffer != nil)
		return nil;

	VVMTLSurfaceImageDescriptor		*desc = (VVMTLSurfaceImageDescriptor *)n.descriptor;
	NSUInteger		descWidth = desc.width;
	NSUInteger		descHeight = desc.height;
	OSType			cvPixelFormat = desc.cvPixelFormat;
	if (descWidth == 0 || descHeight == 0)	{
		return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid dimensions (%ld x %ld)",(unsigned long)descWidth,(unsigned long)descHeight] }];
	}

	//	create the IOSurface-backed CVPixelBuffer
	CVPixelBufferRef		cvpb = NULL;
	CVReturn		cvErr = CVPixelBufferCreate(
		kCFAllocatorDefault,
		descWidth,
		descHeight,
		cvPixelFormat,
		(__bridge CFDictionaryRef)@{ (NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{} },
		&cvpb);
	if (cvErr != kCVReturnSuccess || cvpb == NULL)	{
		n.preferDeletion = YES;
		return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"problem (%d) while creating pixel buffer",cvErr] }];
	}
	//	the setter retains the cvpb- we still hold our own local create-ref ('cvpb') until the very end of this method
	n.cvpb = cvpb;

	//	tag the color attachments so downstream consumers (the encoder) know the colorimetry.  range follows the CV format.
	CVBufferSetAttachment(cvpb, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
	CVBufferSetAttachment(cvpb, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
	CVBufferSetAttachment(cvpb, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);

	//	derive the IOSurface (NOT retained by this call)- the setter takes the retain + use-count
	IOSurfaceRef		iosfc = CVPixelBufferGetIOSurface(cvpb);
	if (iosfc == NULL)	{
		n.cvpb = NULL;
		CVPixelBufferRelease(cvpb);
		cvpb = NULL;
		n.preferDeletion = YES;
		return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"problem deriving iosfc from cvpb" }];
	}
	n.iosfc = iosfc;

	//	READ ALL GEOMETRY before releasing the local create-ref below.  read per-plane stride/offset INDEPENDENTLY (chroma stride differs from luma)- never assume bytesPerRow*height.
	//	the surface is CPU-addressable (created with IOSurface properties)- no lock needed for address/offset arithmetic (locking is only for CPU readback).
	size_t			planeCount = IOSurfaceGetPlaneCount(iosfc);
	void			*surfaceBase = IOSurfaceGetBaseAddress(iosfc);
	size_t			surfaceAllocSize = IOSurfaceGetAllocSize(iosfc);

	NSUInteger		cachedOffsets[VVMTLSURFACEIMAGE_MAX_PLANES];
	NSUInteger		cachedBytesPerRows[VVMTLSURFACEIMAGE_MAX_PLANES];
	NSUInteger		cachedWidths[VVMTLSURFACEIMAGE_MAX_PLANES];
	NSUInteger		cachedHeights[VVMTLSURFACEIMAGE_MAX_PLANES];

	//	a non-planar IOSurface reports a plane count of 0- treat it as a single (whole-surface) plane so geometry is still cached
	NSUInteger		effectivePlaneCount = (planeCount == 0) ? 1 : (NSUInteger)planeCount;
	if (effectivePlaneCount > VVMTLSURFACEIMAGE_MAX_PLANES)
		effectivePlaneCount = VVMTLSURFACEIMAGE_MAX_PLANES;
	for (NSUInteger p=0; p<effectivePlaneCount; ++p)	{
		if (planeCount == 0)	{
			cachedOffsets[p] = 0;
			cachedBytesPerRows[p] = IOSurfaceGetBytesPerRow(iosfc);
			cachedWidths[p] = IOSurfaceGetWidth(iosfc);
			cachedHeights[p] = IOSurfaceGetHeight(iosfc);
		}
		else	{
			void		*planeBase = IOSurfaceGetBaseAddressOfPlane(iosfc, p);
			cachedOffsets[p] = (NSUInteger)((uint8_t*)planeBase - (uint8_t*)surfaceBase);
			cachedBytesPerRows[p] = IOSurfaceGetBytesPerRowOfPlane(iosfc, p);
			cachedWidths[p] = IOSurfaceGetWidthOfPlane(iosfc, p);
			cachedHeights[p] = IOSurfaceGetHeightOfPlane(iosfc, p);
		}
	}
	[n setPlaneCount:effectivePlaneCount offsets:cachedOffsets bytesPerRows:cachedBytesPerRows widths:cachedWidths heights:cachedHeights];

	//	the whole-surface no-copy buffer aliases the IOSurface memory.  no-op deallocator: the IOSurface (owned by the CVPixelBuffer) owns this memory- releasing the MTLBuffer must NOT free it.
	//	IOSurface base/alloc are page-aligned, satisfying newBufferWithBytesNoCopy.  bufferWithLengthNoCopy: sets preferDeletion=YES so this buffer is freed-not-pooled (only the VVMTLSurfaceImage recycles, carrying its own buffer forward).
	id<VVMTLBuffer>		wholeBuffer = [self
		bufferWithLengthNoCopy:surfaceAllocSize
		storage:desc.storage
		basePtr:surfaceBase
		bufferDeallocator:^(void *p, NSUInteger l){}];
	if (wholeBuffer == nil)	{
		n.iosfc = NULL;
		n.cvpb = NULL;
		CVPixelBufferRelease(cvpb);
		cvpb = NULL;
		n.preferDeletion = YES;
		return [NSError errorWithDomain:@"VVMTLPool" code:0 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"unable to make no-copy surface buffer (%ld bytes)",(unsigned long)surfaceAllocSize] }];
	}
	n.wholeSurfaceBuffer = wholeBuffer;

	//	all geometry has been read from the retained n.cvpb/n.iosfc- release the local create-ref LAST (no read after release).
	CVPixelBufferRelease(cvpb);
	cvpb = NULL;

	return nil;
}


@end

