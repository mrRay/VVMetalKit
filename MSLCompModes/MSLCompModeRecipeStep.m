//
//  MSLCompModeRecipeStep.m
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import "MSLCompModeRecipeStep.h"




@implementation MSLCompModeRecipeStep

- (id) copyWithZone:(NSZone *)z	{
	MSLCompModeRecipeStep		*returnMe = [[MSLCompModeRecipeStep alloc] init];
	memcpy( returnMe->verts, verts, sizeof(verts) );
	returnMe.img = self.img;
	return returnMe;
}

- (BOOL) isEqual:(id)n	{
	if (n == nil)
		return NO;
	if (![(NSObject*)n isMSLCompModeRecipeStep])
		return NO;
	MSLCompModeRecipeStep		*recast = (MSLCompModeRecipeStep *)n;
	for (int i=0; i<4; ++i)	{
		MSLCompModeQuadVertex		*myVert = verts + i;
		MSLCompModeQuadVertex		*otherVert = recast->verts + i;
		
		for (int j=0; j<2; ++j)	{
			if (myVert->position[j] != otherVert->position[j])
				return NO;
			if (myVert->texCoord[j] != otherVert->texCoord[j])
				return NO;
		}
		if (myVert->srcRect.origin.x != otherVert->srcRect.origin.x
		|| myVert->srcRect.origin.y != otherVert->srcRect.origin.y
		|| myVert->srcRect.size.width != otherVert->srcRect.size.width
		|| myVert->srcRect.size.height != otherVert->srcRect.size.height
		|| myVert->flipH != otherVert->flipH
		|| myVert->flipV != otherVert->flipV
		|| myVert->opacity != otherVert->opacity
		|| myVert->texIndex != otherVert->texIndex
		|| myVert->compModeIndex != otherVert->compModeIndex)
		{
			return NO;
		}
	}
	return YES;
}
- (BOOL) isEqualTo:(id)n	{
	return [self isEqual:n];
}

- (BOOL) isMSLCompModeRecipeStep	{
	return YES;
}

- (void) dumpToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffset	{
	NSLog(@"%s ... %d",__func__,inOffset);
	//	don't check, just dump- the recipe would have already checked...
	uint8_t			*baseWPtr = outBuffer.contents;
	uint8_t			*wPtr = baseWPtr + inOffset;
	size_t			localOffset = inOffset;
	size_t			vertexSize = sizeof(MSLCompModeQuadVertex);
	for (int i=0; i<4; ++i)	{
		memcpy( wPtr, &verts[i], vertexSize );
		wPtr += vertexSize;
		localOffset += vertexSize;
	}
}

@end




@implementation NSObject (MSLCompModeRecipeStepNSObjectAdditions)

- (BOOL) isMSLCompModeRecipeStep	{
	return NO;
}

@end
