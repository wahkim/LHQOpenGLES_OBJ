//
//  MtlParser.h
//  LHQOpenGLES_OBJ
//
//  Created by Xhorse_iOS3 on 2020/5/18.
//  Copyright © 2020 LHQ. All rights reserved.
//

#import <Foundation/Foundation.h>
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

struct mColor
{
    float r;
    float g;
    float b;
};

struct Material
{
    std::string name;
    int Ns;
    int d;
    int Tr;
    mColor Tf;
    int illum;
    
    mColor Ka;
    mColor Kd;
    mColor Ks;
    mColor Ke;
};

struct MtlModel
{
//    Material *mtlDatas; // 数组记录多个材质
//    vector<Material> mtlDatas;
    std::vector<Material> mtlDatas;
    int mtlCount; // 几个mtl
};



@interface MtlParser : NSObject



+ (MtlModel)ParserMtlFileWithfileName:(NSString *)fileName;

@end

