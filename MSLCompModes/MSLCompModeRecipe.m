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

- (size_t) minVertexBufferLength	{
	const size_t	quadSize = sizeof(MSLCompModeQuadVertex) * 4;
	const size_t	localBufferSize = quadSize * self.steps.count;
	return localBufferSize;
}

- (size_t) minProjectionMatrixBufferLength	{
	const size_t	matrixSize = sizeof( simd_float4x4 );
	const size_t	localBufferSize = matrixSize * self.steps.count;
	return localBufferSize;
}

- (void) dumpVertexDataToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffset	{
	//NSLog(@"%s ... %d",__func__,inOffset);
	if (outBuffer == nil)
		return;
	if ( (inOffset + self.minVertexBufferLength) > outBuffer.length )	{
		NSLog(@"ERR: attempted out of bounds write, %s",__func__);
		return;
	}
	
	const size_t	quadSize = sizeof(MSLCompModeQuadVertex) * 4;
	size_t			localOffset = inOffset;
	int				tmpLayerIndex = 0;
	for (MSLCompModeRecipeStep * step in self.steps)	{
		
		[step dumpVertexDataToBuffer:outBuffer atOffset:localOffset];
		
		localOffset += quadSize;
		++tmpLayerIndex;
	}
}

//- (void) dumpLayerDataToBuffer:(id<MTLBuffer>)outBuffer texToGeo:(BOOL)inTexToGeo atOffset:(size_t)inOffset	{
//	if (outBuffer == nil)
//		return;
//	if ( (inOffset + self.minProjectionMatrixBufferLength) > outBuffer.length )	{
//		NSLog(@"ERR: attempted out of bounds write, %s",__func__);
//		return;
//	}
//	const size_t	layerSize = sizeof( MSLCompModeLayer );
//	size_t		localOffset = inOffset;
//	for (MSLCompModeRecipeStep * step in self.steps)	{
//		[step dumpLayerDataToBuffer:outBuffer texToGeo:inTexToGeo atOffset:localOffset];
//		localOffset += layerSize;
//	}
//}

- (void) dumpTexToGeoProjectionMatricesToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffset	{
	if (outBuffer == nil)
		return;
	if ( (inOffset + self.minProjectionMatrixBufferLength) > outBuffer.length )	{
		NSLog(@"ERR: attempted out of bounds write, %s",__func__);
		return;
	}
	const size_t	matrixSize = sizeof( simd_float4x4 );
	size_t			localOffset = inOffset;
	for (MSLCompModeRecipeStep * step in self.steps)	{
		[step dumpTexToGeoMatrixToBuffer:outBuffer atOffset:localOffset];
		localOffset += matrixSize;
	}
}
- (void) dumpGeoToTexProjectionMatricesToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffset	{
	if (outBuffer == nil)
		return;
	if ( (inOffset + self.minProjectionMatrixBufferLength) > outBuffer.length )	{
		NSLog(@"ERR: attempted out of bounds write, %s",__func__);
		return;
	}
	const size_t	matrixSize = sizeof( simd_float4x4 );
	size_t			localOffset = inOffset;
	for (MSLCompModeRecipeStep * step in self.steps)	{
		[step dumpGeoToTexMatrixToBuffer:outBuffer atOffset:localOffset];
		localOffset += matrixSize;
	}
}

@end




@implementation NSObject (MSLCompModeRecipeNSObjectAdditions)

- (BOOL) isMSLCompModeRecipe	{
	return NO;
}

@end
