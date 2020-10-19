//
//  ArmoryHelper.m
//  LHQOpenGLES_OBJ
//
//  Created by Xhorse_iOS3 on 2020/5/18.
//  Copyright © 2020 LHQ. All rights reserved.
//

#import "ArmoryHelper.h"

@implementation ArmoryHelper

+ (NSString *)loadArmoryWithName:(NSString *)name type:(NSString *)type
{
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:type];
    return path;
}

+ (NSString *)loadObjArmoryWithName:(NSString *)name
{
    NSString *path = [ArmoryHelper loadArmoryWithName:name type:@"obj"];
    return path;
}

+ (NSString *)loadMtlArmoryWithName:(NSString *)name
{
    NSString *path = [ArmoryHelper loadArmoryWithName:name type:@"mtl"];
    return path;
}

@end
