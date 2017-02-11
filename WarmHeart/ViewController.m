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

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupView];
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
}

- (IBAction)buttonDidTap:(id)sender
{
    self.isOn = !self.isOn;

    if (self.isOn) {
        [self.button setTitle:@"On" forState:UIControlStateNormal];
    } else {
        [self.button setTitle:@"Off" forState:UIControlStateNormal];
    }
}

- (void)setIsOn:(BOOL)isOn
{
    _isOn = isOn;
    if (isOn) {
        __weak ViewController *weakSelf = (ViewController *)self;
        NSUInteger coreCount = [[NSProcessInfo processInfo] processorCount];
        for (NSUInteger i = 0; i < coreCount; i++) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [weakSelf justAdd];
            });
        }
    } else {
        
    }
}

- (void)setupView
{
    NSLog(@"set up view");
    self.label.text = @"This is a test";

    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(updateCPUUsageLabel) userInfo:nil repeats:YES];
}

- (void)updateCPUUsageLabel
{
    CGFloat usage = cpu_usage();
    NSLog(@"cpu usage %f", usage);
    self.label.text = [NSString stringWithFormat:@"CPU Usage = %f", usage];
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
    return;
}

@end
