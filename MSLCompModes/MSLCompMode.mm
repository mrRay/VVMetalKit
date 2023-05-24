//
//  MSLCompMode.m
//  MSLCompModes
//
//  Created by testadmin on 5/17/23.
//

#import "MSLCompMode.h"




@interface MSLCompMode ()

+ (uint16_t) getNewUID;

@property (strong,readwrite) NSURL * url;
@property (strong,readwrite) NSString * name;
@property (strong,readwrite) NSString * functionDeclarations;
@property (strong,readwrite) NSString * functions;

@end




@implementation MSLCompMode

+ (uint16_t) getNewUID	{
	static uint16_t		globalUID = 0;
	return globalUID++;
}

+ (instancetype) createWithURL:(NSURL *)n	{
	return [[MSLCompMode alloc] initWithURL:n];
}

- (instancetype) initWithURL:(NSURL *)n	{
	NSLog(@"%s ... %@",__func__,n);
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
		const char		*funcDecsCStr = R"(float4 AAAA(device float4 & inBottom, device float4 & inTop, device float & inTopAlpha);
float4 BBBB(device float4 & inTop, device float & inTopAlpha);)";
		_functionDeclarations = [NSString stringWithUTF8String:funcDecsCStr];
		_functionDeclarations = [_functionDeclarations stringByReplacingOccurrencesOfString:@"AAAA" withString:[NSString stringWithFormat:@"%@_CompositeTandB",_name]];
		_functionDeclarations = [_functionDeclarations stringByReplacingOccurrencesOfString:@"BBBB" withString:[NSString stringWithFormat:@"%@_Bottom",_name]];
		
		//	asemble the functions by doing a basic find-and-replace on the raw string.  bail if we can't find anything.
		tmpMutString = [rawString mutableCopy];
		[tmpMutString replaceOccurrencesOfString:@"float4 CompositeTopAndBottom(" withString:[NSString stringWithFormat:@"float4 %@_CompositeTopAndBottom(",_name] options:0 range:NSMakeRange(0,tmpMutString.length)];
		[tmpMutString replaceOccurrencesOfString:@"float4 CompositeBottom(" withString:[NSString stringWithFormat:@"float4 %@_Bottom(",_name] options:0 range:NSMakeRange(0,tmpMutString.length)];
		_functions = [NSString stringWithString:tmpMutString];
		
		_uid = [MSLCompMode getNewUID];
	}
	return self;
}

- (NSString *) description	{
	return [NSString stringWithFormat:@"<MSLCompMode %p %d %@>",self,_uid,_name];
}

@end
