//
//  MSLCompModeRecipeStep.h
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>

#import <MSLCompModes/MSLCompModeSceneShaderTypes.h>

@protocol VVMTLTextureImage;
@class MSLCompMode;

NS_ASSUME_NONNULL_BEGIN




/*		this class represents a single step (a single "layer", which is really a single "quad").
		it is a data structure class- it doesn't really interact with much directly, and mainly just stores values that it generates from higher-level parameters
*/




@interface MSLCompModeRecipeStep : NSObject <NSCopying>	{
	@public
	MSLCompModeQuadVertex		verts[4];	//	coordinate order is BL - TL - BR - TR.  THE ORDER MATTERS, homography matrices are calculated using the position cords (WHICH NEED TO BE IN THIS ORDER) & srcRect/flipH/flipV vals (from which the points are extracted in the expected order).
}

//	setting this also populates the 'texCoord' members of the verts automatically using the 'srcRect', 'flipH', and 'flipV' properties of the img
@property (strong) id<VVMTLTextureImage> img;

//	if you don't use this then you'll need to populate the vertex positions manually
- (void) populateVertexPositionsWithRect:(NSRect)n;
- (void) populateVertexPositionsWithRectFlippedVertically:(NSRect)n;
//	if you don't use this then the vertex opacities will default to 1.0
//- (void) populateVertexOpacities:(float)n;

- (BOOL) populateCompModeWithName:(NSString *)n;
- (BOOL) populateCompModeWithIndex:(uint16_t)n;
- (BOOL) populateWithCompMode:(MSLCompMode *)n;

//	copies the vertex data stored locally to the passed buffer at the passed offset
- (void) dumpVertexDataToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffsetInBytes;
//- (void) dumpLayerDataToBuffer:(id<MTLBuffer>)outBuffer texToGeo:(BOOL)inTexToGeo atOffset:(size_t)inOffset;

//	calculates the projection matrix necessary to display the specified region of the receiver's 'img' texture as a quad with the receiver's 'verts' coordinates and writes it to the passed buffer at the passed offset
- (void) dumpTexToGeoMatrixToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffsetInBytes;
- (void) dumpGeoToTexMatrixToBuffer:(id<MTLBuffer>)outBuffer atOffset:(size_t)inOffsetInBytes;

@property (assign,readwrite) float opacity;	//	this gets written to the struct
@property (assign,readwrite) uint16_t compModeIndex;	//	this gets written to the struct

@end




@interface NSObject (MSLCompModeRecipeStepNSObjectAdditions)
@property (readonly) BOOL isMSLCompModeRecipeStep;
@end




NS_ASSUME_NONNULL_END
