#import "MTLImgBuffer.h"
#import <Accelerate/Accelerate.h>

#import "MTLPool.h"
#import "MTLImgBufferShaderTypes.h"
#import "MTLImgBufferAdditions_Private.h"



#define TIMEDESC(n) CMTimeCopyDescription(kCFAllocatorDefault,n)




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
		self.texture = nil;
		self.buffer = nil;
		self.bufferBytesPerRow = 0;
		self.width = 0;
		self.height = 0;
		self.size = CGSizeMake(self.width, self.height);
		self.srcRect = NSMakeRect(0,0,self.width,self.height);
		self.flipped = NO;
		self.preferDeletion = NO;
		self.checkCount = 0;
		self.parentPool = nil;
		self.supportingObject = nil;
		self.supportingContext = nil;
		self.destroyBlock = nil;
		self.iosfc = nil;
		self.cvpb = nil;
		self.srcBuffer = nil;
	}
	return self;
}
- (void) dealloc	{
	//NSLog(@"%s ... %@",__func__,self);
	if (_preferDeletion || self.srcBuffer != nil)	{
		self.texture = nil;
		self.buffer = nil;
		
		if (self.destroyBlock != nil)
			self.destroyBlock(self);
		
	}
	else	{
		[self.parentPool _returnToPool:self];
	}
	
	//	release the supporting object and clear out the supporting context
	self.supportingObject = nil;
	self.supportingContext = NULL;
	//	if there's an IOSurface/CVPixelBufferRef, toss those now
	if (self.iosfc != NULL)	{
		CFRelease(self.iosfc);
		self.iosfc = NULL;
	}
	if (self.cvpb != NULL)	{
		CVPixelBufferRelease(self.cvpb);
		self.cvpb = NULL;
	}
}


@synthesize width=myWidth;
- (void) setWidth:(NSUInteger)n	{
	myWidth = n;
	mySize.width = n;
}
- (NSUInteger) width	{
	return myWidth;
}

@synthesize height=myHeight;
- (void) setHeight:(NSUInteger)n	{
	myHeight = n;
	mySize.height = n;
}
- (NSUInteger) height	{
	return myHeight;
}

@synthesize size=mySize;
- (void) setSize:(CGSize)n	{
	mySize = n;
	myWidth = mySize.width;
	myHeight = mySize.height;
}
- (CGSize) size	{
	return mySize;
}


- (NSString *) description	{
	//return [NSString stringWithFormat:@"<MTLImgBuffer, %@- %@>",self.texture.label,NSStringFromRect(self.srcRect)];
	
	//if (CGSizeEqualToSize(mySize,myDisplaySize))
	//	return [NSString stringWithFormat:@"<MTLImgBuffer, %@- %ld x %ld>",self.texture.label,(unsigned long)myWidth,(unsigned long)myHeight];
	//else
	//	return [NSString stringWithFormat:@"<MTLImgBuffer, %@- %ld x %ld (%ld x %ld)>",self.texture.label,(unsigned long)myWidth,(unsigned long)myHeight,(unsigned long)myDisplayWidth,(unsigned long)myDisplayHeight];
	
	//return [NSString stringWithFormat:@"<MTLImgBuffer, %@- %@>",self.texture.label,TIMEDESC(self.time)];
	
	return [NSString stringWithFormat:@"<MTLImgBuffer, %@, %d x %d>", self.texture.label, (int)self.size.width, (int)self.size.height];
}


- (void) populateStruct:(struct MTLImgBufferStruct *)n	{
	if (n==nil)
		return;
	n->srcRect.origin.x = round(self.srcRect.origin.x);
	n->srcRect.origin.y = round(self.srcRect.origin.y);
	n->srcRect.size.width = round(self.srcRect.size.width);
	n->srcRect.size.height = round(self.srcRect.size.height);
}


#pragma mark - NSCopying


- (id) copyWithZone:(NSZone*)zone	{
	MTLImgBuffer	*tmpSelf = self;
	//	if 'supportingObject' is a MTLImgBuffer
	MTLImgBuffer	*tmp = [[[tmpSelf class] allocWithZone:zone] init];
	
	tmp.texture = tmpSelf.texture;
	tmp.buffer = tmpSelf.buffer;
	tmp.bufferBytesPerRow = tmpSelf.bufferBytesPerRow;
	tmp.width = tmpSelf.width;	//	don't bother manually copying these, 'size' will populate these ivars
	tmp.height = tmpSelf.height;
	tmp.size = tmpSelf.size;
	tmp.flipped = tmpSelf.flipped;
	tmp.preferDeletion = tmpSelf.preferDeletion;
	tmp.checkCount = 0;
	tmp.time = tmpSelf.time;
	
	tmp.srcRect = tmpSelf.srcRect;
	
	tmp.parentPool = tmpSelf.parentPool;
	
	tmp.supportingObject = tmpSelf.supportingObject;
	tmp.supportingContext = tmpSelf.supportingContext;
	
	tmp.destroyBlock = nil;	//	nil b/c 'srcBuffer' retains the MTLImgBuffer we were copied from...
	
	tmp.iosfc = (tmpSelf.iosfc==NULL) ? NULL : (IOSurfaceRef)CFRetain(tmpSelf.iosfc);
	tmp.cvpb = (tmpSelf.cvpb==NULL) ? NULL : (CVPixelBufferRef)CVPixelBufferRetain(tmpSelf.cvpb);
	
	//	retain the original buffer that contains the resources we're using here
	tmp.srcBuffer = (tmpSelf.srcBuffer!=nil) ? tmpSelf.srcBuffer : tmpSelf;
	
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
		self.texture = n.texture;
		self.buffer = n.buffer;
		self.bufferBytesPerRow = n.bufferBytesPerRow;
		self.width = n.width;
		self.height = n.height;
		self.size = n.size;
		self.flipped = n.flipped;
		self.preferDeletion = NO;	//	if it was 'YES', we would be returning nil here
		self.checkCount = 0;
		self.time = kCMTimeZero;	//	do NOT copy the time!
		
		self.srcRect = n.srcRect;
		self.parentPool = n.parentPool;
		self.supportingObject = n.supportingObject;
		self.supportingContext = n.supportingContext;
		self.destroyBlock = n.destroyBlock;
		
		self.iosfc = (n.iosfc==NULL) ? NULL : (IOSurfaceRef)CFRetain(n.iosfc);
		self.cvpb = (n.cvpb==NULL) ? NULL : (CVPixelBufferRef)CVPixelBufferRetain(n.cvpb);
		
		self.srcBuffer = nil;	//	always nil because we only recycle buffers that own their own content
		
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
