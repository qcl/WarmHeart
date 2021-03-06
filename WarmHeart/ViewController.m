//
//  ViewController.m
//  WarmHeart
//
//  Created by Qing-Cheng Li on 2017/2/7.
//  Copyright © 2017年 Qing-Cheng Li. All rights reserved.
//

#import "ViewController.h"

#import <mach/mach.h>
#import <assert.h>
#import <CoreImage/CoreImage.h>

float cpu_usage()
{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    
    task_basic_info_t      basic_info;
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;
    
    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;
    
    thread_basic_info_t basic_info_th;
    uint32_t stat_thread = 0; // Mach threads
    
    basic_info = (task_basic_info_t)tinfo;
    
    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (thread_count > 0)
        stat_thread += thread_count;
    
    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    int j;
    
    for (j = 0; j < (int)thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }
        
        basic_info_th = (thread_basic_info_t)thinfo;
        
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->user_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }
        
    } // for each thread
    
    kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    assert(kr == KERN_SUCCESS);
    
    return tot_cpu;
}

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIButton *button;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isOn;
@property (nonatomic, assign) CGFloat originalScreenBrightness;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupView];
    [self setupNotification];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSLog(@"view did appear");
    [self.timer fire];
    [UIScreen mainScreen].brightness = 1.0f;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    NSLog(@"view will disappear");
    [UIScreen mainScreen].brightness = self.originalScreenBrightness;
}

- (void)setupNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterBackground:) name:UIApplicationWillTerminateNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIScreen mainScreen] setBrightness:self.originalScreenBrightness];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (IBAction)buttonDidTap:(id)sender
{
    self.isOn = !self.isOn;

    if (self.isOn) {
        [self.button setTitle:@"On" forState:UIControlStateNormal];
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    } else {
        [self.button setTitle:@"Off" forState:UIControlStateNormal];
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
}

- (void)setIsOn:(BOOL)isOn
{
    _isOn = isOn;
    if (isOn) {
        __weak ViewController *weakSelf = (ViewController *)self;
        NSUInteger coreCount = [[NSProcessInfo processInfo] processorCount];
        for (NSUInteger i = 0; i < coreCount/2 + 1; i++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [weakSelf justAdd];
            });
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [weakSelf justBlurSomething];
            });
        }
    } else {
        
    }
}

- (void)setupView
{
    NSLog(@"set up view");
    self.label.text = @"This is a test";

    self.originalScreenBrightness = [UIScreen mainScreen].brightness;

    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(updateCPUUsageLabel) userInfo:nil repeats:YES];
}

- (void)updateCPUUsageLabel
{
    CGFloat usage = cpu_usage();
    //NSLog(@"cpu usage %f", usage);
    self.label.text = [NSString stringWithFormat:@"CPU Usage = %f", usage];
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        if (self.isOn && [UIScreen mainScreen].brightness < 0.99f) {
            [UIScreen mainScreen].brightness = 1.0f;
        }
    } else {
        
    }
}

- (void)justAdd
{
    NSUInteger i = 0;
    while (YES) {
        if (!self.isOn) {
            NSLog(@"STOP!");
            break;
        }
        i += 1;
    }
    NSLog(@"Stoped");
    return;
}

- (void)blurSomething
{
    UIImage *nothingImage = [UIImage imageNamed:@"libgf"];
    NSUInteger scale = 20;
    
    UIGraphicsBeginImageContext(CGSizeMake(nothingImage.size.width * scale, nothingImage.size.height * scale));
    [nothingImage drawInRect:CGRectMake(0, 0, nothingImage.size.width * scale, nothingImage.size.height * scale)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    EAGLContext *openGLContent = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    CIContext *content = [CIContext contextWithEAGLContext:openGLContent];

    UIImage *image = scaledImage;
    CIImage *ciImage = [CIImage imageWithCGImage:image.CGImage];
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    
    NSLog(@"ciImage = %@", ciImage);
    
    [filter setValue:ciImage forKey:kCIInputImageKey];
    [filter setValue:@(10.0f) forKey:kCIInputRadiusKey];
    
    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    CGImageRef ref = [content createCGImage:result fromRect:result.extent];
    UIImage *resultImage = [UIImage imageWithCGImage:ref];
    
    NSLog(@"result = %@", resultImage);
}

- (void)justBlurSomething
{
    while (YES) {
        if (!self.isOn) {
            NSLog(@"STOP BLUR");
            break;
        }

        [self blurSomething];
    }
    return;
}

- (void)appWillEnterBackground:(NSNotification *)notfication
{
    NSLog(@"go to bg");
    [UIScreen mainScreen].brightness = self.originalScreenBrightness;
}

- (void)appWillEnterForground:(NSNotification *)notfication
{
    NSLog(@"go to fg");
    [[UIScreen mainScreen] setBrightness:1.0f];
}

@end
