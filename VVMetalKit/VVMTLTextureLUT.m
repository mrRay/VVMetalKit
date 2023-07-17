//
//  VVMTLTextureLUT.m
//  VVMetalKit
//
//  Created by testadmin on 7/12/23.
//

#import "VVMTLTextureLUT.h"




@interface VVMTLTextureLUT ()
//	if you use NSCopying to copy a texture/lut, this is the original instance from which your copy derives
//	if you make a copy of a copy of a copy or a copy, this will still point to the original texture
//	all copies share the same underlying GPU resource, but may have different extrinsic properties (srcRect, mainly)
@property (strong,readwrite,nullable) VVMTLTextureLUT * srcTexLUT;
@end




@implementation VVMTLTextureLUT

+ (instancetype) createWithDescriptor:(VVMTLTextureLUTDescriptor *)n	{
	return [[VVMTLTextureLUT alloc] initWithDescriptor:n];
}

- (instancetype) initWithDescriptor:(VVMTLTextureLUTDescriptor *)n	{
	self = [super init];
	if (n == nil)
		self = nil;
	if (self != nil)	{
		//	VVMTLTextureLUT conformance
		texture = nil;
		
		buffer = nil;
		
		//	VVMTLLUT conformance
		order = n.order;
		size = n.size;
		
		//	VVMTLRecycleable conformance
		pool = nil;
		preferDeletion = NO;
		recycleCount = 0;
		descriptor = [n copy];
		supportingObject = nil;
		supportingContext = NULL;
		deletionBlock = nil;
		//deletionBlock = ^(id<VVMTLRecycleable> recycled)	{
		//	VVMTLTextureImage		*recast = (VVMTLTextureImage*)blah;
		//	if (recast == nil)
		//		return;
		//};
	}
	return self;
}
- (BOOL) isVVMTLTextureLUT	{
	return YES;
}

#pragma mark - VVMTLTextureLUT conformance

@synthesize texture;
@synthesize buffer;

#pragma mark - NSCopying conformance

- (id) copyWithZone:(NSZone *)z	{
	VVMTLTextureLUT		*returnMe = [[VVMTLTextureLUT allocWithZone:z] initWithDescriptor:(VVMTLTextureLUTDescriptor*)descriptor];
	VVMTLTextureLUT		*srcTex = (_srcTexLUT != nil) ? _srcTexLUT : self;
	
	//	VVMTLTextureImage conformance
	returnMe.texture = srcTex.texture;
	returnMe.buffer = nil;
	returnMe.srcTexLUT = srcTex;	//	make sure the copy retains the src!
	
	//	VVMTLLUT conformance
	returnMe.order = srcTex.order;
	returnMe.size = srcTex.size;
	
	//	VVMTLRecycleable conformance
	returnMe.pool = srcTex.pool;
	returnMe.preferDeletion = YES;	//	we just wait to delete the copy immediately (it will retain the original)
	returnMe.recycleCount = 0;
	returnMe.descriptor = [(NSObject*)srcTex.descriptor copy];
	returnMe.supportingObject = nil;	//	do not copy any of the supporting stuff- the original's handling all this.
	returnMe.supportingContext = nil;
	returnMe.deletionBlock = nil;
	
	return returnMe;
}

#pragma mark - VVMTLLUT conformance

@synthesize order;
@synthesize size;

#pragma mark - VVMTLRecycleable conformance

@synthesize pool;
@synthesize preferDeletion;
@synthesize recycleCount;
@synthesize descriptor;
@synthesize supportingObject;
@synthesize supportingContext;
@synthesize deletionBlock;

@end








@implementation NSObject (VVMTLTextureLUTNSObjectAdditions)
- (BOOL) isVVMTLTextureLUT	{
	return NO;
}
@end

