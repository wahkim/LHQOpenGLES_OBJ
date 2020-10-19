//
//  ArmoryHelper.h
//  LHQOpenGLES_OBJ
//
//  Created by Xhorse_iOS3 on 2020/5/18.
//  Copyright © 2020 LHQ. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ArmoryHelper : NSObject

// 加载本地文件
+ (NSString *)loadArmoryWithName:(NSString *)name type:(NSString *)type;

// obj
+ (NSString *)loadObjArmoryWithName:(NSString *)name;
// mtl
+ (NSString *)loadMtlArmoryWithName:(NSString *)name;

@end
