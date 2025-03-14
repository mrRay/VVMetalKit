//
//  VVMTLImage.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLImage_h
#define MTLImage_h

#import <ImageIO/ImageIO.h>

@protocol VVMTLImage;




/**		This protocol defines properties necessary to describe an image- it's assumed that the image is backed by a Metal texture
*/




@protocol VVMTLImage

///	The width of the GPU asset
@property (assign,readwrite) NSUInteger width;
///	The height of the GPU asset
@property (assign,readwrite) NSUInteger height;
///	The size of the GPU asset- equivalent dimensions to the width and height properties, just expressed as a size for convenience.
@property (readonly) NSSize size;
///	Defines a rectangular region of the GPU asset (origin is in bottom left of the texture).  The "image" consists of the texture data within this region.  Usually the full width/height, but you can do texture atlas stuff, too.  If your texture is flipped vertically, you need to adjust this srcRect to take the flippedness into account- you also need to make use of the 'flipV' property to indicate that the image within 'srcRect' is flipped.
@property (assign,readwrite) NSRect srcRect;
///	Whether or not the image data in 'srcRect' needs to be flipped horizontally when being sampled or displayed
@property (assign,readwrite) BOOL flipH;
///	Whether or not the image data in 'srcRect' needs to be flipped vertically when being sampled or displayed
@property (assign,readwrite) BOOL flipV;
///	The orientation of the texture as you look at the texture.  This property is read-only, and is derived from the values of the 'flipH' and 'flipV' properties.
@property (readonly) CGImagePropertyOrientation cgImagePropertyOrientation;
///	CIImage needs us to pretend textures that are upside-down are really right-side-up- I don't know why, but I'm assuming it has something to do with Metal using the top-left corner of the image as its origin.
@property (readonly) CGImagePropertyOrientation CIImagePropertyOrientation;

@end




#endif /* MTLImage_h */
