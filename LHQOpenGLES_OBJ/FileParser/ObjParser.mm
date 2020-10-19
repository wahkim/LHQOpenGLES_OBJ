//
//  ObjParser.m
//  LHQOpenGLES_OBJ
//
//  Created by Xhorse_iOS3 on 2020/5/16.
//  Copyright © 2020 LHQ. All rights reserved.
//

#import "ObjParser.h"

/**
 遇到的问题：
 一：解析
 1. 文件内有中文字符，编码格式设置为UTF8，导致获取文件内容string为nil
 2. 获取到的顶点坐标(x,y,z)、纹理坐标(u,v)数值不在[-1,1]区间内 （法线坐标也可能不在）
 
 二：显示
 1. 由于钥匙胚需要倒立显示 所以所有数据都*（-1）。
 2. 解析时按比例重新计算了坐标，需保留比例值
 */


using namespace std;

@implementation ObjParser

vector<float> vertexVArray;
vector<string> temp;
size_t size;

vector<string> vLines;
vector<string> vtLines;
vector<string> vnLines;

vector<string> indexV;
vector<string> vinfoV;

float *squareVertexData; // 全部顶点数据 顶点\纹理\法线
int *materialFaceCount; // 每种材质对应多少面
int facetNum; //
MtlModel mtl_model;
int mFaceNum; // 每个材质多少面计算
vector<int> mFaces;
std::vector<std::string> useMtlNames;

float modelScale;

const string OBJ_ANO = "#";
const string OBJ_VERTEX = "v"; // 顶点
const string OBJ_TEXTURE = "vt"; // 贴图
const string OBJ_NORMAL = "vn"; // 法线
const string OBJ_FACET = "f"; // 面
const string OBJ_MTLLIB = "mtllib"; // mtl文件
const string OBJ_USEMTL = "usemtl"; // mtl文件内容对应材质

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (VertexInfo)ParserObjFileWithfileName:(NSString *)fileName
{
    NSString *filePath = [ArmoryHelper loadObjArmoryWithName:fileName];

    string newpath = [filePath UTF8String];
    
    VertexInfo model = parseObj(newpath);
    
    return model;
}

// 解析obj
VertexInfo parseObj(string filePath)
{
    VertexInfo modelData;
    facetNum = 0;
    mFaceNum = 0;
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
            
            parseObjLine(line);
            line.clear();
        }
        
        mFaces.push_back(mFaceNum);
        
        vectorTofloat();
        computeAdaptSquareVertex();
    }
    
    materialFaceCount = (int *)malloc(mFaces.size()*sizeof(int));
    for (int i = 0; i < mFaces.size(); i++) {
        materialFaceCount[i] = mFaces[i] * 3;
    }
    
    modelData = {
        squareVertexData,
        facetNum,
        (int)useMtlNames.size(),
        mtl_model,
        materialFaceCount,
        useMtlNames,
    };
    
    cout<<"facetNum: "<<facetNum<<endl;
    cout<<"parseObj end"<<endl;
    cout<<"mFaces: "<<mFaces.size()<<endl;
    
//    for (int i = 0; i < facetNum * 3 *8; i += 8) {
//        cout<<"squareVertexData:x "<<squareVertexData[i]<<endl;
//        cout<<"squareVertexData:y "<<squareVertexData[i+1]<<endl;
//        cout<<"squareVertexData:z "<<squareVertexData[i+2]<<endl;
//    }
    
    
    is.close();
    
    // 数据一定要clear掉，不然你会发现人生多艰难
    vLines.clear();
    vtLines.clear();
    vnLines.clear();
    vertexVArray.clear();
    mFaces.clear();
    useMtlNames.clear();

    return modelData;
}

// 解析每一行
void parseObjLine(string line)
{
    if(line.find(OBJ_ANO) == 0 || line.empty())
    {
        return;
    }
    else if (line.find(OBJ_NORMAL) == 0)
    {
        vnLines.push_back(line);
    }
    else if(line.find(OBJ_TEXTURE) == 0)
    {
        vtLines.push_back(line);
    }
    else if(line.find(OBJ_VERTEX) == 0)
    {
        vLines.push_back(line);
    }
    else if(line.find(OBJ_FACET) == 0)
    {
        parseObjFacet(line);
    }
    else if(line.find(OBJ_MTLLIB) == 0)
    {
        parsercMtl(line);
    }
    else if(line.find(OBJ_USEMTL) == 0)
    {
        parseObjUseMtl(line);
    }
}

// 解析obj useMtl
void parseObjUseMtl(string line)
{
    vinfoV = split(line, " ");
    size = vinfoV.size();
    if(size != string::npos) {
        useMtlNames.push_back(vinfoV[1]);
    }
    
    if (mFaceNum == 0) {
        return;
    }
    mFaces.push_back(mFaceNum);
    mFaceNum = 0;
}

// 解析obj面 f行
void parseObjFacet(string line)
{
    vinfoV = split(line, " ");
    size = vinfoV.size();
    if(size != string::npos && size >= 3) {
        for(int i = 1; i < size; i ++) {
            indexV = split(vinfoV[i],"/");
            size = indexV.size();
            if(size != string::npos && size == 3) {
                // vertex
                parseObjVertexOrNormal(atoi(indexV[0].c_str()) - 1,true);
                // vn
                parseObjVertexOrNormal(atoi(indexV[2].c_str()) - 1,false);
                // vt
                parseObjTexture(atoi(indexV[1].c_str()) - 1);
            }
        }
        line.clear();
        facetNum ++;
        mFaceNum ++;
    }
}

// 解析obj的纹理
void parseObjTexture(int index) {
    size = vtLines.size();
    if(size == 0){
        appendEmptyVt();
    }else{
        string line = vtLines[index];
        if(!line.empty()){
            temp = split(line, " ");
            size = temp.size();
            if(size != string::npos && size >= 2){
                vertexVArray.push_back(atof(temp[size - 2].c_str()));
                vertexVArray.push_back(atof(temp[size - 1].c_str()));
            }
        }
    }
}

// 没有纹理时添加默认值
void appendEmptyVt() {
    vertexVArray.push_back(1.0);
    vertexVArray.push_back(1.0);
}

// 解析obj的v和vn
void parseObjVertexOrNormal(int index,bool isVertex)
{
    string line = isVertex ? vLines[index] : vnLines[index];
    if(!line.empty()) {
        temp = split(line, " ");
        size = temp.size();
        if(size != string::npos && size >= 3) {
            vertexVArray.push_back(atof(temp[size - 3].c_str()));
            vertexVArray.push_back(atof(temp[size - 2].c_str()));
            vertexVArray.push_back(atof(temp[size - 1].c_str()));
        }
    }
}

// 字符串分割pattern，拿取数值
std::vector<std::string> split(std::string str,std::string pattern)
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

// 转换数据源
// * (-1) 实现倒置效果
void vectorTofloat() {
    cout<<"vertexArray size:"<<vertexVArray.size()<<endl;
    squareVertexData = (float *)malloc(vertexVArray.size()*sizeof(float));
    for (int i = 0; i < vertexVArray.size(); i++) {
//        squareVertexData[i] = vertexVArray[i] * (-1);
        squareVertexData[i] = vertexVArray[i];
    }
}

// 适配（文件里面的数据超出范围）
void computeAdaptSquareVertex()
{
    // 定义出6个变量用于储存最小和最大的xyz
    float xMax = squareVertexData[0];
    float yMax = squareVertexData[1];
    float zMax = squareVertexData[2];
    
    float xMin = squareVertexData[0];
    float yMin = squareVertexData[1];
    float zMin = squareVertexData[2];

    NSLog(@"点个数:%d",facetNum*24);
    // 循环获取最小最大xyz
    for (int i = 0; i < facetNum * 24; i ++) {
        
        if ((i + 1) % 8 == 1)
        {
            if (squareVertexData[i] > xMax) {
                xMax = squareVertexData[i];
            }
            
            if (squareVertexData[i] < xMin)
            {
                xMin = squareVertexData[i];
            }
        }
        else if ((i + 1) % 8 == 2)
        {
            if (squareVertexData[i] > yMax) {
                yMax = squareVertexData[i];
            }
            
            if (squareVertexData[i] < yMin)
            {
                yMin = squareVertexData[i];
            }
        }
        else if ((i + 1) % 8 == 3)
        {
            if (squareVertexData[i] > zMax) {
                zMax = squareVertexData[i];
            }
            
            if (squareVertexData[i] < zMin)
            {
                zMin = squareVertexData[i];
            }
        }
        
    }
    
    
    NSLog(@"xyz最小：%f,%f,%f",xMin,yMin,zMin);
    NSLog(@"xyz最大：%f,%f,%f",xMax,yMax,zMax);
    NSLog(@"中心点坐标为:%f,%f,%f",(xMax-xMin)/2+xMin,(yMax-yMin)/2+yMin,(zMax-zMin)/2+zMin);

    //求出最长的长径
    float diameter = -200.0;
    
    if ((xMax - xMin) >= (yMax - yMin) && (xMax - xMin) >= (zMax - zMin)) {
        diameter = xMax-xMin;
    }
    if ((yMax - yMin) >= (xMax - xMin) && (yMax - yMin) >= (zMax - zMin)) {
        diameter = yMax-yMin;
    }
    if ((zMax - zMin) >= (yMax - yMin) && (xMax - xMin) <= (zMax - zMin)) {
        diameter = zMax - zMin;
    }
    
    NSLog(@"最长的长径：%f",diameter);
    
    // 算出一个合适的比例展示模型
    float scale = 2.0 / diameter;
    modelScale = scale;
    
    float midX,midY,midZ;
    midX = (xMax - xMin) /2 + xMin;
    midY = (yMax - yMin) / 2 + yMin;
    midZ = (zMax - zMin) /2 + zMin;

    for (int i = 0; i < facetNum * 24; i ++) {
        float tem = squareVertexData[i];
        if ((i + 1) % 8 == 1) {
            squareVertexData[i] = (tem - midX)*scale;
        }
        else if((i + 1) % 8 == 2)
        {
            squareVertexData[i] = (tem - midY)*scale;
        }
        else if (( i + 1) % 8 == 3)
        {
            squareVertexData[i] = (tem - midZ)*scale;
        }
        else
        {
            squareVertexData[i] = tem;
        }
        
    }
}

#pragma mark - MTL

void parsercMtl(string line)
{
    vinfoV = split(line, " ");
    size = vinfoV.size();
    if (size != string::npos) {
        
        vector<string> tmp = split(vinfoV[1], ".");
        size_t size1 = tmp.size();
        if (size1 != string::npos) {
            NSString *mtlname = [NSString stringWithCString:tmp[0].c_str() encoding:[NSString defaultCStringEncoding]];

            mtl_model = [MtlParser ParserMtlFileWithfileName:mtlname];
        }
        
    }
}

#pragma mark - Change Vertex

- (float)getModelScale
{
    return modelScale;
}


- (void)changeVertex
{
    NSLog(@"modelScale = %f",modelScale);
}

@end
