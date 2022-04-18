#import "MTLImgBuffer.h"
#import <Accelerate/Accelerate.h>
#import "TargetConditionals.h"

#import "MTLPool.h"
#import "MTLImgBufferShaderTypes.h"
#import "MTLImgBufferAdditions_Private.h"




#define TIMEDESC(n) CMTimeCopyDescription(kCFAllocatorDefault,n)

#if TARGET_OS_IOS
#define NSMakeRect CGRectMake
#endif




@implementation NSObject (MTLImgBufferNSObjectAdditions)
- (BOOL) isMTLImgBuffer	{
	return NO;
}
@end




@interface MTLImgBuffer ()
//	if you use NSCopying to copy a buffer, this is the original instance from which your copy derives
//	if you make a copy of a copy of a copy of a copy, this will still point to the "original" MTLImgBuffer
@property (strong,nullable) MTLImgBuffer * srcBuffer;
@end




@implementation MTLImgBuffer

- (instancetype) init	{
	self = [super init];
	if (self != nil)	{
		_texture = nil;
		_buffer = nil;
		_bufferBytesPerRow = 0;
		_width = 0;
		_height = 0;
		_size = CGSizeMake(_width, _height);
		_srcRect = NSMakeRect(0,0,_width,_height);
		_flipped = NO;
		_preferDeletion = NO;
		_checkCount = 0;
		_time = kCMTimeInvalid;
		_duration = kCMTimeInvalid;
		_parentPool = nil;
		_supportingObject = nil;
		_supportingContext = nil;
		_destroyBlock = nil;
		_iosfc = nil;
		_cvpb = nil;
		_srcBuffer = nil;
	}
	return self;
}
- (void) dealloc	{
	//NSLog(@"%s ... %@",__func__,self);
	if (_preferDeletion || self.srcBuffer != nil)	{
		_texture = nil;
		_buffer = nil;
		
		if (_destroyBlock != nil)
			_destroyBlock(self);
		
	}
	else	{
		[_parentPool _returnToPool:self];
	}
	
	//	release the supporting object and clear out the supporting context
	_supportingObject = nil;
	_supportingContext = NULL;
	//	if there's an IOSurface/CVPixelBufferRef, toss those now
	if (_iosfc != NULL)	{
		IOSurfaceDecrementUseCount(_iosfc);
		CFRelease(_iosfc);
		_iosfc = NULL;
	}
	if (_cvpb != NULL)	{
		CVPixelBufferRelease(_cvpb);
		_cvpb = NULL;
	}
}


@synthesize width=_width;
- (void) setWidth:(NSUInteger)n	{
	_width = n;
	_size.width = n;
}
- (NSUInteger) width	{
	return _width;
}

@synthesize height=_height;
- (void) setHeight:(NSUInteger)n	{
	_height = n;
	_size.height = n;
}
- (NSUInteger) height	{
	return _height;
}

@synthesize size=_size;
- (void) setSize:(CGSize)n	{
	_size = n;
	_width = _size.width;
	_height = _size.height;
}
- (CGSize) size	{
	return _size;
}


- (NSString *) description	{
	//return [NSString stringWithFormat:@"<MTLImgBuffer, %@- %@>",self.texture.label,NSStringFromRect(self.srcRect)];
	
	//if (CGSizeEqualToSize(_size,myDisplaySize))
	//	return [NSString stringWithFormat:@"<MTLImgBuffer, %@- %ld x %ld>",self.texture.label,(unsigned long)_width,(unsigned long)_height];
	//else
	//	return [NSString stringWithFormat:@"<MTLImgBuffer, %@- %ld x %ld (%ld x %ld)>",self.texture.label,(unsigned long)_width,(unsigned long)_height,(unsigned long)myDisplayWidth,(unsigned long)myDisplayHeight];
	
	//return [NSString stringWithFormat:@"<MTLImgBuffer, %@- %@>",self.texture.label,TIMEDESC(self.time)];
	
	if (_buffer!=nil && _texture==nil)	{
		return [NSString stringWithFormat:@"<MTLImgBuffer, B %ld>",_buffer.length];
	}
	
	return [NSString stringWithFormat:@"<MTLImgBuffer, %@, %d x %d>", self.texture.label, (int)self.size.width, (int)self.size.height];
}


- (void) populateStruct:(struct MTLImgBufferStruct *)n	{
	if (n==nil)
		return;
	n->srcRect.origin.x = round(self.srcRect.origin.x);
	n->srcRect.origin.y = round(self.srcRect.origin.y);
	n->srcRect.size.width = round(self.srcRect.size.width);
	n->srcRect.size.height = round(self.srcRect.size.height);
	n->flipped = self.flipped;
}


#pragma mark - NSCopying


- (id) copyWithZone:(NSZone*)zone	{
	MTLImgBuffer	*tmpSelf = self;
	//	if 'supportingObject' is a MTLImgBuffer
	MTLImgBuffer	*tmp = [[[tmpSelf class] allocWithZone:zone] init];
	
	tmp.texture = _texture;
	tmp.buffer = _buffer;
	tmp.bufferBytesPerRow = _bufferBytesPerRow;
	tmp.width = _width;	//	don't bother manually copying these, 'size' will populate these ivars
	tmp.height = _height;
	tmp.size = _size;
	tmp.flipped = _flipped;
	tmp.preferDeletion = _preferDeletion;
	tmp.checkCount = 0;
	tmp.time = _time;
	tmp.duration = _duration;
	
	tmp.srcRect = _srcRect;
	
	tmp.parentPool = _parentPool;
	
	tmp.supportingObject = _supportingObject;
	tmp.supportingContext = _supportingContext;
	
	tmp.destroyBlock = nil;	//	nil b/c 'srcBuffer' retains the MTLImgBuffer we were copied from...
	
	//tmp.iosfc = (_iosfc==NULL) ? NULL : (IOSurfaceRef)CFRetain(_iosfc);
	if (_iosfc == NULL)	{
		tmp.iosfc = NULL;
	}
	else	{
		tmp.iosfc = (IOSurfaceRef)CFRetain(_iosfc);
		IOSurfaceIncrementUseCount(_iosfc);
	}
	
	tmp.cvpb = (_cvpb==NULL) ? NULL : (CVPixelBufferRef)CVPixelBufferRetain(_cvpb);
	
	//	retain the original buffer that contains the resources we're using here
	tmp.srcBuffer = (_srcBuffer!=nil) ? _srcBuffer : tmpSelf;
	
	return tmp;
}


#pragma mark - MTLImgBuffer_Private protocol


- (instancetype) initByRecycling:(MTLImgBuffer *)n	{
	self = [super init];
	
	if (n == nil)	{
		NSLog(@"ERR: bailing, passed was nil, %s",__func__);
		self = nil;
	}
	//	if the passed buffer prefers deletion, we shouldn't be here- don't do anything that would retain it
	if (n.preferDeletion)	{
		NSLog(@"ERR: bailing, passed prefers deletion, %s",__func__);
		self = nil;
	}
	//	if the passed buffer is basically just a reference to another buffer, we shouldn't be here- don't do anything that would retain it
	if (n.srcBuffer != nil)	{
		NSLog(@"ERR: bailing, passed is just a ref, %s",__func__);
		self = nil;
	}
	
	if (self != nil)	{
		//	copy all the properties from the instance we were passed...
		_texture = n.texture;
		_buffer = n.buffer;
		_bufferBytesPerRow = n.bufferBytesPerRow;
		_width = n.width;
		_height = n.height;
		_size = n.size;
		_flipped = n.flipped;
		_preferDeletion = NO;	//	if it was 'YES', we would be returning nil here
		_checkCount = 0;
		_time = kCMTimeInvalid;	//	do NOT copy any of the timing info!
		_duration = kCMTimeInvalid;
		
		_srcRect = n.srcRect;
		_parentPool = n.parentPool;
		_supportingObject = n.supportingObject;
		_supportingContext = n.supportingContext;
		_destroyBlock = n.destroyBlock;
		
		//_iosfc = (n.iosfc==NULL) ? NULL : (IOSurfaceRef)CFRetain(n.iosfc);
		if (n.iosfc == NULL)	{
			_iosfc = NULL;
		}
		else	{
			_iosfc = (IOSurfaceRef)CFRetain(n.iosfc);
			IOSurfaceIncrementUseCount(_iosfc);
		}
		
		_cvpb = (n.cvpb==NULL) ? NULL : (CVPixelBufferRef)CVPixelBufferRetain(n.cvpb);
		
		_srcBuffer = nil;	//	always nil because we only recycle buffers that own their own content
		
		//	clear out some of the properties from the instance we were passed- it's going to be deallocated, and we don't want it to clean itself up yet!
		n.supportingObject = nil;
		n.supportingContext = nil;
		n.destroyBlock = nil;
	}
	
	return self;
}


#pragma mark - subclass overrides


- (BOOL) isMTLImgBuffer	{
	return YES;
}


@end
