//
//  ViewController.m
//  CAM
//
//  Created by 杨培文 on 2017/9/30.
//  Copyright © 2017年 杨培文. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *label;

@end

@implementation ViewController

CvVideoCamera * camera;

- (void)viewDidLoad {
    [super viewDidLoad];
    //初始化摄像头
    camera = [[CvVideoCamera alloc] init];
    camera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    camera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset1920x1080;
    camera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    camera.defaultFPS = 30;
    camera.grayscaleMode = false;
    camera.delegate = self;
    
    [camera start];
}

bool state = true;
- (IBAction)click:(UIButton *)sender {
    if(state){
        [sender setTitle:@"继续" forState: UIControlStateNormal];
        [camera stop];
    }else{
        [sender setTitle:@"暂停" forState: UIControlStateNormal];
        [camera start];
    }
    state = !state;
}

model_clf * clf = [[model_clf alloc] init];
model_cam * cam = [[model_cam alloc] init];
- (void)processImage:(cv::Mat &)input_img {
    //转换图像为正方形
    cv::cvtColor(input_img, input_img, CV_BGR2RGB);
    input_img = input_img(cv::Rect(0, 0, input_img.cols, input_img.cols));
    cv::Mat smallImage;
    cv::resize(input_img, smallImage, cv::Size(224, 224));
    UIImage * image = MatToUIImage(smallImage);
    
    //用模型进行预测
    CVPixelBufferRef bufferRef = [self pixelBufferFromCGImage:image.CGImage];
    float prediction = [clf predictionFromImage:bufferRef error:nil].prediction[0].floatValue;
    MLMultiArray * featuremap = [cam predictionFromImage:bufferRef error:nil].cam;
    CVPixelBufferRelease(bufferRef);
    
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
                img_cam.row(i).col(j) = featuremap[49+i*7+j].floatValue;
            }
        }
    }
    
    //调整 cam 的范围
    int width = input_img.rows;
    img_cam /= 10;
    img_cam.setTo(0, img_cam < 0);
    img_cam.setTo(1, img_cam > 1);
    cv::resize(img_cam, img_cam, cv::Size(width, width));
    
    cv::Mat img_cam2;
    img_cam2 = img_cam * 255;
    img_cam2.convertTo(img_cam2, CV_8U);
    
    //染成彩色
    cv::Mat heatmap(width, width, CV_8UC3);
    cv::applyColorMap(img_cam2, heatmap, cv::COLORMAP_JET);
    cv::cvtColor(heatmap, heatmap, CV_BGR2RGB);
    
    //加在原图上
    cv::Mat outImage(width, width, CV_8UC3);
    cv::addWeighted(input_img, 0.8, heatmap, 0.4, 0, outImage);
    
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
    });
}

//将图片转换为 CVPixelBufferRef
- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image
{
    NSDictionary *options = @{(id)kCVPixelBufferCGImageCompatibilityKey: @YES,
                              (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES};
    CVPixelBufferRef pxbuffer = NULL;
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options, &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, width, height, 8, 4*width,
                                                 rgbColorSpace, kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);

    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);

    return pxbuffer;
}


@end
