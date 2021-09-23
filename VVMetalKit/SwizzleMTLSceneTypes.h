//
//  SwizzleMTLSceneTypes.h
//  VVMetalKit
//
//  Created by testAdmin on 9/22/21.
//

#ifndef SwizzleMTLSceneTypes_h
#define SwizzleMTLSceneTypes_h


typedef enum SwizzlePF	{
	SwizzlePF_RGBA_UI_8 = 'RGBA',	//	8 bit unsigned int per channel (32 bits per pixel)
	//SwizzlePF_BGRA_UI_8 = 'BGRA',
	SwizzlePF_RGBA_FP_32 = 'RGfA',	//	32 bit float per channel (128 bits per pixel)
	SwizzlePF_UYVY_422_UI_8 = '2vuy',
	SwizzlePF_UYVY_422_UI_10 = 'v210',
} SwizzlePF;


typedef struct	{
	uint32_t		inputPF;
	uint32_t		outputPF;
} SwizzleShaderInfo;


typedef enum SwizzleShaderArg	{
	SwizzleShaderArg_SrcImg,
	SwizzleShaderArg_DstImg,
	SwizzleShaderArg_Info
} SwizzleShaderArg;


#endif /* SwizzleMTLSceneTypes_h */
