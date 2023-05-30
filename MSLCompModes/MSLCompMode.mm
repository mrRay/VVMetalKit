//
//  MSLCompMode.m
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import "MSLCompMode.h"




@interface MSLCompMode ()

//+ (uint16_t) getNewUID;

@property (strong,readwrite) NSURL * url;
@property (strong,readwrite) NSString * name;
@property (strong,readwrite) NSString * functionDeclarations;
@property (strong,readwrite) NSString * functions;

@end




@implementation MSLCompMode

//+ (uint16_t) getNewUID	{
//	static uint16_t		globalUID = 0;
//	return globalUID++;
//}

+ (instancetype) createWithURL:(NSURL *)n	{
	return [[MSLCompMode alloc] initWithURL:n];
}

- (instancetype) initWithURL:(NSURL *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	self = [super init];
	if (n == nil)
		self = nil;
	//	if the file doesn't have a .metal file extension, reject it automatically
	if ([n.pathExtension caseInsensitiveCompare:@"metal"] != NSOrderedSame)
		self = nil;
	
	if (self != nil)	{
		//	load the file into a string, bail if we can't
		NSError			*nsErr = nil;
		NSString		*rawString = [[NSString alloc] initWithContentsOfFile:n.path encoding:NSUTF8StringEncoding error:&nsErr];
		if (rawString == nil || rawString.length<1 || nsErr!=nil)	{
			NSLog(@"ERR: (%@) while loading file (%@) in %s",nsErr,n.path,__func__);
			self = nil;
			return self;
		}
		_url = n;
		
		//	figure out the comp mode name (which will also determine the function names), ensuring that it only uses compiler-safe chars
		static NSMutableCharacterSet		*compilerSafeCharSet = nil;
		if (compilerSafeCharSet == nil)	{
			compilerSafeCharSet = [[NSMutableCharacterSet alloc] init];
			[compilerSafeCharSet formUnionWithCharacterSet:[NSCharacterSet lowercaseLetterCharacterSet]];
			[compilerSafeCharSet formUnionWithCharacterSet:[NSCharacterSet uppercaseLetterCharacterSet]];
			[compilerSafeCharSet formUnionWithCharacterSet:[NSCharacterSet decimalDigitCharacterSet]];
		}
		NSMutableString		*tmpMutString = nil;
		//NSMutableString		*tmpName = [[NSMutableString alloc] init];
		////	assemble the "name" by repeatedly copying chars that are "safe" from the tmp string to the filename (deleting them from the tmp string as we go)
		//tmpMutString = [[n.lastPathComponent stringByDeletingPathExtension] mutableCopy];
		//NSRange			rangeToCopy;
		//do	{
		//	rangeToCopy = [tmpMutString rangeOfCharactersFromSet:compilerSafeCharSet];
		//	if (rangeToCopy.location != NSNotFound && rangeToCopy.length > 0)	{
		//		[tmpName appendString:[tmpMutString substringWithRange:rangeToCopy]];
		//		[tmpMutString deleteCharactersInRange:rangeToCopy];
		//	}
		//} while (rangeToCopy.location != NSNotFound && rangeToCopy.length > 0);
		//_name = [NSString stringWithString:tmpName];
		_name = [n.lastPathComponent stringByDeletingPathExtension];
		
		//	assemble the function declarations, they're basically going to be constant strings
		const char		*funcDecsCStr = R"(float4 AAAA(thread float4 & inBottom, thread float4 & inTop, thread float & inTopAlpha);
float4 BBBB(thread float4 & inTop, thread float & inTopAlpha);)";
		_functionDeclarations = [NSString stringWithUTF8String:funcDecsCStr];
		_functionDeclarations = [_functionDeclarations stringByReplacingOccurrencesOfString:@"AAAA" withString:[NSString stringWithFormat:@"%@_CompositeTopAndBottom",_name]];
		_functionDeclarations = [_functionDeclarations stringByReplacingOccurrencesOfString:@"BBBB" withString:[NSString stringWithFormat:@"%@_Bottom",_name]];
		
		//	asemble the functions by doing a basic find-and-replace on the raw string.  bail if we can't find anything.
		tmpMutString = [rawString mutableCopy];
		[tmpMutString replaceOccurrencesOfString:@"float4 CompositeTopAndBottom(" withString:[NSString stringWithFormat:@"float4 %@_CompositeTopAndBottom(",_name] options:0 range:NSMakeRange(0,tmpMutString.length)];
		[tmpMutString replaceOccurrencesOfString:@"float4 CompositeBottom(" withString:[NSString stringWithFormat:@"float4 %@_Bottom(",_name] options:0 range:NSMakeRange(0,tmpMutString.length)];
		_functions = [NSString stringWithString:tmpMutString];
		
		//_compModeIndex = [MSLCompMode getNewUID];
		
		_compModeSwitchStatementFuncPtrs = nil;
	}
	return self;
}

- (NSString *) description	{
	return [NSString stringWithFormat:@"<MSLCompMode %p %d %@>",self,_compModeIndex,_name];
}

@synthesize compModeIndex=_compModeIndex;
- (void) setCompModeIndex:(uint16_t)n	{
	_compModeIndex = n;
	
	const char		*caseCStr = R"(	case CCCC:
		CompositeBottomFuncPtr = BBBB;
		CompositeTopAndBottomFuncPtr = AAAA;
		break;)";
	NSString		*tmpString = [NSString stringWithUTF8String:caseCStr];
	tmpString = [tmpString stringByReplacingOccurrencesOfString:@"AAAA" withString:[NSString stringWithFormat:@"%@_CompositeTopAndBottom",_name]];
	tmpString = [tmpString stringByReplacingOccurrencesOfString:@"BBBB" withString:[NSString stringWithFormat:@"%@_Bottom",_name]];
	tmpString = [tmpString stringByReplacingOccurrencesOfString:@"CCCC" withString:[NSString stringWithFormat:@"%d",_compModeIndex]];
	
	_compModeSwitchStatementFuncPtrs = (tmpString==nil) ? @"" : tmpString;
}
- (uint16_t) compModeIndex	{
	return _compModeIndex;
}

@end
