//
//  MSLCompModeRecipe.h
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>

@class MSLCompModeRecipeStep;

NS_ASSUME_NONNULL_BEGIN




/*		data container class- holds an array of MSLCompModeRecipeStep instances, each of which describes a quad to be composited
*/




@interface MSLCompModeRecipe : NSObject <NSCopying>
@property (strong,readonly) NSMutableArray<MSLCompModeRecipeStep*> * steps;
@property (readonly) size_t minVertexBufferLength;
@property (readonly) size_t minProjectionMatrixBufferLength;
- (void) dumpVertexDataToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffset;
- (void) dumpProjectionMatricesToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffset;
@end




@interface NSObject (MSLCompModeRecipeNSObjectAdditions)
@property (readonly) BOOL isMSLCompModeRecipe;
@end




NS_ASSUME_NONNULL_END
