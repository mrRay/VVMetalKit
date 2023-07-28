//
//  MSLCompMode.h
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN




/*		represents a comp mode on disk
		- comp modes are generally tracked in-app "by name", which is derived from the name of the file ('name' property)
		- calculates function declarations and function contents on init
*/




@interface MSLCompMode : NSObject

+ (instancetype) createWithURL:(NSURL *)n;

- (instancetype) initWithURL:(NSURL *)n;

@property (strong,readonly) NSURL * url;	//	filepath to the comp mode as a NSURL
@property (strong,readonly) NSString * name;	//	last filepath component, minus extension, after replacing any nonconforming chars with underscores
@property (strong,readonly) NSString * funcName;	//	the name of the function (usually "name" with any whitespace chars stripped)
@property (strong,readonly) NSString * functionDeclarations;	//	the function declarations as they'll be added to the shader source code
@property (strong,readonly) NSString * functions;	//	the function contents as they'll be added to the shader source code
@property (strong,readonly) NSString * compModeSwitchStatementFuncPtrs;	//	this string is meant to be inserted into the shader when generating it
@property (readwrite) uint16_t compModeIndex;	//	WHATEVER CREATES THE COMP MODE IS RESPONSIBLE FOR SETTING THIS.  uniquely identifies this composition mode numerically, which is necessary when describing which comp mode to use to shaders

@end




NS_ASSUME_NONNULL_END
