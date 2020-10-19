//
//  MtlParser.m
//  LHQOpenGLES_OBJ
//
//  Created by Xhorse_iOS3 on 2020/5/18.
//  Copyright © 2020 LHQ. All rights reserved.
//

#import "MtlParser.h"

using namespace std;

const string MTL_ANO = "#";
const string MTL_NEWMTL = "newmtl";
const string MTL_D = "d";
const string MTL_NS = "Ns";
const string MTL_TR = "Tr";
const string MTL_TF = "Tf";
const string MTL_ILLUM = "illum";
const string MTL_KA = "Ka";
const string MTL_KD = "Kd";
const string MTL_KS = "Ks";
const string MTL_KE = "Ke";

@implementation MtlParser

vector<string> mtl_content;
size_t mtl_size;

int d;
int Ns;
int Tr;
int illum;
mColor Tf;
mColor Ka;
mColor Kd;
mColor Ks;

Material mtmpModel;
vector<Material> mtlModels;

+ (MtlModel)ParserMtlFileWithfileName:(NSString *)fileName
{
    NSString *filePath = [ArmoryHelper loadMtlArmoryWithName:fileName];
    
    string newpath = [filePath UTF8String];

    MtlModel model = parseMtl(newpath);
    
    return model;
}

// 解析mtl
MtlModel parseMtl(string filePath)
{
    MtlModel modelData;
    
    ifstream is;
    is.open(filePath,ios::in);
    
    if(is.good()) {
        
        string line;
        int lineFeedIndex = -1;
        while(!is.eof()) {
            
            getline(is, line);
            lineFeedIndex = (int)line.find("\r");
            
            if(lineFeedIndex != string::npos) {
                // 包含\r
                line = line.replace(line.end()-1,line.end(),"");
            }
            
            parseMtlLine(line);
            line.clear();
        }
    }

    modelData.mtlDatas = mtlModels;
    modelData.mtlCount = (int)mtlModels.size();
    is.close();
    
    return modelData;
}

// 解析每一行
void parseMtlLine(string line)
{
    if(line.find(MTL_ANO) == 0 || line.empty())
    {
        return;
    }
    else if (line.find(MTL_D) == 1) // \t 显示的4个字符
    {
        mtmpModel.d = std::stoi(mtl_getValue(line));
    }
    else if(line.find(MTL_NS) == 1)
    {
        mtmpModel.Ns = std::stoi(mtl_getValue(line));
    }
    else if(line.find(MTL_TR) == 1)
    {
        mtmpModel.Tr = std::stoi(mtl_getValue(line));
    }
    else if(line.find(MTL_TF) == 1)
    {
        mtmpModel.Tf = mtl_getColor(line);
    }
    else if(line.find(MTL_ILLUM) == 1)
    {
        mtmpModel.illum = std::stoi(mtl_getValue(line));
    }
    else if(line.find(MTL_KA) == 1)
    {
        mtmpModel.Ka = mtl_getColor(line);
    }
    else if(line.find(MTL_KD) == 1)
    {
        mtmpModel.Kd = mtl_getColor(line);
    }
    else if(line.find(MTL_KS) == 1)
    {
        mtmpModel.Ks = mtl_getColor(line);
    }
    else if(line.find(MTL_KE) == 1)
    {
        mtmpModel.Ke = mtl_getColor(line);
        mtlModels.push_back(mtmpModel);
    }
    else if(line.find(MTL_NEWMTL) == 0)
    {
        mtmpModel.name = mtl_getValue(line);
    }
}

// 获取数值
std::string mtl_getValue(std::string str)
{
    std::string value;
    mtl_content = mtl_split(str, " ");
    mtl_size = mtl_content.size();
    if (mtl_size != string::npos) {
        value = mtl_content[1];
    }
    return value;
}

mColor mtl_getColor(std::string str)
{
    mColor color;
    mtl_content = mtl_split(str, " ");
    mtl_size = mtl_content.size();
    if (mtl_size != string::npos) {
        float r = std::stof(mtl_content[1]);
        float g = std::stof(mtl_content[2]);
        float b = std::stof(mtl_content[3]);
        color = {r,g,b};
    }
    return color;
}

// 字符串分割pattern，拿取数值
std::vector<std::string> mtl_split(std::string str,std::string pattern)
{
    std::string::size_type pos;
    std::vector<std::string> result;
    str += pattern; // 扩展字符串以方便操作
    int size = (int)str.size();
    for(int i = 0; i < size; i ++)
    {
        pos = str.find(pattern,i);
        if(pos < size)
        {
            std::string s = str.substr(i,pos - i);
            result.push_back(s);
            i = (int)(pos + pattern.size() - 1);
        }
    }
    return result;
}

@end
