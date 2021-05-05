//
//  RedView.m
//  BasicPlaybackTest
//
//  Created by testAdmin on 4/1/21.
//

#import "RedView.h"

@implementation RedView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    [[NSColor redColor] set];
    NSRectFill(dirtyRect);
}

@end
