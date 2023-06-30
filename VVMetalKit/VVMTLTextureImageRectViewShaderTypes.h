//
//  VVMTLTextureImageRectViewShaderTypes.h
//  VVMetalKit
//
//  Created by testadmin on 6/29/23.
//

#ifndef VVMTLTextureImageRectViewShaderTypes_h
#define VVMTLTextureImageRectViewShaderTypes_h


#import <TargetConditionals.h>
#if defined(TARGET_OS_IOS) && TARGET_OS_IOS==1
#include <VVMetalKitTouch/SizingToolTypes.h>
#include <VVMetalKitTouch/VVMTLTextureImageShaderTypes.h>
#else
#include <VVMetalKit/SizingToolTypes.h>
#include <VVMetalKit/VVMTLTextureImageShaderTypes.h>
#endif




typedef enum VVMTLTextureImageRectView_VS_Index	{
	VVMTLTextureImageRectView_VS_Index_Verts = 0,	//	geometry data formatted as 'VVMTLTextureImageRectViewVertex'
	VVMTLTextureImageRectView_VS_Index_MVPMatrix		//	a 4x4 matrix describing the (concatenated) model/view/projection matrix
} VVMTLTextureImageRectView_VS_Index;




typedef enum VVMTLTextureImageRectView_FS_Index	{
	VVMTLTextureImageRectView_FS_Index_Color = 0,	//	texture to be displayed
	VVMTLTextureImageRectView_FS_Index_Geo	//	VVMTLTextureImageStruct describing how/where to draw the texture (there are four of these structs at this index)
} VVMTLTextureImageRectView_FS_Index;




typedef struct	{
	vector_float2		position;
} VVMTLTextureImageRectViewVertex;


#endif /* VVMTLTextureImageRectViewShaderTypes_h */
