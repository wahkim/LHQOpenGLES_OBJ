//
//  OBJView.m
//  LHQOpenGLES_OBJ
//
//  Created by Xhorse_iOS3 on 2020/5/19.
//  Copyright © 2020 LHQ. All rights reserved.
//

#import "OBJView.h"
#import <GLKit/GLKit.h>
#import "ObjParser.h"
#import "ArmoryHelper.h"
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#import "MtlParser.h"
 
using namespace std;

@interface OBJView ()

@property (nonatomic, strong) CAEAGLLayer *eaglLayer;
@property (nonatomic, strong) EAGLContext *eaglContext;
@property (nonatomic, strong) GLKBaseEffect *effect; // 用于设置通用的OpenGL ES环境
@property (nonatomic, strong) ObjParser *objParser;
@property (nonatomic, strong) NSTimer *timer;

@end

@implementation OBJView
{
    GLKView *glview;
    GLuint buffer; // 缓冲
    GLuint _renderBuffer;
    GLuint _frameBuffer;

    int dataCount; // 模型坐标个数
    float *squareVertexData; // 定义数组
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
/*
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        self.backgroundColor = [UIColor grayColor];
        
        [self setupOpenGL];
        [self loadingOBJ:@"13321_1039"];
        
//        [self loadingOBJ:@"8788"];
//
//        [self createProgram];
//        [self setupVBO];
//
//        [self render];
    }
    return self;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (void)setupOpenGL {
    
    _eaglLayer = (CAEAGLLayer *) self.layer;
    _eaglLayer.opaque = YES;
    
    _eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @YES,
                                      kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
    
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:_eaglContext];

    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    glClearColor(0, 1, 1, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [_eaglContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];

    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    
    self.effect = [[GLKBaseEffect alloc]init];
    self.effect.light0.enabled = GL_TRUE;
    self.effect.light0.diffuseColor = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
    self.effect.light0.position = GLKVector4Make(41, 42, 47, 1.0);
    
}

#pragma mark - load OBJ

- (void)loadingOBJ:(NSString*)fileName
{
    self.objParser = [[ObjParser alloc] init];
    VertexInfo info = [self.objParser ParserObjFileWithfileName:fileName];
    //    VertexInfo pro = [ObjParser ParserObjFileWithfileName:fileName];

        self->squareVertexData = info.squareVertexData;
        self->faceNum          = info.faceNum;
        self->mtlcModel        = info.materialDatas;
        self->mFaceNum         = info.materialFaceCount;
        self->useMtCount       = info.useMtlCount;
        self->useMtlNames      = info.useMtls;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self render];
        });
    
}

- (void)render {
    
    dataCount  = (int)(faceNum * 3);

      // 顶点数组保存进缓冲区
      glGenBuffers(1, &buffer);
      glBindBuffer(GL_ARRAY_BUFFER, buffer); // faceNum*24*4
      glBufferData(GL_ARRAY_BUFFER, faceNum * 3 * 8 * sizeof(GLfloat), squareVertexData, GL_STATIC_DRAW);

      // 顶点坐标
      glEnableVertexAttribArray(GLKVertexAttribPosition);
      glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 0);
    
      // 法线
      glEnableVertexAttribArray(GLKVertexAttribNormal);
      glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 3 * sizeof(GLfloat));
      
      // 纹理
      glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
      glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 6 * sizeof(GLfloat));
    
    glClearColor(131/255.0, 166/255.0, 205/255.0, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    int first = 0;
    for (int i = 0; i < useMtCount; i ++) {

        std::string name = useMtlNames[i];

        for (int j = 0; j < mtlcModel.mtlDatas.size(); j ++) {
            Material m = mtlcModel.mtlDatas[j];
            if (m.name == name) {
                self.effect.material.ambientColor = GLKVector4Make(m.Ka.r, m.Ka.g, m.Ka.b, 1.0); // 环境光
                self.effect.material.diffuseColor = GLKVector4Make(m.Kd.r, m.Kd.g, m.Kd.b, 1.0); // 漫射光
                self.effect.material.specularColor = GLKVector4Make(m.Ks.r, m.Ks.g, m.Ks.b, 1.0); // 反射光
            }
        }

        if (i > 0) {
            first += mFaceNum[i - 1];
        }

        [self.effect prepareToDraw];
        glDrawArrays(GL_TRIANGLES, first, mFaceNum[i]);


    }
    [self.eaglContext presentRenderbuffer:GL_RENDERBUFFER];
    
//        [self.effect prepareToDraw];
//        glDrawArrays(GL_TRIANGLES, 0, dataCount);
//    [self.eaglContext presentRenderbuffer:GL_RENDERBUFFER];
//    if (!self.timer) {
//        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(onRes) userInfo:nil repeats:YES];
//    }
}

- (void)onRes {
    
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
                self.effect.material.specularColor = GLKVector4Make(m.Ks.r, m.Ks.g, m.Ks.b, 1.0); // 反射光
            }
        }

        if (i > 0) {
            first += mFaceNum[i - 1];
        }

        [self.effect prepareToDraw];
        glDrawArrays(GL_TRIANGLES, first, mFaceNum[i]);
        [self.eaglContext presentRenderbuffer:GL_RENDERBUFFER];

    }
}

- (void)dealloc {
    
    if ([self.timer isValid]) {
        [self.timer invalidate];
        self.timer = nil;
    }
}
 */

@end
