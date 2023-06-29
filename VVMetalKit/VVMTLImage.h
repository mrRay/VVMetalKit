//
//  VVMTLImage.h
//  VVMetalKit
//
//  Created by testadmin on 6/23/23.
//

#ifndef MTLImage_h
#define MTLImage_h

@protocol VVMTLImage;




/*		Describes how the contents of a GPU asset portray an image
*/




@protocol VVMTLImage

@property (assign,readwrite) NSUInteger width;	//	width of the GPU asset
@property (assign,readwrite) NSUInteger height;	//	height of the GPU asset
@property (assign,readwrite) NSRect srcRect;	//	defines a rectangular region of the GPU asset (origin is in bottom left).  the "image" consists of the texture data within this region.  usually the full width/height, but you can do texture atlas stuff, too.  if your texture is flipped vertically, you need to adjust this srcRect to take the flippedness into account.
@property (assign,readwrite) BOOL flipH;	//	whether or not the image data in 'srcRect' needs to be flipped horizontally when being sampled or displayed
@property (assign,readwrite) BOOL flipV;	//	whether or not the image data in 'srcRect' needs to be flipped vertically when being sampled or displayed

@end




#endif /* MTLImage_h */
