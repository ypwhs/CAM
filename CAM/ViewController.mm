//
//  ViewController.m
//  CAM
//
//  Created by 杨培文 on 2017/9/30.
//  Copyright © 2017年 杨培文. All rights reserved.
//

#import "ViewController.h"
#import <Vision/Vision.h>
#import "my_model.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *label;

@end

CvVideoCamera * camera;

VNCoreMLRequest * request;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    camera = [[CvVideoCamera alloc] init];
    camera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    camera.defaultAVCaptureSessionPreset = AVCaptureSessionPresetiFrame960x540;
    camera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    camera.defaultFPS = 60;
    camera.grayscaleMode = false;
    camera.delegate = self;
    
    _label.layer.cornerRadius = 5;
    _label.layer.masksToBounds = YES;
    
    MLModel * mlmodel = [[[my_model alloc] init] model];
    VNCoreMLModel * model = [VNCoreMLModel modelForMLModel:mlmodel error:nil];
    
    request = [[VNCoreMLRequest alloc] initWithModel:model completionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        VNCoreMLFeatureValueObservation *res = ((VNCoreMLFeatureValueObservation *)(request.results[0]));
        float result = [[[res.featureValue multiArrayValue] objectAtIndexedSubscript:0] floatValue];
        printf("%.2f\n", result);
        
        NSString * resultString;
        if(result < 0.05){
            resultString = [NSString stringWithFormat:@"猫的概率：%.2f", 1-result];
        }
        else if(result > 0.95){
            resultString = [NSString stringWithFormat:@"狗的概率：%.2f", result];
        }
        else{
            resultString = @"未探测到猫狗";
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            _label.text = resultString;
        });
    }];
    request.imageCropAndScaleOption = VNImageCropAndScaleOptionCenterCrop;
}

- (void)viewDidAppear:(BOOL)animated {
    [camera start];
}

bool state = true;
- (IBAction)click:(UIButton *)sender {
    if(state){
        [sender setTitle:@"继续" forState: UIControlStateNormal];
        [camera stop];
        
        NSDictionary *options_dict = [[NSDictionary alloc] init];
        NSArray *request_array = @[request];
        CIImage *imageToDetect = [[CIImage alloc]initWithImage:MatToUIImage(image)];
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCIImage:imageToDetect options:options_dict];
        
        dispatch_sync(dispatch_get_global_queue(0, 0), ^{
            [handler performRequests:request_array error:nil];
        });
        
    }else{
        [sender setTitle:@"识别" forState: UIControlStateNormal];
        [camera start];
    }
    state = !state;
}

cv::Mat image;
- (void)processImage:(cv::Mat &)input_img {
    cvtColor(input_img, image, CV_BGR2RGB);
    dispatch_async(dispatch_get_main_queue(), ^{
        _imageView.image = MatToUIImage(image);
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
