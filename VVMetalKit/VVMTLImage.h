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




/*		Describes how the contents of a GPU asset portray an image
*/




@protocol VVMTLImage

@property (assign,readwrite) NSUInteger width;	//	width of the GPU asset
@property (assign,readwrite) NSUInteger height;	//	height of the GPU asset
@property (readonly) NSSize size;	//	the size of the GPU asset.  read-only, basically just creates an NSSize from 'width' and 'height'
@property (assign,readwrite) NSRect srcRect;	//	defines a rectangular region of the GPU asset (origin is in bottom left).  the "image" consists of the texture data within this region.  usually the full width/height, but you can do texture atlas stuff, too.  if your texture is flipped vertically, you need to adjust this srcRect to take the flippedness into account.
@property (assign,readwrite) BOOL flipH;	//	whether or not the image data in 'srcRect' needs to be flipped horizontally when being sampled or displayed
@property (assign,readwrite) BOOL flipV;	//	whether or not the image data in 'srcRect' needs to be flipped vertically when being sampled or displayed
@property (readonly) CGImagePropertyOrientation cgImagePropertyOrientation;	//	the orientation of the texture as you look at the texture
@property (readonly) CGImagePropertyOrientation CIImagePropertyOrientation;	//	CIImage needs us to pretend textures that are upside-down are really right-side-up- I don't know why, but I'm assuming it has something to do with Metal using the top-left corner of the image as its origin.

@end




#endif /* MTLImage_h */
