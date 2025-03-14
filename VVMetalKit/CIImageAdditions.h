/*
 *  CIImageAdditions.h
 *  VDMX
 *
 *  Created by bagheera on 10/6/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#import <VVMetalKit/VVMetalKit.h>




/**		This class addition allows a CIImage to retain an instance of VVMTLTextureImage- it uses objective-c runtime functions to create a strong ref between the CIImage and an
*/




@interface CIImage (CIImageAdditions)

///	This property is retained for the lifetime of the CIImage
@property (strong) id<VVMTLTextureImage> backingVVMTLTextureImage;

@end
