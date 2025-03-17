//
//  VVMTLLUT.h
//  VVMetalKit
//
//  Created by testadmin on 7/12/23.
//

#ifndef VVMTLLUT_h
#define VVMTLLUT_h

@protocol VVMTLLUT;




/**		Describes how the contents of a GPU asset portray a LUT
*/




@protocol VVMTLLUT

@property (assign,readwrite) uint8_t order;
@property (assign,readwrite) MTLSize size;

@end




#endif /* VVMTLLUT_h */
