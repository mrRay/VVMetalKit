//
//  MSLCompModeController.m
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import "MSLCompModeController.h"
#import "MSLCompMode.h"
#import "MSLCompModeResourceController.h"
#import "MSLCompModeResource.h"
#import <VVMetalKit/VVMetalKit.h>




NSString * const kMSLCompModeReloadNotificationName = @"kMSLCompModeReloadNotificationName";




@interface MSLCompModeController ()
@property (strong) NSMutableArray<NSURL*> * assetURLs;	//	these are either URLs to comp mode shaders or directories containing comp mode shaders.  contents refreshed when "reload" is called.
@property (strong,readwrite) NSArray<MSLCompMode*> * compModes;
@property (strong,readwrite) NSArray<MSLCompModeResource*> * resources;
- (void) _reloadCompModes;
- (void) _reloadShaderSrc;
@property (strong,readwrite) MSLCompModeResourceController * rsrcCtrlrA;
@property (strong,readwrite) MSLCompModeResourceController * rsrcCtrlrB;
- (void) _populateResourceControllerA;
- (void) _populateResourceControllerB;
@end




@implementation MSLCompModeController


+ (MSLCompModeController *) global	{
	if (self != [MSLCompModeController class])	{
		NSLog(@"ERR: wrong class (%@) in %s",self,__func__);
		return nil;
	}
	
	static MSLCompModeController		*global = [[MSLCompModeController alloc] init];
	return global;
}


- (instancetype) init	{
	self = [super init];
	if (self != nil)	{
		_assetURLs = [[NSMutableArray alloc] init];
		_compModes = @[];
		_resources = @[];
		[self _populateResourceControllerA];
		[self _populateResourceControllerB];
	}
	return self;
}


- (void) _populateResourceControllerA	{
	
	_rsrcCtrlrA = [MSLCompModeResourceController create];
	_rsrcCtrlrA.reloadBlock = ^(NSArray<MSLCompMode*> *inModes)	{
		//	if we don't actually have any modes, respond appropriately...
		if (inModes==nil || inModes.count < 1)	{
			return (NSString*)nil;
		}
		
		//	re-generate the shader source code
		NSMutableString		*shaderFunctionDeclarations = [[NSMutableString alloc] init];
		NSMutableString		*shaderFunctionDefinitions = [[NSMutableString alloc] init];
		NSMutableString		*shaderCompModeSwitchCases = [[NSMutableString alloc] init];
		
		for (MSLCompMode * compMode in inModes)	{
			[shaderFunctionDeclarations appendString:compMode.functionDeclarations];
			[shaderFunctionDeclarations appendString:@"\r"];
			[shaderFunctionDefinitions appendString:compMode.functions];
			[shaderFunctionDefinitions appendString:@"\r"];
			[shaderCompModeSwitchCases appendString:compMode.compModeSwitchStatementFuncPtrs];
			[shaderCompModeSwitchCases appendString:@"\r"];
		}
		
		
		//	this is the base string for the shader (as a multi-line c++ string).  we're going to modify it until we've got the final shader
		const char		*shaderBaseCStr = R"(
#include <metal_stdlib>
using namespace metal;

#include "MSLCompModeSceneAShaderTypes.h"




typedef struct	{
	float4			position [[ position ]];
	uint16_t		vertexID [[ flat ]];	//	the index of the buffer corresponding to this fragment
	uint16_t		layerIndex [[ flat ]];	//	the index of the layer (floor(vertexID/4))
	float2			texCoord [[ sample_perspective ]];	//	interpolated & normalized
} MSLCompModeSceneRasterizerData;

typedef struct	{
	texture2d<float, access::sample>		texture;	//	has an implicit id of 0
} MSLCompModeSceneTexture;

typedef struct {
	float4		gl_FragCoord;
	float4		_VVCanvasRect;
} MSLCompModeFragData;




PUT_FUNCTION_DECLARATIONS_HERE




vertex MSLCompModeSceneRasterizerData MSLCompModeControllerVtxFunc(
	uint vertexID [[ vertex_id ]],
	constant MSLCompModeQuadVertex * inVerts [[ buffer( MSLCompModeSceneA_VS_Index_Verts ) ]],
	constant float4x4 * inMVP [[ buffer( MSLCompModeSceneA_VS_Index_MVPMatrix ) ]],
	constant MSLCompModeLayer * inLayers [[ buffer( MSLCompModeSceneA_VS_Index_Layers ) ]]
	)
{
	MSLCompModeSceneRasterizerData		returnMe;
	
	returnMe.vertexID = vertexID;
	returnMe.layerIndex = vertexID/4;
	returnMe.texCoord = inVerts[vertexID].texCoord;
	
	//	the homography projection matrix we calculated converts tex coords (the 'position' member of the vertex struct isn't actually used except when calculating the homography)
	constant MSLCompModeLayer	*targetLayer = (inLayers + returnMe.layerIndex);
	constant float4x4		*homographyProjMatrix = &targetLayer->utilityTransform;
	returnMe.position = *inMVP * *homographyProjMatrix * float4(inVerts[vertexID].texCoord, 0, 1);
	
	return returnMe;
}




fragment float4 MSLCompModeControllerFrgFunc(
	MSLCompModeSceneRasterizerData inRasterData [[ stage_in ]],
	
	device MSLCompModeLayer * inLayers [[ buffer( MSLCompModeSceneA_FS_Index_Layers ) ]],
	device MSLCompModeSceneTexture * textures [[ buffer( MSLCompModeSceneA_FS_Index_Textures ) ]],
	
	constant MSLCompModeJob * job [[ buffer( MSLCompModeSceneA_FS_Index_Job ) ]],
	
	float4 baseCanvasColor [[ color(0) ]] )
{
	MSLCompModeFragData		fragRenderData = { inRasterData.position, job->canvasRect };
	fragRenderData.gl_FragCoord.y = fragRenderData._VVCanvasRect.w - fragRenderData.gl_FragCoord.y;
	
	device MSLCompModeLayer		*layerPtr = inLayers + inRasterData.layerIndex;
	float		layerOpacity = layerPtr->opacity;
	if (layerOpacity == 0.0)
		return baseCanvasColor;
	
	//	get a ptr to the texture we're going to sample
	device MSLCompModeSceneTexture		*texStructPtr = textures + layerPtr->texIndex;
	constexpr sampler		sampler( mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel );
	float4		layerColor = texStructPtr->texture.sample( sampler, inRasterData.texCoord );
	
	//	UPDATE: these function pointers cause a metal compiler error (non-recoverable?) on some (older) hardware (with AMD GPUs).
	//	populate function pointers for the two different kinds of composition functions based on the comp mode of the vertex we're rendering
	//float4 (*CompositeTopAndBottomFuncPtr)(thread float4 &, thread float4 &, thread float &, thread MSLCompModeFragData &) = nullptr;
	//float4 (*CompositeBottomFuncPtr)(thread float4 &, thread float &, thread MSLCompModeFragData &) = nullptr;
	
	bool		isBottomLayer = (baseCanvasColor.r == 0. && baseCanvasColor.g == 0. && baseCanvasColor.b == 0. && baseCanvasColor.a == 0.);
	
	switch (layerPtr->compModeIndex)	{
PUT_SWITCH_CASES_TO_FUNC_PTRS_HERE
	}
	
	//	if something's wrong, just return opaque green for this fragment
	//if (CompositeTopAndBottomFuncPtr == nullptr || CompositeBottomFuncPtr == nullptr)	{
	//	return float4(0,0,1,1);
	//}
	
	//	figure out if this is the "bottom" layer or not, and call the appropriate composition function pointer
	//if (isBottomLayer)	{
	//	return CompositeBottomFuncPtr( layerColor, layerOpacity, fragRenderData );
	//}
	//else	{
	//	return CompositeTopAndBottomFuncPtr( baseCanvasColor, layerColor, layerOpacity, fragRenderData );
	//}
	
	return baseCanvasColor;
}




PUT_FUNCTION_DEFINITIONS_HERE

)";
		NSError				*nsErr = nil;
		NSMutableString		*shaderBaseString = [[NSString stringWithUTF8String:shaderBaseCStr] mutableCopy];
		
		[shaderBaseString
			replaceOccurrencesOfString:@"PUT_FUNCTION_DECLARATIONS_HERE"
			withString:shaderFunctionDeclarations
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		[shaderBaseString
			replaceOccurrencesOfString:@"PUT_FUNCTION_DEFINITIONS_HERE"
			withString:shaderFunctionDefinitions
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		[shaderBaseString
			replaceOccurrencesOfString:@"PUT_SWITCH_CASES_TO_FUNC_PTRS_HERE"
			withString:shaderCompModeSwitchCases
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		
		NSBundle			*libBundle = nil;
		NSURL				*libBundleURL = nil;
		
		//	the shader #includes "MSLCompModeSceneAShaderTypes.h", which we have to manually load into a string 
		libBundle = [NSBundle bundleForClass:[MSLCompModeController class]];
		libBundleURL = libBundle.bundleURL;
		NSURL				*shaderATypeDataURL = [[libBundleURL URLByAppendingPathComponent:@"Headers"] URLByAppendingPathComponent:@"MSLCompModeSceneAShaderTypes.h"];
		NSString			*shaderATypeData = [NSString stringWithContentsOfFile:shaderATypeDataURL.path encoding:NSUTF8StringEncoding error:&nsErr];
		//NSLog(@"shaderATypeData is %@",shaderATypeData);
		[shaderBaseString replaceOccurrencesOfString:@"#include \"MSLCompModeSceneAShaderTypes.h\""
			withString:shaderATypeData
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		
		//	the shader #includes "MSLCompModeSceneShaderTypes.h", which we have to manually load into a string...
		NSURL				*shaderTypeDataURL = [[libBundleURL URLByAppendingPathComponent:@"Headers"] URLByAppendingPathComponent:@"MSLCompModeSceneShaderTypes.h"];
		NSString			*shaderTypeData = [NSString stringWithContentsOfFile:shaderTypeDataURL.path encoding:NSUTF8StringEncoding error:&nsErr];
		//NSLog(@"shaderBTypeData is %@",shaderBTypeData);
		[shaderBaseString replaceOccurrencesOfString:@"#include \"MSLCompModeSceneShaderTypes.h\""
			withString:shaderTypeData
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		
		
		//	the shader #includes "SizingTool_metal.h", which we have to manually load into a string
		//libBundle = [NSBundle bundleForClass:[VVMTLPool class]];
		//libBundleURL = libBundle.bundleURL;
		//NSURL				*sizingToolMetalTypeDataURL = [[libBundleURL URLByAppendingPathComponent:@"Headers"] URLByAppendingPathComponent:@"SizingTool_metal.h"];
		//NSString			*sizingToolMetalTypeData = [NSString stringWithContentsOfFile:sizingToolMetalTypeDataURL.path encoding:NSUTF8StringEncoding error:&nsErr];
		//NSLog(@"sizingToolMetalTypeData is %@",sizingToolMetalTypeData);
		//[shaderBaseString replaceOccurrencesOfString:@"#include <VVMetalKit/SizingTool_metal.h>"
		//	withString:sizingToolMetalTypeData
		//	options:NSLiteralSearch
		//	range:NSMakeRange(0,shaderBaseString.length)];
		
		//	the shader #includes "SizingToolTypes.h", which we have to manually load into a string
		libBundle = [NSBundle bundleForClass:[VVMTLPool class]];
		libBundleURL = libBundle.bundleURL;
		NSURL				*sizingToolTypeDataURL = [[libBundleURL URLByAppendingPathComponent:@"Headers"] URLByAppendingPathComponent:@"SizingToolTypes.h"];
		NSString			*sizingToolTypeData = [NSString stringWithContentsOfFile:sizingToolTypeDataURL.path encoding:NSUTF8StringEncoding error:&nsErr];
		//NSLog(@"sizingToolTypeData is %@",sizingToolTypeData);
		[shaderBaseString replaceOccurrencesOfString:@"#include <VVMetalKit/SizingToolTypes.h>"
			withString:sizingToolTypeData
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		
		return [NSString stringWithString:shaderBaseString];
	};
	
}
- (void) _populateResourceControllerB	{
	
	_rsrcCtrlrB = [MSLCompModeResourceController create];
	_rsrcCtrlrB.reloadBlock = ^(NSArray<MSLCompMode*> *inModes)	{
		//	if we don't actually have any modes, respond appropriately...
		if (inModes==nil || inModes.count < 1)	{
			return (NSString*)nil;
		}
		
		//	re-generate the shader source code
		NSMutableString		*shaderFunctionDeclarations = [[NSMutableString alloc] init];
		NSMutableString		*shaderFunctionDefinitions = [[NSMutableString alloc] init];
		NSMutableString		*shaderCompModeSwitchCases = [[NSMutableString alloc] init];
		
		for (MSLCompMode * compMode in inModes)	{
			[shaderFunctionDeclarations appendString:compMode.functionDeclarations];
			[shaderFunctionDeclarations appendString:@"\r"];
			[shaderFunctionDefinitions appendString:compMode.functions];
			[shaderFunctionDefinitions appendString:@"\r"];
			[shaderCompModeSwitchCases appendString:compMode.compModeSwitchStatementFuncPtrs];
			[shaderCompModeSwitchCases appendString:@"\r"];
		}
		
		
		//	this is the base string for the shader (as a multi-line c++ string).  we're going to modify it until we've got the final shader
		const char		*shaderBaseCStr = R"(
#include <metal_stdlib>
using namespace metal;

#include "MSLCompModeSceneBShaderTypes.h"




typedef struct	{
	float4			position [[ position ]];
	float2			texCoord [[ sample_perspective ]];	//	interpolated & normalized
} MSLCompModeSceneRasterizerData;

typedef struct	{
	texture2d<float, access::sample>		texture;	//	has an implicit id of 0
} MSLCompModeSceneTexture;

typedef struct {
	float4		gl_FragCoord;
	float4		_VVCanvasRect;
} MSLCompModeFragData;




static inline float MaxX(thread GRect & inRect)	{
	if (inRect.size.width > 0.)
		return inRect.origin.x + inRect.size.width;
	else
		return inRect.origin.x;
}
static inline float MinX(thread GRect & inRect)	{
	if (inRect.size.width > 0.)
		return inRect.origin.x;
	else
		return inRect.origin.x + inRect.size.width;
}
static inline float MaxY(thread GRect & inRect)	{
	if (inRect.size.height > 0.)
		return inRect.origin.y + inRect.size.height;
	else
		return inRect.origin.y;
}
static inline float MinY(thread GRect & inRect)	{
	if (inRect.size.height > 0.)
		return inRect.origin.y;
	else
		return inRect.origin.y + inRect.size.height;
}

static inline bool PointInRect(GPoint inPoint, GRect inRect)	{
	if (inPoint.x < MinX(inRect) || inPoint.x > MaxX(inRect))
		return false;
	if (inPoint.y < MinY(inRect) || inPoint.y > MaxY(inRect))
		return false;
	return true;
}




PUT_FUNCTION_DECLARATIONS_HERE




vertex MSLCompModeSceneRasterizerData MSLCompModeControllerVtxFunc(
	uint vertexID [[ vertex_id ]],
	constant MSLCompModeQuadVertex * inVerts [[ buffer( MSLCompModeSceneB_VS_Index_Verts ) ]],
	constant float4x4 * inMVP [[ buffer( MSLCompModeSceneB_VS_Index_MVPMatrix ) ]]
	)
{
	MSLCompModeSceneRasterizerData		returnMe;
	
	//	the MVP is an orthogonal transform that incldues the 'canvasBounds' property of MSLCompModeScene. we're 
	//	drawing a single, full-frame quad, and the texture coordinates of the vertexes are the same as the vertex 
	//	position geometry.  this lets us have the vertex shader do the texture coordinate interpolation- and the 
	//	fragment shader can just read the 'texCoord' property from the rasterizer data, which will be the 
	//	coordinates in "canvas" coordinate space that need to be rendered at that fragment.
	
	returnMe.position = *inMVP * float4(inVerts[vertexID].position, 0, 1);
	
	returnMe.texCoord = inVerts[vertexID].texCoord;
	
	return returnMe;
}




fragment float4 MSLCompModeControllerFrgFunc(
	MSLCompModeSceneRasterizerData inRasterData [[ stage_in ]],
	
	device MSLCompModeLayer * inLayers [[ buffer( MSLCompModeSceneB_FS_Index_Layers ) ]],
	device MSLCompModeSceneTexture * textures [[ buffer( MSLCompModeSceneB_FS_Index_Textures ) ]],
	
	constant MSLCompModeJob * job [[ buffer( MSLCompModeSceneB_FS_Index_Job ) ]])
{
	
	//	assemble the structure we'll pass to the comp modes we need to check...
	MSLCompModeFragData		fragRenderData = { inRasterData.position, job->canvasRect };
	fragRenderData.gl_FragCoord.y = fragRenderData._VVCanvasRect.w - fragRenderData.gl_FragCoord.y;
	
	//	run through the layers, calculating composition color at this fragment
	float4		baseCanvasColor = float4(0., 0., 0., 0.);
	for (int i=0; i<job->layerCount; ++i)
	{
		device MSLCompModeLayer		*layerPtr = inLayers + i;
		
		//	first of all, if the layer's opacity is 0, we can skip it.
		float		layerOpacity = layerPtr->opacity;
		if (layerOpacity <= 0.)	{
			continue;
		}
		
		//	convert the local fragment coords to texture coords using the 'utilityTransform'
		device float4x4		*homographyProjMatrix = &layerPtr->utilityTransform;
		//float4		layerTexCoordsAtThisFrag = *homographyProjMatrix * fragRenderData.gl_FragCoord;
		float4		layerTexCoordsAtThisFrag = *homographyProjMatrix * float4(inRasterData.texCoord.xy, 0., 1.);
		
		//	if this point is NOT within the layer's srcRect for this texture, we can skip composition...
		if ( !PointInRect( (GPoint){ layerTexCoordsAtThisFrag.x, layerTexCoordsAtThisFrag.y }, layerPtr->srcRect ) )	{
			continue;
		}
		
		//	get a ptr to the texture we're going to sample, sample the texture at the coords for this fragment
		device MSLCompModeSceneTexture		*texStructPtr = textures + layerPtr->texIndex;
		constexpr sampler		sampler( mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel );
		float4		layerColor = texStructPtr->texture.sample( sampler, layerTexCoordsAtThisFrag.xy );
		
		bool		isBottomLayer = (baseCanvasColor.r == 0. && baseCanvasColor.g == 0. && baseCanvasColor.b == 0. && baseCanvasColor.a == 0.);
		switch (layerPtr->compModeIndex)	{
PUT_SWITCH_CASES_TO_FUNC_PTRS_HERE
		}
		
	}
	
	return baseCanvasColor;
	
}




PUT_FUNCTION_DEFINITIONS_HERE

)";
		NSError				*nsErr = nil;
		NSMutableString		*shaderBaseString = [[NSString stringWithUTF8String:shaderBaseCStr] mutableCopy];
		
		[shaderBaseString
			replaceOccurrencesOfString:@"PUT_FUNCTION_DECLARATIONS_HERE"
			withString:shaderFunctionDeclarations
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		[shaderBaseString
			replaceOccurrencesOfString:@"PUT_FUNCTION_DEFINITIONS_HERE"
			withString:shaderFunctionDefinitions
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		[shaderBaseString
			replaceOccurrencesOfString:@"PUT_SWITCH_CASES_TO_FUNC_PTRS_HERE"
			withString:shaderCompModeSwitchCases
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		
		//	the shader #includes "MSLCompModeSceneBShaderTypes.h", which we have to manually load into a string 
		NSBundle			*libBundle = [NSBundle bundleForClass:[MSLCompModeController class]];
		NSURL				*libBundleURL = libBundle.bundleURL;
		NSURL				*shaderBTypeDataURL = [[libBundleURL URLByAppendingPathComponent:@"Headers"] URLByAppendingPathComponent:@"MSLCompModeSceneBShaderTypes.h"];
		NSString			*shaderBTypeData = [NSString stringWithContentsOfFile:shaderBTypeDataURL.path encoding:NSUTF8StringEncoding error:&nsErr];
		//NSLog(@"shaderBTypeData is %@",shaderBTypeData);
		[shaderBaseString replaceOccurrencesOfString:@"#include \"MSLCompModeSceneBShaderTypes.h\""
			withString:shaderBTypeData
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		
		//	the shader #includes "MSLCompModeSceneShaderTypes.h", which we have to manually load into a string...
		NSURL				*shaderTypeDataURL = [[libBundleURL URLByAppendingPathComponent:@"Headers"] URLByAppendingPathComponent:@"MSLCompModeSceneShaderTypes.h"];
		NSString			*shaderTypeData = [NSString stringWithContentsOfFile:shaderTypeDataURL.path encoding:NSUTF8StringEncoding error:&nsErr];
		//NSLog(@"shaderBTypeData is %@",shaderBTypeData);
		[shaderBaseString replaceOccurrencesOfString:@"#include \"MSLCompModeSceneShaderTypes.h\""
			withString:shaderTypeData
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		
		/*
		//	the shader #includes "SizingTool_metal.h", which we have to manually load into a string
		libBundle = [NSBundle bundleForClass:[VVMTLPool class]];
		libBundleURL = libBundle.bundleURL;
		NSURL				*sizingToolMetalTypeDataURL = [[libBundleURL URLByAppendingPathComponent:@"Headers"] URLByAppendingPathComponent:@"SizingTool_metal.h"];
		NSString			*sizingToolMetalTypeData = [NSString stringWithContentsOfFile:sizingToolMetalTypeDataURL.path encoding:NSUTF8StringEncoding error:&nsErr];
		//NSLog(@"sizingToolMetalTypeData is %@",sizingToolMetalTypeData);
		[shaderBaseString replaceOccurrencesOfString:@"#include <VVMetalKit/SizingTool_metal.h>"
			withString:sizingToolMetalTypeData
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		*/
		//	the shader #includes "SizingToolTypes.h", which we have to manually load into a string
		libBundle = [NSBundle bundleForClass:[VVMTLPool class]];
		libBundleURL = libBundle.bundleURL;
		NSURL				*sizingToolTypeDataURL = [[libBundleURL URLByAppendingPathComponent:@"Headers"] URLByAppendingPathComponent:@"SizingToolTypes.h"];
		NSString			*sizingToolTypeData = [NSString stringWithContentsOfFile:sizingToolTypeDataURL.path encoding:NSUTF8StringEncoding error:&nsErr];
		//NSLog(@"sizingToolTypeData is %@",sizingToolTypeData);
		[shaderBaseString replaceOccurrencesOfString:@"#include <VVMetalKit/SizingToolTypes.h>"
			withString:sizingToolTypeData
			options:NSLiteralSearch
			range:NSMakeRange(0,shaderBaseString.length)];
		
		return [NSString stringWithString:shaderBaseString];
		
	};
	
}


- (void) setCompModeDirectoryURLs:(NSArray<NSURL*> *)n	{
	if (n == nil || n.count < 1)
		return;
	
	@synchronized (self)	{
		[_assetURLs removeAllObjects];
		for (NSURL * url in n)	{
			if (![_assetURLs containsObject:url])	{
				[_assetURLs addObject:url];
			}
		}
		[self _reloadCompModes];
		[self _reloadShaderSrc];
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter]
			postNotificationName:kMSLCompModeReloadNotificationName
			object:self
			userInfo:nil];
	});
}
- (void) addCompModeDirectoryURL:(NSURL *)n	{
	if (n == nil)
		return;
	
	BOOL			postNotification = NO;
	@synchronized (self)	{
		if (![_assetURLs containsObject:n])	{
			[_assetURLs addObject:n];
			[self _reloadCompModes];
			[self _reloadShaderSrc];
			postNotification = YES;
		}
	}
	
	if (postNotification)	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter]
				postNotificationName:kMSLCompModeReloadNotificationName
				object:self
				userInfo:nil];
		});
	}
}
- (void) addCompModeURL:(NSURL *)n	{
	if (n == nil)
		return;
	
	BOOL			postNotification = NO;
	@synchronized (self)	{
		if (![_assetURLs containsObject:n])	{
			[_assetURLs addObject:n];
			[self _reloadCompModes];
			[self _reloadShaderSrc];
			postNotification = YES;
		}
	}
	
	if (postNotification)	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter]
				postNotificationName:kMSLCompModeReloadNotificationName
				object:self
				userInfo:nil];
		});
	}
}


//	reloads the list of comp modes, re-scanning any directories and checking to make sure that individually-added comp modes still exist
- (void) reload	{
	@synchronized (self)	{
		[self _reloadCompModes];
		[self _reloadShaderSrc];
	}
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter]
			postNotificationName:kMSLCompModeReloadNotificationName
			object:self
			userInfo:nil];
	});
}
- (void) _reloadCompModes	{
	//NSLog(@"%s",__func__);
	if (_assetURLs == nil || _assetURLs.count < 1)	{
		return;
	}
	
	//	clear the comp modes
	NSMutableArray<MSLCompMode*>		*localCompModes = [[NSMutableArray alloc] init];
	
	//	run through the assets, creating comp modes
	NSFileManager		*fm = [NSFileManager defaultManager];
	for (NSURL * assetURL in _assetURLs)	{
		BOOL		isDir = NO;
		if (![fm fileExistsAtPath:assetURL.path isDirectory:&isDir])
			continue;
		
		if (!isDir)	{
			MSLCompMode		*compMode = [MSLCompMode createWithURL:assetURL];
			if (compMode != nil)	{
				NSUInteger		existingIndex = [localCompModes indexOfObject:compMode];
				if (existingIndex != NSNotFound)
					[localCompModes removeObjectAtIndex:existingIndex];
				[localCompModes addObject:compMode];
			}
		}
		else	{
			NSError			*nsErr = nil;
			NSArray<NSURL*>		*urls = [fm
				contentsOfDirectoryAtURL:assetURL
				includingPropertiesForKeys:nil
				options:NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsHiddenFiles
				error:&nsErr];
			for (NSURL * url in urls)	{
				MSLCompMode		*compMode = [MSLCompMode createWithURL:url];
				if (compMode != nil)	{
					NSUInteger		existingIndex = [localCompModes indexOfObject:compMode];
					if (existingIndex != NSNotFound)
						[localCompModes removeObjectAtIndex:existingIndex];
					[localCompModes addObject:compMode];
				}
			}
		}
	}
	
	//	sort the comp modes
	[localCompModes sortUsingComparator:^(MSLCompMode *a, MSLCompMode *b)	{
		return [a.name caseInsensitiveCompare:b.name];
	}];
	//	give the comp modes indexes so we can associate a vertex's comp mode with a given func ptr
	int			tmpIndex = 0;
	for (MSLCompMode * compMode in localCompModes)	{
		compMode.compModeIndex = tmpIndex;
		++tmpIndex;
	}
	self.compModes = [NSArray arrayWithArray:localCompModes];
	//NSLog(@"\t\tcompModes are %@",_compModes);
}
- (void) _reloadShaderSrc	{
	//NSLog(@"%s",__func__);
	[_rsrcCtrlrA reload];
	[_rsrcCtrlrB reload];
}


@synthesize compModes=_compModes;
- (void) setCompModes:(NSArray<MSLCompMode*> *)n	{
	@synchronized (self)	{
		_compModes = (n==nil) ? @[] : n;
	}
}
- (NSArray<MSLCompMode*> *) compModes	{
	NSArray		*returnMe = nil;
	@synchronized (self)	{
		returnMe = [NSArray arrayWithArray:_compModes];
	}
	return returnMe;
}


- (MSLCompMode *) compModeWithName:(NSString *)n	{
	if (n == nil)
		return nil;
	@synchronized (self)	{
		for (MSLCompMode * compMode in _compModes)	{
			NSString		*tmpName = compMode.name;
			if ([tmpName localizedCaseInsensitiveCompare:n] == NSOrderedSame)	{
				return compMode;
			}
		}
	}
	return nil;
}
- (MSLCompMode *) compModeWithIndex:(uint16_t)n	{
	@synchronized (self)	{
		if (n >= _compModes.count)
			return nil;
		return _compModes[n];
	}
}


@end
