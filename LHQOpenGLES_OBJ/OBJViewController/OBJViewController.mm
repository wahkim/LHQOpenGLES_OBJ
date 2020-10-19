//
//  OBJViewController.m
//  LHQOpenGLES_OBJ
//
//  Created by Xhorse_iOS3 on 2020/5/16.
//  Copyright © 2020 LHQ. All rights reserved.
//

#import "OBJViewController.h"
#import "ObjParser.h"
#import "ArmoryHelper.h"
#import "MtlParser.h"
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>

using namespace std;

@interface OBJViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) EAGLContext *context; // 上下文
@property (nonatomic, strong) GLKBaseEffect *effect; // 用于设置通用的OpenGL ES环境
@property (nonatomic, strong) ObjParser *objParser;
@property (nonatomic, strong) NSMutableArray *spaceItems;
@property (nonatomic, assign) NSInteger tapCount;

@property (nonatomic, assign) NSInteger depCount;

@property (nonatomic, strong) NSMutableArray *topIndexList;
@property (nonatomic, strong) NSMutableArray *botIndexList;


@end

@implementation OBJViewController
{
    GLKView *glview;
    GLuint buffer; // 缓冲

    int dataCount; // 模型坐标个数
    float *squareVertexData; // 定义数组 原数据
    float *preSquareVertexData; // 处理后的数据
    MtlModel mtlcModel;
    int *mFaceNum; // 每个材质多少面
    int faceNum; // 三角片面数
    int useMtCount;
    vector<std::string> useMtlNames;

    float _bigSize; // 控制模型大小（1-180）
    float _rotate; // 旋转角度
    
    CGPoint lastLocation;//最后的触摸点
    GLKMatrix4 _rotMatrix; // 旋转矩阵
    GLKVector3 _current_position; // 当前位置
    GLKVector3 _anchor_position; // 锚点位置
    GLKQuaternion _quatStart; // 原始的旋转对象
    GLKQuaternion _quat; // 当前旋转对象
    
    BOOL _slerping; // 当前状态是否睡眠
    float _slerpCur; // 动画进度
    float _slerpMax; // 进度最大值
    GLKQuaternion _slerpStart; // 起点
    GLKQuaternion _slerpEnd; // 终点
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"obj模型";
    self.view.backgroundColor = [UIColor whiteColor];

    _rotate = 0;
    _bigSize = 40.0; // 控制模型大小（1-180）
    _rotMatrix = GLKMatrix4Identity;
    _quat = GLKQuaternionMake(0, 0, 0, 1);
    _quatStart = GLKQuaternionMake(0, 0, 0, 1);
    _slerping = YES;
    self.spaceItems = [NSMutableArray array];
    _tapCount = 0;
    _depCount = 0;
    
    self.topIndexList = [NSMutableArray array];
    self.botIndexList = [NSMutableArray array];
    
    [self setupConfig];
    [self loadingOBJ:@"hy15_12348"]; // 13321_1039 5022_179 13335_1222 12174_79 12348_1346 12349_1049
    [self addGesture];
    [self setupViews];
    
//    GLKVector4 v1111 = {1,2,4,9};
//    NSValue *data = [NSValue value:&v1111 withObjCType:@encode(union _GLKVector4)];
//    GLKVector4 result;
//    [data getValue:&result];
//    NSLog(@"result");
}

- (void)dealloc
{
    [EAGLContext setCurrentContext:nil];
    glDeleteBuffers(1, &buffer);
    self.effect = nil;
}

#pragma mark - Setup

- (void)setupConfig
{
    glview = [[GLKView alloc] init];
    [self setView:glview];
    
    self.context = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    glClearColor(131/255.0, 166/255.0, 205/255.0, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glview.context = self.context;
    glview.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    glview.drawableDepthFormat = GLKViewDrawableDepthFormat24;
//    glview.center = self.view.center;
    
    self.view.frame = CGRectMake(0, 0, 200, 200);
    [EAGLContext setCurrentContext:self.context];
    // 深度检测
    glEnable(GL_DEPTH_TEST);
}

- (void)setupViews
{
//    NSArray *depthList = @[@790,@754,@718,@682,@646,@610]; // 单位 0.01mm hon66
    
    NSArray *depthList = @[@820,@760,@700,@640]; // 单位 0.01mm DWO5
    
    for (NSInteger index = 0; index < depthList.count; index ++) {
        
        NSString *string = [NSString stringWithFormat:@"%@",depthList[index]];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(20 + index * (35 + 10), [UIScreen mainScreen].bounds.size.height - 100, 35, 35);
        button.backgroundColor = [UIColor whiteColor];
        [button setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [button setTitle:string forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14];
        [button addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
    }
    
//    NSArray *spcaceList = @[@1840,@1535,@1230,@925,@620,@380]; // 单位 0.01mm hon66
    
    NSArray *spcaceList = @[@270,@479,@688,@897,@1106,@1315,@1524,@1733]; // 单位 0.01mm DWO5
    
    for (NSInteger index = 0; index < spcaceList.count; index ++) {
        
        NSString *string = [NSString stringWithFormat:@"%@",spcaceList[index]];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(20 + index * (35 + 10), [UIScreen mainScreen].bounds.size.height - 180, 35, 35);
        button.backgroundColor = [UIColor whiteColor];
        button.titleLabel.font = [UIFont systemFontOfSize:14];
        [button setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [button setTitle:string forState:UIControlStateNormal];
        [self.view addSubview:button];
        [self.spaceItems addObject:button];
    }
    
}

- (NSInteger)spaceItemsSelect
{
    if (_tapCount >= self.spaceItems.count) {
        _tapCount -= self.spaceItems.count;
    }
    
    [self.spaceItems enumerateObjectsUsingBlock:^(UIView *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.backgroundColor = [UIColor whiteColor];
    }];
    
    UIButton *view = self.spaceItems[_tapCount];
    view.backgroundColor = [UIColor orangeColor];
    
    _tapCount += 1;
    
    return [view.titleLabel.text integerValue];
}

#pragma mark - Action Method

- (void)buttonAction:(UIButton *)sender
{
    NSLog(@"%@",sender.titleLabel.text);
    NSInteger number = _depCount % 8;
    _depCount += 1;
    [self.topIndexList removeAllObjects];
    [self.botIndexList removeAllObjects];
    
    CGFloat scale = [self.objParser getModelScale];
    
    CGFloat bladeLength = 2650 * 0.01 *scale;
    // 齿位
    CGFloat space = [self spaceItemsSelect]* 0.01 *scale;
    
    CGFloat bladeWidth = 830;
    
    CGFloat flatWidth = 100 * 0.01 *scale;
    
    BOOL isEqual = YES;
    NSInteger axisCount = 1;
    if (axisCount == 1) {
        isEqual = NO;
    } else {
        isEqual = YES;
    }
    NSInteger keyAlignment = 0;
    
    CGFloat depthf = (bladeWidth - [sender.titleLabel.text integerValue])*0.01 * scale;
    NSLog(@"depthf = %lf",depthf);
    
    // 画左边
    CGFloat xs1 = -4.15 * scale;
    CGFloat xs2 = -4.15 * scale;
    
    CGFloat xe1 = -2.15 * scale;
    CGFloat xe2 = -2.15 * scale;
    
    CGFloat ys1 = -4.0 * scale;
    CGFloat ys2 = -4.0 * scale; // -0.0148
    
    CGFloat ye1 = -25.6 * scale;
    CGFloat ye2 = -25.6 * scale; // - 0.947     0.07 / 0.9322 == 0.075
    
    CGFloat zs1 = 1.25 * scale;
    CGFloat zs2 = -0.35 * scale;
    
    CGFloat ze1 = 1.25 * scale;
    CGFloat ze2 = -0.35 * scale;
    __block NSInteger tcount = 5;
    
    __block CGFloat topY;
    __block CGFloat botY;
    
    __block CGFloat tmpH = 0.1 * scale;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        for (NSInteger i = 0; i < self->faceNum * 3 * 8; i +=8) {
        
            CGFloat x = self->squareVertexData[i];
            CGFloat y = self->squareVertexData[i+1];
            CGFloat z = self->squareVertexData[i+2];
            
                if (abs(xs1 - x) < 0.000001) { // xs1 <= x && xe1 >= x
//                    NSLog(@"xs1 = %f, x = %f, xe1 = %f",xs1,x,xe1);
                    if (ys1 >= y && ye1 <= y) {
                        
                        if (keyAlignment == 0) {
                            topY = - (fabs(ys1) + space) + flatWidth/2 + depthf;
                            botY = - (fabs(ys1) + space) - flatWidth/2 - depthf;
                            
                            if (topY >= y && botY <= y) {
                                // 中间
                                if (topY - depthf >= y && botY +depthf <= y) {
                                    x += depthf;
                                    self->preSquareVertexData[i] = x;
                                    /// 0.1 * scale
                                }
                                // 上边
                                else if (y > topY - depthf && y <= topY) {
                                    
                                    NSLog(@"上x = %f,y = %f, z = %f, i = %ld",x,y,z,i); // 0.003704 = 0.037037 * 0.1
//                                    x += depthf/ 3;
//                                    self->preSquareVertexData[i] = x;

                                        BOOL isExsit = NO;
                                        NSInteger index = 0;
                                        for (NSInteger ii = 0; ii <self.topIndexList.count; ii ++) {
                                            NSMutableArray *arr = self.topIndexList[ii];
                                            
                                            GLKVector4 vector;
                                            NSValue *value = [arr firstObject];
                                            [value getValue:&vector];
                                            if (abs(vector.z - z) < 0.000001 && abs(vector.y - y) < 0.000001) {
                                                index = ii;
                                                isExsit = YES;
                                                break;
                                           } else {
                                                 isExsit = NO;
                                           }
                                        }
                                        
                                        GLKVector4 vector = {static_cast<float>(x),static_cast<float>(y),static_cast<float>(z),static_cast<float>(i)};
                                        NSValue *value = [NSValue value:&vector withObjCType:@encode(union _GLKVector4)];
                                        if (isExsit == NO) {
                                            
                                            NSMutableArray *arr = [NSMutableArray arrayWithObject:value];
                                            [self.topIndexList addObject:arr];
                                        } else {
                                            NSMutableArray *arr = self.topIndexList[index];
                                            [arr addObject:value];
                                        }
                                    
                                }
//                                // 下边
                                else if (y < botY + depthf && y >= botY) {
//                                    x += depthf/2;
//                                    self->preSquareVertexData[i] = x;
//                                    [self.botIndexList addObject:[NSNumber numberWithInteger:i]];
                                    
                                    BOOL isExsit = NO;
                                    NSInteger index = 0;
                                    for (NSInteger ii = 0; ii <self.botIndexList.count; ii ++) {
                                        NSMutableArray *arr = self.botIndexList[ii];
                                        
                                        GLKVector4 vector;
                                        NSValue *value = [arr firstObject];
                                        [value getValue:&vector];
                                        if (abs(vector.z - z) < 0.000001 && abs(vector.y - y) < 0.000001) {
                                            index = ii;
                                            isExsit = YES;
                                            break;
                                       } else {
                                             isExsit = NO;
                                       }
                                    }
                                    
                                    GLKVector4 vector = {static_cast<float>(x),static_cast<float>(y),static_cast<float>(z),static_cast<float>(i)};
                                    NSValue *value = [NSValue value:&vector withObjCType:@encode(union _GLKVector4)];
                                    if (isExsit == NO) {
                                        
                                        NSMutableArray *arr = [NSMutableArray arrayWithObject:value];
                                        [self.botIndexList addObject:arr];
                                    } else {
                                        NSMutableArray *arr = self.botIndexList[index];
                                        [arr addObject:value];
                                    }
                                }
                                
                            }
                        }
                        
                    }
                }
        }
        if (number == 0) {
            NSLog(@"self.topIndexList = %@",self.topIndexList);
            CGFloat tInterval = depthf / self.topIndexList.count;
            for (int jj = 0; jj < self.topIndexList.count; jj ++) {
                CGFloat tv = (jj + 1) * tInterval;
                NSArray *arr = self.topIndexList[jj];
                for (int g = 0; g < arr.count; g ++) {
                    GLKVector4 vector;
                    NSValue *value = arr[g];
                    [value getValue:&vector];
                    CGFloat x = vector.x + tv;
                    NSInteger indx = (int)vector.w;
                    self->preSquareVertexData[indx] = x;
                }
            }
        }
        
        
        CGFloat bInterval = depthf / self.botIndexList.count;
        for (int jj = 0; jj < self.botIndexList.count; jj ++) {
            CGFloat tv = (self.botIndexList.count-jj) * bInterval;
            NSArray *arr = self.botIndexList[jj];
            for (int g = 0; g < arr.count; g ++) {
                GLKVector4 vector;
                NSValue *value = arr[g];
                [value getValue:&vector];
                CGFloat x = vector.x + tv;
                NSInteger indx = (int)vector.w;
                self->preSquareVertexData[indx] = x;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self render];
        });
    });
}

/* hon66
- (void)buttonAction:(UIButton *)sender
{
    NSLog(@"%@",sender.titleLabel.text);
    
    [self.topIndexList removeAllObjects];
    [self.botIndexList removeAllObjects];
    
    CGFloat scale = [self.objParser getModelScale];
    CGFloat bladeLength = 2500 * 0.01 *scale;
    // 齿型数据
    CGFloat space = [self spaceItemsSelect]* 0.01 *scale;
    // 钥匙宽
    CGFloat bladeWidth = 895;
    // 齿型宽度
    CGFloat flatWidth = 60 * 0.01 *scale;
    // 有几个轴 1: 外沟双边 AB面一致，2: 外沟双边 AB面不一致）
    BOOL isEqual = YES;
    NSInteger axisCount = 1;
    if (axisCount == 1) {
        isEqual = NO;
    } else {
        isEqual = YES;
    }
    
    // 0 为肩对齐，1为顶对齐
    NSInteger keyAlignment = 1;
    
    // 计算实际齿深
    CGFloat depthf = (bladeWidth - [sender.titleLabel.text integerValue])*0.01 * scale;
    NSLog(@"depthf = %lf",depthf);
    
    CGFloat z1 = 1.5 * scale; // 1.5 为txt的临时数据,暂时直接拿值
    CGFloat z2 = 0.45 * scale;
    
    CGFloat y1 = -23.5 * scale;
    CGFloat y2 = -4.2 * scale;
    
    CGFloat x1 = -3.4 * scale;
    CGFloat x2 = -4.5 * scale;
    
    __block CGFloat topY;
    __block CGFloat botY;
//    if (keyAlignment == 1) {
//        topY = y1 - space + flatWidth/2 + depthf;
//        botY = y1 - space - flatWidth/2 - depthf;
//    } else {
//        topY = y2 + space + flatWidth/2 + depthf;
//        botY = y2 + space - flatWidth/2 - depthf;
//    }
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (NSInteger i = 0; i < self->faceNum * 3 * 8; i +=8) {
            
            CGFloat x = self->squareVertexData[i];
            CGFloat y = self->squareVertexData[i+1];
            CGFloat z = self->squareVertexData[i+2];
            
            
            if (z <= z1 && z >= z2) {

               if (x >= x2 && x <= x1) {
                   
                   
                  if (keyAlignment == 1) {
                    
                      topY = - (fabs(y2) + space) + flatWidth/2 + depthf;
                      botY = - (fabs(y2) + space) - flatWidth/2 - depthf;
                      if (topY > y && botY < y) {
                          
                          // 中间
                          if (topY - depthf > y && botY + depthf < y) {
                              x += depthf;
                              self->preSquareVertexData[i] = x;
                          }
                          
                          // 上边
                          if (y > topY - depthf) {
                              [self.topIndexList addObject:[NSNumber numberWithInteger:i]];
                          }
                          // 下边
                          if (y < botY + depthf) {
                              [self.botIndexList addObject:[NSNumber numberWithInteger:i]];
                          }
                      }
                  }
                   
                }
            }
             
        }
        
//        CGFloat tInterval = depthf / self.topIndexList.count;
//        for (int i = 0; i < self.topIndexList.count; i ++) {
//            NSNumber *indexNumber = [[self.topIndexList reverseObjectEnumerator] allObjects][i];
//            NSInteger index = [indexNumber integerValue];
//            CGFloat xValue = self->squareVertexData[index];
//            xValue += tInterval * (i+1);
//            self->preSquareVertexData[index] = xValue;
//        }
//
//        CGFloat bInterval = depthf / self.botIndexList.count;
//        for (int i = 0; i < self.botIndexList.count; i ++) {
//            NSNumber *indexNumber = [[self.botIndexList reverseObjectEnumerator] allObjects][i];
//            NSInteger index = [indexNumber integerValue];
//            CGFloat xValue = self->squareVertexData[index];
//            xValue += bInterval * (i+1);
//            self->preSquareVertexData[index] = xValue;
//        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self render];
        });
        
    });
     
    
}
 
 */

#pragma mark - load OBj

- (void)loadingOBJ:(NSString*)fileName
{
    __weak typeof(self) weakself = self;
    self.objParser = [[ObjParser alloc] init];
    VertexInfo info = [self.objParser ParserObjFileWithfileName:fileName];
//    VertexInfo pro = [ObjParser ParserObjFileWithfileName:fileName];

    self->squareVertexData = info.squareVertexData;
    
    self->faceNum          = info.faceNum;
    self->mtlcModel        = info.materialDatas;
    self->mFaceNum         = info.materialFaceCount;
    self->useMtCount       = info.useMtlCount;
    self->useMtlNames      = info.useMtls;
    self->preSquareVertexData = new float[faceNum * 3 * 8];
    memcpy(self->preSquareVertexData, info.squareVertexData, faceNum * 3 * 8* sizeof(GLfloat));
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self render];
    });
    
    [self.objParser changeVertex];
}

#pragma mark - Render Method

// 渲染界面
- (void)render
{
    dataCount  = (int)(faceNum * 3);

    // 顶点数组保存进缓冲区
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer); // faceNum*24*4
    glBufferData(GL_ARRAY_BUFFER, faceNum * 3 * 8 * sizeof(GLfloat), preSquareVertexData, GL_STATIC_DRAW);

    // 将缓冲区的数据复制进通用顶点属性中
    // 顶点坐标
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 0);
  
    // 法线
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 3 * sizeof(GLfloat));
//
//    // 纹理
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 6 * sizeof(GLfloat));

    self.effect = [[GLKBaseEffect alloc]init];
    self.effect.light0.enabled = GL_TRUE;
//    self.effect.light0.diffuseColor = GLKVector4Make(204/255.0, 205/255.0, 207/255.0, 1.0);
    self.effect.light0.diffuseColor = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
    self.effect.light0.position = GLKVector4Make(41, 42, 47, 1.0);
    
//    free(squareVertexData);
}

#pragma mark - GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(131/255.0, 166/255.0, 205/255.0, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    int first = 0;
    for (int i = 0; i < useMtCount; i ++) {

        std::string name = useMtlNames[i];

        for (int j = 0; j < mtlcModel.mtlDatas.size(); j ++) {
            Material m = mtlcModel.mtlDatas[j];
            if (m.name == name) {
                self.effect.material.ambientColor = GLKVector4Make(m.Ka.r, m.Ka.g, m.Ka.b, 1.0); // 环境光
                self.effect.material.diffuseColor = GLKVector4Make(m.Kd.r, m.Kd.g, m.Kd.b, 1.0); // 漫射光
//                self.effect.material.specularColor = GLKVector4Make(m.Ks.r, m.Ks.g, m.Ks.b, 1.0); // 反射光
            }
        }

        if (i > 0) {
            first += mFaceNum[i - 1];
        }

        [self.effect prepareToDraw];
        glDrawArrays(GL_TRIANGLES, first, mFaceNum[i]);

    }
    
//    [self.effect prepareToDraw];
//    glDrawArrays(GL_TRIANGLES, 0, faceNum *3); // 有几行数据，最后一个参数就是多少
}

- (void)update
{
    _rotate += 1.0f;
    // 投影矩阵
    // GLKMathDegreesToRadians值越大，模型越小(0-180)
    CGSize size = self.view.bounds.size;
    float aspect = fabs(size.width / size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(_bigSize), aspect, 1.0f, 10.0f);
    self.effect.transform.projectionMatrix = projectionMatrix;
    
    // 模型矩阵
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, 0.0f, 0.0f, -6.0f); //平移
    
    // 模型复原
    if (_slerping) {
        //获得动画目前所处的进度
        _slerpCur += self.timeSinceLastUpdate;
        float slerpAmt = _slerpCur / _slerpMax;
        if (slerpAmt > 1.0) {
            
            slerpAmt = 1.0;
        }
        
        // 计算出slerpStart和slerpEnd之间的合适的旋转角度
        // GLKQuaternionSlerp 返回两个四元数的球面线性插值
        _quat = GLKQuaternionSlerp(_slerpStart, _slerpEnd, slerpAmt);

        // 旋转
        modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, 0);
        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, GLKMathDegreesToRadians(_rotate));
        modelViewMatrix = GLKMatrix4RotateZ(modelViewMatrix, 0);
    }
    else
    {
        // 拖拽视图的视角
        GLKMatrix4 rotation = GLKMatrix4MakeWithQuaternion(_quat); // 把quaternion 四元数转换成一个旋转矩阵
        modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, rotation);
    }

    self.effect.transform.modelviewMatrix = modelViewMatrix;
}

#pragma mark - Gesture Method

- (void)addGesture
{
    // 拖拽手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(onPan:)];
    pan.minimumNumberOfTouches = 1;
    pan.delegate = self;
    [glview addGestureRecognizer:pan];
    
    // 双击
    UITapGestureRecognizer * dtRec = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    dtRec.numberOfTapsRequired = 2;
    [glview addGestureRecognizer:dtRec];
}

- (void)onPan:(UIPanGestureRecognizer *)gesture
{
    // 模型复原需要更新数据
    if (_slerping) {
        _quat = GLKQuaternionMake(0, 0, 0, 1);
        _quatStart = GLKQuaternionMake(0, 0, 0, 1);
        _slerping = NO;
        _rotate = 0;
    }
    CGPoint location = [gesture locationInView:gesture.view];
//    CGPoint diff = CGPointMake(lastLocation.x - location.x, lastLocation.y - location.y);
//
//    float rotX = -1 * GLKMathDegreesToRadians(diff.y / 2.0);
//    float rotY = -1 * GLKMathDegreesToRadians(diff.x / 2.0);
    
    /**
     返回一个倒置矩阵
     GLKMatrix4Invert(GLKMatrix4 matrix, bool * __nullable isInvertible);
     */
//    bool isInvertible;
//    GLKVector3 xAxis = GLKMatrix4MultiplyVector3(GLKMatrix4Invert(_rotMatrix, &isInvertible), GLKVector3Make(1, 0, 0));
//    _rotMatrix = GLKMatrix4Rotate(_rotMatrix, rotX, xAxis.x, xAxis.y, xAxis.z);
//    GLKVector3 yAxis = GLKMatrix4MultiplyVector3(GLKMatrix4Invert(_rotMatrix, &isInvertible), GLKVector3Make(0, 1, 0));
//    _rotMatrix = GLKMatrix4Rotate(_rotMatrix, rotY, yAxis.x, yAxis.y, yAxis.z);
    
    _current_position = GLKVector3Make(location.x, location.y, 0);
    _current_position = [self projectOntoSurface:_current_position];
    
    [self computeIncremental];
    
    lastLocation = [gesture locationInView:gesture.view];
}

- (void)doubleTap:(UITapGestureRecognizer *)gesture
{
    [UIView animateWithDuration:1 animations:^{
        
        self->_slerping = YES;
        self->_slerpCur = 0;
        self->_slerpMax = 1.0;
        self->_slerpStart = self->_quat;
        self->_slerpEnd = GLKQuaternionMake(0, 0, 0, 1);
        self->_quat = GLKQuaternionMake(0, 0, 0, 1);
        self->_bigSize = 40;
    }];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UITouch * touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.view];
    
    // 建立锚点
    _anchor_position = GLKVector3Make(location.x, location.y, 0);
    _anchor_position = [self projectOntoSurface:_anchor_position];
    
    _current_position = _anchor_position;
    _quatStart = _quat;
}

- (void)computeIncremental {
    
    // GLKVector3 GLKVector3CrossProduct(GLKVector3 vectorLeft, GLKVector3 vectorRight); 返回两个向量的叉积
    // float GLKVector3DotProduct(GLKVector3 vectorLeft, GLKVector3 vectorRight); 返回两个向量的点积
    GLKVector3 axis = GLKVector3CrossProduct(_anchor_position, _current_position);
    float dot = GLKVector3DotProduct(_anchor_position, _current_position); 
    float angle = acosf(dot);
    
    // 创建一个坐标轴或旋转角度的四元数（quaternion）
    GLKQuaternion Q_rot = GLKQuaternionMakeWithAngleAndVector3Axis(angle * 2, axis);
    Q_rot = GLKQuaternionNormalize(Q_rot);
    
    // 一个四元数乘以另外一个四元数（联合旋转）
    _quat = GLKQuaternionMultiply(Q_rot, _quatStart);
    
}

- (GLKVector3)projectOntoSurface:(GLKVector3)touchPoint
{
    // 计算出z值 r^2 = x^2 + y^2 + z^2
    // float radius = self.view.bounds.size.width/3;
    float radius = self.view.bounds.size.width;
    
    GLKVector3 center = GLKVector3Make(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 0);
    GLKVector3 P = GLKVector3Subtract(touchPoint, center); // 减
    
    // 翻转y轴，因为像素坐标向底部增加
    P = GLKVector3Make(P.x, P.y * -1, P.z);
    
    float radius2 = radius * radius;
    float length2 = P.x*P.x + P.y*P.y;

    if (length2 <= radius2) {
        // 在视图半径范围内
        // 修改单次旋转弧度,P.z越小。旋转越快
        P.z = sqrt(radius2 - length2)/2 /2; // 再除2是为了旋转更快

    }
    else {
        // 在视图半径范围外，拿取离点击最近的点
         P.x *= radius / sqrt(length2);
         P.y *= radius / sqrt(length2);
         P.z = 0;
         
//        P.z = radius2 / (2.0 * sqrt(length2));
//        float length = sqrt(length2 + P.z * P.z);
//        // 返回通过将向量的每个分量除以标量值而创建的新向量。
//        P = GLKVector3DivideScalar(P, length); // 除
    }
    
    // GLKVector3Normalize() 返回通过将输入向量归一化为一段长度创建的新向量1.0。
    return GLKVector3Normalize(P);
}



@end
