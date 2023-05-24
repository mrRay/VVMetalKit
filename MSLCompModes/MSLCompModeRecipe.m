//
//  MSLCompModeRecipe.m
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import "MSLCompModeRecipe.h"
#import "MSLCompModeRecipeStep.h"




@implementation MSLCompModeRecipe

- (instancetype) init	{
	self = [super init];
	if (self != nil)	{
		_steps = [[NSMutableArray alloc] init];
	}
	return self;
}

- (id) copyWithZone:(NSZone *)z	{
	MSLCompModeRecipe		*returnMe = [[MSLCompModeRecipe alloc] init];
	[returnMe.steps addObjectsFromArray:self.steps];
	return returnMe;
}

- (BOOL) isEqual:(id)n	{
	if (n == nil)
		return NO;
	if (![(NSObject*)n isMSLCompModeRecipe])
		return NO;
	MSLCompModeRecipe		*recast = (MSLCompModeRecipe *)n;
	return [self.steps isEqualToArray:recast.steps];
}
- (BOOL) isEqualTo:(id)n	{
	return [self isEqual:n];
}

- (BOOL) isMSLCompModeRecipe	{
	return YES;
}

- (size_t) minBufferLength	{
	static size_t	quadSize = sizeof(MSLCompModeQuadVertex) * 4;
	size_t			localBufferSize = quadSize * self.steps.count;
	return localBufferSize;
}

- (void) dumpToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffset	{
	NSLog(@"%s ... %d",__func__,inOffset);
	if (outBuffer == nil)
		return;
	if ( (inOffset + self.minBufferLength) > outBuffer.length )	{
		NSLog(@"ERR: attempted out of bounds write, %s",__func__);
		return;
	}
	static size_t	quadSize = sizeof(MSLCompModeQuadVertex) * 4;
	size_t			localOffset = inOffset;
	for (MSLCompModeRecipeStep * step in self.steps)	{
		[step dumpToBuffer:outBuffer atOffset:localOffset];
		localOffset += quadSize;
	}
}

@end




@implementation NSObject (MSLCompModeRecipeNSObjectAdditions)

- (BOOL) isMSLCompModeRecipe	{
	return NO;
}

@end
