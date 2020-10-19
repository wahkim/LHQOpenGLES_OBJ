//
//  OBJViewController_1.m
//  LHQOpenGLES_OBJ
//
//  Created by Xhorse_iOS3 on 2020/5/19.
//  Copyright © 2020 LHQ. All rights reserved.
//

#import "OBJViewController_1.h"
#import "OBJView.h"
#import <GLKit/GLKit.h>
#import "ObjParser.h"
#import "ArmoryHelper.h"
#import "MtlParser.h"
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>

using namespace std;

@interface OBJViewController_1 () <GLKViewDelegate>

@property (nonatomic, strong) GLKView *objView;
@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) CAEAGLLayer *glLayer;
@property (nonatomic, assign) GLuint framebuffer;
@property (nonatomic, assign) GLuint colorRenderbuffer;
@property (nonatomic, assign) GLint framebufferWidth;
@property (nonatomic, assign) GLint framebufferHeight;
@property (nonatomic, strong) GLKBaseEffect *effect;

@property (nonatomic, strong) ObjParser *objParser;

@end

@implementation OBJViewController_1
{
    GLuint buffer;//缓冲
    
    int dataCount; // 模型坐标个数
    float *squareVertexData; // 定义数组 原数据
    float *preSquareVertexData; // 处理后的数据
    struct MtlModel mtlcModel;
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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.objView = [[GLKView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    self.objView.center = self.view.center;
    self.objView.delegate = self;
    [self.view addSubview:self.objView];
    
    _rotate = 0;
    _bigSize = 40.0; // 控制模型大小（1-180）
    _rotMatrix = GLKMatrix4Identity;
    _quat = GLKQuaternionMake(0, 0, 0, 1);
    _quatStart = GLKQuaternionMake(0, 0, 0, 1);
    _slerping = YES;
    
    
    //set up context
     self.glContext = [[EAGLContext alloc] initWithAPI: kEAGLRenderingAPIOpenGLES2];
     [EAGLContext setCurrentContext:self.glContext];
     glEnable(GL_DEPTH_TEST);//激活深度检测
    //set up layer
    self.glLayer = [CAEAGLLayer layer];
    self.glLayer.frame = self.objView.bounds;
    self.glLayer.opaque = YES;
    [self.objView.layer addSublayer:self.glLayer];
    self.glLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking:@NO, kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};
    
    
    //set up base effect
    self.effect = [[GLKBaseEffect alloc] init];
    self.effect.light0.enabled = GL_TRUE;
    self.effect.light0.diffuseColor = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
    self.effect.light0.position = GLKVector4Make(41, 42, 47, 1.0);
    //set up buffers
    [self setUpBuffers];
    
    [self loadingOBJ:@"12174_79"];
    
//    //draw frame
//    [self drawFrame];
    
}

- (void)dealloc {
    
    if (_framebuffer) {
         //delete framebuffer
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }

    if (_colorRenderbuffer) {
        //delete color render buffer
        glDeleteRenderbuffers(1, &_colorRenderbuffer);
         _colorRenderbuffer = 0;
    }
    [EAGLContext setCurrentContext:nil];
    
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    NSLog(@"1");
}

#pragma mark - load OBj

- (void)loadingOBJ:(NSString*)fileName
{
    __weak typeof(self) weakself = self;
    self.objParser = [[ObjParser alloc] init];
    VertexInfo info = [self.objParser ParserObjFileWithfileName:fileName];

    self->squareVertexData = info.squareVertexData;

    self->faceNum          = info.faceNum;
    self->mtlcModel        = info.materialDatas;
    self->mFaceNum         = info.materialFaceCount;
    self->useMtCount       = info.useMtlCount;
    self->useMtlNames      = info.useMtls;
    self->preSquareVertexData = new float[faceNum * 3 * 8];
    memcpy(self->preSquareVertexData, info.squareVertexData, faceNum * 3 * 8* sizeof(GLfloat));

    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self drawFrame];
        
    });
    
    [self.objParser changeVertex];
}

- (void)setUpBuffers
{
     //set up frame buffer
     glGenFramebuffers(1, &_framebuffer);
     glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);

     //set up color render buffer
     glGenRenderbuffers(1, &_colorRenderbuffer);
     glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
     glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderbuffer);
     [self.glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.glLayer];
     glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_framebufferWidth);
     glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_framebufferHeight);

     //check success
     if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
         NSLog(@"Failed to make complete framebuffer object: %i", glCheckFramebufferStatus(GL_FRAMEBUFFER));
     }
}

- (void)drawFrame {
    glClearColor(131/255.0, 166/255.0, 205/255.0, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer); // faceNum*24*4
    glBufferData(GL_ARRAY_BUFFER, faceNum* 3 * 8 * sizeof(GLfloat), preSquareVertexData, GL_STATIC_DRAW);
       
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _framebufferWidth, _framebufferHeight);
    // 顶点坐标
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 0);
         
    // 法线
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 3 * sizeof(GLfloat));
       
    // 纹理
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 6 * sizeof(GLfloat));

//    [self.effect prepareToDraw];
//    glDrawArrays(GL_TRIANGLES, 0, faceNum*3);
    
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
    
    //present render buffer
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
    [self.glContext presentRenderbuffer:GL_RENDERBUFFER];
    
//    _rotate += 1.0f;
//    // 投影矩阵
//    // GLKMathDegreesToRadians值越大，模型越小(0-180)
//    CGSize size = self.view.bounds.size;
//    float aspect = fabs(size.width / size.height);
//    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(_bigSize), aspect, 1.0f, 10.0f);
//    self.effect.transform.projectionMatrix = projectionMatrix;
//
//    // 模型矩阵
//    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
//    modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, 0.0f, 0.0f, -6.0f); //平移
//
//    // 模型复原
//    if (_slerping) {
//        //获得动画目前所处的进度
//        _slerpCur += 0; // self.timeSinceLastUpdate;
//        float slerpAmt = _slerpCur / _slerpMax;
//        if (slerpAmt > 1.0) {
//
//            slerpAmt = 1.0;
//        }
//
//        // 计算出slerpStart和slerpEnd之间的合适的旋转角度
//        // GLKQuaternionSlerp 返回两个四元数的球面线性插值
//        _quat = GLKQuaternionSlerp(_slerpStart, _slerpEnd, slerpAmt);
//
//        // 旋转
//        modelViewMatrix = GLKMatrix4RotateX(modelViewMatrix, 0);
//        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, GLKMathDegreesToRadians(_rotate));
//        modelViewMatrix = GLKMatrix4RotateZ(modelViewMatrix, 0);
//    }
//    else
//    {
//        // 拖拽视图的视角
//        GLKMatrix4 rotation = GLKMatrix4MakeWithQuaternion(_quat); // 把quaternion 四元数转换成一个旋转矩阵
//        modelViewMatrix = GLKMatrix4Multiply(modelViewMatrix, rotation);
//    }
//
//    self.effect.transform.modelviewMatrix = modelViewMatrix;
//
//    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(drawFrame) userInfo:nil repeats:YES];

}

- (void)render {
    /*
    //set up vertices
    GLfloat vertices[] = {
        -0.5f, -0.5f, -1.0f,0.0f, 0.0f, 1.0f, 1.0f,
        0.0f, 0.5f, -1.0f,0.0f, 1.0f, 0.0f, 1.0f,
        0.5f, -0.5f, -1.0f,1.0f, 0.0f, 0.0f, 1.0f,
    };
//    GLfloat vertices[] = {
//        -0.5f, -0.5f, -1.0f, 0.0f, 0.5f, -1.0f, 0.5f, -0.5f, -1.0f,
//    };
//
//     //set up colors
//    GLfloat colors[] = {
//        0.0f, 0.0f, 1.0f, 1.0f, 0.0f, 1.0f, 0.0f, 1.0f, 1.0f, 0.0f, 0.0f, 1.0f,
//    };
    //bind framebuffer & set viewport
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _framebufferWidth, _framebufferHeight);

    // 顶点数组保存进缓冲区
    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer); // faceNum*24*4
    glBufferData(GL_ARRAY_BUFFER,  3 * 8 * sizeof(GLfloat), vertices, GL_STATIC_DRAW);
    //bind shader program
    [self.effect prepareToDraw];
    //clear the screen
    glClear(GL_COLOR_BUFFER_BIT); glClearColor(0.0, 0.0, 0.0, 1.0);


     //draw triangle
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glEnableVertexAttribArray(GLKVertexAttribColor);
//    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, vertices);
//    glVertexAttribPointer(GLKVertexAttribColor,4, GL_FLOAT, GL_FALSE, 0, colors);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 7, 0);
    glVertexAttribPointer(GLKVertexAttribColor,4, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 7, (char *)NULL + 3 * sizeof(GLfloat));
    glDrawArrays(GL_TRIANGLES, 0, 3);
    */
    
//    GLuint buffer;
//    glGenBuffers(1, &buffer);
//    glBindBuffer(GL_ARRAY_BUFFER, buffer); // faceNum*24*4
//    glBufferData(GL_ARRAY_BUFFER,  3 * 8 * sizeof(GLfloat), preSquareVertexData, GL_STATIC_DRAW);
//
//    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
//    glViewport(0, 0, _framebufferWidth, _framebufferHeight);
//    // 顶点坐标
//        glEnableVertexAttribArray(GLKVertexAttribPosition);
//        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 0);
//
//        // 法线
//        glEnableVertexAttribArray(GLKVertexAttribNormal);
//        glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 3 * sizeof(GLfloat));
//    //
//    //    // 纹理
//        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
//        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 8, (char *)NULL + 6 * sizeof(GLfloat));
//
//    //present render buffer
//    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
//    [self.glContext presentRenderbuffer:GL_RENDERBUFFER];
    
    glClearColor(131/255.0, 166/255.0, 205/255.0, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
//    int first = 0;
//    for (int i = 0; i < useMtCount; i ++) {
//
//        std::string name = useMtlNames[i];
//
//        for (int j = 0; j < mtlcModel.mtlDatas.size(); j ++) {
//            Material m = mtlcModel.mtlDatas[j];
//            if (m.name == name) {
//                self.effect.material.ambientColor = GLKVector4Make(m.Ka.r, m.Ka.g, m.Ka.b, 1.0); // 环境光
//                self.effect.material.diffuseColor = GLKVector4Make(m.Kd.r, m.Kd.g, m.Kd.b, 1.0); // 漫射光
//                self.effect.material.specularColor = GLKVector4Make(m.Ks.r, m.Ks.g, m.Ks.b, 1.0); // 反射光
//            }
//        }
//
//        if (i > 0) {
//            first += mFaceNum[i - 1];
//        }
//
//        [self.effect prepareToDraw];
//        glDrawArrays(GL_TRIANGLES, first, mFaceNum[i]);
//
//    }
    
    [self.effect prepareToDraw];
    glDrawArrays(GL_TRIANGLES, 0, (int)(faceNum*3));
}



@end
