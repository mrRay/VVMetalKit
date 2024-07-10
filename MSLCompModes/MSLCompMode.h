//
//  MSLCompMode.h
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN




/*		Data container class, represents a comp mode on disk.
		- RAII, parses function declarations and function contents on init from file at provided URL
		- comp modes are generally tracked in-app "by name", which is derived from the name of the file ('name' property)
		- the 'isEqual:' method only compares the 'name' properties for equality!
*/




@interface MSLCompMode : NSObject

+ (instancetype) createWithURL:(NSURL *)n;

- (instancetype) initWithURL:(NSURL *)n;

@property (strong,readonly) NSURL * url;	//	filepath to the comp mode as a NSURL
@property (strong,readonly) NSString * name;	//	last filepath component, minus extension. may have whitespace!
@property (strong,readonly) NSString * funcName;	//	the name of the function (usually "name" with any whitespace chars stripped)
@property (strong,readonly) NSString * functionDeclarations;	//	the function declarations as they'll be added to the shader source code
@property (strong,readonly) NSString * functions;	//	the function contents as they'll be added to the shader source code
@property (strong,readonly) NSString * compModeSwitchStatementFuncPtrs;	//	this string is meant to be inserted into the shader when generating it
@property (readwrite) uint16_t compModeIndex;	//	WHATEVER CREATES THE COMP MODE IS RESPONSIBLE FOR SETTING THIS.  uniquely identifies this composition mode numerically, which is necessary when describing which comp mode to use to shaders

@end




@interface NSObject (MSLCompModeNSObjectAdditions)
@property (readonly) BOOL isMSLCompMode;
@end




NS_ASSUME_NONNULL_END
