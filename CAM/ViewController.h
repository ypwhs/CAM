//
//  ViewController.h
//  CAM
//
//  Created by 杨培文 on 2017/9/30.
//  Copyright © 2017年 杨培文. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/videoio/cap_ios.h>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/highgui/highgui.hpp>
#import <opencv2/imgproc/imgproc.hpp>

@interface ViewController : UIViewController <CvVideoCameraDelegate>


@end
