//
//  ViewController.m
//  CAM
//
//  Created by 杨培文 on 2017/9/30.
//  Copyright © 2017年 杨培文. All rights reserved.
//

#import "ViewController.h"
#import <CoreML/CoreML.h>
#import "model_clf.h"
#import "model_cam.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIImageView *imageView2;

@end

CvVideoCamera * camera;
model_clf * clf = [[model_clf alloc] init];
model_cam * cam = [[model_cam alloc] init];

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //初始化摄像头
    camera = [[CvVideoCamera alloc] init];
    camera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    camera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
    camera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    camera.defaultFPS = 30;
    camera.grayscaleMode = false;
    camera.delegate = self;
    
    _label.layer.cornerRadius = 2;
    _label.layer.masksToBounds = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [camera start];
}

- (void)recognize {
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        //用模型进行预测
        CVPixelBufferRef bufferRef = [self pixelBufferFromCGImage:image.CGImage size:CGSizeMake(224, 224)];
        float prediction = [clf predictionFromImage:bufferRef error:nil].prediction[0].floatValue;
        MLMultiArray * featuremap = [cam predictionFromImage:bufferRef error:nil].cam;
        
        //把 MLMultiArray 转换为 Mat
        cv::Mat img_cam(7, 7, CV_32F);
        for(int i = 0; i < 7; i++)
        {
            for(int j = 0; j < 7; j++){
                if(prediction > 0.5){
                    img_cam.row(i).col(j) = featuremap[i*7+j].floatValue;
                }
                else
                {
                    img_cam.row(i).col(j) = featuremap[i*7+j+49].floatValue;
                }
            }
        }
        
        //调整 cam 的范围
        double min, max;
        cv::minMaxLoc(img_cam, &min, &max);
        img_cam -= min;
        img_cam /= max;
        img_cam -= 0.2;
        img_cam /= 0.8;
        cv::resize(img_cam, img_cam, cv::Size(224, 224));
        
        cv::Mat img_cam2;
        img_cam2 = img_cam * 255;
        img_cam2.convertTo(img_cam2, CV_8U);
        
        //染成彩色
        cv::Mat heatmap(224, 224, CV_8UC3);
        cv::applyColorMap(img_cam2, heatmap, cv::COLORMAP_JET);
        cv::cvtColor(heatmap, heatmap, CV_BGR2RGB);
//        heatmap.setTo(cv::Scalar(0, 0, 0), img_cam < 0.2);
        
        //加在原图上
        cv::Mat outImage(224, 224, CV_8UC3);
        cv::resize(rawImage, rawImage, cv::Size(224, 224));
        cv::addWeighted(rawImage, 0.8, heatmap, 0.4, 0, outImage);
        
        //显示图片和文字
        NSString * resultString;
        if(prediction < 0.5){
            resultString = [NSString stringWithFormat:@"狗的概率：%.2f", 1-prediction];
        }
        else{
            resultString = [NSString stringWithFormat:@"猫的概率：%.2f", prediction];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            _label.text = resultString;
            _imageView.image = MatToUIImage(outImage);
            _imageView2.image = MatToUIImage(heatmap);
        });
    });
}

UIImage * image;
cv::Mat rawImage;
bool state = true;
- (IBAction)click:(UIButton *)sender {
    if(state){
        [sender setTitle:@"继续" forState: UIControlStateNormal];
        [camera stop];
        [self recognize];
    }else{
        [sender setTitle:@"暂停" forState: UIControlStateNormal];
        [camera start];
    }
    state = !state;
}

- (void)processImage:(cv::Mat &)input_img {
    cv::cvtColor(input_img, rawImage, CV_BGR2RGB);
    image = MatToUIImage(rawImage);
    [self recognize];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        _imageView.image = image;
//    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//将图片转换为 CVPixelBufferRef
- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)imageSize
{
    NSDictionary *options = @{(id)kCVPixelBufferCGImageCompatibilityKey: @YES,
                              (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES};
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, imageSize.width,
                                          imageSize.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, imageSize.width,
                                                 imageSize.height, 8, 4*imageSize.width, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    
    CGContextDrawImage(context, CGRectMake(0 + (imageSize.width-CGImageGetWidth(image))/2,
                                           (imageSize.height-CGImageGetHeight(image))/2,
                                           CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}


@end
