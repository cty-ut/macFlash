#import <AppKit/AppKit.h>

static void DrawIcon(NSUInteger size, NSURL *target) {
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:(NSInteger)size pixelsHigh:(NSInteger)size
                  bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
                  colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform scaleBy:(CGFloat)size / 1024.0];
    [transform concat];

    NSBezierPath *base = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(70, 70, 884, 884)
                                                          xRadius:210 yRadius:210];
    [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:0.25 green:0.20 blue:0.55 alpha:1]
                                   endingColor:[NSColor colorWithCalibratedRed:0.10 green:0.11 blue:0.28 alpha:1]]
        drawInBezierPath:base angle:90];
    NSBezierPath *screen = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(185, 238, 654, 568)
                                                            xRadius:85 yRadius:85];
    [[NSColor colorWithCalibratedRed:0.34 green:0.31 blue:0.73 alpha:1] setFill];
    [screen fill];

    NSBezierPath *bolt = [NSBezierPath bezierPath];
    [bolt moveToPoint:NSMakePoint(565, 756)];
    [bolt lineToPoint:NSMakePoint(330, 492)];
    [bolt lineToPoint:NSMakePoint(478, 492)];
    [bolt lineToPoint:NSMakePoint(425, 302)];
    [bolt lineToPoint:NSMakePoint(696, 589)];
    [bolt lineToPoint:NSMakePoint(538, 589)];
    [bolt closePath];
    [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:1 green:0.91 blue:0.38 alpha:1]
                                   endingColor:[NSColor colorWithCalibratedRed:1 green:0.54 blue:0.25 alpha:1]]
        drawInBezierPath:bolt angle:90];

    [NSGraphicsContext restoreGraphicsState];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [png writeToURL:target atomically:YES];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSURL *folder = [[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]]
            URLByAppendingPathComponent:@"AppIcon.iconset" isDirectory:YES];
        [NSFileManager.defaultManager createDirectoryAtURL:folder
                               withIntermediateDirectories:YES attributes:nil error:nil];
        NSArray<NSNumber *> *sizes = @[@16, @16, @32, @32, @128, @128, @256, @256, @512, @512];
        NSArray<NSString *> *names = @[@"icon_16x16.png", @"icon_16x16@2x.png",
            @"icon_32x32.png", @"icon_32x32@2x.png", @"icon_128x128.png",
            @"icon_128x128@2x.png", @"icon_256x256.png", @"icon_256x256@2x.png",
            @"icon_512x512.png", @"icon_512x512@2x.png"];
        for (NSUInteger i = 0; i < sizes.count; i++) {
            NSUInteger pixels = sizes[i].unsignedIntegerValue * (i % 2 == 0 ? 1 : 2);
            DrawIcon(pixels, [folder URLByAppendingPathComponent:names[i]]);
        }
    }
    return 0;
}
