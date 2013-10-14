#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <Accelerate/Accelerate.h>
#import <CoreGraphics/CoreGraphics.h>


#define kGrabberWidth 45.0f
#define kGrabberHeight 17.0f

FOUNDATION_EXTERN UIImage *_UICreateScreenUIImage(void);

NS_INLINE void makeGrabberImage(float progress, UIImageView *grabber, UIColor *baseColor, UIColor *topColor, CGFloat width, CGFloat height) {
    UIGraphicsBeginImageContextWithOptions(grabber.bounds.size, NO, 0.0f);
    
    
    void (^drawPath)(CGFloat lineWidth, UIColor *color) = ^(CGFloat lineWidth, UIColor *color) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path setLineCapStyle:kCGLineCapRound];
        [path setLineJoinStyle:kCGLineJoinRound];
        [path setLineWidth:lineWidth];
        [color setStroke];
        
        CGFloat horizontalSpacing = 0.15f;
        CGFloat verticalSpacing = 0.25f;
        
        CGFloat widthDelta = (grabber.frame.size.width-width)/2.0f;
        CGFloat heightDelta = (grabber.frame.size.height-height)/2.0f;
        
        [path moveToPoint:(CGPoint){widthDelta+width*horizontalSpacing, grabber.frame.size.height*0.5f}];
        
        [path addLineToPoint:(CGPoint){grabber.frame.size.width*0.5f, heightDelta+height*verticalSpacing+height*verticalSpacing*2.0f*(1.0f-progress)}];
        
        [path addLineToPoint:(CGPoint){grabber.frame.size.width-widthDelta-width*horizontalSpacing, grabber.frame.size.height*0.5f}];
        
        [path stroke];
    };
    
    
    drawPath(6.0f, baseColor);
    
    if (topColor) {
        drawPath(4.5f, topColor);
    }

    
    [grabber setImage:UIGraphicsGetImageFromCurrentImageContext()];
    
	UIGraphicsEndImageContext();
}


NS_INLINE UIImage *blurredImage(UIImage *self, CGFloat radius, NSUInteger iterations, UIColor *tintColor, UIImageOrientation orientation) {
    //image must be nonzero size
    if (floorf(self.size.width) * floorf(self.size.height) <= 0.0f) {
        return self;
    }
    
    //boxsize must be an odd integer
    uint32_t boxSize = radius * self.scale;
    
    if (boxSize % 2 == 0) {
        boxSize++;
    }
    
    //create image buffers
    CGImageRef imageRef = self.CGImage;
    vImage_Buffer buffer1, buffer2;
    buffer1.width = buffer2.width = CGImageGetWidth(imageRef);
    buffer1.height = buffer2.height = CGImageGetHeight(imageRef);
    buffer1.rowBytes = buffer2.rowBytes = CGImageGetBytesPerRow(imageRef);
    CFIndex bytes = buffer1.rowBytes * buffer1.height;
    buffer1.data = malloc(bytes);
    buffer2.data = malloc(bytes);
    
    //create temp buffer
    void *tempBuffer = malloc(vImageBoxConvolve_ARGB8888(&buffer1, &buffer2, NULL, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend + kvImageGetTempBufferSize));
    
    //copy image data
    CFDataRef dataSource = CGDataProviderCopyData(CGImageGetDataProvider(imageRef));
    memcpy(buffer1.data, CFDataGetBytePtr(dataSource), bytes);
    CFRelease(dataSource);
    
    for (NSUInteger i = 0; i < iterations; i++) {
        //perform blur
        vImageBoxConvolve_ARGB8888(&buffer1, &buffer2, tempBuffer, 0, 0, boxSize, boxSize, NULL, kvImageEdgeExtend);
        
        //swap buffers
        void *temp = buffer1.data;
        buffer1.data = buffer2.data;
        buffer2.data = temp;
    }
    
    //free buffers
    free(buffer2.data);
    free(tempBuffer);
    
    //create image context from buffer
    CGContextRef ctx = CGBitmapContextCreate(buffer1.data, buffer1.width, buffer1.height, 8, buffer1.rowBytes, CGImageGetColorSpace(imageRef), CGImageGetBitmapInfo(imageRef));
    
    //apply tint
    if (tintColor && CGColorGetAlpha(tintColor.CGColor) > 0.0f) {
        CGContextSetFillColorWithColor(ctx, tintColor.CGColor);
        CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
        CGContextFillRect(ctx, CGRectMake(0.0f, 0.0f, buffer1.width, buffer1.height));
    }
    
    //create image from context
    imageRef = CGBitmapContextCreateImage(ctx);
    UIImage *image = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:orientation];
    
    CGImageRelease(imageRef);
    CGContextRelease(ctx);
    
    free(buffer1.data);
    
    return image;
}

@interface SBBulletinListTabView : UIImageView

@end


%hook SBBulletinListTabView

- (id)init {
    self = %orig;
    if (self) {
        makeGrabberImage(0.0f, self, [UIColor colorWithWhite:0.1f alpha:0.9f], [UIColor colorWithWhite:1.0f alpha:0.9f], kGrabberWidth, kGrabberHeight);
        
        for (UIView *sub in self.subviews) {
            [sub removeFromSuperview];
        }
    }
    return self;
}

%end


%hook SBBulletinListView

static UIImageView *linenView = nil;

+ (UIImage *)linen {
    return nil;
}



//#define DEBUG

#ifdef DEBUG
#define TIME_MEASURE_START(i) CFTimeInterval start##i = CFAbsoluteTimeGetCurrent()
#define TIME_MEASURE_END(i) NSLog(@"ELAPSED TIME (%i) %f", i, CFAbsoluteTimeGetCurrent()-start##i)
#else
#define TIME_MEASURE_START(i)
#define TIME_MEASURE_END(i)
#endif


- (void)layoutForOrientation:(UIInterfaceOrientation)orientation {
    if (!linenView) {
        linenView = MSHookIvar<UIImageView *>(self, "_linenView");
        
        MSHookIvar<UIImageView *>(self, "_linenView") = nil;
        
        [linenView setImage:nil];
        
        TIME_MEASURE_START(2);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            TIME_MEASURE_START(0);
            UIImage *screenImage = _UICreateScreenUIImage();
            TIME_MEASURE_END(0);
            
            
            TIME_MEASURE_START(1);
            UIImage *finalImage = blurredImage(screenImage, 27.5f, 2, [UIColor colorWithWhite:0.0f alpha:0.5f], (UIImageOrientation)orientation-1);
            TIME_MEASURE_END(1);
            
            TIME_MEASURE_END(2);
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                [linenView setImage:finalImage];
                linenView.opaque = YES;
            });
        });
        
        linenView.superview.clipsToBounds = YES;
        
        UIImageView *grabber = MSHookIvar<UIImageView *>(self, "_grabber");
        
        makeGrabberImage(0.0f, grabber, [UIColor colorWithWhite:1.0f alpha:0.3f], nil, kGrabberWidth, kGrabberHeight);
    }
    
    %orig;
}

- (void)positionSlidingViewAtY:(float)y {
    %orig;
    
    if (y > linenView.frame.size.height) {
        y = linenView.frame.size.height;
    }
    else if (y < 0.0f) {
        y = 0.0f;
    }
    
    CGRect linenFrame = linenView.frame;
    
    linenFrame.origin.y = linenFrame.size.height-y;
    
    linenView.frame = linenFrame;
    
    UIImageView *grabber = MSHookIvar<UIImageView *>(self, "_grabber");
    
    makeGrabberImage((y/linenFrame.size.height), grabber, [UIColor colorWithWhite:1.0f alpha:0.3f], nil, kGrabberWidth, kGrabberHeight);
}

- (void)removeFromSuperview {
    %orig;
    linenView = nil;
}

%end


%ctor {
    @autoreleasepool {
        %init();
    }
}