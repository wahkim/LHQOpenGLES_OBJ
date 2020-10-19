//
//  ObjParser.h
//  LHQOpenGLES_OBJ
//
//  Created by Xhorse_iOS3 on 2020/5/16.
//  Copyright © 2020 LHQ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MtlParser.h"
#include <iomanip>
#include <iostream>
#include <fstream>
#include <sstream>
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#import "ArmoryHelper.h"
/**
 *************** obj文件 ****************
 mtllib 8788.mtl  使用的mtl文件
 
 v 顶点坐标（x，y，z）
 vt 顶点纹理坐标（u，v）
 vn 顶点法线坐标
 
 f 三角面 （顶点索引/uv索引/法线索引 顶点索引/uv索引/法线索引 顶点索引/uv索引/法线索引）
 
 
 *************** mtl文件 ****************
 
 - newmtl wire_214229166 材质名
 
 - Ns 32 反射指数
   指定材质的反射指数，定义了反射高光度。
   exponent是反射指数值，该值越高则高光越密集，一般取值范围在0~1000
 
 - d 1 渐隐指数 （参数factor表示物体融入背景的数量，取值范围为0.0~1.0，取值为1.0表示完全不透明，取值为0.0时表示完全透明。当新创建一个物体时，该值默认为1.0，即无渐隐效果。
 与真正的透明物体材质不一样，这个渐隐效果是不依赖于物体的厚度或是否具有光谱特性。该渐隐效果对所有光照模型都有效。）
 
 - Tr 0
 - Tf 1 1 1 滤光透射率
    三种格式
    Tf r g b
    Tf spectral file.rfl factor
    Tf xyz x y z
 
 - illum 2 光照模式，0 禁止光照 ，1 只有环境光和漫反射光，2 所有的光照启用
 - Ka 0.8392 0.8980 0.6510  环境光颜色
 - Kd 0.8392 0.8980 0.6510 漫反射颜色
 - Ks 0.3500 0.3500 0.3500 高光颜色
 
 - map_Ka 为环境反射指定颜色纹理文件(.mpc)或程序纹理文件(.cxc)，或是一个位图文件。在渲染的时候，Ka的值将再乘上map_Ka的值
 - map_Kd key.bmp  为漫反射指定颜色纹理文件(.mpc)或程序纹理文件(.cxc)，或是一个位图文件。作用原理与可选参数与map_Ka同
 - map_bump key.bmp
 - bump key.bmp 为材质指定凹凸纹理文件（.mpb或.cxb）,或是一个位图文件
 
 */

struct VertexInfo
{
    float *squareVertexData; // 有关顶点的全部数据 （顶点、纹理、法线）
    int   faceNum;

    int useMtlCount; // 使用到的mtl数量
    MtlModel materialDatas; // 数组记录多个材质
    int *materialFaceCount; // 数组记录每个材质多少个面
    std::vector<std::string> useMtls; // 使用到的材质名称数组
};


@interface ObjParser : NSObject

- (VertexInfo)ParserObjFileWithfileName:(NSString *)fileName;

- (void)changeVertex;

- (float)getModelScale;

@end

