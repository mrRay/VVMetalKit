//
//  MSLCompModeController.m
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import "MSLCompModeController.h"
#import "MSLCompMode.h"
#import "MSLCompModeControllerResource.h"
#import <VVMetalKit/VVMetalKit.h>




NSString * const kMSLCompModeReloadNotificationName = @"kMSLCompModeReloadNotificationName";




@interface MSLCompModeController ()
@property (strong) NSMutableArray<NSURL*> * assetURLs;	//	these are either URLs to comp mode shaders or directories containing comp mode shaders.  contents refreshed when "reload" is called.
@property (strong,readwrite) NSArray<MSLCompMode*> * compModes;
@property (strong,readwrite) NSArray<MSLCompModeControllerResource*> * resources;
- (void) _reload;
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
		[self _reload];
	}
	return self;
}


- (void) addCompModeDirectoryURL:(NSURL *)n	{
	if (n == nil)
		return;
	
	@synchronized (self)	{
		if (![_assetURLs containsObject:n])	{
			[_assetURLs addObject:n];
			[self _reload];
		}
	}
}
- (void) addCompModeURL:(NSURL *)n	{
	if (n == nil)
		return;
	
	@synchronized (self)	{
		if (![_assetURLs containsObject:n])	{
			[_assetURLs addObject:n];
			[self _reload];
		}
	}
}


//	reloads the list of comp modes, re-scanning any directories and checking to make sure that individually-added comp modes still exist
- (void) reload	{
	@synchronized (self)	{
		[self _reload];
	}
}
- (void) _reload	{
	NSLog(@"%s",__func__);
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
					[localCompModes addObject:compMode];
				}
			}
		}
	}
	
	//	sort the comp modes
	[localCompModes sortUsingComparator:^(MSLCompMode *a, MSLCompMode *b)	{
		return [a.name caseInsensitiveCompare:b.name];
	}];
	_compModes = [NSArray arrayWithArray:localCompModes];
	NSLog(@"\t\tcompModes are %@",_compModes);
	
	
	
	//	re-generate the shader source code
	NSMutableString		*shaderFunctionDeclarations = [[NSMutableString alloc] init];
	NSMutableString		*shaderFunctionDefinitions = [[NSMutableString alloc] init];
	
	for (MSLCompMode * compMode in localCompModes)	{
		[shaderFunctionDeclarations appendString:compMode.functionDeclarations];
		[shaderFunctionDeclarations appendString:@"\r"];
		[shaderFunctionDefinitions appendString:compMode.functions];
		[shaderFunctionDefinitions appendString:@"\r"];
	}
	
	
	
	
	//	this is the base string for the shader (as a multi-line c++ string).  we're going to modify it until we've got the final shader
	const char		*shaderBaseCStr = R"(
#include <metal_stdlib>
using namespace metal;

#include "MSLCompModeSceneShaderTypes.h"




typedef struct	{
	float4			position [[ position ]];
	uint16_t		vertexID [[ flat ]];	//	the index of the buffer corresponding to this fragment
	//MSLCompModeQuadVertex		vertexData;
	float2			texCoord;	//	interpolated & normalized
} MSLCompModeSceneRasterizerData;


typedef struct	{
	texture2d<float>		texture;	//	has an implicit id of 0
} MSLCompModeSceneTexture;




PUT_FUNCTION_DECLARATIONS_HERE




vertex MSLCompModeSceneRasterizerData MSLCompModeControllerVtxFunc(
	uint vertexID [[ vertex_id ]],
	constant MSLCompModeQuadVertex * inVerts [[ buffer(MSLCompModeScene_VS_Index_Verts) ]],
	constant float4x4 * inMVP [[ buffer(MSLCompModeScene_VS_Index_MVPMatrix) ]])
{
	MSLCompModeSceneRasterizerData		returnMe;
	
	//returnMe.vertexData = inVerts[vertexID];
	returnMe.vertexID = vertexID;
	returnMe.texCoord = inVerts[vertexID].texCoord;
	
	//float4x4		mvp = float4x4(*inMVP);
	//float4			pos = float4(inVerts[vertexID].position, 0, 1);
	//returnMe.position = mvp * pos;
	returnMe.position = *inMVP * float4(inVerts[vertexID].position,0,1);
	
	return returnMe;
}




fragment float4 MSLCompModeControllerFrgFunc(
	MSLCompModeSceneRasterizerData inRasterData [[ stage_in ]],
	
	//device ushort& textureCount [[ buffer(0) ]],
	//device SingleTexture* textures [[ buffer(1) ]],
	
	device MSLCompModeQuadVertex * verts [[ buffer(0) ]],
	device MSLCompModeSceneTexture * textures [[ buffer(1) ]],
	
	float4 baseCanvasColor [[ color(0) ]] )
{
	//return float4(1,0,0,1);
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
	//	the shader #includes "MSLCompModeSceneShaderTypes.h", which we have to manually load into a string 
	NSBundle			*libBundle = [NSBundle bundleForClass:[MSLCompModeController class]];
	NSURL				*libBundleURL = libBundle.bundleURL;
	NSURL				*shaderTypeDataURL = [[libBundleURL URLByAppendingPathComponent:@"Headers"] URLByAppendingPathComponent:@"MSLCompModeSceneShaderTypes.h"];
	NSString			*shaderTypeData = [NSString stringWithContentsOfFile:shaderTypeDataURL.path encoding:NSUTF8StringEncoding error:&nsErr];
	//NSLog(@"shaderTypeData is %@",shaderTypeData);
	
	libBundle = [NSBundle bundleForClass:[MTLPool class]];
	libBundleURL = libBundle.bundleURL;
	NSURL				*sizingToolTypeDataURL = [[libBundleURL URLByAppendingPathComponent:@"Headers"] URLByAppendingPathComponent:@"SizingToolTypes.h"];
	NSString			*sizingToolTypeData = [NSString stringWithContentsOfFile:sizingToolTypeDataURL.path encoding:NSUTF8StringEncoding error:&nsErr];
	//NSLog(@"sizingToolTypeData is %@",sizingToolTypeData);
	
	[shaderBaseString replaceOccurrencesOfString:@"#include \"MSLCompModeSceneShaderTypes.h\""
		withString:shaderTypeData
		options:NSLiteralSearch
		range:NSMakeRange(0,shaderBaseString.length)];
	[shaderBaseString replaceOccurrencesOfString:@"#import <VVMetalKit/SizingToolTypes.h>"
		withString:sizingToolTypeData
		options:NSLiteralSearch
		range:NSMakeRange(0,shaderBaseString.length)];
	
	
	//NSLog(@"************ shaderBaseString is:");
	//NSLog(@"%@",shaderBaseString);
	//NSLog(@"************");
	
	
	
	
	
	//	make the resources objects, which compiles the comp mode for every available metal device on the system
	NSMutableArray<MSLCompModeControllerResource*>		*localResources = [[NSMutableArray alloc] init];
	NSArray<id<MTLDevice>>		*metalDevices = MTLCopyAllDevices();
	//NSLog(@"metal devices are %@",metalDevices);
	for (id<MTLDevice> metalDevice in metalDevices)	{
		MSLCompModeControllerResource		*resource = [MSLCompModeControllerResource createWithDevice:metalDevice shaderSrc:shaderBaseString];
		if (resource != nil)
			[localResources addObject:resource];
	}
	_resources = [NSArray arrayWithArray:localResources];
	
	
	//	post a notification that we've reloaded the list of comp modes 
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter]
			postNotificationName:kMSLCompModeReloadNotificationName
			object:self
			userInfo:nil];
	});
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


- (MSLCompModeControllerResource *) resourceForDevice:(id<MTLDevice>)n	{
	if (n == nil)
		return nil;
	@synchronized (self)	{
		for (MSLCompModeControllerResource * resource in _resources)	{
			id<MTLDevice>		tmpDevice = resource.device;
			if (tmpDevice == n || [tmpDevice isEqual:n])
				return resource;
		}
	}
	return nil;
}


@end
