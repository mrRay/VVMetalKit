//
//  MSLCompModeRecipeStep.h
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>

#import <MSLCompModes/MSLCompModeSceneShaderTypes.h>

@class MTLImgBuffer;

NS_ASSUME_NONNULL_BEGIN




/*		this class represents a single step (a single "layer", which is really a single "quad").
		it is a data structure class- it doesn't really interact with much directly, and mainly just stores values
*/




@interface MSLCompModeRecipeStep : NSObject <NSCopying>	{
	@public
	MSLCompModeQuadVertex		verts[4];
}
@property (strong) MTLImgBuffer * img;
- (void) dumpToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffset;
@end




@interface NSObject (MSLCompModeRecipeStepNSObjectAdditions)
@property (readonly) BOOL isMSLCompModeRecipeStep;
@end




NS_ASSUME_NONNULL_END
