#import "MTLPool.h"

#import "MTLImgBuffer.h"
#import "RenderProperties.h"
#import "MTLImgBufferAdditions_Private.h"




#define LOCK(n) os_unfair_lock_lock(n)
#define UNLOCK(n) os_unfair_lock_unlock(n)




static MTLPool		*_globalPool = nil;




@interface MTLPool ()	{
	os_unfair_lock		lock;
	
	CVMetalTextureCacheRef		poolTexCache;
	
	//NSMutableArray			*convPool;
	
}
- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice;
- (void) _labelTexture:(id<MTLTexture>)n;
@property (strong) id<MTLDevice> device;
//@property (strong) NSMutableArray<id<MTLTexture>> * textures;
//@property (strong) NSMutableArray<TexHolder*> * textures;
@property (strong) NSMutableArray<MTLImgBuffer*> * textures;
//- (MTLPoolConv *) _getConvObject;
//- (void) _returnConvObject:(MTLPoolConv *)n;
@end




static NSUInteger TEXINDEX = 0;
static os_unfair_lock TEXINDEXLOCK = OS_UNFAIR_LOCK_INIT;




@implementation MTLPool


#pragma mark - class methods


+ (MTLPool *) global	{
	return _globalPool;
}
+ (void) createGlobalPoolWithDevice:(id<MTLDevice>)inDevice	{
	_globalPool = [[MTLPool alloc] initWithDevice:inDevice];
}


#pragma mark - init/dealloc


- (nullable instancetype) initWithDevice:(id<MTLDevice>)inDevice	{
	self = [super init];
	if (self != nil)	{
		if (inDevice == nil)
			self = nil;
	}
	if (self != nil)	{
		lock = OS_UNFAIR_LOCK_INIT;
		_device = inDevice;
		_textures = [[NSMutableArray alloc] init];
		_housekeepingThreshold = 120;
		
		CVReturn		cvErr = kCVReturnSuccess;
		cvErr = CVMetalTextureCacheCreate(
			NULL,
			NULL,
			_device,
			NULL,
			&poolTexCache
		);
		if (cvErr != kCVReturnSuccess)
			NSLog(@"ERR: unable to create metal texture cache (%d)",cvErr);
		
		//convPool = [[NSMutableArray alloc] init];
		
	}
	return self;
}
- (void) dealloc	{
	if (poolTexCache != NULL)	{
		CFRelease(poolTexCache);
		poolTexCache = NULL;
	}
}


#pragma mark - backend stuff


- (CVMetalTextureCacheRef) cvTexCache	{
	return poolTexCache;
}


- (void) prepForRelease	{
	LOCK(&lock);
	_textures = nil;
	UNLOCK(&lock);
}


- (void) housekeeping	{
	NSMutableIndexSet		*indexesToRemove = nil;
	NSUInteger				idx = 0;
	
	LOCK(&lock);
	for (MTLImgBuffer * holder in _textures)	{
		holder.checkCount += 1;
		if (holder.checkCount > _housekeepingThreshold)	{
			if (indexesToRemove == nil)
				indexesToRemove = [[NSMutableIndexSet alloc] init];
			[indexesToRemove addIndex:idx];
			
			//if (holder.texture.pixelFormat == MTLPixelFormatRGBA16Uint)
			//	NSLog(@"\ttex %@ aged out of pool",holder);
		}
		
		++idx;
	}
	if (indexesToRemove != nil)	{
		//NSLog(@"\tactually freeing %ld textures",indexesToRemove.count);
		[_textures removeObjectsAtIndexes:indexesToRemove];
	}
	UNLOCK(&lock);
}


- (void) _returnToPool:(MTLImgBuffer *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n == nil)
		return;
	
	MTLImgBuffer		*holder = [[MTLImgBuffer alloc] initByRecycling:n];
	if (holder == nil)
		return;
	//	reset 'preferDeletion' to 0 so it wipes itself out if it stays in the pool "too long"
	holder.preferDeletion = YES;
	//	reset 'checkCount' to 0 so it starts waiting to delete itself
	holder.checkCount = 0;
	
	LOCK(&lock);
	if (_textures != nil)
		[_textures addObject:holder];
	UNLOCK(&lock);
}


#pragma mark - texture creation methods


- (void) _labelTexture:(id<MTLTexture>)n	{
	os_unfair_lock_lock(&TEXINDEXLOCK);
	
	n.label = [NSString stringWithFormat:@"%ld",(unsigned long)TEXINDEX];
	++TEXINDEX;
	
	os_unfair_lock_unlock(&TEXINDEXLOCK);
}


- (MTLImgBuffer *) bgra8TexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatBGRA8Unorm;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	//NSLog(@"\thad to create a new texture...");
	
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = n.width;
	desc.height = n.height;
	desc.depth = 1;
	desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device newTextureWithDescriptor:desc];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- bgra8"];
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) rgba8TexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGBA8Unorm;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	//NSLog(@"\thad to create a new texture...");
	
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = n.width;
	desc.height = n.height;
	desc.depth = 1;
	desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device newTextureWithDescriptor:desc];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- rgba8"];
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) rgb10a2TexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGB10A2Uint;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	//NSLog(@"\thad to create a new texture...");
	
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = n.width;
	desc.height = n.height;
	desc.depth = 1;
	desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device newTextureWithDescriptor:desc];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- rgb10a2"];
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) rgb10a2BufferBackedTexSized:(CGSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (s.width < 1 || s.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",s.width,s.height,__func__);
		return nil;
	}
	if (b==nil || bpr<1)	{
		NSLog(@"ERR: prereqs not met, %s",__func__);
		return nil;
	}
/*
		WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:

		id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		[blitEncoder synchronizeResource:myFrame.buffer];
		[blitEncoder endEncoding];
		[cmdBuffer commit];
		[cmdBuffer waitUntilCompleted];
		float		*contents = (float *)[newFrame.buffer contents];
*/
	
	
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGB10A2Uint;
	//MTLPixelFormat		mpf = MTLPixelFormatRGB10A2Unorm;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==s.width && holder.texture.height==s.height && holder.texture.pixelFormat==mpf && holder.buffer!=nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(s.width),round(s.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		//NSLog(@"\treturning existing texture");
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = round(s.width);
	returnMe.height = round(s.height);
	returnMe.srcRect = NSMakeRect(0,0,returnMe.width,returnMe.height);
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	make an appropriately-sized MTLBuffer
	//size_t				bufferBytesPerRow = returnMe.width * 8 * 4 / 8;
	//size_t				acceptableBytesPerRow = [self.device minimumLinearTextureAlignmentForPixelFormat:mpf];
	//NSLog(@"\t\torig bytesPerRow is %ld, acceptable bytesPerRow is %ld",bufferBytesPerRow,acceptableBytesPerRow);
	//if (bufferBytesPerRow % acceptableBytesPerRow != 0)	{
	//	bufferBytesPerRow += (acceptableBytesPerRow - (bufferBytesPerRow % acceptableBytesPerRow));
	//}
	//NSLog(@"\t\tactual bytesPerRow is %ld",bufferBytesPerRow);
	//size_t				bufferSizeInBytes = bufferBytesPerRow * returnMe.height;
	//id<MTLBuffer>		tmpBuffer = [self.device newBufferWithLength:bufferSizeInBytes options:MTLResourceStorageModeManaged];
	
	
	
	size_t				bufferSizeInBytes = bpr * s.height;
	id<MTLBuffer>		tmpBuffer = [self.device newBufferWithBytesNoCopy:b length:bufferSizeInBytes options:MTLResourceStorageModeManaged deallocator:d];
	if (tmpBuffer == nil)	{
		NSLog(@"ERR: unable to create buffer in %s",__func__);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	//	make a texture from that buffer!
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = returnMe.width;
	desc.height = returnMe.height;
	desc.depth = 1;
	//desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.resourceOptions = MTLResourceStorageModeManaged;
	//desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModeManaged;
	//desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsagePixelFormatView;
	id<MTLTexture>		tmpTex = [tmpBuffer
		newTextureWithDescriptor:desc
		offset:0
		bytesPerRow:bpr];
	if (tmpTex == nil)	{
		NSLog(@"ERR: unable to create tex in %s",__func__);
		tmpBuffer = nil;
		tmpTex = nil;
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	[self _labelTexture:tmpTex];
	tmpTex.label = [tmpTex.label stringByAppendingString:@"- rgb10a2B_Ext"];
	
	returnMe.buffer = tmpBuffer;
	returnMe.bufferBytesPerRow = bpr;
	returnMe.texture = tmpTex;
	//NSLog(@"allocated texture %@",returnMe);
	
	return returnMe;
}
- (MTLImgBuffer *) rgb10a2NormTexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGB10A2Unorm;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	//NSLog(@"\thad to create a new texture...");
	
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = n.width;
	desc.height = n.height;
	desc.depth = 1;
	desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device newTextureWithDescriptor:desc];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- rgb10a2"];
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) rgba16TexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGBA16Uint;
	//MTLPixelFormat		mpf = MTLPixelFormatRGBA16Unorm;	//	doesn't work with RED
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	//NSLog(@"\thad to create a new texture...");
	
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = n.width;
	desc.height = n.height;
	desc.depth = 1;
	desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	//desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite | MTLTextureUsagePixelFormatView;
	
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device newTextureWithDescriptor:desc];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- rgba16"];
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) uyvyBufferBackedTexSized:(CGSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (s.width < 1 || s.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",s.width,s.height,__func__);
		return nil;
	}
	if (b==nil || bpr<1)	{
		NSLog(@"ERR: prereqs not met, %s",__func__);
		return nil;
	}
/*
		WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:

		id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		[blitEncoder synchronizeResource:myFrame.buffer];
		[blitEncoder endEncoding];
		[cmdBuffer commit];
		[cmdBuffer waitUntilCompleted];
		float		*contents = (float *)[newFrame.buffer contents];
*/
	
	
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatBGRG422;
	
	//	we're going to skip this "let's try to find a matching texture" bit because the premise of this method is "hey, upload this crap to the GPU"
	/*
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==s.width && holder.texture.height==s.height && holder.texture.pixelFormat==mpf && holder.buffer!=nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(s.width),round(s.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		//NSLog(@"\treturning existing texture");
		return returnMe;
	}
	*/
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = round(s.width);
	returnMe.height = round(s.height);
	returnMe.srcRect = NSMakeRect(0,0,returnMe.width,returnMe.height);
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	make an appropriately-sized MTLBuffer
	//size_t				bufferBytesPerRow = returnMe.width * 8 * 4 / 8;
	//size_t				acceptableBytesPerRow = [self.device minimumLinearTextureAlignmentForPixelFormat:mpf];
	//NSLog(@"\t\torig bytesPerRow is %ld, acceptable bytesPerRow is %ld",bufferBytesPerRow,acceptableBytesPerRow);
	//if (bufferBytesPerRow % acceptableBytesPerRow != 0)	{
	//	bufferBytesPerRow += (acceptableBytesPerRow - (bufferBytesPerRow % acceptableBytesPerRow));
	//}
	//NSLog(@"\t\tactual bytesPerRow is %ld",bufferBytesPerRow);
	//size_t				bufferSizeInBytes = bufferBytesPerRow * returnMe.height;
	//id<MTLBuffer>		tmpBuffer = [self.device newBufferWithLength:bufferSizeInBytes options:MTLResourceStorageModeManaged];
	
	
	size_t				bufferSizeInBytes = bpr * s.height;
	if (bufferSizeInBytes % 4096 != 0)
		bufferSizeInBytes = ((bufferSizeInBytes/4096)+1)*4096;
	id<MTLBuffer>		tmpBuffer = [self.device newBufferWithBytesNoCopy:b length:bufferSizeInBytes options:MTLResourceStorageModeManaged deallocator:d];
	if (tmpBuffer == nil)	{
		NSLog(@"ERR: unable to create buffer in %s",__func__);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	//	make a texture from that buffer!
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = returnMe.width;
	desc.height = returnMe.height;
	desc.depth = 1;
	//desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.resourceOptions = MTLResourceStorageModeManaged;
	//desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModeManaged;
	//desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
	desc.usage = MTLTextureUsageShaderRead /*| MTLTextureUsageShaderWrite | MTLTextureUsagePixelFormatView*/;
	id<MTLTexture>		tmpTex = [tmpBuffer
		newTextureWithDescriptor:desc
		offset:0
		bytesPerRow:bpr];
	if (tmpTex == nil)	{
		NSLog(@"ERR: unable to create tex in %s",__func__);
		tmpBuffer = nil;
		tmpTex = nil;
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	[self _labelTexture:tmpTex];
	tmpTex.label = [tmpTex.label stringByAppendingString:@"- rgb10a2B_Ext"];
	
	returnMe.buffer = tmpBuffer;
	returnMe.bufferBytesPerRow = bpr;
	returnMe.texture = tmpTex;
	//NSLog(@"allocated texture %@",returnMe);
	
	return returnMe;
}
- (MTLImgBuffer *) rgbaFloatTexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
	
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGBA32Float;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		//NSLog(@"\treturning existing texture");
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	//NSLog(@"\thad to create a new texture...");
	
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = n.width;
	desc.height = n.height;
	desc.depth = 1;
	//desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.resourceOptions = MTLResourceStorageModeManaged;	//	GPU-only
	//desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModeManaged;	//	GPU-only
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device newTextureWithDescriptor:desc];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- rgbaFloat"];
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) rgbaFloatBufferBackedTexSized:(CGSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(s));
	if (s.width < 1 || s.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",s.width,s.height,__func__);
		return nil;
	}
	if (b==nil || bpr<1)	{
		NSLog(@"ERR: prereqs not met, %s",__func__);
		return nil;
	}
/*
		WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:

		id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		[blitEncoder synchronizeResource:myFrame.buffer];
		[blitEncoder endEncoding];
		[cmdBuffer commit];
		[cmdBuffer waitUntilCompleted];
		float		*contents = (float *)[newFrame.buffer contents];
*/
	
	
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGBA32Float;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==s.width && holder.texture.height==s.height && holder.texture.pixelFormat==mpf && holder.buffer!=nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(s.width),round(s.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		//NSLog(@"\treturning existing texture");
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = round(s.width);
	returnMe.height = round(s.height);
	returnMe.srcRect = NSMakeRect(0,0,returnMe.width,returnMe.height);
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	make an appropriately-sized MTLBuffer
	//size_t				bufferBytesPerRow = returnMe.width * 8 * 4 / 8;
	//size_t				acceptableBytesPerRow = [self.device minimumLinearTextureAlignmentForPixelFormat:mpf];
	//NSLog(@"\t\torig bytesPerRow is %ld, acceptable bytesPerRow is %ld",bufferBytesPerRow,acceptableBytesPerRow);
	//if (bufferBytesPerRow % acceptableBytesPerRow != 0)	{
	//	bufferBytesPerRow += (acceptableBytesPerRow - (bufferBytesPerRow % acceptableBytesPerRow));
	//}
	//NSLog(@"\t\tactual bytesPerRow is %ld",bufferBytesPerRow);
	//size_t				bufferSizeInBytes = bufferBytesPerRow * returnMe.height;
	//id<MTLBuffer>		tmpBuffer = [self.device newBufferWithLength:bufferSizeInBytes options:MTLResourceStorageModeManaged];
	
	
	
	size_t				bufferSizeInBytes = bpr * s.height;
	id<MTLBuffer>		tmpBuffer = [self.device newBufferWithBytesNoCopy:b length:bufferSizeInBytes options:MTLResourceStorageModeManaged deallocator:d];
	if (tmpBuffer == nil)	{
		NSLog(@"ERR: unable to create buffer in %s",__func__);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	//	make a texture from that buffer!
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = returnMe.width;
	desc.height = returnMe.height;
	desc.depth = 1;
	//desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.resourceOptions = MTLResourceStorageModeManaged;
	//desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModeManaged;
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
	id<MTLTexture>		tmpTex = [tmpBuffer
		newTextureWithDescriptor:desc
		offset:0
		bytesPerRow:bpr];
	if (tmpTex == nil)	{
		NSLog(@"ERR: unable to create tex in %s",__func__);
		tmpBuffer = nil;
		tmpTex = nil;
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	[self _labelTexture:tmpTex];
	tmpTex.label = [tmpTex.label stringByAppendingString:@"- rgbaFloatB_Ext"];
	
	returnMe.buffer = tmpBuffer;
	returnMe.bufferBytesPerRow = bpr;
	returnMe.texture = tmpTex;
	//NSLog(@"allocated texture %@",returnMe);
	
	return returnMe;
}
- (MTLImgBuffer *) rgbaBufferBackedFloatTexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
/*
		WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:

		id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		[blitEncoder synchronizeResource:myFrame.buffer];
		[blitEncoder endEncoding];
		[cmdBuffer commit];
		[cmdBuffer waitUntilCompleted];
		float		*contents = (float *)[newFrame.buffer contents];
*/
	
	
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGBA32Float;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.pixelFormat==mpf && holder.buffer!=nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		//NSLog(@"\treturning existing texture");
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = round(n.width);
	returnMe.height = round(n.height);
	returnMe.srcRect = NSMakeRect(0,0,returnMe.width,returnMe.height);
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	make an appropriately-sized MTLBuffer
	size_t				bufferBytesPerRow = returnMe.width * 32 * 4 / 8;
	size_t				acceptableBytesPerRow = [self.device minimumLinearTextureAlignmentForPixelFormat:mpf];
	//NSLog(@"\t\torig bytesPerRow is %ld, acceptable bytesPerRow is %ld",bufferBytesPerRow,acceptableBytesPerRow);
	if (bufferBytesPerRow % acceptableBytesPerRow != 0)	{
		bufferBytesPerRow += (acceptableBytesPerRow - (bufferBytesPerRow % acceptableBytesPerRow));
	}
	//NSLog(@"\t\tactual bytesPerRow is %ld",bufferBytesPerRow);
	size_t				bufferSizeInBytes = bufferBytesPerRow * returnMe.height;
	id<MTLBuffer>		tmpBuffer = [self.device newBufferWithLength:bufferSizeInBytes options:MTLResourceStorageModeManaged];
	if (tmpBuffer == nil)	{
		NSLog(@"ERR: unable to create buffer in %s",__func__);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	//	make a texture from that buffer!
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = returnMe.width;
	desc.height = returnMe.height;
	desc.depth = 1;
	//desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.resourceOptions = MTLResourceStorageModeManaged;
	//desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModeManaged;
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
	id<MTLTexture>		tmpTex = [tmpBuffer
		newTextureWithDescriptor:desc
		offset:0
		bytesPerRow:bufferBytesPerRow];
	if (tmpTex == nil)	{
		NSLog(@"ERR: unable to create tex in %s",__func__);
		tmpBuffer = nil;
		tmpTex = nil;
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	[self _labelTexture:tmpTex];
	tmpTex.label = [tmpTex.label stringByAppendingString:@"- rgbaFloatB"];
	
	returnMe.buffer = tmpBuffer;
	returnMe.bufferBytesPerRow = bufferBytesPerRow;
	returnMe.texture = tmpTex;
	//NSLog(@"allocated texture %@",returnMe);
	
	return returnMe;
}
- (MTLImgBuffer *) bgra8BufferBackedTexSized:(CGSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (s.width < 1 || s.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",s.width,s.height,__func__);
		return nil;
	}
	if (b==nil || bpr<1)	{
		NSLog(@"ERR: prereqs not met, %s",__func__);
		return nil;
	}
/*
		WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:

		id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		[blitEncoder synchronizeResource:myFrame.buffer];
		[blitEncoder endEncoding];
		[cmdBuffer commit];
		[cmdBuffer waitUntilCompleted];
		float		*contents = (float *)[newFrame.buffer contents];
*/
	
	
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatBGRA8Unorm;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==s.width && holder.texture.height==s.height && holder.texture.pixelFormat==mpf && holder.buffer!=nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(s.width),round(s.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		//NSLog(@"\treturning existing texture");
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = round(s.width);
	returnMe.height = round(s.height);
	returnMe.srcRect = NSMakeRect(0,0,returnMe.width,returnMe.height);
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	make an appropriately-sized MTLBuffer
	//size_t				bufferBytesPerRow = returnMe.width * 8 * 4 / 8;
	//size_t				acceptableBytesPerRow = [self.device minimumLinearTextureAlignmentForPixelFormat:mpf];
	//NSLog(@"\t\torig bytesPerRow is %ld, acceptable bytesPerRow is %ld",bufferBytesPerRow,acceptableBytesPerRow);
	//if (bufferBytesPerRow % acceptableBytesPerRow != 0)	{
	//	bufferBytesPerRow += (acceptableBytesPerRow - (bufferBytesPerRow % acceptableBytesPerRow));
	//}
	//NSLog(@"\t\tactual bytesPerRow is %ld",bufferBytesPerRow);
	//size_t				bufferSizeInBytes = bufferBytesPerRow * returnMe.height;
	//id<MTLBuffer>		tmpBuffer = [self.device newBufferWithLength:bufferSizeInBytes options:MTLResourceStorageModeManaged];
	
	
	
	size_t				bufferSizeInBytes = bpr * s.height;
	id<MTLBuffer>		tmpBuffer = [self.device newBufferWithBytesNoCopy:b length:bufferSizeInBytes options:MTLResourceStorageModeManaged deallocator:d];
	//id<MTLBuffer>		tmpBuffer = [self.device newBufferWithBytes:b length:bufferSizeInBytes options:MTLResourceStorageModeManaged];
	if (tmpBuffer == nil)	{
		NSLog(@"ERR: unable to create buffer in %s",__func__);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	//	make a texture from that buffer!
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = returnMe.width;
	desc.height = returnMe.height;
	desc.depth = 1;
	//desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.resourceOptions = MTLResourceStorageModeManaged;
	//desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModeManaged;
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
	id<MTLTexture>		tmpTex = [tmpBuffer
		newTextureWithDescriptor:desc
		offset:0
		bytesPerRow:bpr];
	if (tmpTex == nil)	{
		NSLog(@"ERR: unable to create tex in %s",__func__);
		tmpBuffer = nil;
		tmpTex = nil;
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	[self _labelTexture:tmpTex];
	tmpTex.label = [tmpTex.label stringByAppendingString:@"- bgra8B_Ext"];
	
	returnMe.buffer = tmpBuffer;
	returnMe.bufferBytesPerRow = bpr;
	returnMe.texture = tmpTex;
	//NSLog(@"allocated texture %@",returnMe);
	
	return returnMe;
}
- (MTLImgBuffer *) rgbaHalfFloatTexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGBA16Float;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		//NSLog(@"\treturning existing texture");
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	//NSLog(@"\thad to create a new texture...");
	
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = n.width;
	desc.height = n.height;
	desc.depth = 1;
	//desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.resourceOptions = MTLResourceStorageModeManaged;	//	GPU-only
	//desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModeManaged;	//	GPU-only
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device newTextureWithDescriptor:desc];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- rgbaFloat"];
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) rgbaHalfFloatBufferBackedTexSized:(CGSize)s basePtr:(void*)b bytesPerRow:(uint32_t)bpr bufferDeallocator:(void (^)(void *pointer, NSUInteger length))d	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(s));
	if (s.width < 1 || s.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",s.width,s.height,__func__);
		return nil;
	}
	if (b==nil || bpr<1)	{
		NSLog(@"ERR: prereqs not met, %s",__func__);
		return nil;
	}
/*
		WHEN YOU NEED TO ACCESS THE CONTENTS OF THIS TEXTURE FROM THE CPU, DO THIS:

		id<MTLBlitCommandEncoder>		blitEncoder = [cmdBuffer blitCommandEncoder];
		[blitEncoder synchronizeResource:myFrame.buffer];
		[blitEncoder endEncoding];
		[cmdBuffer commit];
		[cmdBuffer waitUntilCompleted];
		float		*contents = (float *)[newFrame.buffer contents];
*/
	
	
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGBA16Float;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==s.width && holder.texture.height==s.height && holder.texture.pixelFormat==mpf && holder.buffer!=nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(s.width),round(s.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			//NSLog(@"\tfound pre-existing texture...");
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		//NSLog(@"\treturning existing texture");
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = round(s.width);
	returnMe.height = round(s.height);
	returnMe.srcRect = NSMakeRect(0,0,returnMe.width,returnMe.height);
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	make an appropriately-sized MTLBuffer
	//size_t				bufferBytesPerRow = returnMe.width * 8 * 4 / 8;
	//size_t				acceptableBytesPerRow = [self.device minimumLinearTextureAlignmentForPixelFormat:mpf];
	//NSLog(@"\t\torig bytesPerRow is %ld, acceptable bytesPerRow is %ld",bufferBytesPerRow,acceptableBytesPerRow);
	//if (bufferBytesPerRow % acceptableBytesPerRow != 0)	{
	//	bufferBytesPerRow += (acceptableBytesPerRow - (bufferBytesPerRow % acceptableBytesPerRow));
	//}
	//NSLog(@"\t\tactual bytesPerRow is %ld",bufferBytesPerRow);
	//size_t				bufferSizeInBytes = bufferBytesPerRow * returnMe.height;
	//id<MTLBuffer>		tmpBuffer = [self.device newBufferWithLength:bufferSizeInBytes options:MTLResourceStorageModeManaged];
	
	
	
	size_t				bufferSizeInBytes = bpr * s.height;
	id<MTLBuffer>		tmpBuffer = [self.device newBufferWithBytesNoCopy:b length:bufferSizeInBytes options:MTLResourceStorageModeManaged deallocator:d];
	if (tmpBuffer == nil)	{
		NSLog(@"ERR: unable to create buffer in %s",__func__);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	//	make a texture from that buffer!
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = returnMe.width;
	desc.height = returnMe.height;
	desc.depth = 1;
	//desc.resourceOptions = MTLResourceStorageModePrivate;	//	GPU-only
	desc.resourceOptions = MTLResourceStorageModeManaged;
	//desc.storageMode = MTLStorageModePrivate;	//	GPU-only
	desc.storageMode = MTLStorageModeManaged;
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
	id<MTLTexture>		tmpTex = [tmpBuffer
		newTextureWithDescriptor:desc
		offset:0
		bytesPerRow:bpr];
	if (tmpTex == nil)	{
		NSLog(@"ERR: unable to create tex in %s",__func__);
		tmpBuffer = nil;
		tmpTex = nil;
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	[self _labelTexture:tmpTex];
	tmpTex.label = [tmpTex.label stringByAppendingString:@"- rgbaFloatB_Ext"];
	
	returnMe.buffer = tmpBuffer;
	returnMe.bufferBytesPerRow = bpr;
	returnMe.texture = tmpTex;
	//NSLog(@"allocated texture %@",returnMe);
	
	return returnMe;
}
- (MTLImgBuffer *) bufferForExistingTexture:(id<MTLTexture>)n	{
	//NSLog(@"%s",__func__);
	if (n == nil)
		return nil;
	
	MTLImgBuffer		*returnMe = [[MTLImgBuffer alloc] init];
	returnMe.texture = n;
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = YES;
	returnMe.parentPool = self;
	
	[self _labelTexture:n];
	n.label = [n.label stringByAppendingString:@"- existing"];
	//NSLog(@"made buffer for existing texture %@",returnMe);
	return returnMe;
}
- (MTLImgBuffer *) bgra8IOSurfaceBackedTexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatBGRA8Unorm;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.iosurface!=NULL && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = NO;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	
	//	make an IOSurface-backed CVPixelBuffer
	CVPixelBufferRef	cvpb = NULL;
	CVReturn			cvErr = CVPixelBufferCreate(
		kCFAllocatorDefault,
		n.width,
		n.height,
		kCVPixelFormatType_32BGRA,
		(__bridge CFDictionaryRef)@{
			(NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{ }
			},
		&cvpb);
	if (cvErr != kCVReturnSuccess || cvpb == NULL)	{
		NSLog(@"ERR: unable to make CVPB in %s",__func__);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	IOSurfaceRef		iosfc = CVPixelBufferGetIOSurface(cvpb);
	if (iosfc == NULL)	{
		NSLog(@"ERR: CVPB not backed by an IOSurface, %s",__func__);
		CFRelease(cvpb);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	//	make a MTLTexture from the IOSurface
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = n.width;
	desc.height = n.height;
	desc.depth = 1;
	//desc.cpuCacheMode = MTLCPUCacheModeDefaultCache;
	//desc.storageMode = MTLStorageModeManaged;
	//desc.storageMode = MTLStorageModeShared;
	//desc.hazardTrackingMode = MTLHazardTrackingModeDefault;
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device
		newTextureWithDescriptor:desc
		iosurface:iosfc
		plane:0];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- bgra8IOSfc"];
	
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		returnMe.cvpb = cvpb;
		returnMe.iosfc = CVPixelBufferGetIOSurface(cvpb);
		returnMe.destroyBlock = ^(MTLImgBuffer * bufferBeingFreed)	{
			CFRelease(cvpb);
		};
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) rgbaFloat32IOSurfaceBackedTexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGBA32Float;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.iosurface!=NULL && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = YES;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	
	//	make an IOSurface-backed CVPixelBuffer
	CVPixelBufferRef	cvpb = NULL;
	CVReturn			cvErr = CVPixelBufferCreate(
		kCFAllocatorDefault,
		n.width,
		n.height,
		kCVPixelFormatType_128RGBAFloat,
		(__bridge CFDictionaryRef)@{
			(NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{ }
			},
		&cvpb);
	if (cvErr != kCVReturnSuccess || cvpb == NULL)	{
		NSLog(@"ERR: unable to make CVPB in %s",__func__);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	IOSurfaceRef		iosfc = CVPixelBufferGetIOSurface(cvpb);
	if (iosfc == NULL)	{
		NSLog(@"ERR: CVPB not backed by an IOSurface, %s",__func__);
		CFRelease(cvpb);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	//	make a MTLTexture from the IOSurface
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = n.width;
	desc.height = n.height;
	desc.depth = 1;
	//desc.cpuCacheMode = MTLCPUCacheModeDefaultCache;
	//desc.storageMode = MTLStorageModeManaged;
	//desc.storageMode = MTLStorageModeShared;
	//desc.hazardTrackingMode = MTLHazardTrackingModeDefault;
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device
		newTextureWithDescriptor:desc
		iosurface:iosfc
		plane:0];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- rgbaFloatIosfc"];
	
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		returnMe.cvpb = cvpb;
		returnMe.iosfc = CVPixelBufferGetIOSurface(cvpb);
		returnMe.destroyBlock = ^(MTLImgBuffer * bufferBeingFreed)	{
			CFRelease(cvpb);
		};
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) rgbaHalfFloatIOSurfaceBackedTexFromCVPB:(CVPixelBufferRef)inCVPB	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (inCVPB == NULL)	{
		NSLog(@"ERR: invalid pixel buffer in %s",__func__);
		return nil;
	}
	CGSize			targetSize = CGSizeMake(CVPixelBufferGetWidth(inCVPB),CVPixelBufferGetHeight(inCVPB));
	if (targetSize.width < 1 || targetSize.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",targetSize.width,targetSize.height,__func__);
		return nil;
	}
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatRGBA16Float;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	//LOCK(&lock);
	//NSUInteger			idx = 0;
	//for (MTLImgBuffer * holder in _textures)	{
	//	if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.iosurface!=NULL && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
	//		returnMe = holder;
	//		returnMe.preferDeletion = NO;
	//		returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	//		returnMe.flipped = NO;
	//		//	retain the texture in the object we'll be returning, remove it from the pool
	//		//returnMe.texture = holder.texture;
	//		//returnMe.iosfc = holder.iosfc;
	//		//returnMe.cvpb = holder.cvpb;
	//		//returnMe.destroyBlock = holder.destroyBlock;
	//		[_textures removeObjectAtIndex:idx];
	//		break;
	//	}
	//	++idx;
	//}
	//UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = round(targetSize.width);
	returnMe.height = round(targetSize.height);
	//returnMe.displaySize = CGSizeMake(targetSize.width, targetSize.height);
	returnMe.srcRect = NSMakeRect(0,0,returnMe.width,returnMe.height);
	returnMe.flipped = NO;
	returnMe.preferDeletion = YES;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	
	//	make an IOSurface-backed CVPixelBuffer
	//CVPixelBufferRef	cvpb = NULL;
	//CVReturn			cvErr = CVPixelBufferCreate(
	//	kCFAllocatorDefault,
	//	targetSize.width,
	//	targetSize.height,
	//	kCVPixelFormatType_128RGBAFloat,
	//	(__bridge CFDictionaryRef)@{
	//		(NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{ }
	//		},
	//	&cvpb);
	//if (cvErr != kCVReturnSuccess || cvpb == NULL)	{
	//	NSLog(@"ERR: unable to make CVPB in %s",__func__);
	//	returnMe.preferDeletion = YES;
	//	returnMe = nil;
	//	return nil;
	//}
	
	IOSurfaceRef		iosfc = CVPixelBufferGetIOSurface(inCVPB);
	if (iosfc == NULL)	{
		NSLog(@"ERR: CVPB not backed by an IOSurface, %s",__func__);
		CFRelease(inCVPB);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	//	make a MTLTexture from the IOSurface
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = targetSize.width;
	desc.height = targetSize.height;
	desc.depth = 1;
	//desc.cpuCacheMode = MTLCPUCacheModeDefaultCache;
	//desc.storageMode = MTLStorageModeManaged;
	//desc.storageMode = MTLStorageModeShared;
	//desc.hazardTrackingMode = MTLHazardTrackingModeDefault;
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device
		newTextureWithDescriptor:desc
		iosurface:iosfc
		plane:0];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- rgbaFloatIosfc"];
	
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		returnMe.cvpb = inCVPB;
		returnMe.iosfc = iosfc;
		returnMe.destroyBlock = ^(MTLImgBuffer * bufferBeingFreed)	{
			CFRelease(inCVPB);
		};
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) uyvyIOSurfaceBackedTexSized:(CGSize)n	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(n));
	if (n.width < 1 || n.height < 1)	{
		NSLog(@"ERR: invalid dimensions (%0.3f, %0.3f) in %s",n.width,n.height,__func__);
		return nil;
	}
	MTLImgBuffer		*returnMe = nil;
	
	MTLPixelFormat		mpf = MTLPixelFormatBGRG422;
	
	//	run through the array of textures in our pool, try to find one that matches the description
	LOCK(&lock);
	NSUInteger			idx = 0;
	for (MTLImgBuffer * holder in _textures)	{
		if (holder.texture.width==n.width && holder.texture.height==n.height && holder.texture.iosurface!=NULL && holder.texture.pixelFormat==mpf && holder.buffer==nil)	{
			returnMe = holder;
			returnMe.preferDeletion = NO;
			returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
			returnMe.flipped = NO;
			//	retain the texture in the object we'll be returning, remove it from the pool
			//returnMe.texture = holder.texture;
			//returnMe.iosfc = holder.iosfc;
			//returnMe.cvpb = holder.cvpb;
			//returnMe.destroyBlock = holder.destroyBlock;
			[_textures removeObjectAtIndex:idx];
			break;
		}
		++idx;
	}
	UNLOCK(&lock);
	
	//	if we found a texture, we can return now
	if (returnMe != nil)	{
		return returnMe;
	}
	
	returnMe = [[MTLImgBuffer alloc] init];
	returnMe.width = n.width;
	returnMe.height = n.height;
	//returnMe.displaySize = CGSizeMake(n.width, n.height);
	returnMe.srcRect = NSMakeRect(0,0,round(n.width),round(n.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = YES;
	returnMe.parentPool = self;
	
	//	...if we're here then we couldn't find a pooled texture- we have to create one.
	
	//	make an IOSurface-backed CVPixelBuffer
	CVPixelBufferRef	cvpb = NULL;
	CVReturn			cvErr = CVPixelBufferCreate(
		kCFAllocatorDefault,
		n.width,
		n.height,
		kCVPixelFormatType_422YpCbCr8,
		(__bridge CFDictionaryRef)@{
			(NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{ }
			},
		&cvpb);
	if (cvErr != kCVReturnSuccess || cvpb == NULL)	{
		NSLog(@"ERR: unable to make CVPB in %s",__func__);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	IOSurfaceRef		iosfc = CVPixelBufferGetIOSurface(cvpb);
	if (iosfc == NULL)	{
		NSLog(@"ERR: CVPB not backed by an IOSurface, %s",__func__);
		CFRelease(cvpb);
		returnMe.preferDeletion = YES;
		returnMe = nil;
		return nil;
	}
	
	//	make a MTLTexture from the IOSurface
	MTLTextureDescriptor	*desc = [[MTLTextureDescriptor alloc] init];
	desc.textureType = MTLTextureType2D;
	desc.pixelFormat = mpf;
	desc.width = n.width;
	desc.height = n.height;
	desc.depth = 1;
	//desc.cpuCacheMode = MTLCPUCacheModeDefaultCache;
	//desc.storageMode = MTLStorageModeManaged;
	//desc.storageMode = MTLStorageModeShared;
	//desc.hazardTrackingMode = MTLHazardTrackingModeDefault;
	desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
	
	//	make a new texture matching the descriptor
	id<MTLTexture>		newTex = [self.device
		newTextureWithDescriptor:desc
		iosurface:iosfc
		plane:0];
	[self _labelTexture:newTex];
	newTex.label = [newTex.label stringByAppendingString:@"- 2vuyIosfc"];
	
	//	if we managed to create a new texture, finish populating the object we'll be returning and return it
	if (newTex != nil)	{
		returnMe.texture = newTex;
		returnMe.cvpb = cvpb;
		returnMe.iosfc = CVPixelBufferGetIOSurface(cvpb);
		returnMe.destroyBlock = ^(MTLImgBuffer * bufferBeingFreed)	{
			CFRelease(cvpb);
		};
		//NSLog(@"allocated texture %@",returnMe);
		return returnMe;
	}
	
	//	...if we're here, something went wrong and we have to return nil.  first destroy what we've created so far.
	
	returnMe.preferDeletion = YES;
	returnMe = nil;
	return returnMe;
}
- (MTLImgBuffer *) bufferForCVMTLTex:(CVMetalTextureRef)inRef sized:(CGSize)inSize	{
	//NSLog(@"%s ... %@",__func__,NSStringFromSize(inSize));
	if (inRef == NULL)
		return nil;
	
	id<MTLTexture>		tmpTex = CVMetalTextureGetTexture(inRef);
	if (tmpTex == nil)
		return nil;
	[self _labelTexture:tmpTex];
	tmpTex.label = [tmpTex.label stringByAppendingString:@"- CVMTlTex"];
	
	CFRetain(inRef);
	
	MTLImgBuffer		*returnMe = [[MTLImgBuffer alloc] init];
	returnMe.texture = tmpTex;
	
	returnMe.width = inSize.width;
	returnMe.height = inSize.height;
	//returnMe.displaySize = returnMe.size;
	returnMe.srcRect = NSMakeRect(0,0,round(inSize.width),round(inSize.height));
	returnMe.flipped = NO;
	returnMe.preferDeletion = YES;
	returnMe.parentPool = self;
	returnMe.supportingObject = nil;
	returnMe.destroyBlock = ^(MTLImgBuffer * bufferBeingFreed)	{
		CFRelease(inRef);
	};
	
	//NSLog(@"\t\treturning %@",returnMe);
	
	return returnMe;
}
/*
- (MTLImgBuffer *) bufferForCVPixelBuffer:(CVPixelBufferRef)inCVPB texCache:(CVMetalTextureCacheRef)inTexCache anamorphicRatio:(double)inAR inCommandBuffer:(id<MTLCommandBuffer>)inCB completionHandler:(void(^)(MTLImgBuffer * requestedTex))inCompletionHandler	{
	CVMetalTextureCacheRef		texCache = (inTexCache==nil) ? poolTexCache : inTexCache;
	CVReturn				cvErr = kCVReturnSuccess;
	OSType					pbpf = CVPixelBufferGetPixelFormatType(inCVPB);
	MTLPixelFormat			mpf;
	//FourCCLog(@"pixel buffer format is ",pbpf);
	//NSLog(@"\tpb size is %d x %d",CVPixelBufferGetWidth(pb),CVPixelBufferGetHeight(pb));
	//NSLog(@"\tpb fourcc is %@ (%ld / 0x%X)",[NSString stringFromFourCC:pbpf], pbpf, pbpf);
	//NSLog(@"\tpb bytes per row is %ld",CVPixelBufferGetBytesPerRow(pb));
	//NSLog(@"\tpb plane count is %ld",CVPixelBufferGetPlaneCount(pb));

	switch (pbpf)	{
	case 32:		mpf = MTLPixelFormatRGB10A2Unorm;		break;	//	returned if we don't specify a pixel format in the AVF output's dict?
	case '2vuy':	mpf = MTLPixelFormatBGRG422;		break;
	case 'yuvs':	mpf = MTLPixelFormatGBGR422;		break;
	case 'yuvf':	mpf = MTLPixelFormatGBGR422;		break;
	case 'BGRA':	mpf = MTLPixelFormatBGRA8Unorm;		break;
	case 'RGBA':	mpf = MTLPixelFormatRGBA8Unorm;		break;
	case 'RGfA':	mpf = MTLPixelFormatRGBA32Float;	break;
	case 'b64a':	mpf = MTLPixelFormatRGBA16Uint;	break;
	case 'RGhA':	mpf = MTLPixelFormatRGBA16Float;	break;
	case 'R10k':	mpf = MTLPixelFormatRGB10A2Unorm;	break;

	case 'v216':	mpf = MTLPixelFormatGBGR422;		break;
	case 'v210':	mpf = MTLPixelFormatBGRG422;		break;
	case 'v410':	mpf = MTLPixelFormatGBGR422;		break;
	default:	mpf = 0; NSLog(@"ERR: unrecognized 4cc: %@ (%d / 0x%X)",[NSString stringFromFourCC:pbpf],(unsigned int)pbpf,(unsigned int)pbpf);	break;
	}

	size_t			width = CVPixelBufferGetWidth(inCVPB);
	size_t			height = CVPixelBufferGetHeight(inCVPB);
	CVMetalTextureRef		metalTexRef = NULL;
	cvErr = CVMetalTextureCacheCreateTextureFromImage(
		kCFAllocatorDefault,
		texCache,
		inCVPB,
		NULL,
		mpf,
		width,
		height,
		0,
		&metalTexRef
	);
	
	if (cvErr != kCVReturnSuccess && metalTexRef==NULL)	{
		NSLog(@"ERR: unable to create metal tex for pixel buffer (%d) in %s",cvErr,__func__);
		return nil;
	}
	
	BOOL			shotIsAnamorphic = (inAR==1.0) ? NO : YES;
	CGSize			baseTexSize = CGSizeMake(width, height);
	CGSize			actualTexSize = CGSizeMake(round(inAR * (double)width), height);
	
	//	if the pixel format is kCVPixelFormatType_64ARGB
	if (pbpf == 'b64a')	{
		//	this pixel format is big-endian, so we have to convert it to little-endian before it'll be recognizable in metal...
		MTLImgBuffer		*rawTex = [[MTLPool global] bufferForCVMTLTex:metalTexRef sized:baseTexSize];
		CFRelease(metalTexRef);
		if (rawTex == nil)	{
			NSLog(@"ERR: raw tex nil for YCbCr in %s",__func__);
			return nil;
		}
		
		if (shotIsAnamorphic)	{
			MTLImgBuffer		*rgbaTex = [[MTLPool global] rgbaFloatTexSized:baseTexSize];
			MTLImgBuffer		*fixedTex = [[MTLPool global] rgbaFloatTexSized:actualTexSize];
			if (rgbaTex==nil || fixedTex==nil)	{
				NSLog(@"ERR: unable to allocate intermed tex for A b64a in %s",__func__);
				return nil;
			}
			
			//id<MTLCommandQueue>		cmdQueue = [RenderProperties global].bgCmdQueue;
			id<MTLCommandBuffer>	cmdBuffer = (inCB != nil) ? inCB : [[RenderProperties global].bgCmdQueue commandBuffer];
			MTLPoolConv			*conv = [self _getConvObject];
			
			[conv.proresConv convertColorsOfImg:rawTex renderToImg:rgbaTex inCommandBuffer:cmdBuffer];
			[conv.anamorphicConv
				applyAnamorphicValue:[AnamorphicValue createWithRatio:inAR]
				toImg:rgbaTex
				renderToImg:fixedTex
				inCommandBuffer:cmdBuffer];
		
			[cmdBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
				MTLImgBuffer		*tmpTexA = rgbaTex;
				MTLImgBuffer		*tmpTexB = fixedTex;
				
				if (inCompletionHandler != nil)
					inCompletionHandler(fixedTex);
				
				tmpTexA = nil;
				tmpTexB = nil;
				
				[self _returnConvObject:conv];
			}];
			
			//	if we weren't passed a command buffer, we're free to commit the command buffer we created...
			if (inCB == nil)
				[cmdBuffer commit];
			
			//	if (there's no completion handler) AND (we weren't given a command buffer), we should wait for the command buffer to complete...
			if (inCompletionHandler == nil && inCB == nil)	{
				[cmdBuffer waitUntilCompleted];
				rgbaTex = nil;
				return fixedTex;
			}
			//	else this method was passed either a completion handler or a command buffer...
			else	{
				//	if this method was passed a command buffer then it's likely that other objects will want to use the texture we generated here in the command buffer...
				if (inCB != nil)	{
					rgbaTex = nil;
					return fixedTex;
				}
				//	else this method wasn't passed a command buffer- it created its own command buffer, but it's returning immediately, so we have to return nil...
				else	{
					rgbaTex = nil;
					fixedTex = nil;
					return nil;
				}
			}
		}
		else	{
			MTLImgBuffer		*usefulTex = [[MTLPool global] rgbaFloatTexSized:baseTexSize];
			if (usefulTex == nil)	{
				NSLog(@"ERR: unable to allocate intermed tex for NA b64a in %s",__func__);
				return nil;
			}
			
			//id<MTLCommandQueue>		cmdQueue = [RenderProperties global].bgCmdQueue;
			id<MTLCommandBuffer>	cmdBuffer = (inCB != nil) ? inCB : [[RenderProperties global].bgCmdQueue commandBuffer];
			MTLPoolConv			*conv = [self _getConvObject];
			
			[conv.proresConv convertColorsOfImg:rawTex renderToImg:usefulTex inCommandBuffer:cmdBuffer];
	
			[cmdBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
				//NSLog(@"\t\tavf color conversion cmd buffer completed");
				MTLImgBuffer		*tmpTexA = usefulTex;
				
				if (inCompletionHandler != nil)
					inCompletionHandler(usefulTex);
				
				tmpTexA = nil;
				
				[self _returnConvObject:conv];
			}];
			
			//	if we weren't passed a command buffer, we're free to commit the command buffer we created...
			if (inCB == nil)
				[cmdBuffer commit];
			
			//	if (there's no completion handler) AND (we weren't given a command buffer), we should wait for the command buffer to complete...
			if (inCompletionHandler == nil && inCB == nil)	{
				[cmdBuffer waitUntilCompleted];
				return usefulTex;
			}
			//	else this method was passed either a completion handler or a command buffer...
			else	{
				//	if this method was passed a command buffer then it's likely that other objects will want to use the texture we generated here in the command buffer...
				if (inCB != nil)	{
					return usefulTex;
				}
				//	else this method wasn't passed a command buffer- it created its own command buffer, but it's returning immediately, so we have to return nil...
				else	{
					usefulTex = nil;
					return nil;
				}
			}
			
		}
	}
	else if (pbpf == '2vuy' || pbpf == 'yuvs' || pbpf == 'yuvf')	{
		MTLImgBuffer		*rawTex = [[MTLPool global] bufferForCVMTLTex:metalTexRef sized:baseTexSize];
		CFRelease(metalTexRef);
		if (rawTex == nil)	{
			NSLog(@"ERR: raw tex nil for YCbCr in %s",__func__);
			return nil;
		}
	
		if (shotIsAnamorphic)	{
			
			MTLImgBuffer		*rgbaTex = [[MTLPool global] rgbaFloatTexSized:baseTexSize];
			MTLImgBuffer		*fixedTex = [[MTLPool global] rgbaFloatTexSized:actualTexSize];
			if (rgbaTex==nil || fixedTex==nil)	{
				NSLog(@"ERR: unable to allocate intermed tex for A YCbCr in %s",__func__);
				return nil;
			}
			
			//id<MTLCommandQueue>		cmdQueue = [RenderProperties global].bgCmdQueue;
			id<MTLCommandBuffer>	cmdBuffer = (inCB != nil) ? inCB : [[RenderProperties global].bgCmdQueue commandBuffer];
			MTLPoolConv			*conv = [self _getConvObject];
			
			[conv.commonConv convertColorsOfImg:rawTex renderToImg:rgbaTex inCommandBuffer:cmdBuffer];
			
			[conv.anamorphicConv
				applyAnamorphicValue:[AnamorphicValue createWithRatio:inAR]
				toImg:rgbaTex
				renderToImg:fixedTex
				inCommandBuffer:cmdBuffer];
	
			[cmdBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
				MTLImgBuffer		*tmpTexA = rgbaTex;
				MTLImgBuffer		*tmpTexB = fixedTex;
				
				if (inCompletionHandler != nil)
					inCompletionHandler(fixedTex);
				
				tmpTexA = nil;
				tmpTexB = nil;
				
				[self _returnConvObject:conv];
			}];
			
			//	if we weren't passed a command buffer, we're free to commit the command buffer we created...
			if (inCB == nil)
				[cmdBuffer commit];
			
			//	if (there's no completion handler) AND (we weren't given a command buffer), we should wait for the command buffer to complete...
			if (inCompletionHandler == nil && inCB == nil)	{
				[cmdBuffer waitUntilCompleted];
				rgbaTex = nil;
				return fixedTex;
			}
			//	else this method was passed either a completion handler or a command buffer...
			else	{
				//	if this method was passed a command buffer then it's likely that other objects will want to use the texture we generated here in the command buffer...
				if (inCB != nil)	{
					rgbaTex = nil;
					return fixedTex;
				}
				//	else this method wasn't passed a command buffer- it created its own command buffer, but it's returning immediately, so we have to return nil...
				else	{
					rgbaTex = nil;
					fixedTex = nil;
					return nil;
				}
			}
			
		}
		else	{
			
			MTLImgBuffer		*usefulTex = [[MTLPool global] rgbaFloatTexSized:baseTexSize];
			if (usefulTex == nil)	{
				NSLog(@"ERR: unable to allocate intermed tex for NA YCbCr in %s",__func__);
				return nil;
			}
			
			//id<MTLCommandQueue>		cmdQueue = [RenderProperties global].bgCmdQueue;
			id<MTLCommandBuffer>	cmdBuffer = (inCB != nil) ? inCB : [[RenderProperties global].bgCmdQueue commandBuffer];
			MTLPoolConv			*conv = [self _getConvObject];
			
			[conv.commonConv convertColorsOfImg:rawTex renderToImg:usefulTex inCommandBuffer:cmdBuffer];
			
			[cmdBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
				//NSLog(@"\t\tavf color conversion cmd buffer completed");
				MTLImgBuffer		*tmpTexA = usefulTex;
				
				if (inCompletionHandler != nil)
					inCompletionHandler(usefulTex);
				
				tmpTexA = nil;
				
				[self _returnConvObject:conv];
			}];
			
			//	if we weren't passed a command buffer, we're free to commit the command buffer we created...
			if (inCB == nil)
				[cmdBuffer commit];
			
			//	if (there's no completion handler) AND (we weren't given a command buffer), we should wait for the command buffer to complete...
			if (inCompletionHandler == nil && inCB == nil)	{
				[cmdBuffer waitUntilCompleted];
				return usefulTex;
			}
			//	else this method was passed either a completion handler or a command buffer...
			else	{
				//	if this method was passed a command buffer then it's likely that other objects will want to use the texture we generated here in the command buffer...
				if (inCB != nil)	{
					return usefulTex;
				}
				//	else this method wasn't passed a command buffer- it created its own command buffer, but it's returning immediately, so we have to return nil...
				else	{
					usefulTex = nil;
					return nil;
				}
			}
			
		}
	}
	else	{
		MTLImgBuffer		*rawTex = [[MTLPool global] bufferForCVMTLTex:metalTexRef sized:baseTexSize];
		CFRelease(metalTexRef);
		if (rawTex == nil)	{
			NSLog(@"ERR: raw tex nil for unspec in %s",__func__);
			return nil;
		}
		
		if (shotIsAnamorphic)	{
			
			MTLImgBuffer		*usefulTex = [[MTLPool global] rgbaFloatTexSized:actualTexSize];
			if (usefulTex == nil)	{
				NSLog(@"ERR: unable to allocate intermed tex for NA YCbCr in %s",__func__);
				return nil;
			}
			
			//id<MTLCommandQueue>		cmdQueue = [RenderProperties global].bgCmdQueue;
			id<MTLCommandBuffer>	cmdBuffer = (inCB != nil) ? inCB : [[RenderProperties global].bgCmdQueue commandBuffer];
			MTLPoolConv			*conv = [self _getConvObject];
			
			[conv.anamorphicConv
				applyAnamorphicValue:[AnamorphicValue createWithRatio:inAR]
				toImg:rawTex
				renderToImg:usefulTex
				inCommandBuffer:cmdBuffer];
	
			[cmdBuffer addCompletedHandler:^(id<MTLCommandBuffer> cb)	{
				MTLImgBuffer		*tmpTexA = usefulTex;
				
				if (inCompletionHandler != nil)
					inCompletionHandler(usefulTex);
				
				tmpTexA = nil;
				
				[self _returnConvObject:conv];
			}];
			
			//	if we weren't passed a command buffer, we're free to commit the command buffer we created...
			if (inCB == nil)
				[cmdBuffer commit];
			
			//	if (there's no completion handler) AND (we weren't given a command buffer), we should wait for the command buffer to complete...
			if (inCompletionHandler == nil && inCB == nil)	{
				[cmdBuffer waitUntilCompleted];
				return usefulTex;
			}
			//	else this method was passed either a completion handler or a command buffer...
			else	{
				//	if this method was passed a command buffer then it's likely that other objects will want to use the texture we generated here in the command buffer...
				if (inCB != nil)	{
					return usefulTex;
				}
				//	else this method wasn't passed a command buffer- it created its own command buffer, but it's returning immediately, so we have to return nil...
				else	{
					usefulTex = nil;
					return nil;
				}
			}
			
		}
		else	{
			if (inCompletionHandler != nil)
				inCompletionHandler(rawTex);
			return rawTex;
		}
	}
	
	
	//return nil;
}
*/


@end
